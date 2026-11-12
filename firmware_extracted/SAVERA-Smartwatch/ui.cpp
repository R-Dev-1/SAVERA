// ui.cpp - LVGL v8.4 + Arduino_GFX (ST7789V2) + CST816T  -  SAVERA Smartwatch
//   Tile 1: Beranda  (jam, hari/tanggal, denyut nadi, SpO2, status Dikenakan, baterai, Wi-Fi). Ketuk jam = atur waktu
//   Tile 2: Wi-Fi    (status, jaringan, IP, kunci IP, pairing HP, pilih manual, lupakan [hanya bila ada jaringan tersimpan])
//   Tile 3: Aktivitas(deteksi IMU Diam/Berjalan/Berlari + rekam data)
//   Tile 4: Sistem   (info perangkat, prosesor, sensor, daya, diagnostik; digulir atas-bawah)
//   Layar terpisah: daftar jaringan, kata sandi, pairing QR, atur waktu, "Sedang mematikan"
#include "ui.h"
#include <lvgl.h>
#include <Arduino_GFX_Library.h>
#include "TouchDrvCSTXXX.hpp"
#include "config.h"
#include "app_state.h"
#include "i2c_bus.h"
#include "wifi_mgr.h"
#include "imu_activity.h"
#include "power_diag.h"
#include "clock_rtc.h"
#include "battery.h"
#include "splash_img.h"
#include <WiFi.h>
#include <esp_system.h>

// ===================== DISPLAY & TOUCH =====================
static Arduino_DataBus* bus = new Arduino_HWSPI(PIN_LCD_DC, PIN_LCD_CS, PIN_LCD_SCK, PIN_LCD_MOSI);
static Arduino_GFX* gfx = new Arduino_ST7789(bus, PIN_LCD_RST, 0 /*rotation*/, true /*IPS*/, LCD_WIDTH, LCD_HEIGHT,
                                             0, 20, 0, 20);
static TouchDrvCSTXXX touch;
static volatile bool g_touchIrq = false;
static bool g_touchActive = false;
static bool g_blOn = true;

static lv_disp_draw_buf_t draw_buf;
static lv_disp_drv_t disp_drv;
static lv_indev_drv_t indev_drv;
static lv_color_t* buf1; static lv_color_t* buf2;

static void blSet(bool on) {
  g_blOn = on;
  ledcWrite(PIN_LCD_BL, on ? BACKLIGHT_LEVEL : 0);
}

static void flush_cb(lv_disp_drv_t* d, const lv_area_t* a, lv_color_t* c) {
  uint32_t w = a->x2 - a->x1 + 1, h = a->y2 - a->y1 + 1;
#if (LV_COLOR_16_SWAP != 0)
  gfx->draw16bitBeRGBBitmap(a->x1, a->y1, (uint16_t*)&c->full, w, h);
#else
  gfx->draw16bitRGBBitmap(a->x1, a->y1, (uint16_t*)&c->full, w, h);
#endif
  lv_disp_flush_ready(d);
}

static bool g_touchOk = false;
#ifndef TOUCH_DEBUG
#define TOUCH_DEBUG 1          // 1 = cetak koordinat sentuhan pertama ke Serial Monitor
#endif

// --- parameter kepekaan (ubah di sini bila perlu) ---
#define TOUCH_GRACE_MS    120  // setelah tepi interrupt, tetap polling selama ini (data pertama CST816 sering belum siap)
#define TOUCH_RELEASE_MS  50   // sentuhan dianggap dilepas bila tidak ada data selama ini (menahan celah data sesaat)
#define SWIPE_PX          24   // geseran horizontal minimal (px) untuk pindah halaman

static volatile bool g_touchRecoverReq = false;   // touch macet: INT LOW tapi tidak ada data
static uint8_t tStuck = 0;
static volatile int  g_pendingDir = 0;        // +1 / -1: geseran terdeteksi, dikerjakan oleh task UI
static volatile bool g_swipeAllowed = true;   // diatur task UI: hanya aktif di layar utama & tanpa dropdown terbuka
static int16_t tx0, ty0, tlx, tly;
static uint32_t tLastSeen = 0, tIrqMs = 0;
static bool tSwipeDone = false, tWakeOnly = false;

static void touch_cb(lv_indev_drv_t*, lv_indev_data_t* data) {
  data->state = LV_INDEV_STATE_REL;
  if (!g_touchOk || !i2c_bus_ok()) return;      // bus macet: jangan menghantam bus
  uint32_t now = millis();
  if (g_touchIrq) { g_touchIrq = false; tIrqMs = now; }
  bool irqLow = digitalRead(PIN_TOUCH_IRQ) == LOW;

  // baca bila: sedang disentuh, pin INT LOW, atau masih dalam jendela toleransi setelah interrupt
  if (g_touchActive || irqLow || (now - tIrqMs) < TOUCH_GRACE_MS) {
    int16_t x[1], y[1];
    uint8_t n;
    { I2cLock l; n = touch.getPoint(x, y, 1); }
    if (n) {
      if (!g_touchActive) {                      // awal sentuhan
        g_touchActive = true;
        tx0 = x[0]; ty0 = y[0]; tSwipeDone = false;
        tWakeOnly = !g_blOn;
        if (tWakeOnly) { blSet(true); lv_disp_trig_activity(NULL); }   // sentuhan pertama hanya membangunkan layar
#if TOUCH_DEBUG
        Serial.printf("[TOUCH] x=%d y=%d\n", x[0], y[0]);
#endif
      }
      tlx = x[0]; tly = y[0]; tLastSeen = now;
      tStuck = 0;
    } else if (irqLow && !g_touchActive) {
      if (++tStuck > 40) { tStuck = 0; g_touchRecoverReq = true; }
    } else tStuck = 0;
  }

  if (!g_touchActive) return;
  if (now - tLastSeen > TOUCH_RELEASE_MS) { g_touchActive = false; tWakeOnly = false; return; }   // dilepas
  if (tWakeOnly) return;

  data->state = LV_INDEV_STATE_PR;
  data->point.x = tlx; data->point.y = tly;

  // deteksi geser sendiri (lebih peka & pasti daripada scroll bawaan LVGL)
  if (!tSwipeDone && g_swipeAllowed) {
    int dx = tlx - tx0, dy = tly - ty0;
    if (abs(dx) >= SWIPE_PX && abs(dx) * 2 > abs(dy) * 3) {
      tSwipeDone = true;
      g_pendingDir = dx < 0 ? +1 : -1;
      lv_indev_wait_release(lv_indev_get_act());   // batalkan klik pada objek yang sedang ditekan
    }
  }
}

static bool touchBegin() {
  for (int i = 0; i < 5; i++) {
    bool ok;
    { I2cLock l; ok = touch.begin(Wire, CST816_SLAVE_ADDRESS, PIN_I2C_SDA, PIN_I2C_SCL); }
    if (ok) return true;
    delay(100);
  }
  return false;
}

// Pemulihan perangkat keras: bus I2C, touch, dan (opsional) layar. Dipicu otomatis (touch macet)
// atau manual: tahan tombol BOOT 2 detik.
static void hwRecover(bool full) {
  Serial.printf("[UI] pemulihan %s\n", full ? "layar+touch+I2C" : "touch+I2C");
  i2c_recover();
  if (full) { gfx->begin(); ledcWrite(PIN_LCD_BL, BACKLIGHT_LEVEL); }
  g_touchOk = touchBegin();
  g_touchActive = false; g_touchIrq = false;
  if (full) lv_obj_invalidate(lv_scr_act());
}

// ===================== INIT LAYAR AWAL & INIT ULANG PANEL =====================
static bool g_earlyDone = false;
static volatile bool g_dispReinitReq = false;
static uint32_t g_dispReinitCnt = 0, g_lastReinitMs = 0;

void ui_request_display_reinit() { g_dispReinitReq = true; }

static void drawSplash() {
  gfx->draw16bitRGBBitmap(0, 0, (uint16_t*)splash_img, SPLASH_W, SPLASH_H);   // logo SAVERA (flash)
}

// Layar dihidupkan SEBELUM I2C/sensor disentuh, jadi bus macet atau PPG bermasalah tidak bisa lagi membuat layar blank.
void ui_early() {
  if (g_earlyDone) return;
  g_earlyDone = true;
  pinMode(PIN_BTN_BOOT, INPUT_PULLUP);
  pinMode(PIN_BTN_PWR, INPUT_PULLUP);
  ledcAttach(PIN_LCD_BL, 5000, 8);
  ledcWrite(PIN_LCD_BL, 0);                       // backlight mati selama init panel (tanpa kilat putih)
  if (!gfx->begin()) Serial.println("[UI] gfx->begin() gagal");
  drawSplash();
  blSet(true);
}

static void doDisplayReinit(const char* why) {
  Serial.printf("[UI] init ulang panel (%s)\n", why);
  ledcWrite(PIN_LCD_BL, 0);
  gfx->begin();                                   // reset hardware + urutan init penuh ST7789
  gfx->fillScreen(RGB565_BLACK);
  if (g_earlyDone && lv_scr_act()) { lv_obj_invalidate(lv_scr_act()); lv_refr_now(NULL); }
  if (g_blOn) ledcWrite(PIN_LCD_BL, BACKLIGHT_LEVEL);
  g_dispReinitCnt++;
  g_lastReinitMs = millis();
  StateLock l; g_state.disp_reinit = g_dispReinitCnt;
}

// ===================== TEMA & HELPER =====================
#define C_BG     lv_color_hex(0x0B0F14)
#define C_CARD   lv_color_hex(0x151B23)
#define C_TEXT   lv_color_hex(0xE8EEF5)
#define C_MUTED  lv_color_hex(0x7D8A99)
#define C_HR     lv_color_hex(0xFF5A6A)
#define C_SPO2   lv_color_hex(0x4FC3F7)
#define C_OK     lv_color_hex(0x3DDC84)
#define C_WARN   lv_color_hex(0xFFB84D)
#define C_BAD    lv_color_hex(0xFF5252)
#define C_IDLE   lv_color_hex(0x8FA3B8)

