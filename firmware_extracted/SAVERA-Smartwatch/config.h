// ============================================================================
//  config.h  -  SAVERA Smartwatch (ESP32-C6-Touch-LCD-1.69)
//  Semua pin, konstanta, ambang batas, dan konfigurasi cloud ada di sini.
// ============================================================================
#pragma once
#include <Arduino.h>

// ----------------------------------------------------------------------------
//  1. IDENTITAS PERANGKAT
// ----------------------------------------------------------------------------
#define FW_VERSION          "0.6.0"
#define DEVICE_NAME         "SAVERA-Smartwatch"   // hostname DHCP + mDNS (SAVERA-Smartwatch.local) + kunci path Firebase (tanpa spasi)
#define DEVICE_LABEL        "SAVERA Smartwatch"   // nama tampilan (layar, web, API)
#define MDNS_SERVICE_NAME   "medwatch"            // service mDNS: _medwatch._tcp (untuk discovery app Android / NSD)
#define HTTP_PORT           80
#define API_TOKEN           ""                    // isi untuk mewajibkan ?token=xxx / header X-Token pada API lokal

// Zona waktu (POSIX). WIB = UTC+7  ->  "WIB-7"  | WITA = "WITA-8" | WIT = "WIT-9"
#define TZ_POSIX            "WIB-7"
#define NTP_SERVER_1        "id.pool.ntp.org"
#define NTP_SERVER_2        "pool.ntp.org"

// ----------------------------------------------------------------------------
//  2. DEKLARASI PIN  (sumber: skematik & contoh resmi Waveshare ESP32-C6-Touch-LCD-1.69)
// ----------------------------------------------------------------------------
//  --- Pin ONBOARD (jangan dipakai untuk hal lain) ---
//  GPIO0   BAT_ADC     ADC tegangan baterai (pembagi 1/3)
//  GPIO1   LCD_SCLK    SPI clock layar ST7789V2
//  GPIO2   LCD_MOSI    SPI data layar
//  GPIO3   LCD_DC      Data/Command layar
//  GPIO4   LCD_RST     Reset layar (+ reset touch)
//  GPIO5   LCD_CS      Chip select layar
//  GPIO6   LCD_BL      Backlight layar (PWM)
//  GPIO7   I2C SCL     Bus I2C bersama: Touch CST816T, RTC PCF85063, IMU QMI8658, ES8311, + MAX30102
//  GPIO8   I2C SDA     (sama seperti di atas)
//  GPIO9   BOOT / IMU_INT    tombol BOOT (aktif LOW) - strapping pin, JANGAN ditarik LOW saat boot
//  GPIO10  RTC_INT     interrupt RTC (tidak dipakai)
//  GPIO11  TP_INT      interrupt touch (aktif LOW)
//  GPIO12/13 USB D-/D+ port Type-C
//  GPIO15  BAT_EN      enable pembagi tegangan baterai (HIGH = aktif)
//  GPIO16/17 UART TXD/RXD  pad terekspos (bebas, UART0 tidak dipakai karena Serial lewat USB-CDC)
//  GPIO18  PWR_KEY     tombol PWR (aktif LOW)
//  GPIO19-23 I2S audio (ES8311) - tidak dipakai di proyek ini
//
//  --- Pin EKSTERNAL: sensor MAX30102 (modul breakout) ---
//     MAX30102 VIN  -> pad 3V3 board   (lihat catatan modul 1.8V/3.3V di README)
//     MAX30102 GND  -> pad GND board
//     MAX30102 SDA  -> GPIO8  (pad SDA)   ← bus I2C bersama, alamat 0x57
//     MAX30102 SCL  -> GPIO7  (pad SCL)
//     MAX30102 INT  -> TIDAK DIPAKAI (polling FIFO). Dicadangkan: GPIO17 (pad RXD) bila nanti perlu.
// ----------------------------------------------------------------------------
#define PIN_LCD_SCK         1
#define PIN_LCD_MOSI        2
#define PIN_LCD_DC          3
#define PIN_LCD_RST         4
#define PIN_LCD_CS          5
#define PIN_LCD_BL          6
#define PIN_I2C_SCL         7
#define PIN_I2C_SDA         8
#define PIN_BTN_BOOT        9
#define PIN_TOUCH_IRQ       11
#define PIN_BAT_EN          15
#define PIN_BTN_PWR         18
#define PIN_BAT_ADC         0

#define PIN_MAX30102_SDA    PIN_I2C_SDA        // 8
#define PIN_MAX30102_SCL    PIN_I2C_SCL        // 7
#define PIN_MAX30102_INT    (-1)               // tidak dipakai (cadangan: 17)

#define LCD_WIDTH           240
#define LCD_HEIGHT          280

// Alamat I2C (informasi)
//   0x15 CST816T | 0x51 PCF85063 | 0x6B QMI8658 | 0x18 ES8311 | 0x57 MAX30102
#define I2C_FREQ_HZ         100000   // 100 kHz: lebih toleran terhadap kabel sensor yang panjang & pull-up ganda
#define ADDR_MAX30102       0x57
// Alamat yang dipindai saat boot (HANYA ini; memindai 1..126 membuang waktu bila bus macet)
#define I2C_PROBE_ADDRS     { 0x15, 0x51, 0x6B, 0x18, 0x57 }   // touch, RTC, IMU, codec, MAX30102

