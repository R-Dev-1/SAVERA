#include "battery.h"
#include "config.h"
#include "app_state.h"
#include "ui.h"

// Kurva Li-Po 1 sel (tegangan istirahat -> %)
struct Pt { float v; uint8_t p; };
static const Pt kCurve[] = {
  {4.20f,100},{4.15f,95},{4.11f,90},{4.08f,85},{4.02f,80},{3.98f,75},{3.95f,70},{3.91f,65},{3.87f,60},
  {3.85f,55},{3.84f,50},{3.82f,45},{3.80f,40},{3.79f,35},{3.77f,30},{3.75f,25},{3.73f,20},{3.71f,15},
  {3.69f,10},{3.61f,5},{3.27f,0}
};

static float pctFromV(float v) {
  const int n = sizeof(kCurve) / sizeof(kCurve[0]);
  if (v >= kCurve[0].v) return 100;
  if (v <= kCurve[n - 1].v) return 0;
  for (int i = 0; i < n - 1; i++) {
    if (v <= kCurve[i].v && v > kCurve[i + 1].v) {
      float f = (v - kCurve[i + 1].v) / (kCurve[i].v - kCurve[i + 1].v);
      return kCurve[i + 1].p + f * (kCurve[i].p - kCurve[i + 1].p);
    }
  }
  return 0;
}

static float vFast = 0, vSlow = 0, vHist[30];   // vHist: 1 sampel/10 dtk => 5 menit
static int histN = 0, histTick = 0;
static bool charging = false, first = true;

void battery_set_charging(bool on) { charging = on; }

void battery_init() {
  pinMode(PIN_BAT_EN, OUTPUT);
  digitalWrite(PIN_BAT_EN, HIGH);          // BAT_EN = kunci daya baterai (sudah dinaikkan di initVariant(); tetap dijaga di sini)
  analogReadResolution(12);
}

static float readV() {
  uint32_t sum = 0;
  for (int i = 0; i < 16; i++) { sum += analogReadMilliVolts(PIN_BAT_ADC); delayMicroseconds(300); }
  return (sum / 16.0f) * BAT_DIVIDER / 1000.0f;
}

void battery_update() {
  float v = readV();
  {   // pantau sag daya: tegangan terendah + picu init ulang panel bila turun di bawah ambang
    static uint32_t lastSag = 0;
    { StateLock l; if (v < g_state.vbat_min) g_state.vbat_min = v; }
    if (v < VBAT_SAG_V && millis() - lastSag > 60000UL) {
      lastSag = millis();
      Serial.printf("[PWR] sag daya: VBAT=%.2f V (< %.2f) -> init ulang panel\n", v, (double)VBAT_SAG_V);
      ui_request_display_reinit();
    }
  }
  if (first) { vFast = vSlow = v; first = false; for (int i = 0; i < 30; i++) vHist[i] = v; histN = 30; }
  vFast += 0.30f * (v - vFast);            // ~ 3-5 dtk
  vSlow += 0.03f * (v - vSlow);            // ~ 30-60 dtk

  // --- estimasi charging dari tegangan ---
  //  a) lonjakan cepat saat USB dicolok (tegangan terminal naik)  b) lonjakan turun saat dicabut
  //  c) tren naik pelan (>= +15 mV / 5 menit) saat fase CC
  if (vFast - vSlow > 0.06f) charging = true;
  else if (vSlow - vFast > 0.06f) charging = false;
  if (++histTick >= 5) {                   // dipanggil tiap 2 dtk => 10 dtk
    histTick = 0;
    float oldest = vHist[0];
    memmove(vHist, vHist + 1, 29 * sizeof(float)); vHist[29] = vFast;
    if (vFast - oldest > 0.015f) charging = true;
    else if (oldest - vFast > 0.015f) charging = false;
  }

  float pct = pctFromV(vFast);
  bool full = charging && vFast >= BAT_FULL_V;
  if (full) pct = 100;
  else if (charging && pct > 99) pct = 99;

  StateLock l;
  g_state.vbat = vFast;
  g_state.batt_pct = (uint8_t)(pct + 0.5f);
  g_state.charging = charging;
}
