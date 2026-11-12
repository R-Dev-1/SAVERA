#include "wifi_mgr.h"
#include <WiFi.h>
#include <ESPmDNS.h>
#include <DNSServer.h>
#include <esp_random.h>
#include <Preferences.h>
#include <time.h>
#include "config.h"
#include "app_state.h"
#include "clock_rtc.h"
#include "web_api.h"
#include "power_diag.h"

static Preferences prefs;
static char g_ssid[33] = "", g_pass[65] = "";
static bool g_iplock = true;
static volatile bool g_reqConnect = false, g_reqScan = false, g_reqForget = false;
static bool g_connected = false, g_connecting = false, g_usingStatic = false, g_webStarted = false;
static uint32_t g_attemptStart = 0, g_lastFail = 0, g_lastRssi = 0, g_lastSync = 0;
static bool g_ntpPending = false, g_scanning = false;

static WifiScanItem g_scan[20];
static int g_scanN = 0;
static uint32_t g_scanSeq = 0;

// ---------- util NVS: IP statis per SSID ----------
static void staticKey(char* out) {
  uint32_t h = 2166136261u;
  for (const char* p = g_ssid; *p; p++) { h ^= (uint8_t)*p; h *= 16777619u; }
  snprintf(out, 12, "n%08lx", (unsigned long)h);
}

static bool loadStatic(IPAddress& ip, IPAddress& gw, IPAddress& mask, IPAddress& dns) {
  char key[12]; staticKey(key);
  String v = prefs.getString(key, "");
  if (v.length() < 7) return false;
  int a = v.indexOf(','), b = v.indexOf(',', a + 1), c = v.indexOf(',', b + 1);
  if (a < 0 || b < 0 || c < 0) return false;
  return ip.fromString(v.substring(0, a)) && gw.fromString(v.substring(a + 1, b)) &&
         mask.fromString(v.substring(b + 1, c)) && dns.fromString(v.substring(c + 1));
}

static void saveStatic() {
  char key[12]; staticKey(key);
  String v = WiFi.localIP().toString() + "," + WiFi.gatewayIP().toString() + "," +
             WiFi.subnetMask().toString() + "," + WiFi.dnsIP().toString();
  prefs.putString(key, v);
}

static void eraseStatic() { char key[12]; staticKey(key); prefs.remove(key); }

// ---------- koneksi ----------
static void setWifiState(WifiState s) { StateLock l; g_state.wifi = s; }

static void beginConnect(bool allowStatic) {
  IPAddress ip, gw, mask, dns;
  WiFi.disconnect(false);
  if (allowStatic && g_iplock && loadStatic(ip, gw, mask, dns)) { WiFi.config(ip, gw, mask, dns); g_usingStatic = true; }
  else { WiFi.config(IPAddress(0, 0, 0, 0), IPAddress(0, 0, 0, 0), IPAddress(0, 0, 0, 0)); g_usingStatic = false; }
  WiFi.setHostname(DEVICE_NAME);
  WiFi.begin(g_ssid, g_pass);
  g_attemptStart = millis();
  g_connecting = true;
  setWifiState(WIFI_ST_CONNECTING);
  { StateLock l; strlcpy(g_state.ssid, g_ssid, sizeof g_state.ssid); }
}