static lv_obj_t* mkLabel(lv_obj_t* p, const lv_font_t* f, lv_color_t c, const char* t) {
  lv_obj_t* l = lv_label_create(p);
  lv_obj_set_style_text_font(l, f, 0);
  lv_obj_set_style_text_color(l, c, 0);
  lv_label_set_text(l, t);
  return l;
}

static lv_obj_t* mkCard(lv_obj_t* p, int x, int y, int w, int h) {
  lv_obj_t* o = lv_obj_create(p);
  lv_obj_remove_style_all(o);
  lv_obj_set_pos(o, x, y); lv_obj_set_size(o, w, h);
  lv_obj_set_style_bg_color(o, C_CARD, 0); lv_obj_set_style_bg_opa(o, LV_OPA_COVER, 0);
  lv_obj_set_style_radius(o, 14, 0);
  lv_obj_clear_flag(o, LV_OBJ_FLAG_SCROLLABLE);
  return o;
}

static void setText(lv_obj_t* l, const char* t) {
  if (strcmp(lv_label_get_text(l), t) != 0) lv_label_set_text(l, t);
}

static lv_obj_t* mkBtn(lv_obj_t* p, int x, int y, int w, int h, const char* txt, lv_color_t bg, lv_event_cb_t cb) {
  lv_obj_t* b = lv_btn_create(p);
  lv_obj_set_pos(b, x, y); lv_obj_set_size(b, w, h);
  lv_obj_set_style_bg_color(b, bg, 0);
  lv_obj_set_style_radius(b, 12, 0);
  lv_obj_t* l = lv_label_create(b);
  lv_label_set_text(l, txt);
  lv_obj_set_style_text_font(l, &lv_font_montserrat_14, 0);
  lv_obj_center(l);
  lv_obj_set_ext_click_area(b, 4);
  if (cb) lv_obj_add_event_cb(b, cb, LV_EVENT_CLICKED, NULL);
  return b;
}

static void tcol(lv_obj_t* o, lv_color_t c) { if (lv_obj_get_style_text_color(o, 0).full != c.full) lv_obj_set_style_text_color(o, c, 0); }
static void bcol(lv_obj_t* o, lv_color_t c) { if (lv_obj_get_style_bg_color(o, 0).full != c.full) lv_obj_set_style_bg_color(o, c, 0); }

static void setBtnText(lv_obj_t* b, const char* t) { setText(lv_obj_get_child(b, 0), t); }

static const char* kHari[] = {"Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"};
static const char* kBulan[] = {"Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember"};

// ===================== WIDGET =====================
static lv_obj_t *scr_main, *scr_scan, *scr_pw, *scr_pair, *scr_time, *scr_off, *scr_type, *scr_chg;
static lv_obj_t *tv, *t_home, *t_wifi, *t_act, *t_sys;
// status bar
static lv_obj_t *sb_wifi, *sb_batt;
// home
static lv_obj_t *lbl_time, *lbl_date, *lbl_hr, *lbl_spo2, *chip, *chip_dot, *chip_txt, *lbl_name, *lbl_ip;
// wifi tile
static lv_obj_t *wv_status, *wv_ssid, *wv_ip, *wv_rssi, *sw_iplock, *btn_manual, *btn_forget;
// system tile
static lv_obj_t *sys_cont;
enum { SV_UPTIME, SV_CHIP, SV_RAM, SV_TOUCH, SV_IMU, SV_PPG, SV_RTC, SV_BATT, SV_CHG, SV_WIFI, SV_IP, SV_CLOUD, SV_MAC, SV_I2C, SV_RESET, SV_BOOT, SV_COUNT };
static lv_obj_t* sv[SV_COUNT];
// time screen
static lv_obj_t *tm_sw, *tm_hh, *tm_mm, *tm_dd, *tm_mo, *tm_yy, *tm_hint, *tm_colon;
static char optH[96], optM[190], optD[100], optY[220];
// power-off
static lv_img_dsc_t splash_dsc;
static bool offActive = false;
static uint32_t offT0 = 0;
// pairing screen
static lv_obj_t *pr_qr, *pr_l1, *pr_l2;
static char pairQr[112] = "";
static bool pairSeen = false;
static uint32_t pairOpenMs = 0, pairOkMs = 0;
// activity tile
static lv_obj_t *lbl_act, *lbl_act_sub, *btn_rec, *btn_type, *lbl_rec;
static int recType = -1;                                   // -1 = belum dipilih; 0 Diam, 1 Berjalan, 2 Berlari
static const char* kTypeName[] = {"Diam", "Berjalan", "Berlari"};
static lv_color_t typeColor(int t) { return lv_palette_main(t == 0 ? LV_PALETTE_BLUE_GREY : t == 1 ? LV_PALETTE_GREEN : LV_PALETTE_ORANGE); }
// charge screen
static lv_obj_t *chg_pct, *chg_txt;
// scan screen
static lv_obj_t *scan_list, *scan_title;
static uint32_t scanSeqShown = 0;
static char scanSsid[12][33]; static bool scanSecure[12];
// password screen
static lv_obj_t *pw_ssid, *pw_ta, *pw_kb;
static char pendingSsid[33];
static bool inSyncSwitch = false;
static int g_tileIdx = 0;                       // indeks halaman aktif (dikelola sendiri; getter tileview kosong sebelum geseran pertama)

// ===================== EVENT =====================
static void goMain(int tile = -1) {
  lv_scr_load(scr_main);
  if (tile >= 0 && tile <= 3) {
    g_tileIdx = tile;
    lv_obj_set_tile(tv, tile == 0 ? t_home : tile == 1 ? t_wifi : tile == 2 ? t_act : t_sys, LV_ANIM_OFF);
  }
}

static void startConnect() {
  wifi_connect(pendingSsid, lv_textarea_get_text(pw_ta));
  lv_textarea_set_text(pw_ta, "");
  goMain(1);
}

// Membuka "Pilih manual" = memindai SEKALI. Daftar lama dikosongkan agar hasil basi tidak tampil; tombol "Pindai" untuk memindai lagi.
static void startScanUi() {
  lv_obj_clean(scan_list);
  scanSeqShown = 0xFFFFFFFFu;                 // paksa daftar digambar ulang saat hasil baru masuk
  lv_label_set_text(scan_title, "Memindai...");
  wifi_scan_request();
}
static void ev_open_scan(lv_event_t*) { startScanUi(); lv_scr_load(scr_scan); }
static void ev_rescan(lv_event_t*) { startScanUi(); }
static void ev_back_main(lv_event_t*) { goMain(1); }
static void ev_forget(lv_event_t*) { wifi_forget(); }

static void ev_open_pair(lv_event_t*) {
  pairQr[0] = 0; pairSeen = false; pairOkMs = 0; pairOpenMs = millis();
  lv_obj_add_flag(pr_qr, LV_OBJ_FLAG_HIDDEN);             // QR sisa sesi lalu disembunyikan sampai AP benar-benar aktif
  lv_label_set_text(pr_l1, "Menyiapkan...");
  lv_label_set_text(pr_l2, "");
  wifi_prov_start();
  lv_scr_load(scr_pair);
}
static void ev_pair_cancel(lv_event_t*) { wifi_prov_stop(); goMain(1); }
static void ev_pair_manual(lv_event_t*) { wifi_prov_stop(); ev_open_scan(nullptr); }

// ---- atur waktu ----
static void tmApplyEnabled() {
  bool a = lv_obj_has_state(tm_sw, LV_STATE_CHECKED);
  lv_obj_t* r[] = {tm_hh, tm_mm, tm_dd, tm_mo, tm_yy};
  for (lv_obj_t* o : r) {                                   // sinkron otomatis aktif => atur manual dikunci (abu-abu, tidak bisa disentuh)
    if (a) { lv_obj_add_state(o, LV_STATE_DISABLED); lv_obj_clear_flag(o, LV_OBJ_FLAG_CLICKABLE); }
    else   { lv_obj_clear_state(o, LV_STATE_DISABLED); lv_obj_add_flag(o, LV_OBJ_FLAG_CLICKABLE); }
  }
  lv_obj_set_style_opa(tm_colon, a ? LV_OPA_30 : LV_OPA_COVER, 0);
  lv_label_set_text(tm_hint, a ? "Diambil dari internet via Wi-Fi" : "Atur tanggal dan jam manual");
}
static void ev_tm_sw(lv_event_t*) { tmApplyEnabled(); }
static void ev_open_time(lv_event_t*) {
  AppState s = state_snapshot();
  int y = s.time_valid ? s.year : 2026, mo = s.time_valid ? s.month : 1, d = s.time_valid ? s.day : 1;
  int h = s.time_valid ? s.hour : 8, mi = s.time_valid ? s.minute : 0;
  if (y < 2025 || y > 2060) y = 2026;
  lv_roller_set_selected(tm_hh, h, LV_ANIM_OFF);
  lv_roller_set_selected(tm_mm, mi, LV_ANIM_OFF);
  lv_roller_set_selected(tm_dd, d - 1, LV_ANIM_OFF);
  lv_roller_set_selected(tm_mo, mo - 1, LV_ANIM_OFF);
  lv_roller_set_selected(tm_yy, y - 2025, LV_ANIM_OFF);
  if (clock_auto()) lv_obj_add_state(tm_sw, LV_STATE_CHECKED); else lv_obj_clear_state(tm_sw, LV_STATE_CHECKED);
  tmApplyEnabled();
  lv_scr_load(scr_time);
}
static void ev_tm_cancel(lv_event_t*) { goMain(0); }
static void ev_tm_save(lv_event_t*) {
  if (lv_obj_has_state(tm_sw, LV_STATE_CHECKED)) {
    clock_set_auto(true);
    wifi_ntp_resync();
  } else {
    int h = lv_roller_get_selected(tm_hh), mi = lv_roller_get_selected(tm_mm);
    int d = lv_roller_get_selected(tm_dd) + 1, mo = lv_roller_get_selected(tm_mo) + 1, y = 2025 + lv_roller_get_selected(tm_yy);
    static const uint8_t dim[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
    int mx = dim[mo - 1] + ((mo == 2 && ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0)) ? 1 : 0);
    if (d > mx) d = mx;
    clock_set_auto(false);
    clock_set_local(y, mo, d, h, mi);
    clock_update();
  }
  goMain(0);
}static void ev_iplock(lv_event_t* e) {
  if (inSyncSwitch) return;
  wifi_set_ip_lock(lv_obj_has_state(lv_event_get_target(e), LV_STATE_CHECKED));
}

