# SAVERA-Smartwatch — ESP32-C6-Touch-LCD-1.69 + MAX30102  (v0.6.0)

Firmware Arduino untuk alat riset smartwatch: SpO2 + denyut nadi, status **Dikenakan / Tidak Dikenakan**, jam & tanggal, baterai + charging, Wi-Fi lewat layar sentuh, API lokal + Firebase, dan IMU yang saat ini **hanya membedakan Diam / Berjalan / Berlari** sambil mencatat data CSV untuk melatih model nanti. Deteksi jatuh belum dibuat.

> **Status v0.2.0:** **sudah berhasil dikompilasi** (arduino-cli, esp32 core 3.3.5, lvgl 8.4.0, GFX 1.6.0, SensorLib 0.3.1; 1,75 MB flash, RAM statis 19%). **Belum diuji di perangkat keras Anda** — lihat bagian 11 untuk apa yang harus dicek dan dikirim balik.

## 1. Setup Arduino IDE
| Item | Nilai |
|---|---|
| Board | ESP32C6 Dev Module (core esp32 3.x) |
| USB CDC On Boot | **Enabled** (agar `Serial` lewat Type-C) |
| Flash Size | **16MB** |
| Partition | otomatis memakai `partitions.csv` di folder sketch (LittleFS ±9.9 MB untuk rekaman) |
| Library | **lvgl 8.4.0** (bukan 9.x), **GFX Library for Arduino 1.6.0**, **SensorLib 0.3.1**, **SparkFun MAX3010x Pulse and Proximity Sensor Library** |

Catatan: paket contoh Waveshare memuat `lvgl` 9.3.0 di folder libraries. Bila itu terpasang, hapus/ganti dengan 8.4.0, karena UI ditulis dengan API LVGL v8. `lv_conf.h` di folder sketch ini sudah mengaktifkan font 20/32/48 dan otomatis dipakai.
Cocokkan juga opsi Tools dengan gambar "Arduino Project Parameter Settings" di dokumentasi Waveshare.

## 2. Deklarasi pin
**Onboard (jangan dipakai ulang):** BAT_ADC=GPIO0, BAT_EN=GPIO15, LCD SCLK/MOSI/DC/RST/CS/BL = GPIO1/2/3/4/5/6, I2C SCL=GPIO7, SDA=GPIO8, TP_INT=GPIO11, BOOT=GPIO9 (strapping, jangan ditarik LOW saat boot), PWR_KEY=GPIO18, USB=GPIO12/13.

**MAX30102 (eksternal), bus I2C bersama alamat 0x57:**
| MAX30102 | Board | Keterangan |
|---|---|---|
| VIN | 3V3 | cek modul Anda: umumnya 3.3–5 V |
| GND | GND | |
| SDA | GPIO8 | bersama touch/RTC/IMU |
| SCL | GPIO7 | |
| INT | tidak dipakai | polling FIFO. Cadangan bila perlu: GPIO17 (pad RXD). Jangan GPIO9/GPIO18 |

Alamat di bus: 0x15 touch, 0x51 RTC, 0x6B IMU, 0x18 codec, 0x57 MAX30102 (tidak bentrok). Definisi lengkap ada di `config.h`. Posisi fisik pad ada pada gambar *Pinout Definition* di halaman Waveshare (gambar itu tidak terbaca oleh saya, jadi cek di sana).
Hati-hati: sebagian modul MAX30102 murah memakai pull-up I2C ke 1.8 V. Bila I2C tidak stabil, ukur tegangan pull-up SDA/SCL.

