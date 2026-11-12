#include "app_state.h"

AppState g_state;
SemaphoreHandle_t g_state_mtx = nullptr;

void state_init() {
  g_state_mtx = xSemaphoreCreateMutex();
  memset(&g_state, 0, sizeof(g_state));
  g_state.spo2 = -1;
  g_state.hr = -1;
  g_state.batt_pct = 0;
  g_state.wifi = WIFI_ST_NOCREDS;
  strcpy(g_state.ip, "-");
  g_state.activity = ACT_IDLE;
  strcpy(g_state.reset_reason, "-");
  g_state.vbat_min = 9.9f;
}

AppState state_snapshot() {
  StateLock l;
  return g_state;
}

const char* activity_str(Activity a) {
  switch (a) {
    case ACT_WALK: return "Berjalan";
    case ACT_RUN:  return "Berlari";
    default:       return "Diam";
  }
}

// JSON dipakai bersama oleh HTTP /api/data dan push Firebase.
// Catatan: saat tidak dikenakan, spo2/hr = null dan teks = "--".
int state_build_json(const AppState& s, char* buf, size_t n, bool include_imu) {
  char spo2_v[8], hr_v[8], spo2_t[8], hr_t[8];
  if (s.worn && s.spo2 > 0) { snprintf(spo2_v, sizeof spo2_v, "%d", s.spo2); snprintf(spo2_t, sizeof spo2_t, "%d", s.spo2); }
  else { strcpy(spo2_v, "null"); strcpy(spo2_t, "--"); }
  if (s.worn && s.hr > 0)   { snprintf(hr_v, sizeof hr_v, "%d", s.hr);       snprintf(hr_t, sizeof hr_t, "%d", s.hr); }
  else { strcpy(hr_v, "null"); strcpy(hr_t, "--"); }

  char timestr[32];
  if (s.time_valid) snprintf(timestr, sizeof timestr, "%04u-%02u-%02u %02u:%02u:%02u", s.year, s.month, s.day, s.hour, s.minute, s.second);
  else strcpy(timestr, "--");

  int len = snprintf(buf, n,
    "{\"device\":\"%s\",\"fw\":\"%s\",\"ip\":\"%s\",\"ssid\":\"%s\",\"rssi\":%d,"
    "\"epoch\":%lu,\"time\":\"%s\","
    "\"wear\":\"%s\",\"worn\":%s,\"spo2\":%s,\"hr\":%s,\"spo2_text\":\"%s\",\"hr_text\":\"%s\",\"ir\":%lu,"
    "\"battery\":{\"pct\":%u,\"volt\":%.2f,\"charging\":%s},"
    "\"activity\":{\"state\":\"%s\",\"code\":%d,\"std\":%.3f,\"cadence\":%.1f,\"svm\":%.2f},"
    "\"log\":{\"active\":%s,\"rows\":%lu,\"dropped\":%lu},"
    "\"sys\":{\"reset\":\"%s\",\"boots\":%lu,\"i2c_fault\":%u,\"i2c_recov\":%lu,\"vmin\":%.2f,\"disp_reinit\":%lu,\"heap_min\":%lu}",
    DEVICE_NAME, FW_VERSION, s.ip, s.ssid, (int)s.rssi,
    (unsigned long)s.epoch, timestr,
    s.worn ? "Dikenakan" : "Tidak Dikenakan", s.worn ? "true" : "false", spo2_v, hr_v, spo2_t, hr_t, (unsigned long)s.ir,
    (unsigned)s.batt_pct, s.vbat, s.charging ? "true" : "false",
    activity_str(s.activity), (int)s.activity, s.act_std, s.act_cadence, s.svm,
    s.logging ? "true" : "false", (unsigned long)s.log_rows, (unsigned long)s.log_dropped,
    s.reset_reason, (unsigned long)s.boot_count, (unsigned)s.i2c_fault, (unsigned long)s.i2c_recoveries,
    s.vbat_min > 9.0f ? 0.0f : s.vbat_min, (unsigned long)s.disp_reinit, (unsigned long)s.heap_min);

  if (include_imu && len > 0 && (size_t)len < n) {
    len += snprintf(buf + len, n - len,
      ",\"imu\":{\"ax\":%.3f,\"ay\":%.3f,\"az\":%.3f,\"gx\":%.2f,\"gy\":%.2f,\"gz\":%.2f}",
      s.ax, s.ay, s.az, s.gx, s.gy, s.gz);
  }
  if (len > 0 && (size_t)len < n - 2) { buf[len++] = '}'; buf[len] = 0; }
  return len;
}