static void onConnected() {
  g_connecting = false;
  if (g_iplock && !g_usingStatic) saveStatic();           // ingat IP ini untuk jaringan ini
  WiFi.setSleep(WIFI_POWER_SAVE ? true : false);
  {
    StateLock l;
    g_state.wifi = WIFI_ST_CONNECTED;
    strlcpy(g_state.ssid, g_ssid, sizeof g_state.ssid);
    strlcpy(g_state.ip, WiFi.localIP().toString().c_str(), sizeof g_state.ip);
    g_state.rssi = WiFi.RSSI();
  }
  MDNS.end();
  if (MDNS.begin(DEVICE_NAME)) {
    MDNS.addService("http", "tcp", HTTP_PORT);
    MDNS.addService(MDNS_SERVICE_NAME, "tcp", HTTP_PORT);
    MDNS.addServiceTxt(MDNS_SERVICE_NAME, "tcp", "name", DEVICE_NAME);
    MDNS.addServiceTxt(MDNS_SERVICE_NAME, "tcp", "id", WiFi.macAddress().c_str());
    MDNS.addServiceTxt(MDNS_SERVICE_NAME, "tcp", "fw", FW_VERSION);
    MDNS.addServiceTxt(MDNS_SERVICE_NAME, "tcp", "api", "/api/data");
  }
  configTzTime(TZ_POSIX, NTP_SERVER_1, NTP_SERVER_2);
  g_ntpPending = true;
  Serial.printf("[WIFI] terhubung %s  IP %s  (%s)\n", g_ssid, WiFi.localIP().toString().c_str(), g_usingStatic ? "IP tetap" : "DHCP");
}

static void doScan() {
  int r = WiFi.scanComplete();
  if (!g_scanning) { WiFi.scanDelete(); WiFi.scanNetworks(true); g_scanning = true; return; }
  if (r == WIFI_SCAN_RUNNING) return;
  g_scanning = false;
  if (r < 0) { g_scanN = 0; g_scanSeq++; WiFi.scanDelete(); return; }       // gagal: tampilkan "tidak ada jaringan", jangan menggantung
  int n = 0;
  for (int i = 0; i < r && n < 20; i++) {
    String s = WiFi.SSID(i);
    if (s.length() == 0) continue;
    bool dup = false;
    for (int k = 0; k < n; k++) if (s == g_scan[k].ssid) dup = true;
    if (dup) continue;
    strlcpy(g_scan[n].ssid, s.c_str(), sizeof g_scan[n].ssid);
    g_scan[n].rssi = WiFi.RSSI(i);
    g_scan[n].secure = WiFi.encryptionType(i) != WIFI_AUTH_OPEN;
    n++;
  }
  WiFi.scanDelete();
  g_scanN = n; g_scanSeq++;
}


// ===================== PAIRING LEWAT HP =====================
static DNSServer g_dns;
static portMUX_TYPE g_provMux = portMUX_INITIALIZER_UNLOCKED;
static ProvInfo P;
static bool g_provActive = false;
static volatile uint8_t g_provCmd = 0;                 // 1 = mulai, 2 = berhenti (perintah terakhir menang)
static volatile bool g_pcReq = false;
static char g_pcSsid[33], g_pcPass[65];
static uint32_t g_provT0 = 0, g_provConnT0 = 0, g_provOkT = 0;

static void provSet(ProvState st, const char* msg = nullptr) {
  portENTER_CRITICAL(&g_provMux);
  P.st = st;
  if (msg) strlcpy(P.msg, msg, sizeof P.msg);
  portEXIT_CRITICAL(&g_provMux);
}

static void provBegin() {
  crumb(CR_NET, "prov-begin");
  uint8_t mac[6]; WiFi.macAddress(mac);
  uint32_t r = esp_random() % 100000000UL;
  portENTER_CRITICAL(&g_provMux);
  memset(&P, 0, sizeof P);
  snprintf(P.ap_ssid, sizeof P.ap_ssid, "%s%02X%02X", PROV_AP_PREFIX, mac[4], mac[5]);
  snprintf(P.pin, sizeof P.pin, "%0*lu", PROV_PIN_DIGITS, (unsigned long)(r % 100000000UL));
  P.pin[PROV_PIN_DIGITS] = 0;
  P.st = PROV_OFF;                                   // "menyiapkan": berubah setelah AP benar-benar aktif
  portEXIT_CRITICAL(&g_provMux);

  WiFi.mode(WIFI_AP_STA);
  WiFi.setTxPower(WIFI_TX_POWER);
  bool ok = WiFi.softAP(P.ap_ssid, P.pin, 1, 0, 2);
  if (ok) WiFi.softAPConfig(IPAddress(192, 168, 4, 1), IPAddress(192, 168, 4, 1), IPAddress(255, 255, 255, 0));
  Serial.printf("[PROV] softAP(%s) -> %s, IP AP %s\n", P.ap_ssid, ok ? "OK" : "GAGAL", WiFi.softAPIP().toString().c_str());
  if (!ok) {
    WiFi.mode(WIFI_STA);
    provSet(PROV_FAILED, "AP gagal dimulai. Coba lagi.");
    g_provActive = false;
    return;
  }
  g_dns.start(53, "*", WiFi.softAPIP());            // semua nama domain -> jam (memicu popup captive portal di HP)
  g_provActive = true;
  g_provT0 = millis();
  g_reqScan = true;
  provSet(PROV_WAIT_CLIENT);
  Serial.printf("[PROV] AP aktif: %s  sandi: %s  (http://192.168.4.1)\n", P.ap_ssid, P.pin);
}