## 3. Alur fitur
- **Beranda**: jam, tanggal (hari, tanggal, bulan, tahun), denyut, SpO2, status Dikenakan, baterai %, ikon Wi-Fi, nama alat + IP. Geser kiri/kanan untuk halaman lain.
- **Dikenakan**: rata-rata IR di atas `PPG_WEAR_ON_IR` selama 1 dtk → "Dikenakan". Di bawah `PPG_WEAR_OFF_IR` selama 0,5 dtk → "Tidak Dikenakan", nilai menjadi `--` (JSON: `null`). Tuning dengan nilai `ir` di `/api/data`.
- **Wi-Fi**: halaman Wi-Fi → *Ganti Jaringan* → pilih SSID → ketik sandi → Hubungkan. Tersimpan di NVS dan tersambung otomatis saat boot. Menampilkan status, SSID, IP, nama alat, RSSI.
- **Kunci IP**: setelah sukses DHCP, IP/gateway/mask/DNS disimpan per SSID dan dipakai lagi sebagai IP tetap di jaringan itu. Bila gagal, otomatis kembali DHCP. Jaringan baru mendapat IP baru otomatis. Cara paling kuat tetap *DHCP reservation* di router berdasarkan MAC.
- **Nama alat**: `SAVERA-Smartwatch` dipakai sebagai hostname DHCP (muncul di daftar klien router), mDNS `SAVERA-Smartwatch.local`, dan service `_medwatch._tcp` (TXT: name, id, fw, api). Di Android, gunakan **NsdManager** untuk menemukan service lalu ambil IP-nya; resolusi `.local` lewat DNS biasa tidak selalu bekerja di Android.
- **Baterai**: tegangan dari ADC (GPIO0 ×3) → persen lewat kurva Li-Po. Charger ETA6098 **tidak punya pin status ke GPIO**, jadi status *charging* diestimasi dari lonjakan/tren tegangan (kurang presisi).
- **Waktu**: RTC PCF85063 + sinkron NTP (WIB, `TZ_POSIX`) setiap terhubung dan tiap 30 menit.

## 4. Data ke aplikasi
**Firebase RTDB (REST)**, isi `FIREBASE_DB_URL` dan `FIREBASE_API_KEY` di `config.h`:
- `devices/SAVERA-Smartwatch/live` diperbarui tiap 2 dtk (JSON yang sama dengan `/api/data` + `server_ts`)
- `devices/SAVERA-Smartwatch/info` berisi IP, MAC, firmware, mDNS

Contoh rules (wajib login anonymous aktif di Firebase Auth; jangan biarkan `".write": true` publik):
```json
{ "rules": { "devices": { ".read": "auth != null", ".write": "auth != null" } } }
```
Koneksi TLS memakai `setInsecure()` (tanpa validasi sertifikat) agar mudah dicoba; untuk produksi ganti dengan `setCACertBundle()`.

**HTTP lokal (port 80):** `/api/info`, `/api/data` (`?imu=1` menambah nilai mentah), `/api/activity`, `/api/time?epoch=…`, `/api/log/{status,start,stop,marker,list,download,delete}`. Isi `API_TOKEN` untuk mewajibkan `?token=` atau header `X-Token`.

## 5. IMU: Diam / Berjalan / Berlari
QMI8658 dibaca 100 Hz (±16 g, ±1024 dps, satuan g dan deg/s seperti dataset TemanJalan). Per jendela 2 dtk (evaluasi tiap 0,5 dtk) dihitung std SVM dan kadens (puncak/dtk):
- std < 0,08 g → **Diam**
- std ≥ 0,60 g, atau std ≥ 0,35 g dengan kadens ≥ 2,6/dtk → **Berlari**
- selain itu → **Berjalan**
- status berganti setelah 2 jendela berturut-turut sama.

Semua ambang di `config.h` (`ACT_*`) adalah **tebakan awal untuk pergelangan/punggung tangan** dan harus disetel dengan data Anda.

## 6. Merekam data untuk ML
Halaman **Aktivitas** (atau API): pilih label (Diam/Berjalan/Berlari) dan tujuan (*Flash* = file di LittleFS, *Serial* = stream CSV ke PC), tekan **Mulai Rekam**. **Tanda** (atau tombol BOOT) menandai momen perubahan aktivitas (kolom `Marker`).
Format CSV (komentar `#` berisi metadata, baca dengan `pandas.read_csv(..., comment='#')`):
```
Timestamp(ms),AccX,AccY,AccZ,GyroX,GyroY,GyroZ,Marker,Activity
```
`Activity` adalah keluaran pengklasifikasi aturan (bukan label asli). Label asli ada di nama file dan header `# label=`.
Unduh: `http://SAVERA-Smartwatch.local/api/log/download?name=<file>`; daftar di `/api/log/list`.
Catatan kualitas: penulisan flash dapat menimbulkan jitter sesaat, sehingga timestamp dicatat dari timer sebenarnya (resampling ke 100 Hz tepat dilakukan saat preprocessing). Untuk data paling bersih gunakan mode Serial. Laju ±5 KB/dtk (±300 KB/menit).

