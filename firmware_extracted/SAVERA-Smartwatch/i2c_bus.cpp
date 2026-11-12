#include "i2c_bus.h"
#include "app_state.h"

SemaphoreHandle_t g_i2c_mtx = nullptr;
static volatile uint8_t  g_fault = 0;
static volatile uint8_t  g_devmask = 0;
static volatile bool     g_recoverEvt = false;
static uint32_t          g_recoveries = 0;

uint8_t i2c_lines() {
  uint8_t f = 0;
  if (digitalRead(PIN_I2C_SDA) == LOW) f |= 1;
  if (digitalRead(PIN_I2C_SCL) == LOW) f |= 2;
  return f;
}

bool i2c_bus_ok() { return g_fault == 0; }
uint8_t i2c_devmask() { return g_devmask; }
bool i2c_take_recover_event() { bool e = g_recoverEvt; g_recoverEvt = false; return e; }

static void publishFault() {
  StateLock l;
  g_state.i2c_fault = g_fault;
  g_state.i2c_recoveries = g_recoveries;
}

// Pemulihan bus: bila ada perangkat menahan SDA LOW (mis. transaksi terputus saat glitch daya),
// beri pulsa SCL sampai SDA lepas, kirim STOP, lalu aktifkan Wire lagi.
// Pin SELALU diberikan eksplisit ke Wire.begin() agar tidak pernah jatuh ke pin bawaan board (GPIO6 = backlight!).
static void recover_locked(bool quiet) {
  Wire.end();
  pinMode(PIN_I2C_SDA, INPUT_PULLUP);
  pinMode(PIN_I2C_SCL, INPUT_PULLUP);
  delayMicroseconds(50);
  for (int i = 0; i < 9 && digitalRead(PIN_I2C_SDA) == LOW; i++) {
    pinMode(PIN_I2C_SCL, OUTPUT); digitalWrite(PIN_I2C_SCL, LOW); delayMicroseconds(10);
    pinMode(PIN_I2C_SCL, INPUT_PULLUP); delayMicroseconds(10);
  }
  pinMode(PIN_I2C_SDA, OUTPUT); digitalWrite(PIN_I2C_SDA, LOW); delayMicroseconds(10);   // STOP: SDA naik saat SCL tinggi
  pinMode(PIN_I2C_SCL, INPUT_PULLUP); delayMicroseconds(10);
  pinMode(PIN_I2C_SDA, INPUT_PULLUP); delayMicroseconds(50);
  g_fault = i2c_lines();                       // masih LOW setelah pemulihan = masalah listrik (bukan perangkat nyangkut)
  Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL, I2C_FREQ_HZ);
  Wire.setTimeOut(30);
  g_recoveries++;
  g_recoverEvt = true;
  if (!quiet && (g_recoveries <= 3 || g_recoveries % 30 == 0))
    Serial.printf("[I2C] bus dipulihkan (ke-%lu) SDA=%s SCL=%s\n", (unsigned long)g_recoveries,
                  (g_fault & 1) ? "LOW" : "ok", (g_fault & 2) ? "LOW" : "ok");
}

void i2c_recover() { { I2cLock l; recover_locked(false); } publishFault(); }

void i2c_init() {
  g_i2c_mtx = xSemaphoreCreateMutex();

  // 1) Cek tingkat garis SEBELUM Wire menyentuhnya: dengan pull-up internal, bus sehat harus HIGH.
  pinMode(PIN_I2C_SDA, INPUT_PULLUP);
  pinMode(PIN_I2C_SCL, INPUT_PULLUP);
  delay(5);
  uint8_t lv = i2c_lines();
  Serial.printf("[I2C] tingkat garis awal: SDA=%s SCL=%s\n", (lv & 1) ? "LOW" : "HIGH", (lv & 2) ? "LOW" : "HIGH");
  g_fault = lv;
  if (lv) { recover_locked(false); }
  else {
    Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL, I2C_FREQ_HZ);
    Wire.setTimeOut(30);
  }

  // 2) Pindai HANYA alamat yang dikenal (5 transaksi, bukan 126)
  const uint8_t addrs[] = I2C_PROBE_ADDRS;
  uint8_t mask = 0;
  Serial.print("[I2C] perangkat ditemukan:");
  for (size_t i = 0; i < sizeof addrs; i++) {
    Wire.beginTransmission(addrs[i]);
    if (Wire.endTransmission(true) == 0) {
      Serial.printf(" 0x%02X", addrs[i]);
      switch (addrs[i]) { case 0x15: mask |= 1; break; case 0x51: mask |= 2; break; case 0x6B: mask |= 4; break;
                          case 0x18: mask |= 8; break; case 0x57: mask |= 16; break; }
    }
  }
  if (!mask) Serial.print(" (TIDAK ADA - bus mati / rel daya periferal turun)");
  Serial.println();
  g_devmask = mask;
  g_fault = i2c_lines();
  { StateLock l; g_state.i2c_devmask = mask; }
  publishFault();
}

bool i2c_watchdog() {
  if (xSemaphoreTake(g_i2c_mtx, pdMS_TO_TICKS(100)) != pdTRUE) return false;   // ada transaksi panjang: lewati
  uint8_t f = i2c_lines();
  if (f) { delay(3); f = i2c_lines(); }
  bool recovered = false;
  if (f) { recover_locked(false); recovered = true; }
  else   { g_fault = 0; }
  xSemaphoreGive(g_i2c_mtx);
  publishFault();
  return recovered;
}
