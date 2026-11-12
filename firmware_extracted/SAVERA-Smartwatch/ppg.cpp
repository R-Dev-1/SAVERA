// ppg.cpp - driver MAX30102 minimal (register langsung) + algoritma Maxim (spo2_algorithm.h)
//
// Konfigurasi sensor: mode SpO2 (RED+IR), 100 sps dengan averaging 4 => 25 sampel/detik efektif
// (algoritma Maxim mengasumsikan 25 Hz, jendela 100 sampel = 4 detik, dihitung ulang tiap 1 detik).
#include "ppg.h"
#include <Wire.h>
#include "driver/gpio.h"
#include <spo2_algorithm.h>      // dari library "SparkFun MAX3010x Pulse and Proximity Sensor Library"
#include "config.h"
#include "app_state.h"
#include "i2c_bus.h"
#include "power_diag.h"

// --- register MAX30102 ---
#define REG_INT_STATUS1   0x00
#define REG_FIFO_WR_PTR   0x04
#define REG_FIFO_OVF      0x05
#define REG_FIFO_RD_PTR   0x06
#define REG_FIFO_DATA     0x07
#define REG_FIFO_CFG      0x08
#define REG_MODE_CFG      0x09
#define REG_SPO2_CFG      0x0A
#define REG_LED1_PA       0x0C   // RED
#define REG_LED2_PA       0x0D   // IR
#define REG_PART_ID       0xFF

#define PPG_BUF_LEN       100
#define PPG_STEP          25

#if PPG_USE_SOFT_I2C
// ---- I2C bit-bang open-drain pada pin terpisah (tidak mengganggu bus touch/RTC/IMU) ----
#include "driver/gpio.h"
#define PPG_LOCK ((void)0)
static inline void sda(int v) { gpio_set_level((gpio_num_t)PIN_PPG_SDA_ALT, v); }
static inline void scl(int v) { gpio_set_level((gpio_num_t)PIN_PPG_SCL_ALT, v); }
static inline int  sdaRead()  { return gpio_get_level((gpio_num_t)PIN_PPG_SDA_ALT); }
static inline void dly() { delayMicroseconds(PPG_SOFTI2C_HALF_US); }
static bool softInited = false;
static void softInit() {
  if (softInited) return;
  const gpio_num_t pins[2] = {(gpio_num_t)PIN_PPG_SDA_ALT, (gpio_num_t)PIN_PPG_SCL_ALT};
  for (int i = 0; i < 2; i++) {
    gpio_reset_pin(pins[i]);
    gpio_set_direction(pins[i], GPIO_MODE_INPUT_OUTPUT_OD);
    gpio_set_pull_mode(pins[i], GPIO_PULLUP_ONLY);
    gpio_set_level(pins[i], 1);
  }
  softInited = true;
}
static void sStart() { sda(1); scl(1); dly(); sda(0); dly(); scl(0); dly(); }
static void sStop()  { sda(0); dly(); scl(1); dly(); sda(1); dly(); }
static bool sWrite(uint8_t b) {
  for (int i = 7; i >= 0; i--) { sda((b >> i) & 1); dly(); scl(1); dly(); scl(0); }
  sda(1); dly(); scl(1); dly();
  bool ack = (sdaRead() == 0);
  scl(0); dly();
  return ack;
}
static uint8_t sRead(bool ack) {
  uint8_t v = 0;
  sda(1);
  for (int i = 0; i < 8; i++) { dly(); scl(1); dly(); v = (v << 1) | (sdaRead() ? 1 : 0); scl(0); }
  sda(ack ? 0 : 1); dly(); scl(1); dly(); scl(0); dly(); sda(1);
  return v;
}
static bool wr8(uint8_t reg, uint8_t v) {
  softInit();
  sStart();
  bool ok = sWrite(ADDR_MAX30102 << 1) && sWrite(reg) && sWrite(v);
  sStop();
  return ok;
}
static bool rdN(uint8_t reg, uint8_t* buf, uint8_t n) {
  softInit();
  sStart();
  if (!sWrite(ADDR_MAX30102 << 1) || !sWrite(reg)) { sStop(); return false; }
  sStart();
  if (!sWrite((ADDR_MAX30102 << 1) | 1)) { sStop(); return false; }
  for (uint8_t i = 0; i < n; i++) buf[i] = sRead(i < n - 1);
  sStop();
  return true;
}
#else
// ---- bus I2C bersama (Wire) ----
#define PPG_LOCK I2cLock _ppgLock
static bool wr8(uint8_t reg, uint8_t v) {
  Wire.beginTransmission(ADDR_MAX30102);
  Wire.write(reg);
  Wire.write(v);
  return Wire.endTransmission() == 0;
}

