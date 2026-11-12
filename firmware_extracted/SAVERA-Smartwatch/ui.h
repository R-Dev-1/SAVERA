#pragma once
void ui_early();                     // layar hidup lebih dulu (tidak bergantung I2C/sensor): splash + backlight
void ui_init();                      // LVGL + touch + task UI (butuh i2c_init() sudah jalan)
void ui_request_display_reinit();    // minta init ulang panel (sag daya / bus macet / manual)
void ui_charge_boot();                // mode isi daya saat papan dinyalakan USB; tidak kembali