static void provEnd() {
  crumb(CR_NET, "prov-end");
  g_dns.stop();
  WiFi.softAPdisconnect(true);
  WiFi.mode(WIFI_STA);
  WiFi.setTxPower(WIFI_TX_POWER);
  g_provActive = false;
  provSet(PROV_OFF);
  g_lastFail = millis() - WIFI_RETRY_INTERVAL_MS;   // lanjutkan sambung otomatis ke jaringan tersimpan
  Serial.println("[PROV] selesai: AP dan halaman pairing ditutup");
}

static uint32_t g_rebootAt = 0;

// Alur: HP mengirim SSID+sandi -> disimpan ke NVS -> jam restart -> saat boot otomatis terhubung ke jaringan itu.
static void provTick() {
  uint32_t now = millis();                            // SELALU baca ulang: nilai 'now' dari pemanggil basi setelah provBegin() (bug lama:
                                                      // selisih negatif jadi sangat besar => sesi dianggap kedaluwarsa dan AP langsung ditutup)
  uint8_t cl = WiFi.softAPgetStationNum();
  int32_t d = (int32_t)(now - g_provT0);
  uint32_t el = d < 0 ? 0 : (uint32_t)d / 1000;
  portENTER_CRITICAL(&g_provMux);
  P.clients = cl;
  ProvState st = P.st;
  P.remain_s = el >= PROV_TIMEOUT_S ? 0 : PROV_TIMEOUT_S - el;
  portEXIT_CRITICAL(&g_provMux);

  if (st == PROV_WAIT_CLIENT && cl > 0) provSet(PROV_CLIENT_JOINED);
  else if (st == PROV_CLIENT_JOINED && cl == 0) provSet(PROV_WAIT_CLIENT);

  if (g_pcReq && st != PROV_REBOOTING) {              // HP mengirim SSID + sandi
    g_pcReq = false;
    strlcpy(g_ssid, g_pcSsid, sizeof g_ssid);
    strlcpy(g_pass, g_pcPass, sizeof g_pass);
    prefs.putString("ssid", g_ssid);
    prefs.putString("pass", g_pass);
    portENTER_CRITICAL(&g_provMux);
    strlcpy(P.target, g_pcSsid, sizeof P.target);
    strlcpy(P.msg, "Data diterima", sizeof P.msg);
    P.st = PROV_REBOOTING;
    portEXIT_CRITICAL(&g_provMux);
    g_rebootAt = now + 2500;                          // beri waktu halaman web & layar menampilkan hasil
    Serial.printf("[PROV] data diterima untuk \"%s\": restart lalu terhubung\n", g_ssid);
  }
  if (st == PROV_REBOOTING && now >= g_rebootAt) {
    Serial.println("[PROV] restart...");
    Serial.flush();
    esp_restart();
  }
  if (el >= PROV_TIMEOUT_S && st != PROV_REBOOTING) provEnd();
}

void wifi_prov_start() { g_provCmd = 1; }
void wifi_prov_stop()  { g_provCmd = 2; }
bool wifi_prov_active() { return g_provActive; }

ProvInfo wifi_prov_info() {
  ProvInfo c;
  portENTER_CRITICAL(&g_provMux);
  c = P;
  portEXIT_CRITICAL(&g_provMux);
  return c;
}

