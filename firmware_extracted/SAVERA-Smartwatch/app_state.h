// app_state.h - state bersama antar task (dilindungi mutex)
#pragma once
#include <Arduino.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>
#include "config.h"

enum Activity  : uint8_t { ACT_IDLE = 0, ACT_WALK = 1, ACT_RUN = 2 };
enum WifiState : uint8_t { WIFI_ST_NOCREDS = 0, WIFI_ST_CONNECTING = 1, WIFI_ST_CONNECTED = 2, WIFI_ST_FAILED = 3 };
enum LogMode   : uint8_t { LOG_MODE_FLASH = 0, LOG_MODE_SERIAL = 1 };

struct AppState {
  // --- PPG (MAX30102) ---
  bool     ppg_ok;        // sensor terdeteksi
  bool     worn;          // true = "Dikenakan"
  int16_t  spo2;          // -1 = tidak valid ("--")
  int16_t  hr;            // -1 = tidak valid ("--")
  uint32_t ir;            // nilai IR rata-rata (untuk tuning ambang)
  // --- Baterai ---
  float    vbat;
  uint8_t  batt_pct;
  bool     charging;
  // --- Waktu ---
  bool     time_valid;
  uint16_t year; uint8_t month, day, hour, minute, second, wday;  // wday 0=Minggu
  uint32_t epoch;
  // --- WiFi ---
  WifiState wifi;
  char     ssid[33];
  char     ip[16];
  int8_t   rssi;
  bool     ip_lock;
  // --- IMU & aktivitas ---
  bool      imu_ok;
  Activity  activity;      // diam / berjalan / berlari
  float     act_std;       // std SVM jendela terakhir (g)
  float     act_cadence;   // puncak per detik jendela terakhir
  float     svm;
  float     ax, ay, az, gx, gy, gz;
  // --- Pencatatan ---
  bool      logging;
  LogMode   log_mode;
  char      log_label[24];
  char      log_file[48];
  uint32_t  log_rows;
  uint32_t  log_dropped;
  uint32_t  log_start_ms;
  // --- Cloud ---
  bool      cloud_ok;
  // --- Diagnostik sistem (tampil di halaman "Sistem" + /api/data) ---
  uint8_t   i2c_fault;      // 0 = bus sehat, bit0 = SDA tertahan LOW, bit1 = SCL tertahan LOW
  uint8_t   i2c_devmask;    // perangkat terdeteksi saat boot: bit0 touch 0x15, bit1 RTC 0x51, bit2 IMU 0x6B, bit3 codec 0x18, bit4 MAX30102 0x57
  uint32_t  i2c_recoveries; // berapa kali bus dipulihkan sejak boot
  float     vbat_min;       // tegangan baterai terendah sejak boot (indikator sag daya)
  uint32_t  disp_reinit;    // berapa kali panel layar di-init ulang
  uint32_t  boot_count;     // jumlah boot (NVS)
  char      reset_reason[16];
  uint32_t  heap_min;
};

extern AppState g_state;
extern SemaphoreHandle_t g_state_mtx;

void     state_init();
AppState state_snapshot();
int      state_build_json(const AppState& s, char* buf, size_t n, bool include_imu);
const char* activity_str(Activity a);       // "Diam" / "Berjalan" / "Berlari"

struct StateLock {
  StateLock()  { xSemaphoreTake(g_state_mtx, portMAX_DELAY); }
  ~StateLock() { xSemaphoreGive(g_state_mtx); }
};