static void ev_pick_ssid(lv_event_t* e) {
  int i = (int)(intptr_t)lv_event_get_user_data(e);
  strlcpy(pendingSsid, scanSsid[i], sizeof pendingSsid);
  if (scanSecure[i]) {
    lv_label_set_text(pw_ssid, pendingSsid);
    lv_textarea_set_text(pw_ta, "");
    lv_textarea_set_password_mode(pw_ta, true);
    lv_scr_load(scr_pw);
  } else {
    wifi_connect(pendingSsid, "");
    goMain(1);
  }
}

static void ev_pw_cancel(lv_event_t*) { lv_scr_load(scr_scan); }
static void ev_pw_connect(lv_event_t*) { startConnect(); }
static void ev_pw_show(lv_event_t*) { lv_textarea_set_password_mode(pw_ta, !lv_textarea_get_password_mode(pw_ta)); }
static void ev_kb(lv_event_t* e) {
  lv_event_code_t c = lv_event_get_code(e);
  if (c == LV_EVENT_READY) startConnect();
  else if (c == LV_EVENT_CANCEL) lv_scr_load(scr_scan);
}

static char recErr[64] = "";
static void ev_rec(lv_event_t*) {
  AppState s = state_snapshot();
  if (s.logging) { log_stop(); recErr[0] = 0; return; }
  if (recType < 0) return;                                  // tombol rekam baru aktif setelah tipe dipilih
  if (!log_start(kTypeName[recType], LOG_MODE_FLASH, recErr, sizeof recErr)) { /* pesan tampil di status */ } else recErr[0] = 0;
}
static void ev_type_open(lv_event_t*) { lv_scr_load(scr_type); }
static void ev_type_pick(lv_event_t* e) { recType = (int)(intptr_t)lv_event_get_user_data(e); recErr[0] = 0; goMain(2); }
static void ev_type_cancel(lv_event_t*) { goMain(2); }

// ===================== BANGUN UI =====================
// Layar fisik berada di dalam bezel jam dengan sudut membulat, sehingga tepi atas/bawah/sudut tertutup.
// Semua konten diberi margin aman. Ubah 4 angka ini bila masih ada yang terpotong.
static const int MX     = 14;                 // margin kiri/kanan konten
static const int SB_PAD = 26;                 // jarak ikon status bar dari tepi (sudut atas membulat)
static const int SB_H   = 34;                 // tinggi status bar
static const int TILE_H = 226;                // tinggi area tile (berakhir y=260, sisakan ruang bawah untuk bezel)
static const int CW     = LCD_WIDTH - 2 * MX; // lebar kartu penuh = 212

static void buildStatusBar() {
  lv_obj_t* bar = lv_obj_create(scr_main);
  lv_obj_remove_style_all(bar);
  lv_obj_set_size(bar, LCD_WIDTH, SB_H); lv_obj_set_pos(bar, 0, 0);
  sb_wifi = mkLabel(bar, &lv_font_montserrat_14, C_MUTED, LV_SYMBOL_WIFI);
  lv_obj_set_pos(sb_wifi, SB_PAD, 9);
  sb_batt = mkLabel(bar, &lv_font_montserrat_14, C_TEXT, "--%");
  lv_obj_align(sb_batt, LV_ALIGN_TOP_RIGHT, -SB_PAD, 9);
}

static void buildHome() {
  lbl_time = mkLabel(t_home, &lv_font_montserrat_48, C_TEXT, "--:--");
  lv_obj_align(lbl_time, LV_ALIGN_TOP_MID, 0, -2);
  lbl_date = mkLabel(t_home, &lv_font_montserrat_14, C_MUTED, "");
  lv_obj_align(lbl_date, LV_ALIGN_TOP_MID, 0, 54);
  // ketuk jam / tanggal = atur waktu
  for (lv_obj_t* o : {lbl_time, lbl_date}) {
    lv_obj_add_flag(o, LV_OBJ_FLAG_CLICKABLE);
    lv_obj_set_ext_click_area(o, 10);
    lv_obj_add_event_cb(o, ev_open_time, LV_EVENT_CLICKED, NULL);
  }

  const int cw = (CW - 12) / 2;                         // 100
  lv_obj_t* c1 = mkCard(t_home, MX, 76, cw, 78);
  lv_obj_t* h1 = mkLabel(c1, &lv_font_montserrat_14, C_HR, "DENYUT");
  lv_obj_set_width(h1, cw); lv_obj_set_style_text_align(h1, LV_TEXT_ALIGN_CENTER, 0);
  lv_obj_set_pos(h1, 0, 6);
  lbl_hr = mkLabel(c1, &lv_font_montserrat_32, C_TEXT, "--");
  lv_obj_align(lbl_hr, LV_ALIGN_CENTER, 0, 4);
  lv_obj_t* u1 = mkLabel(c1, &lv_font_montserrat_12, C_MUTED, "BPM");
  lv_obj_align(u1, LV_ALIGN_BOTTOM_MID, 0, -4);

  lv_obj_t* c2 = mkCard(t_home, MX + cw + 12, 76, cw, 78);
  lv_obj_t* h2 = mkLabel(c2, &lv_font_montserrat_14, C_SPO2, "OKSIGEN");
  lv_obj_set_width(h2, cw); lv_obj_set_style_text_align(h2, LV_TEXT_ALIGN_CENTER, 0);
  lv_obj_set_pos(h2, 0, 6);
  lbl_spo2 = mkLabel(c2, &lv_font_montserrat_32, C_TEXT, "--");
  lv_obj_align(lbl_spo2, LV_ALIGN_CENTER, 0, 4);
  lv_obj_t* u2 = mkLabel(c2, &lv_font_montserrat_12, C_MUTED, "SpO2 %");
  lv_obj_align(u2, LV_ALIGN_BOTTOM_MID, 0, -4);

  chip = mkCard(t_home, MX, 160, CW, 26);
  lv_obj_set_style_radius(chip, 13, 0);
  chip_dot = lv_obj_create(chip);
  lv_obj_remove_style_all(chip_dot);
  lv_obj_set_size(chip_dot, 10, 10);
  lv_obj_set_style_radius(chip_dot, LV_RADIUS_CIRCLE, 0);
  lv_obj_set_style_bg_opa(chip_dot, LV_OPA_COVER, 0);
  lv_obj_align(chip_dot, LV_ALIGN_LEFT_MID, 12, 0);
  chip_txt = mkLabel(chip, &lv_font_montserrat_14, C_TEXT, "Tidak Dikenakan");
  lv_obj_set_width(chip_txt, CW - 40);
  lv_label_set_long_mode(chip_txt, LV_LABEL_LONG_DOT);
  lv_obj_align(chip_txt, LV_ALIGN_LEFT_MID, 30, 0);

  lbl_name = mkLabel(t_home, &lv_font_montserrat_14, C_MUTED, DEVICE_LABEL);
  lv_obj_align(lbl_name, LV_ALIGN_TOP_MID, 0, 190);
  lbl_ip = mkLabel(t_home, &lv_font_montserrat_14, C_MUTED, "Belum terhubung");
  lv_obj_align(lbl_ip, LV_ALIGN_TOP_MID, 0, 205);
}

static lv_obj_t* mkRow(lv_obj_t* card, int y, const char* key) {
  lv_obj_t* k = mkLabel(card, &lv_font_montserrat_14, C_MUTED, key);
  lv_obj_set_pos(k, 12, y);
  lv_obj_t* v = mkLabel(card, &lv_font_montserrat_14, C_TEXT, "-");
  lv_obj_set_width(v, CW - 92 - 8);
  lv_label_set_long_mode(v, LV_LABEL_LONG_DOT);
  lv_obj_set_pos(v, 92, y);
  return v;
}

static void buildWifi() {
  lv_obj_t* t = mkLabel(t_wifi, &lv_font_montserrat_20, C_TEXT, "Wi-Fi");
  lv_obj_set_pos(t, MX + 4, 0);
  lv_obj_t* card = mkCard(t_wifi, MX, 28, CW, 94);
  wv_status = mkRow(card, 6, "Status");
  wv_ssid   = mkRow(card, 27, "Jaringan");
  wv_ip     = mkRow(card, 48, "Alamat IP");
  wv_rssi   = mkRow(card, 69, "Sinyal");

  lv_obj_t* kl = mkLabel(t_wifi, &lv_font_montserrat_14, C_TEXT, "Kunci IP");
  lv_obj_set_pos(kl, MX + 4, 130);
  sw_iplock = lv_switch_create(t_wifi);
  lv_obj_set_size(sw_iplock, 54, 28);
  lv_obj_set_ext_click_area(sw_iplock, 12);
  lv_obj_set_pos(sw_iplock, LCD_WIDTH - MX - 54 - 2, 124);
  lv_obj_add_event_cb(sw_iplock, ev_iplock, LV_EVENT_VALUE_CHANGED, NULL);

  mkBtn(t_wifi, MX, 156, CW, 32, LV_SYMBOL_WIFI "  Pasangkan lewat HP", lv_palette_main(LV_PALETTE_BLUE), ev_open_pair);
  btn_manual = mkBtn(t_wifi, MX, 192, CW, 32, "Pilih manual", lv_palette_darken(LV_PALETTE_GREY, 2), ev_open_scan);
  btn_forget = mkBtn(t_wifi, MX + 136, 192, CW - 136, 32, "Lupakan", lv_palette_darken(LV_PALETTE_GREY, 2), ev_forget);
  lv_obj_add_flag(btn_forget, LV_OBJ_FLAG_HIDDEN);          // baru muncul bila ada jaringan tersimpan
}

