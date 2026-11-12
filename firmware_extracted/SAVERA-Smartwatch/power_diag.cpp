#include "power_diag.h"
#include <Preferences.h>
#include <esp_system.h>
#include <esp_attr.h>
#include "esp_core_dump.h"
#include "config.h"
#include "app_state.h"

struct CrumbBlock { uint32_t magic; uint32_t p[CR_COUNT]; };
RTC_NOINIT_ATTR static CrumbBlock g_cb;
static const char* kSlotName[CR_COUNT] = { "setup", "ui", "imu", "ppg", "net", "sys", "cloud" };
static const uint32_t CB_MAGIC = 0xC0FFEE42;

static volatile bool g_off = false;
void power_set_off(bool off) { g_off = off; }
bool power_is_off() { return g_off; }

void crumb(uint8_t slot, const char* label) {
  if (slot < CR_COUNT) g_cb.p[slot] = (uint32_t)(uintptr_t)label;
}

const char* reset_reason_str(int r) {
  switch ((esp_reset_reason_t)r) {
    case ESP_RST_POWERON:   return "POWERON";
    case ESP_RST_EXT:       return "EXT";
    case ESP_RST_SW:        return "SW";
    case ESP_RST_PANIC:     return "PANIC";
    case ESP_RST_INT_WDT:   return "INT_WDT";
    case ESP_RST_TASK_WDT:  return "TASK_WDT";
    case ESP_RST_WDT:       return "WDT";
    case ESP_RST_BROWNOUT:  return "BROWNOUT";
    case ESP_RST_DEEPSLEEP: return "DEEPSLEEP";
    case ESP_RST_USB:       return "USB";
    default:                return "OTHER";
  }
}

// GPIO15 = BAT_EN: kunci daya jalur baterai (contoh resmi Waveshare: bsp_pwr.c). Harus HIGH secepat mungkin.
static bool g_pwrAtBoot = false;
bool power_pwr_at_boot() { return g_pwrAtBoot; }

void power_latch() {
  pinMode(PIN_BAT_EN, OUTPUT);
  digitalWrite(PIN_BAT_EN, HIGH);
  static bool sampled = false;
  if (!sampled) {                                  // contoh pertama = saat initVariant(): tombol yang menyalakan papan masih ditekan
    sampled = true;
    pinMode(PIN_BTN_PWR, INPUT_PULLUP);
    delayMicroseconds(200);
    g_pwrAtBoot = digitalRead(PIN_BTN_PWR) == LOW;
  }
}

static bool inFlash(uint32_t p) { return p >= 0x42000000u && p < 0x43000000u; }

void boot_diag() {
  esp_reset_reason_t rr = esp_reset_reason();
  const char* rs = reset_reason_str(rr);

  Preferences p; p.begin("diag", false);
  uint32_t boots = p.getUInt("boots", 0) + 1; p.putUInt("boots", boots);
  uint32_t brown = p.getUInt("brown", 0);
  if (rr == ESP_RST_BROWNOUT) { brown++; p.putUInt("brown", brown); }
  p.end();

  { StateLock l; strlcpy(g_state.reset_reason, rs, sizeof g_state.reset_reason); g_state.boot_count = boots; }
  Serial.printf("[BOOT] alasan reset: %s | boot ke-%lu | brownout total: %lu\n", rs, (unsigned long)boots, (unsigned long)brown);

  // Jejak tahap terakhir (hanya bermakna bila reset BUKAN power-on)
  if (rr != ESP_RST_POWERON && g_cb.magic == CB_MAGIC) {
    Serial.print("[BOOT] tahap terakhir sebelum reset:");
    for (int i = 0; i < CR_COUNT; i++) {
      uint32_t v = g_cb.p[i];
      if (v && inFlash(v)) Serial.printf(" %s=%s", kSlotName[i], (const char*)(uintptr_t)v);
    }
    Serial.println();
  }
  g_cb.magic = CB_MAGIC;
  for (int i = 0; i < CR_COUNT; i++) g_cb.p[i] = 0;

  // Ringkasan crash dari partisi coredump: nama task yang sedang jalan saat TASK_WDT/panic = tersangka utama
  if (esp_core_dump_image_check() == ESP_OK) {
    esp_core_dump_summary_t* sum = (esp_core_dump_summary_t*)malloc(sizeof(esp_core_dump_summary_t));
    if (sum && esp_core_dump_get_summary(sum) == ESP_OK) {
      Serial.printf("[CRASH] task=%s pc=0x%08lx ra=0x%08lx mcause=0x%lx\n", sum->exc_task, (unsigned long)sum->exc_pc,
                    (unsigned long)sum->ex_info.ra, (unsigned long)sum->ex_info.mcause);
    }
    free(sum);
    esp_core_dump_image_erase();
  }
}
