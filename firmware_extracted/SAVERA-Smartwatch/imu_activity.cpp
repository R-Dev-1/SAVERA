// imu_activity.cpp
//  - Baca QMI8658 tiap 10 ms (100 Hz). Satuan: akselerasi g, gyro deg/s (sama dengan dataset TemanJalan / MPU6500).
//  - Klasifikasi aturan: DIAM / BERJALAN / BERLARI dari std SVM + jumlah puncak per detik (kadens) per jendela 2 dtk.
//  - Pencatat data CSV ke flash (LittleFS) atau stream Serial, kolom Marker & Activity untuk pelabelan.
#include "imu_activity.h"
#include <Wire.h>
#include <LittleFS.h>
#include <freertos/stream_buffer.h>
#include <esp_timer.h>
#include <math.h>
#include "SensorQMI8658.hpp"
#include "config.h"
#include "i2c_bus.h"
#include "power_diag.h"

#if ENABLE_ML_MODEL
  #include "model_100hz_800ms.h"      // hasil export (EloquentML/micromlgen) dari data wrist Anda
  using namespace Eloquent::ML::Port;
#endif

static SensorQMI8658 qmi;
static volatile bool g_fs_ok = false;

// ===================== PENCATAT =====================
static StreamBufferHandle_t g_sb = nullptr;
static File g_file;
static volatile bool g_log_active = false;
static volatile bool g_log_stopreq = false;
static volatile bool g_log_busy = false;
static volatile bool g_marker = false;
static LogMode g_mode = LOG_MODE_FLASH;
static uint64_t g_t0_us = 0;
static uint32_t g_rows = 0, g_dropped = 0;
static volatile uint8_t g_act_code = 0;       // aktivitas terklasifikasi saat ini (ditulis ke CSV)

bool log_fs_ok() { return g_fs_ok; }

static void sanitize(const char* in, char* out, size_t n) {
  size_t j = 0;
  for (; in && *in && j < n - 1; in++) {
    char c = *in;
    if (isalnum((unsigned char)c) || c == '-' || c == '_') out[j++] = c;
    else if (c == ' ') out[j++] = '_';
  }
  out[j] = 0;
  if (!j) strcpy(out, "data");
}

bool log_start(const char* label, LogMode mode, char* err, size_t errn) {
  if (g_log_active || g_log_busy) { snprintf(err, errn, "sedang merekam"); return false; }
  char lab[24]; sanitize(label, lab, sizeof lab);
  AppState s = state_snapshot();
  char path[64] = "";

  if (mode == LOG_MODE_FLASH) {
    if (!g_fs_ok) { snprintf(err, errn, "LittleFS tidak aktif (cek partitions.csv)"); return false; }
    size_t freeB = LittleFS.totalBytes() - LittleFS.usedBytes();
    if (freeB < LOG_MIN_FREE_BYTES) { snprintf(err, errn, "memori flash hampir penuh"); return false; }
    if (!LittleFS.exists(LOG_DIR)) LittleFS.mkdir(LOG_DIR);
    char stamp[24];
    if (s.time_valid) snprintf(stamp, sizeof stamp, "%04u%02u%02u-%02u%02u%02u", s.year, s.month, s.day, s.hour, s.minute, s.second);
    else snprintf(stamp, sizeof stamp, "up%lu", (unsigned long)(millis() / 1000));
    snprintf(path, sizeof path, "%s/%s_%s.csv", LOG_DIR, lab, stamp);
    g_file = LittleFS.open(path, FILE_WRITE);
    if (!g_file) { snprintf(err, errn, "gagal membuat file"); return false; }
  }

  char hdr[480];
  int n = snprintf(hdr, sizeof hdr,
    "# device=%s\n# fw=%s\n# fs_hz=%d\n# acc_range_g=16\n# gyro_range_dps=1024\n# unit_acc=g\n# unit_gyro=dps\n"
    "# label=%s\n# waktu=%s\n# Activity: 0=diam 1=berjalan 2=berlari (hasil klasifikasi aturan, BUKAN label asli)\n"
    "Timestamp(ms),AccX,AccY,AccZ,GyroX,GyroY,GyroZ,Marker,Activity\n",
    DEVICE_NAME, FW_VERSION, IMU_FS_HZ, lab,
    s.time_valid ? "tersinkron" : "belum-valid");
  if (mode == LOG_MODE_FLASH) g_file.write((const uint8_t*)hdr, n);
  else {
#if defined(ARDUINO_USB_CDC_ON_BOOT) && ARDUINO_USB_CDC_ON_BOOT
    Serial.setTxTimeoutMs(0);
#endif
    Serial.write((const uint8_t*)hdr, n);
  }

  xStreamBufferReset(g_sb);
  g_rows = 0; g_dropped = 0; g_marker = false;
  g_mode = mode;
  g_t0_us = esp_timer_get_time();
  g_log_stopreq = false;
  g_log_busy = true;
  g_log_active = true;
  {
    StateLock l;
    g_state.logging = true; g_state.log_mode = mode;
    strlcpy(g_state.log_label, lab, sizeof g_state.log_label);
    strlcpy(g_state.log_file, mode == LOG_MODE_FLASH ? path : "(serial)", sizeof g_state.log_file);
    g_state.log_rows = 0; g_state.log_dropped = 0; g_state.log_start_ms = millis();
  }
  return true;
}