// --- halaman Sistem: daftar info yang digulir atas-bawah ---
static lv_obj_t* mkSection(const char* title) {
  lv_obj_t* l = mkLabel(sys_cont, &lv_font_montserrat_12, lv_palette_main(LV_PALETTE_LIGHT_BLUE), title);
  lv_obj_set_style_pad_top(l, 8, 0);
  return l;
}
static lv_obj_t* mkInfo(const char* key, const char* val, int slot = -1) {
  lv_obj_t* r = lv_obj_create(sys_cont);
  lv_obj_remove_style_all(r);
  lv_obj_set_size(r, CW, LV_SIZE_CONTENT);
  lv_obj_set_flex_flow(r, LV_FLEX_FLOW_ROW);
  lv_obj_set_style_pad_column(r, 6, 0);
  lv_obj_clear_flag(r, LV_OBJ_FLAG_SCROLLABLE);
  lv_obj_t* k = mkLabel(r, &lv_font_montserrat_12, C_MUTED, key);
  lv_obj_set_width(k, 62);
  lv_obj_t* v = mkLabel(r, &lv_font_montserrat_12, C_TEXT, val);
  lv_obj_set_flex_grow(v, 1);
  lv_label_set_long_mode(v, LV_LABEL_LONG_WRAP);
  if (slot >= 0) sv[slot] = v;
  return v;
}

static void buildSystem() {
  sys_cont = lv_obj_create(t_sys);
  lv_obj_remove_style_all(sys_cont);
  lv_obj_set_size(sys_cont, LCD_WIDTH, TILE_H);
  lv_obj_set_pos(sys_cont, 0, 0);
  lv_obj_set_flex_flow(sys_cont, LV_FLEX_FLOW_COLUMN);
  lv_obj_set_style_pad_left(sys_cont, MX, 0);
  lv_obj_set_style_pad_right(sys_cont, MX, 0);
  lv_obj_set_style_pad_bottom(sys_cont, 20, 0);
  lv_obj_set_style_pad_row(sys_cont, 3, 0);
  lv_obj_set_scroll_dir(sys_cont, LV_DIR_VER);
  lv_obj_set_scrollbar_mode(sys_cont, LV_SCROLLBAR_MODE_OFF);

  lv_obj_t* t = mkLabel(sys_cont, &lv_font_montserrat_20, C_TEXT, "Sistem");
  lv_obj_set_style_pad_left(t, 4, 0);

  mkSection("PERANGKAT");
  mkInfo("Nama", DEVICE_LABEL);
  mkInfo("Firmware", "v" FW_VERSION);
  mkInfo("Papan", "Waveshare ESP32-C6-Touch-LCD-1.69");
  mkInfo("Aktif", "-", SV_UPTIME);

  mkSection("PROSESOR");
  mkInfo("Chip", "-", SV_CHIP);
  mkInfo("Memori", "-", SV_RAM);
  mkInfo("Flash", "16 MB (QSPI)");
  mkInfo("Radio", "Wi-Fi 6 2.4 GHz, Bluetooth 5 LE");

  mkSection("LAYAR & SENTUH");
  mkInfo("Layar", "ST7789 IPS 1.69\" 240x280");
  mkInfo("Sentuh", "-", SV_TOUCH);

  mkSection("SENSOR");
  mkInfo("Gerak", "-", SV_IMU);
  mkInfo("Nadi/SpO2", "-", SV_PPG);
  mkInfo("Jam", "-", SV_RTC);

  mkSection("DAYA");
  mkInfo("Baterai", "-", SV_BATT);
  mkInfo("Pengisi", "-", SV_CHG);

  mkSection("JARINGAN");
  mkInfo("Wi-Fi", "-", SV_WIFI);
  mkInfo("IP", "-", SV_IP);
  mkInfo("Cloud", "-", SV_CLOUD);
  mkInfo("MAC", "-", SV_MAC);

  mkSection("DIAGNOSTIK");
  mkInfo("Bus I2C", "-", SV_I2C);
  mkInfo("Reset", "-", SV_RESET);
  mkInfo("Boot", "-", SV_BOOT);
}

static void buildActivity() {
  lv_obj_t* t = mkLabel(t_act, &lv_font_montserrat_20, C_TEXT, "Aktivitas");
  lv_obj_set_pos(t, MX + 4, 0);
  lv_obj_t* card = mkCard(t_act, MX, 28, CW, 60);
  lbl_act = mkLabel(card, &lv_font_montserrat_32, C_IDLE, "DIAM");
  lv_obj_align(lbl_act, LV_ALIGN_CENTER, 0, -8);
  lbl_act_sub = mkLabel(card, &lv_font_montserrat_12, C_MUTED, "");
  lv_obj_align(lbl_act_sub, LV_ALIGN_BOTTOM_MID, 0, -4);

  lv_obj_t* rh = mkLabel(t_act, &lv_font_montserrat_14, C_TEXT, "Rekam Data");
  lv_obj_set_pos(rh, MX + 4, 94);
  lv_obj_t* rc = mkLabel(t_act, &lv_font_montserrat_12, C_MUTED, "Data Ini Digunakan Untuk Machine Learning");
  lv_obj_set_width(rc, CW - 4); lv_label_set_long_mode(rc, LV_LABEL_LONG_WRAP);
  lv_obj_set_pos(rc, MX + 4, 112);

  // Tombol Tipe menampilkan tipe terpilih (nama + warna). Tombol rekam di bawahnya.
  btn_type = mkBtn(t_act, MX, 148, CW, 36, "Pilih Tipe", lv_palette_darken(LV_PALETTE_GREY, 2), ev_type_open);
  btn_rec  = mkBtn(t_act, MX, 190, CW, 36, "Mulai Rekam", lv_palette_main(LV_PALETTE_GREEN), ev_rec);

  lbl_rec = mkLabel(t_act, &lv_font_montserrat_12, C_WARN, "");          // hanya untuk pesan galat rekam
  lv_obj_set_width(lbl_rec, CW);
  lv_label_set_long_mode(lbl_rec, LV_LABEL_LONG_DOT);
  lv_obj_set_pos(lbl_rec, MX + 4, 130);
  lv_obj_add_flag(lbl_rec, LV_OBJ_FLAG_HIDDEN);
}

static void buildType() {
  scr_type = lv_obj_create(NULL);
  lv_obj_set_style_bg_color(scr_type, C_BG, 0);
  lv_obj_t* tt = mkLabel(scr_type, &lv_font_montserrat_16, C_TEXT, "Pilih Tipe Data");
  lv_obj_set_pos(tt, SB_PAD, 10);
  for (int i = 0; i < 3; i++) {
    lv_obj_t* b = mkBtn(scr_type, MX, 40 + i * 50, CW, 42, kTypeName[i], lv_palette_main(i == 0 ? LV_PALETTE_BLUE_GREY : i == 1 ? LV_PALETTE_GREEN : LV_PALETTE_ORANGE), ev_type_pick);
    lv_obj_remove_event_cb(b, ev_type_pick);
    lv_obj_add_event_cb(b, ev_type_pick, LV_EVENT_CLICKED, (void*)(intptr_t)i);
  }
  mkBtn(scr_type, MX, 194, CW, 36, "Batal", lv_palette_darken(LV_PALETTE_GREY, 2), ev_type_cancel);
}

static void buildScan() {
  scr_scan = lv_obj_create(NULL);
  lv_obj_set_style_bg_color(scr_scan, C_BG, 0);
  scan_title = mkLabel(scr_scan, &lv_font_montserrat_16, C_TEXT, "Pilih Jaringan");
  lv_obj_set_pos(scan_title, SB_PAD, 12);
  scan_list = lv_list_create(scr_scan);
  lv_obj_set_pos(scan_list, 8, 40); lv_obj_set_size(scan_list, LCD_WIDTH - 16, 168);
  mkBtn(scr_scan, MX, 214, 100, 38, "Pindai", lv_palette_main(LV_PALETTE_BLUE), ev_rescan);
  mkBtn(scr_scan, LCD_WIDTH - MX - 100, 214, 100, 38, "Kembali", lv_palette_darken(LV_PALETTE_GREY, 2), ev_back_main);
}

static void buildPair() {
  scr_pair = lv_obj_create(NULL);
  lv_obj_set_style_bg_color(scr_pair, C_BG, 0);
  lv_obj_t* tt = mkLabel(scr_pair, &lv_font_montserrat_14, C_TEXT, "Pasangkan lewat HP");
  lv_obj_set_pos(tt, SB_PAD, 8);
  lv_obj_t* box = lv_obj_create(scr_pair);
  lv_obj_remove_style_all(box);
  lv_obj_set_size(box, 150, 150); lv_obj_set_pos(box, (LCD_WIDTH - 150) / 2, 30);
  lv_obj_set_style_bg_color(box, lv_color_white(), 0); lv_obj_set_style_bg_opa(box, LV_OPA_COVER, 0);
  lv_obj_set_style_radius(box, 8, 0);
  pr_qr = lv_qrcode_create(box, 134, lv_color_black(), lv_color_white());
  lv_obj_center(pr_qr);
  pr_l1 = mkLabel(scr_pair, &lv_font_montserrat_12, C_TEXT, "");
  lv_obj_set_width(pr_l1, CW); lv_label_set_long_mode(pr_l1, LV_LABEL_LONG_WRAP);
  lv_obj_set_style_text_align(pr_l1, LV_TEXT_ALIGN_CENTER, 0);
  lv_obj_set_pos(pr_l1, MX, 184);
  pr_l2 = mkLabel(scr_pair, &lv_font_montserrat_12, C_MUTED, "");
  lv_obj_set_width(pr_l2, CW); lv_label_set_long_mode(pr_l2, LV_LABEL_LONG_WRAP);
  lv_obj_set_style_text_align(pr_l2, LV_TEXT_ALIGN_CENTER, 0);
  lv_obj_set_pos(pr_l2, MX, 212);
  mkBtn(scr_pair, MX, 234, 96, 28, "Batal", lv_palette_darken(LV_PALETTE_GREY, 2), ev_pair_cancel);
  mkBtn(scr_pair, MX + 104, 234, CW - 104, 28, "Ketik di jam", lv_palette_darken(LV_PALETTE_GREY, 2), ev_pair_manual);
}