## 7. Menyambungkan model ML (nanti)
Latih ulang dengan data dari alat ini (model TemanJalan dilatih pada sensor MPU6500 dan penempatan berbeda, jadi jangan dipakai langsung). Pipeline-nya sudah disiapkan sama: 100 Hz, jendela 80 sampel (800 ms), 6 fitur `[Acc_Mean, Gyro_Min, Acc_Max, Gyro_Mean, Acc_Min, Gyro_Std]`. Kelas: 0=diam, 1=berjalan, 2=berlari. Ganti `model_100hz_800ms.h` lalu set `ENABLE_ML_MODEL 1` di `config.h`.

## 8. Catatan penting
- **Baterai 602030:** sel ukuran 602030 (6×20×30 mm) umumnya hanya ±250–400 mAh; 1200 mAh pada ukuran itu tidak lazim. Periksa label sel. Pastikan juga arus charge ETA6098 di skematik tidak melebihi batas charge sel (biasanya 0,5C–1C) sebelum dicas lama tanpa pengawasan.
- **SpO2** dari punggung tangan dengan algoritma Maxim tanpa kalibrasi bersifat estimasi riset, bukan alat medis.
- Estimasi umur baterai dengan layar menyala dan Wi-Fi aktif cukup pendek; `SCREEN_TIMEOUT_S` mematikan layar otomatis (sentuh / tombol PWR untuk menyalakan).

## 9. Pemecahan masalah (hasil uji lapangan)
- **Layar blank / touch mati setelah dipakai lama:** tahan tombol **BOOT 2 detik** untuk memulihkan bus I2C, layar, dan touch. Touch yang macet juga dipulihkan otomatis.
- **Touch mati hanya saat MAX30102 tersambung:** kemungkinan besar masalah listrik di bus I2C bersama, bukan logika kode. Cek (1) tegangan SDA/SCL saat idle dengan modul tersambung, harus mendekati 3,3 V (bila 1,8–2,5 V, pull-up modul ke rel 1,8 V; lepas resistor pull-up SDA/SCL di modul), (2) kabel USB/konektor magnetik yang memberi drop tegangan, (3) panjang kabel sensor.
- **Isolasi total (definitif):** sambungkan SDA modul ke pad RXD (GPIO17) dan SCL modul ke pad TXD (GPIO16), lalu set `PPG_USE_SOFT_I2C 1` di `config.h`. MAX30102 memakai bus sendiri sehingga tidak bisa mengganggu touch/RTC/IMU.
- **Perangkat terasa panas:** cek bagian mana yang panas (modul ESP32, IC charger, atau baterai). Bila baterai ikut panas, cabut dan hentikan pengisian.

## 10. Perbaikan v0.1.1 (touch mati / freeze terkait PPG)
- `ppg.cpp`: pembacaan register kini memakai **STOP** (bukan repeated-start). Repeated-start ke alamat yang tidak menjawab (PPG dicabut / sedang reset) bisa membuat bus I2C bersama macet sehingga touch ikut mati.
- Sensor tidak ada: hanya probe alamat (+STOP) tiap 5 dtk, tidak ada pembacaan register.
- 3 pembacaan pointer FIFO digabung jadi 1 transaksi; `delay(50)` reset tidak lagi menahan mutex I2C.
- `i2c_watchdog()` (dipanggil `sys_task` tiap 0,5 dtk): SDA/SCL tertahan LOW saat idle => bus dipulihkan otomatis.
- Belum dikompilasi/diuji di perangkat. Bila freeze tetap terjadi, ukur tegangan SDA/SCL (lihat bagian 9) dan coba `PPG_USE_SOFT_I2C 1`.

## 11. Perubahan v0.2.0 (pairing HP + perbaikan layar blank)