static bool rdN(uint8_t reg, uint8_t* buf, uint8_t n) {
  Wire.beginTransmission(ADDR_MAX30102);
  Wire.write(reg);
  if (Wire.endTransmission(true) != 0) return false;   // WAJIB STOP: repeated-start yang di-NACK membuat bus macet
  if (Wire.requestFrom((uint8_t)ADDR_MAX30102, (uint8_t)n) != n) return false;
  for (uint8_t i = 0; i < n; i++) buf[i] = Wire.read();
  return true;
}
#endif

// Probe ringan (hanya alamat + STOP): aman dipanggil berkala walau sensor tidak ada.
static bool ppg_probe() {
#if PPG_USE_SOFT_I2C
  uint8_t id = 0; return rdN(REG_PART_ID, &id, 1);
#else
  PPG_LOCK;
  Wire.beginTransmission(ADDR_MAX30102);
  return Wire.endTransmission(true) == 0;
#endif
}

static bool max30102_begin() {
  if (!ppg_probe()) return false;
  {
    PPG_LOCK;
    uint8_t id = 0;
    if (!rdN(REG_PART_ID, &id, 1) || id != 0x15) return false;    // 0x15 = MAX30102/MAX30105
    wr8(REG_MODE_CFG, 0x40);                                      // reset
  }
  vTaskDelay(pdMS_TO_TICKS(50));                                  // mutex dilepas: touch/IMU tetap jalan
  PPG_LOCK;
  wr8(REG_FIFO_CFG, (2 << 5) | 0x10);                             // average 4, rollover aktif
  wr8(REG_MODE_CFG, 0x03);                                        // mode SpO2 (RED + IR)
  wr8(REG_SPO2_CFG, (1 << 5) | (1 << 2) | 0x03);                  // ADC 4096 nA, 100 sps, pulse 411 us (18-bit)
  wr8(REG_LED1_PA, PPG_LED_CURRENT);
  wr8(REG_LED2_PA, PPG_LED_CURRENT);
  wr8(REG_FIFO_WR_PTR, 0); wr8(REG_FIFO_OVF, 0); wr8(REG_FIFO_RD_PTR, 0);
  uint8_t st; rdN(REG_INT_STATUS1, &st, 1);                       // bersihkan flag
  return true;
}

// Baca semua sampel yang tersedia di FIFO. Return jumlah sampel.
static int max30102_read(uint32_t* red, uint32_t* ir, int maxn) {
  PPG_LOCK;
  uint8_t ptr[3];                                                 // 0x04 WR_PTR, 0x05 OVF, 0x06 RD_PTR
  if (!rdN(REG_FIFO_WR_PTR, ptr, 3)) return -1;
  uint8_t wp = ptr[0] & 0x1F, ovf = ptr[1], rp = ptr[2] & 0x1F;
  int n = (wp - rp) & 0x1F;
  if (n == 0 && ovf > 0) n = 32;
  if (n > maxn) n = maxn;
  int done = 0;
  while (done < n) {
    int chunk = min(n - done, 10);                                // 10 sampel = 60 byte per transaksi
    uint8_t raw[60];
    if (!rdN(REG_FIFO_DATA, raw, chunk * 6)) return -1;
    for (int i = 0; i < chunk; i++) {
      const uint8_t* p = raw + i * 6;
      red[done + i] = (((uint32_t)p[0] << 16) | ((uint32_t)p[1] << 8) | p[2]) & 0x3FFFF;
      ir[done + i]  = (((uint32_t)p[3] << 16) | ((uint32_t)p[4] << 8) | p[5]) & 0x3FFFF;
    }
    done += chunk;
  }
  return done;
}