// ----------------------------------------------------------------------------
//  2b. DAYA & PEMULIHAN  (hasil telaah contoh resmi Waveshare + skematik)
// ----------------------------------------------------------------------------
//  GPIO15 BAT_EN = KUNCI DAYA baterai (transistor S8050 -> MOSFET AO3401). Contoh resmi Waveshare
//  menaikkannya HIGH paling awal. Bila LOW, jalur baterai terputus dan papan mati total.
//  Firmware ini menaikkannya di initVariant() (sebelum setup()) dan menunggu tombol PWR dilepas.
#define DISPLAY_REINIT_BOOT_MS    1100   // inisialisasi ULANG panel sekali setelah rel daya stabil (0 = nonaktif)
#define VBAT_SAG_V                3.30f  // tegangan baterai di bawah ini = sag daya -> panel di-init ulang
#define I2C_FAULT_BACKOFF_MS      2000   // task I2C menunggu selama ini bila bus macet (tidak menghantam bus)

// Daya MAX30102 dari GPIO (OPSIONAL, butuh kabel VIN modul dipindah dari pad 3V3 ke pad GPIO ini).
//   -1 = nonaktif (VIN tetap ke 3V3).  Contoh: 17 (pad RXD).  Sensor baru dinyalakan SETELAH layar/touch/IMU
//   hidup; bila modul menahan SDA/SCL LOW, dayanya dipotong lagi sehingga bus utama tetap sehat.
#define PPG_PWR_PIN               (-1)
#define PPG_START_DELAY_MS        3000   // PPG baru disentuh setelah boot stabil

// ----------------------------------------------------------------------------
//  3. BATERAI  (Li-Po 3.7V, charger ETA6098 onboard)
// ----------------------------------------------------------------------------
#define BAT_DIVIDER         3.0f     // VBAT = V_ADC x 3
#define BAT_FULL_V          4.17f    // >= ini saat charging => dianggap penuh

// ----------------------------------------------------------------------------
//  4. SENSOR PPG MAX30102
// ----------------------------------------------------------------------------
// --- Opsi: MAX30102 di bus I2C TERPISAH (bit-bang) agar tidak berbagi jalur dengan touch/RTC/IMU ---
//     1 = pakai pin di bawah (sambungkan SDA modul ke pad RXD=GPIO17, SCL modul ke pad TXD=GPIO16; VIN & GND tetap sama)
#define PPG_USE_SOFT_I2C    0
#define PIN_PPG_SDA_ALT     17
#define PIN_PPG_SCL_ALT     16
#define PPG_SOFTI2C_HALF_US 5        // setengah periode clock bit-bang (µs) ≈ 50-100 kHz
#define PPG_LED_CURRENT     0x3C     // 0x00..0xFF, tiap step 0.2 mA (0x3C ≈ 12 mA). Naikkan bila sinyal lemah
#define PPG_WEAR_ON_IR      20000    // rata-rata IR di atas ini (>=1 dtk)  => "Dikenakan"
#define PPG_WEAR_OFF_IR     8000     // rata-rata IR di bawah ini (>=0.5 dtk) => "Tidak Dikenakan"
#define PPG_HOLD_MS         12000    // lama menahan nilai terakhir bila pembacaan tak valid sesaat

// ----------------------------------------------------------------------------
//  5. IMU / KLASIFIKASI AKTIVITAS / PENCATATAN DATA
//     Tahap ini HANYA membedakan: DIAM, BERJALAN, BERLARI (belum deteksi jatuh).
// ----------------------------------------------------------------------------
#define IMU_FS_HZ           100      // laju sampling yang dicatat (sama dgn pipeline TemanJalan 100 Hz)
#define IMU_ACC_RANGE       SensorQMI8658::ACC_RANGE_16G
#define IMU_GYR_RANGE       SensorQMI8658::GYR_RANGE_1024DPS

// Klasifikasi aturan per jendela 2 dtk (hop 0.5 dtk) memakai SVM = sqrt(ax^2+ay^2+az^2) dalam g.
// Ini TITIK AWAL; tuning dengan data rekaman Anda (lihat README).
#define ACT_WINDOW          200      // 2 detik @100 Hz
#define ACT_HOP             50       // evaluasi tiap 0.5 detik
#define ACT_STD_IDLE        0.08f    // std SVM < ini            => DIAM
#define ACT_STD_RUN         0.60f    // std SVM >= ini           => BERLARI
#define ACT_CADENCE_RUN     2.6f     // puncak/detik >= ini (dan std >= ACT_STD_RUN_MIN) => BERLARI
#define ACT_STD_RUN_MIN     0.35f
#define ACT_PEAK_MIN_GAP    22       // jarak minimal antar puncak (sampel) = 220 ms
#define ACT_CONFIRM         2        // butuh N jendela berturut-turut sama sebelum status berganti