### Pairing Wi-Fi lewat HP (QR)
Halaman **Wi-Fi** → tombol **Pasangkan lewat HP**:
1. Jam membuat AP sementara `SAVERA-Smartwatch-XXXX` (WPA2, sandi acak 8 digit per sesi) dan menampilkan **QR 1** (format `WIFI:`). Scan dengan kamera HP → HP langsung tersambung ke AP jam.
2. Layar otomatis ganti ke **QR 2** (`http://192.168.4.1/`) atau HP membuka popup *captive portal* sendiri. Halaman web di jam menampilkan daftar jaringan hasil pindai jam, ketik/isi sandi, tekan *Hubungkan*.
3. Jam mencoba terhubung (kredensial baru disimpan hanya bila sukses), layar menampilkan IP, AP mati sendiri. Gagal → pesan penyebab (sandi salah / SSID tidak ditemukan / waktu habis), bisa coba lagi. Sesi berhenti otomatis setelah 5 menit.
- **Hanya 2.4 GHz.** ESP32-C6 tidak punya radio 5 GHz, jadi tidak bisa memakai 5 GHz (jaringan 5-GHz-saja tidak muncul di daftar). Catatan ini juga tampil di layar dan di halaman web.
- Tombol *Pilih manual* / *Ketik di jam* tetap ada (keyboard layar sudah diperbaiki, lihat bawah).
- Untuk aplikasi Flutter (SAVERA): `GET /api/wifi/scan` dan `GET/POST /api/wifi/connect?ssid=..&pass=..` (pakai `API_TOKEN` bila diisi).
- Bluetooth tidak ditambahkan: QR sudah cukup, dan BLE + Wi-Fi + LVGL sekaligus menambah beban RAM/daya pada papan tanpa PSRAM dengan baterai kecil.

### Perbaikan UI
- **Keyboard layar sandi berada di luar layar** (hanya baris pertama terlihat di foto Anda). Penyebab: `lv_obj_set_pos()` pada keyboard yang secara bawaan rata-bawah menggeser 118 px *ke bawah*. Diganti `lv_obj_align(TOP_LEFT)`. Tombol "Hubungkan" yang terpotong juga dilebarkan (diberi label "Sambung").
- Halaman ke-4 **Sistem**: alasan reset, jumlah boot, tegangan baterai + minimum, status SDA/SCL, perangkat I2C yang ditemukan (T=touch R=RTC I=IMU C=codec P=PPG), memori, tombol *Reset layar* dan *Restart*. Ini membantu karena Serial Monitor terputus tiap reset (USB-CDC).

### Perbaikan blank screen / freeze (hasil telaah contoh resmi Waveshare + skematik + log Anda)
Pin yang dipakai firmware ini **sudah identik** dengan tabel pin Waveshare dan dengan jawaban di thread komunitas (SCLK1 MOSI2 DC3 RST4 CS5 BL6, SDA8 SCL7). Thread itu menyelesaikan masalah penanya yang memakai pin papan lain; itu bukan penyebab layar blank Anda. Yang ditemukan:
1. **Layar baru dinyalakan setelah I2C.** Urutan lama: pindai I2C → baterai → RTC → baru layar. Bila bus macet, layar tidak pernah tampil. Kini `ui_early()` menghidupkan layar lebih dulu (splash), sebelum I2C/sensor disentuh.
2. **BAT_EN (GPIO15) adalah kunci daya baterai** (contoh resmi Waveshare menaikkannya paling awal; skematik: S8050 → AO3401). Kini dinaikkan di `initVariant()` (sebelum `setup()`).
3. **Tombol PWR yang ditahan saat boot dianggap klik** → layar dimatikan sesaat setelah menyala (terlihat seperti blank). Kini status awal tombol dibaca dulu.
4. **Panel ST7789 yang kehilangan konfigurasinya tidak terdeteksi** (tidak ada jalur baca balik). Foto Anda (layar putih/biru rata, dan UI gelap yang tampak "terbalik" pucat) cocok dengan panel yang ter-reset/ter-init sebagian saat rel daya turun. Kini panel di-init ulang: sekali ±1,5 dtk setelah boot, setelah sag baterai (< 3,30 V), setelah bus I2C dipulihkan, atau manual (tombol *Reset layar*, tahan BOOT 2 dtk).
5. **Log serial Anda menunjukkan seluruh bus I2C mati** (touch 0x15, RTC, IMU tidak ada, bukan hanya PPG), dan `i2c_watchdog` terus melihat SDA/SCL LOW. Itu bukan bug logika: SDA/SCL tertahan LOW secara listrik atau rel daya periferal turun. Firmware kini (a) mengecek level garis sebelum menyentuh bus, (b) memindai hanya 5 alamat, (c) menandai `i2c_fault` sehingga touch/IMU/PPG **berhenti menghantam bus**, (d) menampilkan SDA/SCL LOW di halaman Sistem.
6. **Prioritas task diturunkan**: UI 4 > IMU 3 > PPG/jaringan 2 (sebelumnya IMU 5, PPG 4 di atas UI). Wi-Fi dinyalakan 2,5 dtk setelah boot, TX power 11 dBm dan modem sleep aktif untuk menurunkan puncak arus (baterai kecil mudah ambrol). PPG baru disentuh 3 dtk setelah boot.
7. **TASK_WDT**: penyebab pastinya belum bisa ditentukan dari kode saja. Ditambahkan alat bidik: partisi `coredump` (`partitions.csv`), ringkasan crash saat boot berikutnya (`[CRASH] task=...`), dan jejak tahap terakhir tiap task (`[BOOT] tahap terakhir sebelum reset: ...`). Kirim dua baris itu bila TASK_WDT terjadi lagi. Pesan `No core dump partition found` di log lama tidak berbahaya dan hilang dengan partisi baru.

