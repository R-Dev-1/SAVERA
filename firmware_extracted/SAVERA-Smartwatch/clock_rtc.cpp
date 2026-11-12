#include "clock_rtc.h"
#include <Preferences.h>
#include "SensorPCF85063.hpp"
#include "config.h"
#include "app_state.h"
#include "i2c_bus.h"

static SensorPCF85063 rtc;
static bool rtc_ok = false;
static bool trusted = false;
static bool autoSync = true;       // sinkron NTP otomatis (default aktif)       // RTC pernah disetel dari NTP/API (disimpan di NVS)

void clock_init() {
  setenv("TZ", TZ_POSIX, 1);
  tzset();
  Preferences p; p.begin("clock", true);
  trusted = p.getBool("synced", false);
  autoSync = p.getBool("auto", true);
  p.end();
  I2cLock l;
  rtc_ok = rtc.begin(Wire);
}

void clock_update() {
  if (!rtc_ok) return;
  RTC_DateTime dt;
  { I2cLock l; dt = rtc.getDateTime(); }
  struct tm t = {};
  t.tm_year = dt.getYear() - 1900; t.tm_mon = dt.getMonth() - 1; t.tm_mday = dt.getDay();
  t.tm_hour = dt.getHour(); t.tm_min = dt.getMinute(); t.tm_sec = dt.getSecond(); t.tm_isdst = -1;
  time_t e = mktime(&t);                  // juga mengisi tm_wday
  bool valid = trusted && dt.getYear() >= 2025 && dt.getYear() < 2100;

  StateLock l;
  g_state.time_valid = valid;
  g_state.year = dt.getYear(); g_state.month = dt.getMonth(); g_state.day = dt.getDay();
  g_state.hour = dt.getHour(); g_state.minute = dt.getMinute(); g_state.second = dt.getSecond();
  g_state.wday = t.tm_wday;
  g_state.epoch = valid ? (uint32_t)e : 0;
}

void clock_set_epoch(time_t utcEpoch) {
  if (!rtc_ok) return;
  struct tm t; localtime_r(&utcEpoch, &t);
  { I2cLock l; rtc.setDateTime(t.tm_year + 1900, t.tm_mon + 1, t.tm_mday, t.tm_hour, t.tm_min, t.tm_sec); }
  trusted = true;
  Preferences p; p.begin("clock", false); p.putBool("synced", true); p.end();
}

bool clock_auto() { return autoSync; }

void clock_set_auto(bool on) {
  autoSync = on;
  Preferences p; p.begin("clock", false); p.putBool("auto", on); p.end();
}

void clock_set_local(int y, int mo, int d, int h, int mi) {
  if (!rtc_ok) return;
  { I2cLock l; rtc.setDateTime(y, mo, d, h, mi, 0); }
  trusted = true;
  Preferences p; p.begin("clock", false); p.putBool("synced", true); p.end();
}