void log_stop() {
  if (!g_log_active && !g_log_busy) return;
  g_log_active = false;
  g_log_stopreq = true;
  for (int i = 0; i < 40 && g_log_busy; i++) delay(50);   // tunggu penulis menguras buffer & menutup file
  StateLock l;
  g_state.logging = false;
}

void log_marker() { if (g_log_active) g_marker = true; }

// Task penulis: menguras stream buffer ke file/serial dalam blok besar (hemat siklus tulis flash)
static void writer_task(void*) {
  crumb(CR_IMU, "littlefs");
  g_fs_ok = LittleFS.begin(true);        // di sini (bukan di setup) agar format/mount flash tidak menahan boot
  if (!g_fs_ok) Serial.println("[LOG] LittleFS gagal (pakai partitions.csv dari proyek ini)");
  static uint8_t buf[2048];
  uint32_t lastFlush = millis();
  for (;;) {
    size_t n = xStreamBufferReceive(g_sb, buf, sizeof buf, pdMS_TO_TICKS(400));
    if (n) {
      if (g_mode == LOG_MODE_FLASH) { if (g_file) g_file.write(buf, n); }
      else Serial.write(buf, n);
    }
    if (g_mode == LOG_MODE_FLASH && g_file && millis() - lastFlush > 2000) { g_file.flush(); lastFlush = millis(); }
    if (g_log_stopreq && xStreamBufferIsEmpty(g_sb)) {
      if (g_file) { g_file.flush(); g_file.close(); }
      g_log_stopreq = false;
      g_log_busy = false;
    }
  }
}

// ===================== KLASIFIKASI AKTIVITAS =====================
static float winBuf[ACT_WINDOW];
static int   winN = 0, winSince = 0;
static Activity actCur = ACT_IDLE, actCand = ACT_IDLE;
static int   actCandCnt = 0;
static float lastStd = 0, lastCad = 0;

