// firebase_push.cpp
//  Menulis ke:  <DB>/<FIREBASE_DEVICE_PATH>.json        (PATCH tiap FIREBASE_PUSH_INTERVAL_MS; format dibaca aplikasi SAVERA)
//                 VitalSigns {HeartRate, SpO2}  DeviceStatus {IsWorn, Battery, LastUpdated, Heartbeat, Charging}
//                 FallDetection {IsFallen, BA, BG, Active}  Activity {Type}
//               <DB>/<FIREBASE_DEVICE_PATH>/Info.json   (PUT saat terhubung / IP berubah)
//  Login: anonymous (REST) bila FIREBASE_API_KEY diisi; token disimpan di NVS lalu di-refresh otomatis.
#include "firebase_push.h"
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <math.h>
#include "config.h"
#include "app_state.h"

static WiFiClientSecure g_client;
static String g_idToken, g_refreshToken;
static uint32_t g_tokenExpiryMs = 0;
static char g_lastInfoIp[16] = "";
static bool g_pushedOnce = false;

// ambil nilai string sederhana dari JSON: "key":"value"
static String jsonStr(const String& js, const char* key) {
  String k = String("\"") + key + "\"";
  int i = js.indexOf(k);
  if (i < 0) return "";
  i = js.indexOf(':', i);
  int a = js.indexOf('"', i + 1);
  int b = js.indexOf('"', a + 1);
  if (i < 0 || a < 0 || b < 0) return "";
  return js.substring(a + 1, b);
}

static int httpSend(const char* method, const String& url, const String& body, const char* ctype, String* resp) {
  HTTPClient http;
  http.setConnectTimeout(6000);
  http.setTimeout(6000);
  http.setReuse(true);
  if (!http.begin(g_client, url)) return -1;
  http.addHeader("Content-Type", ctype);
  int code = http.sendRequest(method, (uint8_t*)body.c_str(), body.length());
  if (resp && code > 0) *resp = http.getString();
  http.end();
  return code;
}

static bool authEnsure() {
  if (strlen(FIREBASE_API_KEY) == 0) return true;                       // tanpa auth (rules uji coba)
  if (g_idToken.length() && (int32_t)(g_tokenExpiryMs - millis()) > 120000) return true;

  String resp; int code;
  if (g_refreshToken.length()) {
    String url = String("https://securetoken.googleapis.com/v1/token?key=") + FIREBASE_API_KEY;
    code = httpSend("POST", url, "grant_type=refresh_token&refresh_token=" + g_refreshToken, "application/x-www-form-urlencoded", &resp);
    if (code == 200) {
      g_idToken = jsonStr(resp, "id_token");
      String rt = jsonStr(resp, "refresh_token"); if (rt.length()) g_refreshToken = rt;
      g_tokenExpiryMs = millis() + 3500UL * 1000UL;
      Preferences p; p.begin("fb", false); p.putString("rt", g_refreshToken); p.end();
      return g_idToken.length() > 0;
    }
    g_refreshToken = "";                                                // gagal => daftar anonymous baru
  }
  String url = String("https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=") + FIREBASE_API_KEY;
  code = httpSend("POST", url, "{\"returnSecureToken\":true}", "application/json", &resp);
  if (code != 200) { Serial.printf("[FB] login anonymous gagal (%d)\n", code); return false; }
  g_idToken = jsonStr(resp, "idToken");
  g_refreshToken = jsonStr(resp, "refreshToken");
  g_tokenExpiryMs = millis() + 3500UL * 1000UL;
  Preferences p; p.begin("fb", false); p.putString("rt", g_refreshToken); p.end();
  return g_idToken.length() > 0;
}

// path kosong = node perangkat itu sendiri (Devices/Device_01.json)
static String dbUrl(const char* sub) {
  String u = String(FIREBASE_DB_URL) + "/" + FIREBASE_DEVICE_PATH;
  if (sub && sub[0]) u += String("/") + sub;
  u += ".json";
  if (g_idToken.length()) u += "?auth=" + g_idToken;
  return u;
}