static int medianOf(int* a, int n) {
  int t[8];
  for (int i = 0; i < n; i++) t[i] = a[i];
  for (int i = 1; i < n; i++) { int k = t[i], j = i - 1; while (j >= 0 && t[j] > k) { t[j + 1] = t[j]; j--; } t[j + 1] = k; }
  return t[n / 2];
}


// ---- Daya sensor lewat GPIO (opsional, PPG_PWR_PIN >= 0) ----
static bool ppgPowered = true;
static void ppg_power(bool on) {
#if PPG_PWR_PIN >= 0
  pinMode(PPG_PWR_PIN, OUTPUT);
  gpio_set_drive_capability((gpio_num_t)PPG_PWR_PIN, GPIO_DRIVE_CAP_3);
  digitalWrite(PPG_PWR_PIN, on ? HIGH : LOW);
#endif
  ppgPowered = on;
}

// Nyalakan sensor lalu pastikan SDA/SCL tetap HIGH. Modul yang "menjepit" bus (rel 1.8 V / GND lepas / ESD clamp)
// membuat SDA/SCL turun => dayanya dipotong lagi supaya touch, RTC, IMU dan layar tidak ikut mati.
static bool ppg_power_up_safe() {
#if PPG_PWR_PIN >= 0
  ppg_power(true);
  vTaskDelay(pdMS_TO_TICKS(200));
  if (i2c_lines()) {
    ppg_power(false);
    Serial.println("[PPG] modul menahan SDA/SCL LOW saat dinyalakan -> daya sensor dipotong (cek kabel/pull-up modul)");
    i2c_watchdog();
    return false;
  }
#endif
  return true;
}

static void publish(bool ok, bool worn, int spo2, int hr, uint32_t ir) {
  StateLock l;
  g_state.ppg_ok = ok;
  g_state.worn = worn;
  g_state.spo2 = worn ? spo2 : -1;
  g_state.hr = worn ? hr : -1;
  g_state.ir = ir;
}

