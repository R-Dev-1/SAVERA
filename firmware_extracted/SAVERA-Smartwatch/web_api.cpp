#include "web_api.h"
#include <WebServer.h>
#include <WiFi.h>
#include <LittleFS.h>
#include <time.h>
#include "config.h"
#include "app_state.h"
#include "imu_activity.h"
#include "clock_rtc.h"
#include "wifi_mgr.h"
#include "portal_html.h"

static WebServer server(HTTP_PORT);

static void cors() { server.sendHeader("Access-Control-Allow-Origin", "*"); }

static bool authed() {
  if (strlen(API_TOKEN) == 0) return true;
  String t = server.hasHeader("X-Token") ? server.header("X-Token") : server.arg("token");
  if (t == API_TOKEN) return true;
  cors(); server.send(401, "application/json", "{\"error\":\"unauthorized\"}");
  return false;
}

static void sendJson(int code, const String& body) { cors(); server.send(code, "application/json", body); }

static bool safeName(const String& n) { return n.length() > 0 && n.indexOf('/') < 0 && n.indexOf("..") < 0; }

static void hData() {
  if (!authed()) return;
  static char buf[1200];
  AppState s = state_snapshot();
  state_build_json(s, buf, sizeof buf, server.arg("imu") == "1");
  sendJson(200, buf);
}

static void hActivity() {
  if (!authed()) return;
  AppState s = state_snapshot();
  char b[160];
  snprintf(b, sizeof b, "{\"state\":\"%s\",\"code\":%d,\"std\":%.3f,\"cadence\":%.1f,\"svm\":%.2f}",
           activity_str(s.activity), (int)s.activity, s.act_std, s.act_cadence, s.svm);
  sendJson(200, b);
}

static void hInfo() {
  if (!authed()) return;
  char b[560];
  snprintf(b, sizeof b,
    "{\"device\":\"%s\",\"fw\":\"%s\",\"mac\":\"%s\",\"ip\":\"%s\",\"mdns\":\"%s.local\",\"uptime_s\":%lu,"
    "\"heap_free\":%u,\"fs_ok\":%s,\"fs_total\":%u,\"fs_used\":%u,"
    "\"endpoints\":[\"/api/data\",\"/api/activity\",\"/api/time\",\"/api/log/status\",\"/api/log/start\",\"/api/log/stop\",\"/api/log/marker\",\"/api/log/list\",\"/api/log/download\",\"/api/log/delete\"]}",
    DEVICE_NAME, FW_VERSION, WiFi.macAddress().c_str(), WiFi.localIP().toString().c_str(), DEVICE_NAME,
    (unsigned long)(millis() / 1000), (unsigned)ESP.getFreeHeap(), log_fs_ok() ? "true" : "false",
    log_fs_ok() ? (unsigned)LittleFS.totalBytes() : 0u, log_fs_ok() ? (unsigned)LittleFS.usedBytes() : 0u);
  sendJson(200, b);
}

static void hTime() {
  if (!authed()) return;
  if (server.hasArg("epoch")) {
    time_t e = (time_t)strtoul(server.arg("epoch").c_str(), nullptr, 10);
    if (e > 1700000000) { clock_set_epoch(e); clock_update(); }
    else { sendJson(400, "{\"error\":\"epoch tidak valid\"}"); return; }
  }
  AppState s = state_snapshot();
  char b[96];
  snprintf(b, sizeof b, "{\"valid\":%s,\"epoch\":%lu,\"tz\":\"%s\"}", s.time_valid ? "true" : "false", (unsigned long)s.epoch, TZ_POSIX);
  sendJson(200, b);
}

static void hLogStatus() {
  if (!authed()) return;
  AppState s = state_snapshot();
  char b[300];
  snprintf(b, sizeof b, "{\"active\":%s,\"mode\":\"%s\",\"label\":\"%s\",\"file\":\"%s\",\"rows\":%lu,\"dropped\":%lu,\"seconds\":%lu}",
    s.logging ? "true" : "false", s.log_mode == LOG_MODE_FLASH ? "flash" : "serial", s.log_label, s.log_file,
    (unsigned long)s.log_rows, (unsigned long)s.log_dropped, s.logging ? (unsigned long)((millis() - s.log_start_ms) / 1000) : 0UL);
  sendJson(200, b);
}