#if ENABLE_ML_MODEL
static RandomForest mlClf;
static float mlAcc[ML_WINDOW], mlGyr[ML_WINDOW];
static int mlN = 0, mlSince = 0, mlLast = 0;
// Urutan fitur HARUS sama dengan training (mengikuti TemanJalan100HzML-2):
// [Acc_Mean, Gyro_Min, Acc_Max, Gyro_Mean, Acc_Min, Gyro_Std]
static void ml_push(float svm, float gmag) {
  if (mlN < ML_WINDOW) { mlAcc[mlN] = svm; mlGyr[mlN] = gmag; mlN++; }
  else { memmove(mlAcc, mlAcc + 1, (ML_WINDOW - 1) * 4); memmove(mlGyr, mlGyr + 1, (ML_WINDOW - 1) * 4); mlAcc[ML_WINDOW - 1] = svm; mlGyr[ML_WINDOW - 1] = gmag; }
  if (mlN == ML_WINDOW && ++mlSince >= ML_HOP) {
    mlSince = 0;
    float am = 0, gm = 0, amax = mlAcc[0], amin = mlAcc[0], gmin = mlGyr[0];
    for (int i = 0; i < ML_WINDOW; i++) { am += mlAcc[i]; gm += mlGyr[i]; amax = max(amax, mlAcc[i]); amin = min(amin, mlAcc[i]); gmin = min(gmin, mlGyr[i]); }
    am /= ML_WINDOW; gm /= ML_WINDOW;
    float gs = 0; for (int i = 0; i < ML_WINDOW; i++) gs += (mlGyr[i] - gm) * (mlGyr[i] - gm);
    gs = sqrtf(gs / ML_WINDOW);
    float f[6] = { am, gmin, amax, gm, amin, gs };
    mlLast = mlClf.predict(f);
  }
}
#endif

static void classify_window() {
  float mean = 0;
  for (int i = 0; i < ACT_WINDOW; i++) mean += winBuf[i];
  mean /= ACT_WINDOW;
  float var = 0;
  for (int i = 0; i < ACT_WINDOW; i++) { float d = winBuf[i] - mean; var += d * d; }
  float sd = sqrtf(var / ACT_WINDOW);

  // hitung puncak (maksimum lokal di atas mean + 0.5*sd, jarak minimal ACT_PEAK_MIN_GAP) => kadens
  int peaks = 0, lastPk = -ACT_PEAK_MIN_GAP;
  float thr = mean + 0.5f * sd;
  for (int i = 1; i < ACT_WINDOW - 1; i++) {
    if (winBuf[i] > thr && winBuf[i] >= winBuf[i - 1] && winBuf[i] > winBuf[i + 1] && i - lastPk >= ACT_PEAK_MIN_GAP) { peaks++; lastPk = i; }
  }
  float cadence = peaks / ((float)ACT_WINDOW / IMU_FS_HZ);

  Activity cand;
  if (sd < ACT_STD_IDLE) cand = ACT_IDLE;
  else if (sd >= ACT_STD_RUN || (sd >= ACT_STD_RUN_MIN && cadence >= ACT_CADENCE_RUN)) cand = ACT_RUN;
  else cand = ACT_WALK;

#if ENABLE_ML_MODEL
  cand = (Activity)constrain(mlLast, 0, 2);       // ML menggantikan aturan
#endif

  // konfirmasi N jendela berturut-turut agar status tidak berkedip
  if (cand == actCur) { actCandCnt = 0; }
  else if (cand == actCand) { if (++actCandCnt >= ACT_CONFIRM) { actCur = cand; actCandCnt = 0; } }
  else { actCand = cand; actCandCnt = 1; }

  lastStd = sd; lastCad = cadence;
  g_act_code = (uint8_t)actCur;
  StateLock l;
  g_state.activity = actCur;
  g_state.act_std = sd;
  g_state.act_cadence = cadence;
}

static void activity_step(float svm, float gmag) {
#if ENABLE_ML_MODEL
  ml_push(svm, gmag);
#else
  (void)gmag;
#endif
  if (winN < ACT_WINDOW) { winBuf[winN++] = svm; }
  else { memmove(winBuf, winBuf + 1, (ACT_WINDOW - 1) * sizeof(float)); winBuf[ACT_WINDOW - 1] = svm; }
  if (winN == ACT_WINDOW && ++winSince >= ACT_HOP) { winSince = 0; classify_window(); }
}

// ===================== TASK IMU =====================
static bool imu_begin() {
  I2cLock l;
  if (!qmi.begin(Wire, QMI8658_L_SLAVE_ADDRESS, PIN_I2C_SDA, PIN_I2C_SCL)) return false;
  // ODR internal lebih tinggi dari 100 Hz + LPF ~13% ODR, lalu dibaca tiap 10 ms (mirip DLPF + timer 100 Hz di MPU6500)
  qmi.configAccelerometer(IMU_ACC_RANGE, SensorQMI8658::ACC_ODR_500Hz, SensorQMI8658::LPF_MODE_3);
  qmi.configGyroscope(IMU_GYR_RANGE, SensorQMI8658::GYR_ODR_448_4Hz, SensorQMI8658::LPF_MODE_3);
  qmi.enableGyroscope();
  qmi.enableAccelerometer();
  return true;
}