### Langkah uji hardware (urut; berhenti di langkah yang mengubah gejala)
1. **Tanpa PPG, baterai terisi penuh atau dicabut, colok USB dari port/charger yang kuat.** Buka halaman *Sistem*: I2C harus `OK TRIC-` dan VBAT stabil. Bila tetap mati → masalah di papan/baterai/kabel USB, bukan PPG.
2. Pasang PPG, ukur dengan multimeter **tegangan SDA dan SCL saat idle** (harus ≈ 3,3 V). Bila 1,8–2,5 V → pull-up modul ke rel 1,8 V (lepas resistor pull-up SDA/SCL di modul). Bila modul memakai konektor dupont/JST, goyangkan: gejala "hidup sebentar lalu mati" sangat khas kontak GND/VIN yang putus-nyambung.
3. Lihat *Sistem → Baterai (min)*. Bila minimum < 3,3 V saat Wi-Fi/PPG menyala → baterai terlalu kecil/lemah/kosong; gunakan sel yang lebih besar dan sehat. Charger ETA6098 menyuplai beban lewat baterai, jadi baterai drop = seluruh sistem drop.
4. Isolasi total: pindahkan VIN modul PPG ke pad GPIO (mis. RXD = GPIO17), set `PPG_PWR_PIN 17` di `config.h`. PPG hanya dinyalakan setelah sistem stabil dan dayanya dipotong otomatis bila menjepit SDA/SCL, sehingga layar/touch tidak ikut mati. (Alternatif: `PPG_USE_SOFT_I2C 1`, lihat bagian 9.)

## 12. Perubahan v0.3.0 (permintaan UI + merek SAVERA)
- **Merek**: seluruh teks tampilan menjadi "SAVERA Smartwatch"; layar boot dan layar mati memakai logo SAVERA (`splash_img.h`, dibuat dari logo yang Anda kirim). Folder/sketch kini `SAVERA-Smartwatch`. Hostname/mDNS menjadi `SAVERA-Smartwatch.local` dan path Firebase `devices/SAVERA-Smartwatch/...` (nama untuk jaringan tidak boleh berspasi) — **sesuaikan aplikasi Flutter bila memakai nama lama**. AP pairing: `SAVERA-Smartwatch-XXXX`.
- **Tombol PWR**: tekan singkat = layar on/off; **tahan 2 dtk = "Sedang mematikan..." (spinner)** lalu daya baterai diputus lewat BAT_EN. Bila USB masih terpasang, papan tetap menyala tetapi layar/sensor/Wi-Fi mati ("mati lunak"); tekan PWR = boot ulang dengan logo SAVERA. Batas waktu di `config.h` (`PWR_LONGPRESS_MS`, `POWEROFF_ANIM_MS`, `BOOT_SPLASH_MIN_MS`).
- **Waktu**: ketuk jam/tanggal di Beranda → layar *Atur Waktu*: saklar **Sinkron otomatis (Wi-Fi/NTP)** atau atur jam, tanggal, bulan, tahun manual. Mode manual mematikan sinkron NTP. "Waktu belum disetel" hanya muncul bila waktu belum pernah diatur; setelah itu diganti hari dan tanggal.
- **Beranda**: judul DENYUT/OKSIGEN rata tengah. **Wi-Fi**: tombol *Lupakan* hanya muncul bila ada jaringan tersimpan (tanpa itu, *Pilih manual* melebar penuh).
- **Aktivitas**: dropdown label (Diam/Berjalan/Berlari) dan dropdown Flash/Serial dihapus; rekaman memakai label "umum" dan penyimpanan flash.
- **Sistem**: halaman yang digulir atas-bawah berisi perangkat, prosesor (ESP32-C6, RISC-V, RAM, flash, radio), layar & sentuh, sensor (QMI8658, MAX30102, PCF85063) beserta statusnya, daya (VBAT, pengisi), jaringan, dan diagnostik. Tombol Reset layar/Restart dihapus (init ulang panel tetap otomatis).
- Titik penanda halaman dihapus.