static void hLogStart() {
  if (!authed()) return;
  char err[64] = "";
  LogMode m = server.arg("mode") == "serial" ? LOG_MODE_SERIAL : LOG_MODE_FLASH;
  if (log_start(server.arg("label").c_str(), m, err, sizeof err)) hLogStatus();
  else sendJson(409, String("{\"error\":\"") + err + "\"}");
}

static void hLogStop() { if (!authed()) return; log_stop(); hLogStatus(); }
static void hLogMarker() { if (!authed()) return; log_marker(); sendJson(200, "{\"ok\":true}"); }

static void hLogList() {
  if (!authed()) return;
  String out = "{\"files\":[";
  if (log_fs_ok() && LittleFS.exists(LOG_DIR)) {
    File dir = LittleFS.open(LOG_DIR);
    File f = dir.openNextFile();
    bool first = true;
    while (f) {
      if (!f.isDirectory()) {
        if (!first) out += ",";
        first = false;
        String n = f.name(); int sl = n.lastIndexOf('/'); if (sl >= 0) n = n.substring(sl + 1);
        out += "{\"name\":\"" + n + "\",\"size\":" + String((unsigned)f.size()) + "}";
      }
      f = dir.openNextFile();
    }
  }
  out += "]}";
  sendJson(200, out);
}

static void hLogDownload() {
  if (!authed()) return;
  String n = server.arg("name");
  if (!safeName(n)) { sendJson(400, "{\"error\":\"nama tidak valid\"}"); return; }
  AppState s = state_snapshot();
  String path = String(LOG_DIR) + "/" + n;
  if (s.logging && path == s.log_file) { sendJson(409, "{\"error\":\"file sedang direkam\"}"); return; }
  File f = LittleFS.open(path, "r");
  if (!f) { sendJson(404, "{\"error\":\"tidak ditemukan\"}"); return; }
  cors();
  server.sendHeader("Content-Disposition", "attachment; filename=\"" + n + "\"");
  server.streamFile(f, "text/csv");
  f.close();
}

static void hLogDelete() {
  if (!authed()) return;
  String n = server.arg("name");
  if (!safeName(n)) { sendJson(400, "{\"error\":\"nama tidak valid\"}"); return; }
  String path = String(LOG_DIR) + "/" + n;
  AppState s = state_snapshot();
  if (s.logging && path == s.log_file) { sendJson(409, "{\"error\":\"file sedang direkam\"}"); return; }
  sendJson(LittleFS.remove(path) ? 200 : 404, "{\"ok\":true}");
}

static void redirectPortal() {
  if (!wifi_prov_active()) { server.send(404, "text/plain", ""); return; }      // pairing selesai: portal ditutup
  server.sendHeader("Location", "http://192.168.4.1/", true);
  server.sendHeader("Cache-Control", "no-cache");
  server.send(302, "text/plain", "");
}

static void hRoot() {
  if (wifi_prov_active()) {                         // sesi pairing: tampilkan halaman Wi-Fi
    server.sendHeader("Cache-Control", "no-cache");
    server.send_P(200, "text/html; charset=utf-8", PORTAL_HTML);
    return;
  }
  cors();
  server.send(200, "text/plain",
    String(DEVICE_LABEL) + " fw " + FW_VERSION + "\nAPI: /api/info /api/data /api/activity /api/time /api/wifi/scan /api/wifi/connect /api/log/*\n");
}

static void provClosed() { sendJson(410, "{\"error\":\"pairing selesai, halaman ditutup\"}"); }

static void hProvScan() {
  if (!wifi_prov_active()) { provClosed(); return; }
  static char b[2000];
  if (server.arg("rescan") == "1") wifi_scan_request();
  wifi_scan_json(b, sizeof b);
  server.sendHeader("Cache-Control", "no-cache");
  sendJson(200, b);
}