static lv_obj_t* mkRoller(lv_obj_t* p, const char* opts, int x, int y, int w, bool inf) {
  lv_obj_t* r = lv_roller_create(p);
  lv_roller_set_options(r, opts, inf ? LV_ROLLER_MODE_INFINITE : LV_ROLLER_MODE_NORMAL);
  lv_obj_set_style_text_font(r, &lv_font_montserrat_14, 0);
  lv_obj_set_style_text_line_space(r, 3, 0);
  lv_obj_set_style_pad_all(r, 0, 0);
  // tampilan terkunci: seluruh roller memudar + sorotan jadi abu-abu
  lv_obj_set_style_opa(r, LV_OPA_40, LV_STATE_DISABLED);
  lv_obj_set_style_bg_color(r, lv_palette_main(LV_PALETTE_GREY), LV_PART_SELECTED | LV_STATE_DISABLED);
  lv_obj_set_style_text_color(r, lv_palette_main(LV_PALETTE_GREY), LV_STATE_DISABLED);
  lv_roller_set_visible_row_count(r, 3);
  lv_obj_set_size(r, w, 58);                                  // tinggi tetap: dua baris roller + tombol muat tanpa bertumpuk
  lv_obj_set_pos(r, x, y);
  return r;
}

static void buildTime() {
  scr_time = lv_obj_create(NULL);
  lv_obj_set_style_bg_color(scr_time, C_BG, 0);
  lv_obj_t* tt = mkLabel(scr_time, &lv_font_montserrat_16, C_TEXT, "Atur Waktu");
  lv_obj_set_pos(tt, SB_PAD, 8);
  lv_obj_t* sl = mkLabel(scr_time, &lv_font_montserrat_14, C_TEXT, "Sinkron otomatis");
  lv_obj_set_pos(sl, MX + 2, 36);
  tm_sw = lv_switch_create(scr_time);
  lv_obj_set_size(tm_sw, 46, 24);
  lv_obj_set_ext_click_area(tm_sw, 10);
  lv_obj_set_pos(tm_sw, LCD_WIDTH - MX - 46, 32);
  lv_obj_add_event_cb(tm_sw, ev_tm_sw, LV_EVENT_VALUE_CHANGED, NULL);
  tm_hint = mkLabel(scr_time, &lv_font_montserrat_12, C_MUTED, "");
  lv_obj_set_width(tm_hint, CW); lv_label_set_long_mode(tm_hint, LV_LABEL_LONG_DOT);   // satu baris saja
  lv_obj_set_pos(tm_hint, MX + 2, 62);

  size_t n = 0; optH[0] = optM[0] = optD[0] = optY[0] = 0;
  for (int i = 0; i < 24; i++) n += snprintf(optH + n, sizeof optH - n, i ? "\n%02d" : "%02d", i);
  n = 0; for (int i = 0; i < 60; i++) n += snprintf(optM + n, sizeof optM - n, i ? "\n%02d" : "%02d", i);
  n = 0; for (int i = 1; i <= 31; i++) n += snprintf(optD + n, sizeof optD - n, i > 1 ? "\n%02d" : "%02d", i);
  n = 0; for (int i = 2025; i <= 2060; i++) n += snprintf(optY + n, sizeof optY - n, i > 2025 ? "\n%d" : "%d", i);

  const int y1 = 84, y2 = 148;                                // dua baris roller (tinggi 58) + jarak 6
  tm_hh = mkRoller(scr_time, optH, MX, y1, 96, true);
  tm_mm = mkRoller(scr_time, optM, MX + 116, y1, 96, true);
  tm_colon = mkLabel(scr_time, &lv_font_montserrat_20, C_TEXT, ":");
  lv_obj_set_pos(tm_colon, MX + 100, y1 + 17);
  tm_dd = mkRoller(scr_time, optD, MX, y2, 58, true);
  tm_mo = mkRoller(scr_time, "Jan\nFeb\nMar\nApr\nMei\nJun\nJul\nAgu\nSep\nOkt\nNov\nDes", MX + 64, y2, 68, false);
  tm_yy = mkRoller(scr_time, optY, MX + 138, y2, 74, false);
  mkBtn(scr_time, MX, 216, 100, 32, "Batal", lv_palette_darken(LV_PALETTE_GREY, 2), ev_tm_cancel);
  mkBtn(scr_time, MX + 112, 216, CW - 112, 32, "Simpan", lv_palette_main(LV_PALETTE_GREEN), ev_tm_save);
}

static void buildOff() {
  splash_dsc.header.always_zero = 0;
  splash_dsc.header.w = SPLASH_W; splash_dsc.header.h = SPLASH_H;
  splash_dsc.header.cf = LV_IMG_CF_TRUE_COLOR;
  splash_dsc.data_size = SPLASH_W * SPLASH_H * 2;
  splash_dsc.data = (const uint8_t*)splash_img;
  scr_off = lv_obj_create(NULL);
  lv_obj_set_style_bg_color(scr_off, lv_color_white(), 0);
  lv_obj_set_style_bg_opa(scr_off, LV_OPA_COVER, 0);
  lv_obj_t* img = lv_img_create(scr_off);
  lv_img_set_src(img, &splash_dsc);
  lv_obj_set_pos(img, 0, 0);
  lv_obj_t* row = lv_obj_create(scr_off);
  lv_obj_remove_style_all(row);
  lv_obj_set_size(row, LCD_WIDTH, 28);
  lv_obj_set_pos(row, 0, 228);
  lv_obj_set_flex_flow(row, LV_FLEX_FLOW_ROW);
  lv_obj_set_flex_align(row, LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER);
  lv_obj_set_style_pad_column(row, 8, 0);
  lv_obj_clear_flag(row, LV_OBJ_FLAG_SCROLLABLE);
  lv_obj_t* sp = lv_spinner_create(row, 1000, 70);
  lv_obj_set_size(sp, 22, 22);
  lv_obj_set_style_arc_width(sp, 3, LV_PART_MAIN);
  lv_obj_set_style_arc_width(sp, 3, LV_PART_INDICATOR);
  lv_obj_set_style_arc_color(sp, lv_color_hex(0xDCE6F5), LV_PART_MAIN);
  lv_obj_set_style_arc_color(sp, lv_color_hex(0x1E6BE6), LV_PART_INDICATOR);
  lv_obj_t* tx = mkLabel(row, &lv_font_montserrat_14, lv_color_hex(0x0B2A6B), "Sedang mematikan...");
  (void)tx;
}

static void buildPassword() {
  scr_pw = lv_obj_create(NULL);
  lv_obj_set_style_bg_color(scr_pw, C_BG, 0);
  pw_ssid = mkLabel(scr_pw, &lv_font_montserrat_16, C_TEXT, "");
  lv_obj_set_width(pw_ssid, LCD_WIDTH - 2 * SB_PAD);
  lv_label_set_long_mode(pw_ssid, LV_LABEL_LONG_DOT);
  lv_obj_set_pos(pw_ssid, SB_PAD, 12);
  pw_ta = lv_textarea_create(scr_pw);
  lv_textarea_set_one_line(pw_ta, true);
  lv_textarea_set_password_mode(pw_ta, true);
  lv_textarea_set_placeholder_text(pw_ta, "Kata sandi Wi-Fi");
  lv_obj_set_pos(pw_ta, MX, 36); lv_obj_set_size(pw_ta, CW, 38);
  mkBtn(scr_pw, MX, 80, 58, 32, "Batal", lv_palette_darken(LV_PALETTE_GREY, 2), ev_pw_cancel);
  mkBtn(scr_pw, MX + 63, 80, 58, 32, "Lihat", lv_palette_darken(LV_PALETTE_GREY, 2), ev_pw_show);
  mkBtn(scr_pw, MX + 126, 80, CW - 126, 32, "Sambung", lv_palette_main(LV_PALETTE_GREEN), ev_pw_connect);
  pw_kb = lv_keyboard_create(scr_pw);
  lv_obj_set_size(pw_kb, CW, 136);
  lv_obj_align(pw_kb, LV_ALIGN_TOP_LEFT, MX, 118);   // BUG LAMA: set_pos() pada keyboard yang rata-bawah menggeser 118 px KE BAWAH => keyboard di luar layar
                                                     // berakhir y=254, aman dari bezel bawah
  lv_keyboard_set_textarea(pw_kb, pw_ta);
  lv_obj_add_event_cb(pw_kb, ev_kb, LV_EVENT_ALL, NULL);
}

static void buildUi() {
  scr_main = lv_scr_act();
  lv_obj_set_style_bg_color(scr_main, C_BG, 0);
  lv_obj_set_style_bg_opa(scr_main, LV_OPA_COVER, 0);

  tv = lv_tileview_create(scr_main);
  lv_obj_set_size(tv, LCD_WIDTH, TILE_H); lv_obj_set_pos(tv, 0, SB_H);
  lv_obj_set_style_bg_opa(tv, LV_OPA_TRANSP, 0);
  lv_obj_set_scrollbar_mode(tv, LV_SCROLLBAR_MODE_OFF);
  t_home = lv_tileview_add_tile(tv, 0, 0, LV_DIR_NONE);
  t_wifi = lv_tileview_add_tile(tv, 1, 0, LV_DIR_NONE);
  t_act  = lv_tileview_add_tile(tv, 2, 0, LV_DIR_NONE);
  t_sys  = lv_tileview_add_tile(tv, 3, 0, LV_DIR_NONE);

  buildHome(); buildWifi(); buildActivity(); buildSystem();
  buildStatusBar();
  buildScan(); buildPassword(); buildPair(); buildTime(); buildOff(); buildType();
  lv_obj_set_tile(tv, t_home, LV_ANIM_OFF);
  g_tileIdx = 0;
}