// Muatan sesuai kontrak aplikasi. Nilai tak valid ditulis "--" (aplikasi menampilkan teks itu apa adanya);
// jangan dikosongkan/dihapus karena aplikasi lalu menampilkan angka contoh (76 / 98).
static int buildLive(const AppState& s, char* out, size_t n) {
  char hr[8], sp[8], ba[12], bg[16], upd[16];
  bool vit = s.worn && s.hr > 0;
  if (vit) snprintf(hr, sizeof hr, "%d", s.hr); else strcpy(hr, "\"--\"");
  if (s.worn && s.spo2 > 0) snprintf(sp, sizeof sp, "%d", s.spo2); else strcpy(sp, "\"--\"");
  if (s.imu_ok) {
    snprintf(ba, sizeof ba, "%.2fg", s.svm);
    snprintf(bg, sizeof bg, "%d\xC2\xB0/s", (int)(sqrtf(s.gx * s.gx + s.gy * s.gy + s.gz * s.gz) + 0.5f));
  } else { strcpy(ba, "--"); strcpy(bg, "--"); }
  if (s.time_valid) snprintf(upd, sizeof upd, "%02u.%02u", s.hour, s.minute); else strcpy(upd, "Baru saja");
  static const char* kAct[] = {"Diam", "Berjalan", "Berlari"};
  const char* act = (int)s.activity >= 0 && (int)s.activity < 3 ? kAct[(int)s.activity] : "Diam";
  return snprintf(out, n,
    "{\"VitalSigns\":{\"HeartRate\":%s,\"SpO2\":%s},"
    "\"DeviceStatus\":{\"IsWorn\":%s,\"Battery\":%u,\"Charging\":%s,\"LastUpdated\":\"%s\",\"Heartbeat\":{\".sv\":\"timestamp\"}},"
    "\"FallDetection\":{\"IsFallen\":false,\"Active\":false,\"BA\":\"%s\",\"BG\":\"%s\"},"
    "\"Activity\":{\"Type\":\"%s\"}}",
    hr, sp, s.worn ? "true" : "false", (unsigned)s.batt_pct, s.charging ? "true" : "false", upd, ba, bg, act);
}

static bool configured() {
  return FIREBASE_ENABLED && strstr(FIREBASE_DB_URL, "GANTI-") == nullptr && strlen(FIREBASE_DB_URL) > 12;
}

static void cloud_task(void*) {
  { Preferences p; p.begin("fb", true); g_refreshToken = p.getString("rt", ""); p.end(); }
  g_client.setInsecure();     // lihat README: bisa diganti setCACertBundle() untuk validasi sertifikat
  static char buf[1200];
  uint32_t fails = 0;

  for (;;) {
    vTaskDelay(pdMS_TO_TICKS(FIREBASE_PUSH_INTERVAL_MS));
    AppState s = state_snapshot();
    if (!configured() || s.wifi != WIFI_ST_CONNECTED) { StateLock l; g_state.cloud_ok = false; continue; }
    if (!authEnsure()) { StateLock l; g_state.cloud_ok = false; vTaskDelay(pdMS_TO_TICKS(5000)); continue; }

    if (strcmp(g_lastInfoIp, s.ip) != 0) {
      char info[260];
      snprintf(info, sizeof info, "{\"name\":\"%s\",\"mac\":\"%s\",\"fw\":\"%s\",\"ip\":\"%s\",\"mdns\":\"%s.local\",\"boot_ms\":%lu}",
               DEVICE_LABEL, WiFi.macAddress().c_str(), FW_VERSION, s.ip, DEVICE_NAME, (unsigned long)millis());
      if (httpSend("PUT", dbUrl("Info"), info, "application/json", nullptr) == 200) strlcpy(g_lastInfoIp, s.ip, sizeof g_lastInfoIp);
    }

    int n = buildLive(s, buf, sizeof buf);
    int code = (n > 0 && n < (int)sizeof buf) ? httpSend("PATCH", dbUrl(""), buf, "application/json", nullptr) : -2;
    bool ok = (code == 200);
    if (!ok) { fails++; if (code == 401 || code == 403) g_idToken = ""; Serial.printf("[FB] push gagal (%d)%s\n", code, (code == 401 || code == 403) ? " - cek Rules Realtime Database" : ""); }
    else { if (fails || !g_pushedOnce) Serial.printf("[FB] terkirim ke %s\n", FIREBASE_DEVICE_PATH); g_pushedOnce = true; fails = 0; }
    { StateLock l; g_state.cloud_ok = ok; }
    if (fails > 5) vTaskDelay(pdMS_TO_TICKS(10000));             // mundur sebentar bila terus gagal
  }
}

void cloud_init() {
  xTaskCreate(cloud_task, "cloud", 12288, nullptr, 2, nullptr);
}