static void hProvStatus() {
  if (!wifi_prov_active() && wifi_prov_info().st == PROV_OFF) {                 // sesi sudah berakhir
    server.sendHeader("Cache-Control", "no-cache");
    sendJson(200, "{\"state\":\"closed\",\"target\":\"\",\"msg\":\"\",\"ip\":\"\"}");
    return;
  }
  char b[420];
  wifi_prov_status_json(b, sizeof b);
  server.sendHeader("Cache-Control", "no-cache");
  sendJson(200, b);
}

static void hProvConnect() {
  if (!wifi_prov_active()) { provClosed(); return; }
  char err[72] = "";
  if (wifi_prov_submit(server.arg("ssid").c_str(), server.arg("pass").c_str(), err, sizeof err)) sendJson(200, "{\"ok\":true}");
  else sendJson(409, String("{\"error\":\"") + err + "\"}");
}

// API untuk aplikasi (Flutter): daftar jaringan & ganti jaringan lewat jaringan yang sedang terhubung
static void hApiWifiScan() {
  if (!authed()) return;
  static char b[2000];
  if (server.arg("rescan") == "1") wifi_scan_request();
  wifi_scan_json(b, sizeof b);
  sendJson(200, b);
}

static void hApiWifiConnect() {
  if (!authed()) return;
  String ssid = server.arg("ssid");
  if (ssid.length() == 0 || ssid.length() > 32) { sendJson(400, "{\"error\":\"ssid tidak valid\"}"); return; }
  String pass = server.arg("pass");
  if (pass.length() && (pass.length() < 8 || pass.length() > 64)) { sendJson(400, "{\"error\":\"sandi harus 8-64 karakter\"}"); return; }
  wifi_connect(ssid.c_str(), pass.c_str());
  sendJson(200, "{\"ok\":true,\"note\":\"jam berpindah jaringan; cari ulang lewat mDNS\"}");
}

static void hNotFound() {
  if (wifi_prov_active()) { redirectPortal(); return; }   // captive portal: semua URL liar -> halaman pairing
  sendJson(404, "{\"error\":\"not found\"}");
}


static bool g_started = false;

void web_begin() {
  if (g_started) return;
  const char* keys[] = {"X-Token"};
  server.collectHeaders(keys, 1);
  server.on("/", HTTP_GET, hRoot);
  server.on("/api/info", HTTP_GET, hInfo);
  server.on("/api/data", HTTP_GET, hData);
  server.on("/api/activity", HTTP_GET, hActivity);
  server.on("/api/time", hTime);
  server.on("/api/log/status", HTTP_GET, hLogStatus);
  server.on("/api/log/start", hLogStart);
  server.on("/api/log/stop", hLogStop);
  server.on("/api/log/marker", hLogMarker);
  server.on("/api/log/list", HTTP_GET, hLogList);
  server.on("/api/log/download", HTTP_GET, hLogDownload);
  server.on("/api/log/delete", hLogDelete);
  server.on("/api/wifi/scan", HTTP_GET, hApiWifiScan);
  server.on("/api/wifi/connect", hApiWifiConnect);
  server.on("/prov/scan", HTTP_GET, hProvScan);
  server.on("/prov/status", HTTP_GET, hProvStatus);
  server.on("/prov/connect", HTTP_POST, hProvConnect);
  // deteksi captive portal Android / iOS / Windows / Firefox -> arahkan ke halaman pairing
  const char* probes[] = {"/generate_204", "/gen_204", "/hotspot-detect.html", "/library/test/success.html",
                          "/connecttest.txt", "/ncsi.txt", "/redirect", "/fwlink", "/canonical.html", "/success.txt"};
  for (const char* p : probes) server.on(p, redirectPortal);
  server.onNotFound(hNotFound);
  server.begin();
  g_started = true;
}

void web_loop() { if (g_started) server.handleClient(); }