static void imu_task(void*) {
  for (;;) {
    while (true) {
      crumb(CR_IMU, "begin");
      if (i2c_bus_ok() && imu_begin()) break;
      { StateLock l; g_state.imu_ok = false; }
      vTaskDelay(pdMS_TO_TICKS(3000));
    }
    { StateLock l; g_state.imu_ok = true; }
    delay(100);
    winN = 0; winSince = 0;

    TickType_t last = xTaskGetTickCount();
    uint32_t n = 0, lastSpace = 0;
    int bad = 0;
    for (;;) {
      vTaskDelayUntil(&last, pdMS_TO_TICKS(1000 / IMU_FS_HZ));
      if (power_is_off()) vTaskSuspend(nullptr);            // mati lunak
      if (!i2c_bus_ok()) {                                  // bus macet: mundur, jangan menghantam bus
        crumb(CR_IMU, "bus-fault");
        vTaskDelay(pdMS_TO_TICKS(I2C_FAULT_BACKOFF_MS));
        last = xTaskGetTickCount();
        continue;
      }
      crumb(CR_IMU, "read");
      float ax, ay, az, gx, gy, gz;
      bool ok;
      { I2cLock l; ok = qmi.getAccelerometer(ax, ay, az) && qmi.getGyroscope(gx, gy, gz); }
      if (!ok) { if (++bad > 100) { i2c_recover(); break; } continue; }
      bad = 0;
      uint64_t t_us = esp_timer_get_time();
      uint32_t now = (uint32_t)(t_us / 1000);
      float svm = sqrtf(ax * ax + ay * ay + az * az);
      float gmag = sqrtf(gx * gx + gy * gy + gz * gz);

      activity_step(svm, gmag);

      // --- catat baris CSV ---
      if (g_log_active) {
        char line[112];
        uint8_t mk = g_marker ? 1 : 0; g_marker = false;
        int len = snprintf(line, sizeof line, "%.2f,%.3f,%.3f,%.3f,%.2f,%.2f,%.2f,%u,%u\n",
                           (double)(t_us - g_t0_us) / 1000.0, ax, ay, az, gx, gy, gz, mk, (unsigned)g_act_code);
        if (xStreamBufferSpacesAvailable(g_sb) >= (size_t)len) { xStreamBufferSend(g_sb, line, len, 0); g_rows++; }
        else g_dropped++;
        if (g_mode == LOG_MODE_FLASH && now - lastSpace > 5000) {
          lastSpace = now;
          if (LittleFS.totalBytes() - LittleFS.usedBytes() < 64 * 1024) { g_log_active = false; g_log_stopreq = true; }   // flash habis => berhenti otomatis
        }
      }

      // --- publikasi state (10 Hz) ---
      if (++n % (IMU_FS_HZ / 10) == 0) {
        StateLock l;
        g_state.svm = svm;
        g_state.ax = ax; g_state.ay = ay; g_state.az = az;
        g_state.gx = gx; g_state.gy = gy; g_state.gz = gz;
        g_state.log_rows = g_rows; g_state.log_dropped = g_dropped;
        if (!g_log_active && !g_log_busy) g_state.logging = false;
      }
    }
  }
}

void imu_init() {
  g_sb = xStreamBufferCreate(LOG_STREAM_BYTES, 1024);   // trigger 1 KB => penulisan flash dalam blok besar
  xTaskCreate(imu_task, "imu", 5120, nullptr, 3, nullptr);   // prioritas di bawah UI (4): layar/touch tidak boleh kalah
  xTaskCreate(writer_task, "logw", 4096, nullptr, 1, nullptr);
}