// ===================== REFRESH =====================
static void refreshScanList() {
  WifiScanItem items[12]; uint32_t seq = 0;
  int n = wifi_scan_get(items, 12, &seq);
  if (seq == scanSeqShown) return;
  scanSeqShown = seq;
  lv_obj_clean(scan_list);
  for (int i = 0; i < n; i++) {
    strlcpy(scanSsid[i], items[i].ssid, sizeof scanSsid[i]);
    scanSecure[i] = items[i].secure;
    char t[64]; snprintf(t, sizeof t, "%s%s  (%d)", items[i].ssid, items[i].secure ? " *" : "", items[i].rssi);
    lv_obj_t* b = lv_list_add_btn(scan_list, LV_SYMBOL_WIFI, t);
    lv_obj_add_event_cb(b, ev_pick_ssid, LV_EVENT_CLICKED, (void*)(intptr_t)i);
  }
  lv_label_set_text(scan_title, n ? "Pilih Jaringan" : "Tidak ada jaringan");
}

static void refreshPair() {
  ProvInfo p = wifi_prov_info();
  char b[128];
  if (p.st != PROV_OFF) pairSeen = true;
  if (p.st == PROV_OFF) {
    if (pairSeen) { goMain(1); return; }                          // sesi berakhir / dibatalkan
    if (millis() - pairOpenMs > 10000) {                          // AP tidak kunjung aktif: beri tahu, jangan keluar diam-diam
      lv_label_set_text(pr_l1, "Mode pairing gagal dimulai");
      lv_label_set_text(pr_l2, "Tekan Batal lalu coba lagi");
    }
    return;
  }
  const char* want = nullptr;
  static char q1[112];
  if (p.st == PROV_WAIT_CLIENT) {
    snprintf(q1, sizeof q1, "WIFI:T:WPA;S:%s;P:%s;;", p.ap_ssid, p.pin);
    want = q1;
    lv_label_set_text(pr_l1, "1) Scan QR ini: sambungkan HP ke Wi-Fi jam");
    snprintf(b, sizeof b, "%s  sandi %s", p.ap_ssid, p.pin);
    lv_label_set_text(pr_l2, b);
  } else if (p.st == PROV_CLIENT_JOINED) {
    want = "http://192.168.4.1/";
    lv_label_set_text(pr_l1, "2) Scan QR ini untuk membuka halaman jam");
    lv_label_set_text(pr_l2, "atau buka 192.168.4.1 (hanya Wi-Fi 2.4 GHz)");
  } else if (p.st == PROV_REBOOTING) {
    snprintf(b, sizeof b, "Data diterima. Restart lalu terhubung ke %s", p.target);
    lv_label_set_text(pr_l1, b);
    lv_label_set_text(pr_l2, "Halaman pairing ditutup");
  } else if (p.st == PROV_FAILED) {
    snprintf(b, sizeof b, "Gagal: %s", p.msg);
    lv_label_set_text(pr_l1, b);
    lv_label_set_text(pr_l2, "Coba lagi dari halaman di HP");
  }
  if (want && strcmp(pairQr, want) != 0) {
    strlcpy(pairQr, want, sizeof pairQr);
    lv_qrcode_update(pr_qr, pairQr, strlen(pairQr));
    lv_obj_clear_flag(pr_qr, LV_OBJ_FLAG_HIDDEN);
  }
}

static void refresh(const AppState& s) {
  char b[64];

  // --- jam & tanggal ---
  if (s.time_valid) {
    snprintf(b, sizeof b, "%02u:%02u", s.hour, s.minute); setText(lbl_time, b);
    snprintf(b, sizeof b, "%s, %u %s %u", kHari[s.wday % 7], s.day, kBulan[(s.month + 11) % 12], s.year); setText(lbl_date, b);
  } else {
    setText(lbl_time, "--:--"); setText(lbl_date, "Waktu belum disetel");
  }

  // --- vital ---
  bool v = s.worn;
  if (v && s.hr > 0) { snprintf(b, sizeof b, "%d", s.hr); setText(lbl_hr, b); } else setText(lbl_hr, "--");
  if (v && s.spo2 > 0) { snprintf(b, sizeof b, "%d", s.spo2); setText(lbl_spo2, b); } else setText(lbl_spo2, "--");

  // --- status dikenakan ---
  lv_color_t dot; const char* txt;
  if (s.i2c_fault) { dot = C_BAD; txt = "I2C macet: cek kabel"; }
  else if (!s.ppg_ok) { dot = C_BAD; txt = "PPG tidak terdeteksi"; }
  else if (s.worn) { dot = C_OK; txt = "Dikenakan"; }
  else { dot = C_MUTED; txt = "Tidak Dikenakan"; }
  bcol(chip_dot, dot);
  setText(chip_txt, txt);

  // --- baterai ---
  const char* bi = s.batt_pct > 80 ? LV_SYMBOL_BATTERY_FULL : s.batt_pct > 60 ? LV_SYMBOL_BATTERY_3 :
                   s.batt_pct > 35 ? LV_SYMBOL_BATTERY_2 : s.batt_pct > 10 ? LV_SYMBOL_BATTERY_1 : LV_SYMBOL_BATTERY_EMPTY;
  snprintf(b, sizeof b, "%s%u%% %s", s.charging ? LV_SYMBOL_CHARGE " " : "", s.batt_pct, bi);
  setText(sb_batt, b);
  tcol(sb_batt, s.charging ? C_OK : (s.batt_pct <= 15 ? C_BAD : C_TEXT));

  // --- wifi ---
  lv_color_t wc = s.wifi == WIFI_ST_CONNECTED ? C_OK : (s.wifi == WIFI_ST_CONNECTING ? C_WARN : C_MUTED);
  tcol(sb_wifi, wc);
  bool conn = s.wifi == WIFI_ST_CONNECTED;
  setText(lbl_ip, conn ? s.ip : "Belum terhubung");
  static const char* kSt[] = {"Belum diatur", "Menghubungkan...", "Terhubung", "Gagal, mencoba lagi"};
  setText(wv_status, kSt[s.wifi]);
  tcol(wv_status, wc);
  setText(wv_ssid, s.ssid[0] ? s.ssid : "-");
  setText(wv_ip, conn ? s.ip : "-");
  if (conn) { snprintf(b, sizeof b, "%d dBm", s.rssi); setText(wv_rssi, b); } else setText(wv_rssi, "-");
  bool sw = lv_obj_has_state(sw_iplock, LV_STATE_CHECKED);
  if (sw != s.ip_lock) { inSyncSwitch = true; if (s.ip_lock) lv_obj_add_state(sw_iplock, LV_STATE_CHECKED); else lv_obj_clear_state(sw_iplock, LV_STATE_CHECKED); inSyncSwitch = false; }

  // --- aktivitas ---
  const char* an = s.activity == ACT_RUN ? "BERLARI" : s.activity == ACT_WALK ? "BERJALAN" : "DIAM";
  lv_color_t ac = s.activity == ACT_RUN ? C_WARN : s.activity == ACT_WALK ? C_OK : C_IDLE;
  setText(lbl_act, an);
  tcol(lbl_act, s.imu_ok ? ac : C_BAD);
  if (s.imu_ok) { snprintf(b, sizeof b, "std %.2f g   kadens %.1f/dtk", s.act_std, s.act_cadence); setText(lbl_act_sub, b); }
  else setText(lbl_act_sub, "IMU tidak terdeteksi");

  {
    static int8_t lastType = -2;                                   // tombol Tipe: tulisan + warna = tipe yang dipilih
    if (recType != lastType) {
      lastType = recType;
      if (recType < 0) { setBtnText(btn_type, "Pilih Tipe"); bcol(btn_type, lv_palette_darken(LV_PALETTE_GREY, 2)); }
      else { setBtnText(btn_type, kTypeName[recType]); bcol(btn_type, typeColor(recType)); }
    }
  }
  if (s.logging) {
    uint32_t sec = (millis() - s.log_start_ms) / 1000;
    snprintf(b, sizeof b, "Stop  %02lu:%02lu", (unsigned long)(sec / 60), (unsigned long)(sec % 60));
    setBtnText(btn_rec, b);
    bcol(btn_rec, lv_palette_main(LV_PALETTE_RED));
    lv_obj_clear_state(btn_rec, LV_STATE_DISABLED);
    lv_obj_add_state(btn_type, LV_STATE_DISABLED);               // tipe terkunci selama merekam
    lv_obj_add_flag(lbl_rec, LV_OBJ_FLAG_HIDDEN);
  } else {
    setBtnText(btn_rec, "Mulai Rekam");
    bcol(btn_rec, lv_palette_main(LV_PALETTE_GREEN));
    if (recType < 0) lv_obj_add_state(btn_rec, LV_STATE_DISABLED); else lv_obj_clear_state(btn_rec, LV_STATE_DISABLED);
    lv_obj_clear_state(btn_type, LV_STATE_DISABLED);
    if (recErr[0]) { setText(lbl_rec, recErr); lv_obj_clear_flag(lbl_rec, LV_OBJ_FLAG_HIDDEN); }
    else lv_obj_add_flag(lbl_rec, LV_OBJ_FLAG_HIDDEN);
  }

  // --- tombol Lupakan hanya bila ada jaringan tersimpan ---
  {
    static int8_t lastSaved = -1;
    int8_t saved = wifi_has_saved() ? 1 : 0;
    if (saved != lastSaved) {
      lastSaved = saved;
      if (saved) { lv_obj_set_width(btn_manual, 128); lv_obj_clear_flag(btn_forget, LV_OBJ_FLAG_HIDDEN); }
      else       { lv_obj_set_width(btn_manual, CW);  lv_obj_add_flag(btn_forget, LV_OBJ_FLAG_HIDDEN); }
    }
  }

  // --- halaman Sistem ---
  {
    uint32_t up = millis() / 1000;
    snprintf(b, sizeof b, "%lu j %02lu m %02lu d", (unsigned long)(up / 3600), (unsigned long)((up / 60) % 60), (unsigned long)(up % 60));
    setText(sv[SV_UPTIME], b);
    uint16_t rev = ESP.getChipRevision();
    char c[64]; snprintf(c, sizeof c, "%s v%u.%u, RISC-V %u MHz", ESP.getChipModel(), rev / 100, rev % 100, (unsigned)ESP.getCpuFreqMHz());
    setText(sv[SV_CHIP], c);
    snprintf(b, sizeof b, "512 KB SRAM, bebas %lu KB", (unsigned long)(ESP.getFreeHeap() / 1024)); setText(sv[SV_RAM], b);
    setText(sv[SV_TOUCH], g_touchOk ? "CST816T (I2C 0x15) - aktif" : "CST816T - tidak merespons");
    tcol(sv[SV_TOUCH], g_touchOk ? C_TEXT : C_BAD);
    setText(sv[SV_IMU], s.imu_ok ? "QMI8658 6-sumbu - aktif" : "QMI8658 - tidak terdeteksi");
    tcol(sv[SV_IMU], s.imu_ok ? C_TEXT : C_BAD);
    setText(sv[SV_PPG], s.ppg_ok ? "MAX30102 - aktif" : "MAX30102 - tidak terdeteksi");
    tcol(sv[SV_PPG], s.ppg_ok ? C_TEXT : C_BAD);
    snprintf(b, sizeof b, "PCF85063 - %s", !s.time_valid ? "belum disetel" : clock_auto() ? "sinkron otomatis" : "manual");
    setText(sv[SV_RTC], b);
    snprintf(b, sizeof b, "%.2f V (%u%%), terendah %.2f V", s.vbat, s.batt_pct, s.vbat_min > 9.0f ? s.vbat : s.vbat_min);
    setText(sv[SV_BATT], b); tcol(sv[SV_BATT], s.vbat_min < VBAT_SAG_V ? C_WARN : C_TEXT);
    setText(sv[SV_CHG], s.charging ? "ETA6098 - sedang mengisi" : "ETA6098 - tidak mengisi");
    setText(sv[SV_WIFI], kSt[s.wifi]);
    setText(sv[SV_IP], conn ? s.ip : "-");
    setText(sv[SV_CLOUD], !conn ? "-" : s.cloud_ok ? "Firebase - data terkirim" : "Firebase - belum terkirim");
    tcol(sv[SV_CLOUD], (conn && !s.cloud_ok) ? C_WARN : C_TEXT);
    setText(sv[SV_MAC], WiFi.macAddress().c_str());
    if (s.i2c_fault) snprintf(b, sizeof b, "%s tertahan LOW", (s.i2c_fault & 3) == 3 ? "SDA+SCL" : (s.i2c_fault & 1) ? "SDA" : "SCL");
    else snprintf(b, sizeof b, "OK, %d perangkat ditemukan", __builtin_popcount(s.i2c_devmask));
    setText(sv[SV_I2C], b); tcol(sv[SV_I2C], s.i2c_fault ? C_BAD : C_TEXT);
    setText(sv[SV_RESET], s.reset_reason);
    snprintf(b, sizeof b, "ke-%lu, layar diinit ulang %lux", (unsigned long)s.boot_count, (unsigned long)s.disp_reinit);
    setText(sv[SV_BOOT], b);
  }
}