// Pencatatan data
#define LOG_DIR             "/rec"
#define LOG_STREAM_BYTES    12288
#define LOG_MIN_FREE_BYTES  (256 * 1024)

// Model ML (opsional, belum ada). Lihat README bagian "Menyambungkan model ML".
// Kelas model: 0 = diam, 1 = berjalan, 2 = berlari
#define ENABLE_ML_MODEL     0
#define ML_WINDOW           80       // 800 ms @ 100 Hz
#define ML_HOP              40

// ----------------------------------------------------------------------------
//  6. LAYAR
// ----------------------------------------------------------------------------
#define SCREEN_TIMEOUT_S    60       // 0 = selalu menyala
#define BACKLIGHT_LEVEL     160      // 0..255 (lebih rendah = lebih dingin & hemat daya)

// ----------------------------------------------------------------------------
//  7. WIFI
// ----------------------------------------------------------------------------
#define WIFI_CONNECT_TIMEOUT_MS   15000
#define WIFI_STATIC_TIMEOUT_MS    8000
#define WIFI_RETRY_INTERVAL_MS    15000
#define WIFI_POWER_SAVE           1   // 1 = modem sleep (arus rata-rata jauh lebih kecil; mDNS/HTTP tetap bisa dijangkau)
#define WIFI_TX_POWER             WIFI_POWER_11dBm  // puncak arus TX lebih rendah => baterai kecil tidak ambrol. Naikkan bila sinyal lemah
#define WIFI_START_DELAY_MS       2500   // Wi-Fi dinyalakan setelah layar/sensor stabil (hindari lonjakan arus bersamaan)

// --- Pairing lewat HP (QR -> halaman web di jam) ---
//  ESP32-C6 hanya mendukung 2.4 GHz (tidak ada 5 GHz), jadi hanya jaringan 2.4 GHz yang bisa dipakai.
#define PROV_AP_PREFIX            "SAVERA-"   // + 4 hex terakhir MAC
#define PROV_PIN_DIGITS           8      // sandi AP sementara (acak tiap sesi) -> WPA2
#define PROV_TIMEOUT_S            300    // mode pairing berhenti otomatis setelah ini
#define PROV_CONNECT_TIMEOUT_MS   20000

// ----------------------------------------------------------------------------
//  8. FIREBASE (Realtime Database via REST)  -  kontrak data dengan aplikasi SAVERA (Flutter)
//     Aplikasi mendengarkan node  Devices/Device_01  (lihat lib/pages/home_page.dart):
//       VitalSigns/{HeartRate, SpO2}   DeviceStatus/{IsWorn, Battery, LastUpdated}   FallDetection/{IsFallen, BA, BG}
//     Firmware menulis (PATCH) ke node yang sama tiap FIREBASE_PUSH_INTERVAL_MS.
//     Aplikasi menganggap alat "Mati/Terputus" bila tidak ada pembaruan 15 detik => interval harus jauh di bawahnya.
// ----------------------------------------------------------------------------
#define FIREBASE_ENABLED          1
#define FIREBASE_DB_URL           "https://teman-jalan-13983-default-rtdb.asia-southeast1.firebasedatabase.app"   // dari firebase_options.dart
#define FIREBASE_DEVICE_PATH      "Devices/Device_01"   // HARUS sama dengan FirebaseDatabase.instance.ref("...") di aplikasi (huruf besar/kecil berpengaruh)
#define FIREBASE_API_KEY          ""   // Aplikasi saat ini TIDAK memakai Firebase Auth => biarkan kosong dan atur Rules (lihat README).
                                       // Bila diisi => firmware login Anonymous (butuh aplikasi ikut login, kalau tidak aplikasi gagal membaca).
#define FIREBASE_PUSH_INTERVAL_MS 3000

// --- Tombol PWR ---
#define PWR_LONGPRESS_MS          2000   // tahan PWR selama ini = matikan sistem ("Sedang mematikan...")
#define POWEROFF_ANIM_MS          2600   // lama layar "Sedang mematikan" sebelum daya diputus
#define BOOT_SPLASH_MIN_MS        2300   // logo SAVERA minimal tampil selama ini saat boot

// --- Mode isi daya (USB-C) ---
//  Bila papan hidup karena USB (bukan karena tombol PWR ditekan), perangkat tampil "mati" dengan layar isi daya
//  ala HP (ikon baterai + persen). Tekan PWR = nyalakan perangkat (logo SAVERA). BOOT = tampilkan layar lagi.
//  Set 0 saat mengembangkan (supaya colok USB ke PC langsung boot normal).
#define CHARGE_MODE_ON_USB        1
#define CHARGE_SCREEN_MS          12000  // layar isi daya menyala selama ini, lalu padam (daya tetap mengisi)
#define CHARGE_BL_LEVEL           120
#define CHARGE_BOOT_HOLD_MS       1200   // tahan PWR selama ini saat mode isi daya = nyalakan perangkat (tekan singkat = lihat status)
