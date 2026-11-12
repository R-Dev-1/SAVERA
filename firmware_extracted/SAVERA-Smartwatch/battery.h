// battery.h - tegangan, persentase, dan estimasi status charging (ETA6098 tidak punya pin status ke GPIO)
#pragma once
#include <Arduino.h>

void  battery_init();
void  battery_update();      // panggil tiap ~1-2 detik; menulis ke g_state

void battery_set_charging(bool on);   // dipakai mode isi daya (USB pasti terpasang)