bool wifi_prov_submit(const char* ssid, const char* pass, char* err, size_t en) {
  if (!g_provActive) { snprintf(err, en, "mode pairing tidak aktif"); return false; }
  if (!ssid || !ssid[0] || strlen(ssid) > 32) { snprintf(err, en, "SSID tidak valid"); return false; }
  if (pass && pass[0] && (strlen(pass) < 8 || strlen(pass) > 64)) { snprintf(err, en, "sandi harus 8-64 karakter"); return false; }
  if (g_pcReq || wifi_prov_info().st == PROV_REBOOTING) { snprintf(err, en, "data sudah diterima, jam akan restart"); return false; }
  strlcpy(g_pcSsid, ssid, sizeof g_pcSsid);
  strlcpy(g_pcPass, pass ? pass : "", sizeof g_pcPass);
  g_pcReq = true;
  return true;
}

static void jesc(char* out, size_t n, const char* in) {
  size_t j = 0;
  for (; in && *in && j + 7 < n; in++) {
    unsigned char c = (unsigned char)*in;
    if (c == '"' || c == '\\') { out[j++] = '\\'; out[j++] = c; }
    else if (c < 0x20) { j += snprintf(out + j, n - j, "\\u%04x", c); }
    else out[j++] = c;
  }
  out[j] = 0;
}

void wifi_prov_status_json(char* buf, size_t n) {
  ProvInfo i = wifi_prov_info();
  static const char* kN[] = {"off", "waiting", "joined", "rebooting", "failed"};
  char t[100], m[150];
  jesc(t, sizeof t, i.target); jesc(m, sizeof m, i.msg);
  snprintf(buf, n, "{\"state\":\"%s\",\"target\":\"%s\",\"msg\":\"%s\",\"ip\":\"%s\"}", kN[i.st], t, m, i.ip);
}

void wifi_scan_json(char* buf, size_t n) {
  size_t j = snprintf(buf, n, "{\"scanning\":%s,\"nets\":[", wifi_scan_busy() ? "true" : "false");
  for (int i = 0; i < g_scanN && j + 100 < n; i++) {
    char e[100];
    jesc(e, sizeof e, g_scan[i].ssid);
    j += snprintf(buf + j, n - j, "%s{\"ssid\":\"%s\",\"rssi\":%d,\"sec\":%s}", i ? "," : "", e, g_scan[i].rssi, g_scan[i].secure ? "true" : "false");
  }
  if (j + 3 < n) { buf[j++] = ']'; buf[j++] = '}'; buf[j] = 0; }
}