static void ppg_task(void*) {
  static uint32_t irBuf[PPG_BUF_LEN], redBuf[PPG_BUF_LEN];
  static uint32_t tIr[PPG_BUF_LEN], tRed[PPG_BUF_LEN];
  int count = 0, sinceCalc = 0;
  bool worn = false;
  float irAvg = 0;
  int onCnt = 0, offCnt = 0;
  int hrHist[5], spHist[5], hrN = 0, spN = 0;
  int hrOut = -1, spOut = -1;
  uint32_t lastValidMs = 0;

  vTaskDelay(pdMS_TO_TICKS(PPG_START_DELAY_MS));         // biarkan layar/touch/IMU/Wi-Fi stabil dulu
#if PPG_PWR_PIN >= 0
  ppg_power(false);
#endif
  for (;;) {
    crumb(CR_PPG, "init");
    // --- init / re-init sensor ---
    if (!i2c_bus_ok()) {                                         // bus macet: jangan disentuh
      publish(false, false, -1, -1, 0);
      vTaskDelay(pdMS_TO_TICKS(I2C_FAULT_BACKOFF_MS));
      continue;
    }
    if (PPG_PWR_PIN >= 0 && !ppgPowered && !ppg_power_up_safe()) {
      publish(false, false, -1, -1, 0);
      vTaskDelay(pdMS_TO_TICKS(30000));
      continue;
    }
    if (!max30102_begin()) {
      static uint32_t lastWarn = 0;
      if (millis() - lastWarn > 15000) { lastWarn = millis(); Serial.println("[PPG] MAX30102 tidak merespons di 0x57 (cek VIN/GND/SDA=GPIO8/SCL=GPIO7)"); }
      publish(false, false, -1, -1, 0);
#if PPG_PWR_PIN >= 0
      ppg_power(false);                                             // tidak menjawab: matikan daya, coba lagi nanti
#endif
      vTaskDelay(pdMS_TO_TICKS(5000));                              // probe jarang; UI & touch tidak terpengaruh
      continue;
    }
    publish(true, false, -1, -1, 0);
    count = 0; sinceCalc = 0; worn = false; irAvg = 0; onCnt = offCnt = 0; hrN = spN = 0; hrOut = spOut = -1;

    int failures = 0;
    for (;;) {
      vTaskDelay(pdMS_TO_TICKS(40));
      if (power_is_off()) { wr8(REG_MODE_CFG, 0x80); vTaskSuspend(nullptr); }   // mati lunak: LED sensor dimatikan
      if (!i2c_bus_ok()) { crumb(CR_PPG, "bus-fault"); break; }
      crumb(CR_PPG, "read");
      uint32_t red[32], ir[32];
      int n = max30102_read(red, ir, 32);
      if (n < 0) { if (++failures > 25) {                          // ~1 dtk gagal => pulihkan bus lalu init ulang
#if !PPG_USE_SOFT_I2C
        i2c_recover();
#endif
        break; } continue; }
      failures = 0;

      for (int i = 0; i < n; i++) {
        irAvg = (irAvg == 0) ? (float)ir[i] : irAvg * 0.9f + ir[i] * 0.1f;

        // --- deteksi dikenakan (hysteresis + debounce, 25 sampel = 1 dtk) ---
        if (!worn) {
          if (irAvg > PPG_WEAR_ON_IR) { if (++onCnt >= 25) { worn = true; onCnt = 0; count = 0; sinceCalc = 0; hrN = spN = 0; hrOut = spOut = -1; } }
          else onCnt = 0;
        } else {
          if (irAvg < PPG_WEAR_OFF_IR) { if (++offCnt >= 12) { worn = false; offCnt = 0; count = 0; hrOut = spOut = -1; } }
          else offCnt = 0;
        }
        if (!worn) continue;

        // --- isi jendela geser 100 sampel ---
        if (count < PPG_BUF_LEN) {
          irBuf[count] = ir[i]; redBuf[count] = red[i]; count++;
        } else {
          memmove(irBuf, irBuf + 1, (PPG_BUF_LEN - 1) * sizeof(uint32_t));
          memmove(redBuf, redBuf + 1, (PPG_BUF_LEN - 1) * sizeof(uint32_t));
          irBuf[PPG_BUF_LEN - 1] = ir[i]; redBuf[PPG_BUF_LEN - 1] = red[i];
        }
        sinceCalc++;

        if (count == PPG_BUF_LEN && sinceCalc >= PPG_STEP) {
          sinceCalc = 0;
          memcpy(tIr, irBuf, sizeof tIr); memcpy(tRed, redBuf, sizeof tRed);
          int32_t spo2 = 0, hr = 0; int8_t spo2v = 0, hrv = 0;
          maxim_heart_rate_and_oxygen_saturation(tIr, PPG_BUF_LEN, tRed, &spo2, &spo2v, &hr, &hrv);
          bool any = false;
          if (hrv && hr >= 40 && hr <= 180) { hrHist[hrN % 5] = hr; hrN++; hrOut = medianOf(hrHist, min(hrN, 5)); any = true; }
          if (spo2v && spo2 >= 80 && spo2 <= 100) { spHist[spN % 5] = spo2; spN++; spOut = medianOf(spHist, min(spN, 5)); any = true; }
          if (any) lastValidMs = millis();
        }
      }

      // tahan nilai terakhir PPG_HOLD_MS; setelah itu tampil "--"
      if (worn && lastValidMs && millis() - lastValidMs > PPG_HOLD_MS) { hrOut = spOut = -1; hrN = spN = 0; }
      publish(true, worn, spOut, hrOut, (uint32_t)irAvg);
    }
  }
}

void ppg_init() {
  xTaskCreate(ppg_task, "ppg", 6144, nullptr, 2, nullptr);   // prioritas rendah: tidak boleh mengalahkan UI/touch
}