// ===================== TASK UI =====================
static bool btnEdge(int pin, bool& last, uint32_t& t) {
  bool now = digitalRead(pin) == LOW;
  bool fired = false;
  if (now && !last && millis() - t > 80) { fired = true; t = millis(); }
  last = now;
  return fired;
}

// ===================== MODE ISI DAYA (USB) =====================
static lv_disp_t* lvglCoreInit() {
  lv_init();
  const uint32_t bufPx = LCD_WIDTH * 50;
  buf1 = (lv_color_t*)heap_caps_malloc(bufPx * sizeof(lv_color_t), MALLOC_CAP_DEFAULT | MALLOC_CAP_8BIT);
  buf2 = (lv_color_t*)heap_caps_malloc(bufPx * sizeof(lv_color_t), MALLOC_CAP_DEFAULT | MALLOC_CAP_8BIT);
  lv_disp_draw_buf_init(&draw_buf, buf1, buf2, bufPx);
  lv_disp_drv_init(&disp_drv);
  disp_drv.hor_res = LCD_WIDTH; disp_drv.ver_res = LCD_HEIGHT;
  disp_drv.flush_cb = flush_cb; disp_drv.draw_buf = &draw_buf;
  lv_disp_t* disp = lv_disp_drv_register(&disp_drv);
  lv_theme_t* th = lv_theme_default_init(disp, lv_palette_main(LV_PALETTE_BLUE), lv_palette_main(LV_PALETTE_RED), true, &lv_font_montserrat_14);
  lv_disp_set_theme(disp, th);
  return disp;
}

static lv_obj_t *chg_arc, *chg_bolt, *chg_sign;

static void buildCharge() {
  scr_chg = lv_obj_create(NULL);
  lv_obj_set_style_bg_color(scr_chg, lv_color_black(), 0);
  lv_obj_set_style_bg_opa(scr_chg, LV_OPA_COVER, 0);
  const int D = 168;
  chg_arc = lv_arc_create(scr_chg);                             // cincin persen (bukan simbol baterai)
  lv_obj_set_size(chg_arc, D, D);
  lv_obj_set_pos(chg_arc, (LCD_WIDTH - D) / 2, 12);
  lv_arc_set_rotation(chg_arc, 270);
  lv_arc_set_bg_angles(chg_arc, 0, 360);
  lv_arc_set_range(chg_arc, 0, 100);
  lv_arc_set_value(chg_arc, 0);
  lv_obj_remove_style(chg_arc, NULL, LV_PART_KNOB);
  lv_obj_clear_flag(chg_arc, LV_OBJ_FLAG_CLICKABLE);
  lv_obj_set_style_arc_width(chg_arc, 12, LV_PART_MAIN);
  lv_obj_set_style_arc_width(chg_arc, 12, LV_PART_INDICATOR);
  lv_obj_set_style_arc_color(chg_arc, lv_color_hex(0x2A3447), LV_PART_MAIN);
  lv_obj_set_style_arc_color(chg_arc, lv_color_hex(0x25A9F5), LV_PART_INDICATOR);
  lv_obj_set_style_arc_rounded(chg_arc, true, LV_PART_MAIN);
  lv_obj_set_style_arc_rounded(chg_arc, true, LV_PART_INDICATOR);

  chg_bolt = mkLabel(scr_chg, &lv_font_montserrat_20, lv_color_hex(0x25A9F5), LV_SYMBOL_CHARGE);
  lv_obj_align(chg_bolt, LV_ALIGN_TOP_MID, 0, 52);
  lv_obj_t* row = lv_obj_create(scr_chg);                       // angka besar + tanda % kecil
  lv_obj_remove_style_all(row);
  lv_obj_set_size(row, D, 60);
  lv_obj_set_pos(row, (LCD_WIDTH - D) / 2, 78);
  lv_obj_set_flex_flow(row, LV_FLEX_FLOW_ROW);
  lv_obj_set_flex_align(row, LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_END, LV_FLEX_ALIGN_CENTER);
  lv_obj_set_style_pad_column(row, 3, 0);
  lv_obj_clear_flag(row, LV_OBJ_FLAG_SCROLLABLE);
  chg_pct = mkLabel(row, &lv_font_montserrat_48, C_TEXT, "--");
  chg_sign = mkLabel(row, &lv_font_montserrat_20, C_TEXT, "%");
  lv_obj_set_style_pad_bottom(chg_sign, 6, 0);

  chg_txt = mkLabel(scr_chg, &lv_font_montserrat_16, C_MUTED, "");
  lv_obj_align(chg_txt, LV_ALIGN_TOP_MID, 0, 192);
  lv_obj_t* hint = mkLabel(scr_chg, &lv_font_montserrat_12, C_MUTED, "Tahan PWR untuk menyalakan");
  lv_obj_align(hint, LV_ALIGN_TOP_MID, 0, 222);
}

static void refreshCharge(int pct, bool full) {
  char b[8];
  if (pct < 0) pct = 0; if (pct > 100) pct = 100;
  lv_arc_set_value(chg_arc, pct);
  lv_color_t col = full ? C_OK : (pct <= 15 ? C_BAD : lv_color_hex(0x25A9F5));
  lv_obj_set_style_arc_color(chg_arc, col, LV_PART_INDICATOR);
  lv_obj_set_style_text_color(chg_bolt, col, 0);
  setText(chg_bolt, full ? LV_SYMBOL_OK : LV_SYMBOL_CHARGE);
  snprintf(b, sizeof b, "%d", pct);
  setText(chg_pct, b);
  setText(chg_txt, full ? "Terisi penuh" : "Mengisi daya");
  tcol(chg_txt, full ? C_OK : C_MUTED);
}