static void net_task(void*) {
  uint32_t lastMgmt = 0;
  for (;;) {
    if (power_is_off()) {                                 // mati lunak: radio dimatikan, task berhenti
      if (g_provActive) provEnd();
      WiFi.disconnect(true);
      WiFi.mode(WIFI_OFF);
      vTaskSuspend(nullptr);
    }
    crumb(CR_NET, "http");
    web_loop();                                           // layani HTTP (tiap ~5 ms)
    if (g_provActive) g_dns.processNextRequest();
    uint32_t now = millis();
    if (now - lastMgmt >= 200) {
      lastMgmt = now;
      crumb(CR_NET, "mgmt");
      { uint8_t cmd = g_provCmd; g_provCmd = 0;
        if (cmd == 1 && !g_provActive) provBegin();
        else if (cmd == 2 && g_provActive) provEnd(); }
      if (g_provActive) provTick();

      if (g_reqForget) {
        g_reqForget = false;
        prefs.remove("ssid"); prefs.remove("pass");
        g_ssid[0] = 0; g_pass[0] = 0;
        WiFi.disconnect(false); g_connected = false; g_connecting = false;
        { StateLock l; g_state.ssid[0] = 0; strcpy(g_state.ip, "-"); }
        setWifiState(WIFI_ST_NOCREDS);
      }
      if (g_reqConnect) {
        g_reqConnect = false;
        g_connected = false;
        beginConnect(false);                              // jaringan baru => DHCP
      }
      if (g_reqScan || g_scanning) { g_reqScan = false; doScan(); }

      if (g_provActive) {
        // sesi pairing: jangan menyambung ulang otomatis (mengganggu AP)
      } else if (!g_ssid[0]) {
        // belum ada kredensial
      } else if (WiFi.status() == WL_CONNECTED) {
        if (!g_connected) { g_connected = true; onConnected(); }
        if (now - g_lastRssi > 2000) { g_lastRssi = now; StateLock l; g_state.rssi = WiFi.RSSI(); }
        if (clock_auto() && g_ntpPending && time(nullptr) > 1700000000) { clock_set_epoch(time(nullptr)); g_ntpPending = false; g_lastSync = now; }
        else if (clock_auto() && !g_ntpPending && now - g_lastSync > 1800000UL && time(nullptr) > 1700000000) { clock_set_epoch(time(nullptr)); g_lastSync = now; }
      } else {
        if (g_connected) {                                // baru saja terputus
          g_connected = false; g_connecting = false; g_lastFail = now - WIFI_RETRY_INTERVAL_MS;
          setWifiState(WIFI_ST_CONNECTING);
        }
        if (g_connecting) {
          uint32_t to = g_usingStatic ? WIFI_STATIC_TIMEOUT_MS : WIFI_CONNECT_TIMEOUT_MS;
          if (now - g_attemptStart > to) {
            if (g_usingStatic) { eraseStatic(); beginConnect(false); }   // IP tetap gagal => balik ke DHCP
            else { g_connecting = false; g_lastFail = now; setWifiState(WIFI_ST_FAILED); }
          }
        } else if (now - g_lastFail >= WIFI_RETRY_INTERVAL_MS) {
          beginConnect(true);
        }
      }
    }
    vTaskDelay(pdMS_TO_TICKS(5));
  }
}

void wifi_init() {
  prefs.begin("wifi", false);
  String s = prefs.getString("ssid", ""), p = prefs.getString("pass", "");
  strlcpy(g_ssid, s.c_str(), sizeof g_ssid);
  strlcpy(g_pass, p.c_str(), sizeof g_pass);
  g_iplock = prefs.getBool("iplock", true);
  { StateLock l; g_state.ip_lock = g_iplock; strlcpy(g_state.ssid, g_ssid, sizeof g_state.ssid); }
  WiFi.persistent(false);
  WiFi.mode(WIFI_STA);
  WiFi.setTxPower(WIFI_TX_POWER);                         // puncak arus TX lebih rendah
  WiFi.setAutoReconnect(false);
  WiFi.setHostname(DEVICE_NAME);
  g_lastFail = millis() + WIFI_START_DELAY_MS - WIFI_RETRY_INTERVAL_MS;   // sambung setelah boot stabil
  web_begin(); g_webStarted = true;                       // server HTTP aktif sejak awal (portal pairing & API)
  xTaskCreate(net_task, "net", 10240, nullptr, 2, nullptr);
}

void wifi_connect(const char* ssid, const char* pass) {
  strlcpy(g_ssid, ssid, sizeof g_ssid);
  strlcpy(g_pass, pass ? pass : "", sizeof g_pass);
  prefs.putString("ssid", g_ssid);
  prefs.putString("pass", g_pass);
  g_reqConnect = true;
}

void wifi_ntp_resync() { g_ntpPending = true; }

bool wifi_has_saved() { return g_ssid[0] != 0; }

void wifi_forget() { g_reqForget = true; }
void wifi_scan_request() { g_reqScan = true; }
bool wifi_scan_busy() { return g_scanning || g_reqScan; }

int wifi_scan_get(WifiScanItem* out, int maxn, uint32_t* seq) {
  int n = min(g_scanN, maxn);
  for (int i = 0; i < n; i++) out[i] = g_scan[i];
  if (seq) *seq = g_scanSeq;
  return n;
}

void wifi_set_ip_lock(bool on) {
  g_iplock = on;
  prefs.putBool("iplock", on);
  if (!on) eraseStatic();
  StateLock l; g_state.ip_lock = on;
}

bool wifi_get_ip_lock() { return g_iplock; }