## 13. Perubahan v0.4.0
- **Layar isi daya (USB-C)**: bila papan menyala karena USB (reset POWERON dan tombol PWR tidak ditekan saat boot), perangkat tampak "mati" dan hanya menampilkan ikon baterai + persen + "Mengisi daya"/"Terisi penuh" selama 12 dtk, lalu layar padam (isi daya terus). **PWR = nyalakan perangkat** (logo SAVERA lalu UI normal); **BOOT = tampilkan layar isi daya lagi**. Tahan PWR 2 dtk saat USB terpasang juga berakhir di layar ini. Tanpa USB, mati = daya diputus (seperti sebelumnya). Saat mengembangkan, set `CHARGE_MODE_ON_USB 0` di `config.h` agar colok USB ke PC langsung boot normal. Persen saat mengisi memakai tegangan terminal sehingga sedikit lebih tinggi dari kondisi istirahat.
- **Atur Waktu**: tata letak diperbaiki (roller tinggi tetap 58 px, petunjuk satu baris, tombol Batal/Simpan tidak lagi tertimpa).
- **Wi-Fi**: "Pindai ulang" menjadi "Pindai" (layar daftar dan halaman web). "Pilih manual" kini langsung memindai sekali (daftar lama dikosongkan dulu). Pemindaian yang gagal tidak lagi membuat layar menggantung di "Memindai...".
- **Pairing QR**: QR lama tidak lagi tampil sebelum AP benar-benar aktif; bila AP gagal aktif dalam 10 dtk muncul pesan jelas (sebelumnya layar keluar sendiri setelah 4 dtk); hasil `softAP` dicetak di Serial (`[PROV] ...`); perintah mulai/berhenti yang berdekatan kini diurutkan (yang terakhir menang). Setelah pairing selesai AP **dan halaman web pairing ditutup** (`/` kembali ke teks biasa, `/prov/*` menjawab 410). Nama AP lebih pendek: `SAVERA-XXXX`.
- **Aktivitas**: judul "Rekam Data" + keterangan "Data Ini Digunakan Untuk Machine Learning"; tombol "Tanda" diganti **Tipe** (layar pilih Diam / Berjalan / Berlari); **Mulai Rekam baru aktif setelah tipe dipilih**; tipe terkunci selama merekam dan dipakai sebagai label berkas rekaman; tulisan "Siap merekam" dihapus (diganti "Pilih tipe data dulu" / "Tipe: ...").

## 14. Perubahan v0.5.0
- **Pairing QR (akar masalah ditemukan)**: waktu "sekarang" dibaca sebelum AP dinyalakan, sehingga setelah AP aktif selisih waktu menjadi negatif (unsigned = sangat besar) dan sesi dianggap kedaluwarsa: AP langsung ditutup, layar menampilkan "gagal dimulai". Kini `provTick()` membaca `millis()` sendiri dan selisih diamankan.
- **Alur baru**: QR 1 (gabung Wi-Fi jam, WPA2 `SAVERA-XXXX` + sandi acak) → HP tersambung → QR 2 / `http://192.168.4.1` (halaman terbuka otomatis lewat captive portal) → isi SSID + sandi → data **disimpan ke NVS, jam restart, lalu otomatis terhubung** ke jaringan itu. AP dan halaman pairing ikut tertutup karena restart. Sandi yang salah baru ketahuan setelah restart (Wi-Fi tile menampilkan gagal terhubung; ulangi pairing).
- **Atur Waktu**: saat *Sinkron otomatis* menyala, roller jam/tanggal **dikunci**: memudar abu-abu dan tidak bisa disentuh (tidak dihilangkan). Matikan saklar untuk mengatur manual.
- **Layar isi daya** didesain ulang: cincin persen (bukan ikon baterai) dengan ikon petir dan angka besar. Saat USB terpasang dan jam "mati": **PWR tekan singkat = tampilkan status baterai**, **PWR tahan 1,2 dtk = nyalakan perangkat** (logo SAVERA), BOOT = tampilkan status juga (`CHARGE_BOOT_HOLD_MS` di `config.h`).
- **Aktivitas**: tombol **Tipe** kini menampilkan tipe terpilih (Diam abu-biru, Berjalan hijau, Berlari oranye; "Pilih Tipe" bila belum dipilih). Teks status kecil dihapus; saat merekam tombol rekam menjadi "Stop mm:dd". Pesan galat rekam tetap muncul bila ada.