// Perangkat tampak "mati", hanya menampilkan status isi daya (cincin persen).
//   PWR tekan singkat = tampilkan status lagi | PWR tahan = nyalakan perangkat (restart ke boot normal dengan logo) | BOOT = tampilkan status
static void chargeLoop() {
  if (!scr_chg) buildCharge();
  lv_scr_load(scr_chg);
  battery_set_charging(true);                                    // USB pasti terpasang
  g_blOn = true; ledcWrite(PIN_LCD_BL, CHARGE_BL_LEVEL);
  uint32_t onAt = millis(), lastBat = 0, pwrDownAt = 0;
  bool pwrWas = digitalRead(PIN_BTN_PWR) == LOW, bootWas = digitalRead(PIN_BTN_BOOT) == LOW;
  bool armed = !pwrWas, counting = false;                        // PWR yang sedang ditahan saat masuk diabaikan sampai dilepas
  bool bl = true;
  for (;;) {
    uint32_t now = millis();
    if (lastBat == 0 || now - lastBat >= 2000) {
      lastBat = now;
      digitalWrite(PIN_BAT_EN, HIGH); delay(10);                  // baca ADC dengan jalur baterai aktif sebentar
      battery_update();
      digitalWrite(PIN_BAT_EN, LOW);                              // lalu kembali "mati": tanpa USB papan langsung padam
      AppState s = state_snapshot();
      refreshCharge(s.batt_pct, s.batt_pct >= 100);
    }
    bool pw = digitalRead(PIN_BTN_PWR) == LOW, bt = digitalRead(PIN_BTN_BOOT) == LOW;
    if (!pw) armed = true;
    if (armed && pw && !pwrWas) { pwrDownAt = now; counting = true; }
    if (counting && pw && now - pwrDownAt >= CHARGE_BOOT_HOLD_MS) {
      Serial.println("[PWR] PWR ditahan: boot normal"); Serial.flush(); esp_restart();
    }
    if (counting && !pw) {                                        // dilepas sebelum batas tahan = tekan singkat: tampilkan status
      counting = false;
      bl = true; ledcWrite(PIN_LCD_BL, CHARGE_BL_LEVEL); onAt = now;
    }
    pwrWas = pw;
    if (bt && !bootWas) { bl = true; ledcWrite(PIN_LCD_BL, CHARGE_BL_LEVEL); onAt = now; }
    bootWas = bt;
    if (bl && now - onAt > CHARGE_SCREEN_MS) { bl = false; ledcWrite(PIN_LCD_BL, 0); }
    g_dispReinitReq = false;
    lv_timer_handler();
    delay(20);
  }
}

void ui_charge_boot() {
  g_earlyDone = true;
  ledcAttach(PIN_LCD_BL, 5000, 8);
  ledcWrite(PIN_LCD_BL, 0);
  pinMode(PIN_BTN_BOOT, INPUT_PULLUP);
  pinMode(PIN_BTN_PWR, INPUT_PULLUP);
  gfx->begin();
  gfx->fillScreen(RGB565_BLACK);
  battery_init();
  lvglCoreInit();
  buildCharge();
  chargeLoop();                                                  // tidak kembali
}

// ===================== MATIKAN SISTEM =====================
static void startPowerOff(uint32_t now) {
  Serial.println("[PWR] tombol PWR ditahan: mematikan sistem");
  offActive = true; offT0 = now;
  wifi_prov_stop();
  blSet(true);
  lv_scr_load(scr_off);
}

static void finishPowerOff() {
  power_set_off(true);                                     // task sensor/Wi-Fi berhenti
  delay(200);
  blSet(false);
  uint32_t t = millis();
  while (digitalRead(PIN_BTN_PWR) == LOW && millis() - t < 3000) delay(10);   // tombol harus dilepas, kalau tidak jalur PWR menahan daya
  Serial.println("[PWR] BAT_EN = LOW (daya baterai diputus)");
  Serial.flush();
  digitalWrite(PIN_BAT_EN, LOW);                           // tanpa USB: papan mati total di sini
  delay(400);
  // masih ada daya = USB terpasang: tampilkan layar isi daya ala HP (PWR = nyalakan lagi)
  chargeLoop();
}

static void ui_task(void*) {
  // tombol yang SEDANG ditekan saat boot (mis. PWR ditahan untuk menyalakan) bukan "klik": inisialisasi dari kondisi nyata
  bool bootLast = digitalRead(PIN_BTN_BOOT) == LOW;
  bool pwrDown = digitalRead(PIN_BTN_PWR) == LOW, pwrLong = pwrDown;     // ditekan saat boot: abaikan sampai dilepas
  uint32_t pwrDownAt = millis();
  static uint32_t bootT = 0, pwrT = 0, lastRefresh = 0, lastTouchTry = 0, bootHold = 0, lastRecover = 0;
  for (;;) {
    uint32_t now = millis();

    if (btnEdge(PIN_BTN_BOOT, bootLast, bootT)) {
      if (!g_blOn) { blSet(true); lv_disp_trig_activity(NULL); } else log_marker();     // BOOT = tanda saat merekam
    }
    {   // PWR: tekan singkat = layar on/off, tahan lama = matikan sistem
      bool pl = digitalRead(PIN_BTN_PWR) == LOW;
      if (pl && !pwrDown && now - pwrT > 80) { pwrDown = true; pwrLong = false; pwrDownAt = now; pwrT = now; }
      if (pl && pwrDown && !pwrLong && !offActive && now - pwrDownAt >= PWR_LONGPRESS_MS) { pwrLong = true; startPowerOff(now); }
      if (!pl && pwrDown) {
        pwrDown = false;
        if (!pwrLong && !offActive) { if (g_blOn) blSet(false); else { blSet(true); lv_disp_trig_activity(NULL); } }
        pwrT = now;
      }
    }
    if (offActive) {
      lv_disp_trig_activity(NULL);
      if (now - offT0 >= POWEROFF_ANIM_MS) finishPowerOff();                           // tidak kembali
    }

    crumb(CR_UI, "loop");
    if (!g_touchOk && i2c_bus_ok() && now - lastTouchTry > 3000) {           // sentuh gagal saat boot => coba lagi
      lastTouchTry = now;
      g_touchOk = touchBegin();
      Serial.println(g_touchOk ? "[UI] touch CST816 OK (retry)" : "[UI] touch CST816 TIDAK merespons");
    }

    if (digitalRead(PIN_BTN_BOOT) == LOW) {                  // tahan BOOT 2 dtk = pulihkan layar+touch+I2C
      if (!bootHold) bootHold = now;
      else if (now - bootHold > 2000 && now - lastRecover > 5000) { lastRecover = now; hwRecover(true); }
    } else bootHold = 0;
    if (g_touchRecoverReq && now - lastRecover > 10000) { g_touchRecoverReq = false; lastRecover = now; hwRecover(false); }

    // init ulang panel: sekali setelah rel daya stabil, setelah sag daya / bus I2C dipulihkan, atau manual
    if (i2c_take_recover_event() && now - g_lastReinitMs > 10000) g_dispReinitReq = true;
    if (g_dispReinitReq) { g_dispReinitReq = false; crumb(CR_UI, "reinit"); doDisplayReinit("otomatis/manual"); }

    if (SCREEN_TIMEOUT_S > 0 && g_blOn && lv_disp_get_inactive_time(NULL) > SCREEN_TIMEOUT_S * 1000UL) blSet(false);

    if (now - lastRefresh >= 250) {
      lastRefresh = now;
      crumb(CR_UI, "refresh");
      AppState s = state_snapshot();
      refresh(s);
      if (lv_scr_act() == scr_scan) refreshScanList();
      if (lv_scr_act() == scr_pair && !offActive) refreshPair();
    }
    g_swipeAllowed = (lv_scr_act() == scr_main);
    crumb(CR_UI, "lvgl");
    lv_timer_handler();

    if (g_pendingDir) {                                      // geseran terdeteksi -> pindah halaman dengan animasi
      int d = g_pendingDir; g_pendingDir = 0;
      int ni = g_tileIdx + d;
      if (ni >= 0 && ni <= 3 && !offActive) {
        g_tileIdx = ni;
        lv_obj_set_tile(tv, ni == 0 ? t_home : ni == 1 ? t_wifi : ni == 2 ? t_act : t_sys, LV_ANIM_ON);
      }
    }
    vTaskDelay(pdMS_TO_TICKS(5));
  }
}

void ui_init() {
  ui_early();                                        // aman dipanggil ganda

  g_touchOk = touchBegin();
  Serial.println(g_touchOk ? "[UI] touch CST816 OK" : "[UI] touch CST816 GAGAL init (cek I2C / kabel sensor)");
  pinMode(PIN_TOUCH_IRQ, INPUT_PULLUP);
  attachInterrupt(PIN_TOUCH_IRQ, []() { g_touchIrq = true; }, FALLING);

  lv_disp_t* disp = lvglCoreInit();

  lv_indev_drv_init(&indev_drv);
  indev_drv.type = LV_INDEV_TYPE_POINTER; indev_drv.read_cb = touch_cb;
  indev_drv.scroll_limit = 5;        // untuk daftar jaringan (scroll vertikal)
  indev_drv.scroll_throw = 20;       // inersia setelah jari dilepas (bawaan 10): geseran terasa lebih "meluncur"
  indev_drv.gesture_limit = 30;
  lv_indev_t* indev = lv_indev_drv_register(&indev_drv);
  lv_timer_set_period(indev->driver->read_timer, 10);   // baca touch tiap 10 ms (bawaan 30 ms)

  buildUi();

  // Logo SAVERA tetap tampil sampai BOOT_SPLASH_MIN_MS. Di tengah-tengahnya panel di-init ulang sekali
  // (asuransi bila inisialisasi pertama terganggu lonjakan daya), lalu logo digambar lagi.
  if (DISPLAY_REINIT_BOOT_MS > 0) {
    while (millis() < DISPLAY_REINIT_BOOT_MS) delay(10);
    ledcWrite(PIN_LCD_BL, 0);
    gfx->begin();
    drawSplash();
    g_dispReinitCnt++;
    { StateLock l; g_state.disp_reinit = g_dispReinitCnt; }
    if (g_blOn) ledcWrite(PIN_LCD_BL, BACKLIGHT_LEVEL);
  }
  while (millis() < BOOT_SPLASH_MIN_MS) delay(10);
  xTaskCreate(ui_task, "ui", 8192, nullptr, 4, nullptr);   // UI di atas IMU(3)/PPG(2)/jaringan(2)
}
