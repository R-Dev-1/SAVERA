// clock_rtc.h - RTC PCF85063 onboard: jam, tanggal, bulan, tahun
#pragma once
#include <Arduino.h>
#include <time.h>

void clock_init();
void clock_update();                      // baca RTC -> g_state (panggil tiap ~0.5 dtk)
void clock_set_epoch(time_t utcEpoch);    // tulis RTC (waktu lokal sesuai TZ_POSIX), tandai valid
bool clock_auto();                        // true = sinkron otomatis lewat Wi-Fi (NTP); false = manual
void clock_set_auto(bool on);
void clock_set_local(int year, int month, int day, int hour, int minute);   // atur manual (waktu lokal)
