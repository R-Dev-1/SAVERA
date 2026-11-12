// power_diag.h - kunci daya baterai (BAT_EN), diagnosis penyebab reset, jejak tahap terakhir (breadcrumb)
#pragma once
#include <Arduino.h>

void power_latch();                         // BAT_EN = HIGH + tunggu tombol PWR dilepas (panggil paling awal)
void boot_diag();                           // cetak alasan reset, hitung boot, ringkasan crash (TASK_WDT dsb.)
const char* reset_reason_str(int reason);

// Jejak tahap: tiap task menulis "sedang apa" ke memori RTC yang selamat dari reset.
// Setelah TASK_WDT/panic, boot berikutnya mencetak tahap terakhir tiap task => tahu siapa yang macet.
enum CrumbSlot : uint8_t { CR_SETUP = 0, CR_UI, CR_IMU, CR_PPG, CR_NET, CR_SYS, CR_CLOUD, CR_COUNT };
void crumb(uint8_t slot, const char* label);   // label HARUS string literal

// Mati lunak: setelah sequence "Sedang mematikan" semua task sensor/Wi-Fi berhenti (USB masih memberi daya)
void power_set_off(bool off);
bool power_is_off();

// Tombol PWR sedang ditekan saat firmware mulai? (dibaca di initVariant, saat papan baru menyala)
// false + reset POWERON = papan dinyalakan oleh USB, bukan oleh tombol
bool power_pwr_at_boot();