## 15. Terhubung ke aplikasi SAVERA (Firebase) - v0.6.0
Aplikasi Flutter `SAVERA-ConnectableHardware` memakai **Firebase Realtime Database** (proyek `teman-jalan-13983`, RTDB `asia-southeast1`) dan mendengarkan node **`Devices/Device_01`**. Firmware kini menulis ke node yang sama.

| Node | Field | Tipe | Sumber di jam |
|---|---|---|---|
| `VitalSigns` | `HeartRate`, `SpO2` | angka (atau `"--"` bila belum valid) | MAX30102 |
| `DeviceStatus` | `IsWorn` | bool | deteksi dikenakan |
| | `Battery` | angka 0-100 | baterai |
| | `LastUpdated` | teks `HH.MM` (atau `Baru saja` bila jam belum disetel) | RTC |
| | `Heartbeat` | server timestamp | berubah tiap kirim; menjaga "watchdog 15 dtk" aplikasi tetap hidup |
| | `Charging` | bool | tambahan |
| `FallDetection` | `IsFallen` | bool, **selalu `false`** | **belum ada algoritma deteksi jatuh di firmware** |
| | `BA`, `BG` | teks `1.02g`, `3°/s` | besaran akselerasi dan gyro IMU |
| | `Active` | `false` | penanda bahwa detektor jatuh belum aktif |
| `Activity` | `Type` | `Diam`/`Berjalan`/`Berlari` | klasifikasi IMU |
| `Info` | name, mac, fw, ip, mdns | teks | dikirim saat terhubung |

- Interval kirim 3 dtk (`FIREBASE_PUSH_INTERVAL_MS`). Aplikasi menandai alat "Mati" bila tidak ada pembaruan 15 dtk (mis. jam dimatikan atau Wi-Fi putus).
- Nilai tak valid ditulis `"--"` dan bukan dikosongkan: bila field hilang, aplikasi menampilkan angka contoh (76 BPM / 98%).
- Aplikasi tidak memakai Firebase Auth, jadi `FIREBASE_API_KEY` dikosongkan dan akses diatur lewat **Rules** (di bawah).

### Setup
1. Firebase Console -> **Realtime Database -> Rules**, tempel lalu **Publish**:
```
{
  "rules": {
    "Devices": { "Device_01": { ".read": true, ".write": true } },
    "test_connection": { ".read": true, ".write": true },
    ".read": false,
    ".write": false
  }
}
```
   (Aturan "mode uji" bawaan Firebase kedaluwarsa 30 hari setelah dibuat. Bila Serial menampilkan `push gagal (401)` atau `(403)`, periksa tab Rules.)
2. Hubungkan jam ke Wi-Fi 2.4 GHz (Pasangkan lewat HP). Halaman **Sistem -> Cloud** menampilkan `Firebase - data terkirim` bila berhasil; Serial: `[FB] terkirim ke Devices/Device_01`.
3. Console -> Realtime Database -> **Data**: node `Devices/Device_01` terisi dan berubah tiap 3 dtk. Jalankan aplikasi: status berubah dari "Alat Mati" ke terhubung.
4. Keamanan: rules di atas terbuka untuk siapa pun yang tahu URL database. Cukup untuk uji coba/demo; untuk produksi tambahkan Firebase Auth (anonymous) di aplikasi, isi `FIREBASE_API_KEY`, dan ubah rules menjadi `auth != null`.
