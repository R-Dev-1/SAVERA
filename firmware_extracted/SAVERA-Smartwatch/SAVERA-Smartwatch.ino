// ============================================================================
//  SAVERA Smartwatch  -  Waveshare ESP32-C6-Touch-LCD-1.69 + MAX30102
//  Fitur: SpO2 & denyut nadi, status Dikenakan/Tidak Dikenakan, jam/tanggal (RTC + NTP),
//         baterai %, status charging, Wi-Fi via PAIRING HP (QR) atau layar sentuh, API lokal HTTP + mDNS,
//         push ke Firebase, klasifikasi aktivitas IMU (Diam/Berjalan/Berlari) + pencatatan data CSV,
//         halaman "Sistem" (diagnostik reset/daya/I2C).
//
//  Pengaturan Arduino IDE (Tools):
//    Board: ESP32C6 Dev Module | USB CDC On Boot: Enabled | Flash Size: 16MB
//    Partition Scheme: pakai partitions.csv di folder sketch ini (otomatis terpakai)
//  Library (Library Manager): lvgl 8.4.0 | GFX Library for Arduino 1.6.0 | SensorLib 0.3.1 |
//                             SparkFun MAX3010x Pulse and Proximity Sensor Library
//  Lihat README.md untuk detail.
// ============================================================================
#include "config.h"
#include "app_state.h"
#include "i2c_bus.h"
#include "power_diag.h"
#include "battery.h"
#include "clock_rtc.h"
#include "ppg.h"
#include "imu_activity.h"
#include "wifi_mgr.h"
#include "firebase_push.h"
#include "ui.h"
#include <esp_system.h>

// Dipanggil core Arduino SEBELUM setup(): kunci daya baterai (GPIO15 BAT_EN) secepat mungkin.
void initVariant() { power_latch(); }

// Task rumah tangga: RTC tiap 0.5 dtk, baterai tiap 2 dtk, memori tiap 5 dtk
static void sys_task(void*) {
  uint32_t lastBat = 0, lastMem = 0;
  for (;;) {
    crumb(CR_SYS, "i2c-watchdog");
    i2c_watchdog();
    crumb(CR_SYS, "rtc");
    clock_update();
    uint32_t now = millis();
    if (now - lastBat >= 2000) { lastBat = now; crumb(CR_SYS, "battery"); if (!power_is_off()) battery_update(); }
    if (now - lastMem >= 5000) { lastMem = now; StateLock l; g_state.heap_min = ESP.getMinFreeHeap(); }
    vTaskDelay(pdMS_TO_TICKS(500));
  }
}

void setup() {
  power_latch();                       // (ulang, aman) pastikan daya terkunci
  Serial.begin(115200);
  delay(200);
  Serial.printf("\n%s fw %s\n", DEVICE_LABEL, FW_VERSION);

  crumb(CR_SETUP, "state");     state_init();
  crumb(CR_SETUP, "boot_diag"); boot_diag();      // alasan reset + tahap terakhir + ringkasan crash
  if (CHARGE_MODE_ON_USB && esp_reset_reason() == ESP_RST_POWERON && !power_pwr_at_boot()) {
    Serial.println("[BOOT] papan dinyalakan oleh USB (bukan tombol PWR): mode isi daya");
    ui_charge_boot();                              // layar isi daya; tidak kembali (PWR = restart ke boot normal)
  }
  crumb(CR_SETUP, "ui_early");  ui_early();       // LAYAR DULU: tidak bergantung pada I2C / sensor
  crumb(CR_SETUP, "i2c");       i2c_init();
  crumb(CR_SETUP, "battery");   battery_init();
  crumb(CR_SETUP, "rtc");       clock_init();
  battery_update();
  clock_update();

  crumb(CR_SETUP, "ui");        ui_init();        // LVGL + touch (+ task UI)
  crumb(CR_SETUP, "imu");       imu_init();       // IMU 100 Hz + klasifikasi aktivitas + penulis log
  crumb(CR_SETUP, "ppg");       ppg_init();       // MAX30102 (baru disentuh setelah PPG_START_DELAY_MS)
  crumb(CR_SETUP, "wifi");      wifi_init();      // WiFi + mDNS + HTTP API + NTP + pairing
  crumb(CR_SETUP, "cloud");     cloud_init();     // Firebase
  xTaskCreate(sys_task, "sys", 4096, nullptr, 2, nullptr);
  crumb(CR_SETUP, "selesai");
}

void loop() {
  vTaskDelay(pdMS_TO_TICKS(1000));
}
