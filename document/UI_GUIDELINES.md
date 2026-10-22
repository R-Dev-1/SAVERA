# UI Guidelines - SAVERA (Senior Vital-sign & Fall Risk)

Dokumen ini merupakan panduan antarmuka pengguna (UI Guidelines) resmi untuk aplikasi SAVERA, yang diekstrak langsung dari spesifikasi desain dan CSS pada file acuan `SAVERA_Semua_Halaman (1).html`.

---

## 1. Skema Warna (Color Palette)

Skema warna SAVERA menggunakan palet bernuansa medis modern (*healthcare technology*), memadukan biru laut (*navy/blue*), aksen *sky blue*, serta latar es yang lembut (*ice light blue*) untuk kenyamanan mata lansia dan pengasuh.

### Palet Warna Utama (Tokens `:root`)

| Token CSS | Kode Hex | Nilai RGB / HSL | Penggunaan Utama |
| :--- | :--- | :--- | :--- |
| `--navy` | `#0B2A6E` | `rgb(11, 42, 110)` | Brand utama, judul aplikasi, nama pasien, heading tebal |
| `--ink` | `#0F1E3D` | `rgb(15, 30, 61)` | Teks heading gelap, judul konten |
| `--blue` | `#1E6FEB` | `rgb(30, 111, 235)` | Warna primer, aksen tombol, ikon fitur, link aktif |
| `--sky` | `#0EA5E9` | `rgb(14, 165, 233)` | Aksen cerah, gradien awal tombol, dot status live |
| `--l1` | `#F0F7FF` | `rgb(240, 247, 255)` | Latar belakang layar (*screen background*) |
| `--l2` | `#E0F0FE` | `rgb(224, 240, 254)` | Latar belakang wadah ikon (*icon box*), segmen aktif |
| `--l3` | `#BAE0FD` | `rgb(186, 224, 253)` | *Ambient glow* radial, ring avatar, *track* progress bar |
| `--line` | `#D6E6FB` | `rgb(214, 230, 251)` | Garis batas (*border*) kartu, input, dan pembatas |
| `--muted` | `#64748B` | `rgb(100, 116, 139)` | Teks sekunder, label caption, timestamp, footnote |
| `--body` | `#334155` | `rgb(51, 65, 85)` | Teks isi (*body text*), deskripsi lead, paragraf |
| `--red` | `#E11D2E` | `rgb(225, 29, 46)` | Status bahaya / darurat jatuh (*fall alert*) |
| `--dred` | `#9F1239` | `rgb(159, 18, 57)` | Aksen merah tua status kritis |

### Warna Gradien & Efek Permukaan

*   **Gradien Tombol & Avatar Primer:**  
    `linear-gradient(135deg, #0EA5E9 0%, #1E6FEB 100%)`  
    *(Kombinasi `--sky` ke `--blue` dengan arah diagonal 135°)*
*   **Ambient Glow Layar Sambutan:**  
    `radial-gradient(closest-side, #BAE0FD 0%, rgba(186, 224, 253, 0) 100%)`  
    *(Cahaya lembut radial di bagian atas latar belakang)*
*   **Status Normal / Aman (Banner):**  
    Background: `linear-gradient(135deg, #BBF7D0, #ECFDF5)`  
    Border: `1px solid #A7F3D0`  
    Teks: `#065F46` / `#059669`
*   **Status Jeda / Jam Dilepas (Banner):**  
    Background: `#E8EDF3`  
    Border: `1px dashed #94A3B8`  
    Teks: `#475569`

---

## 2. Tipografi (Typography)

*   **Font Utama:** `Inter`, didukung oleh `Roboto` atau `system-ui, sans-serif`.
*   **Perilaku Angka:** `font-variant-numeric: tabular-nums` (agar pembacaan detak jantung dan angka sensor konsisten lurus).

### Hierarki & Ukuran Font

| Elemen / Kelas | Ukuran Font | Berat (*Weight*) | Spasi Huruf (*Tracking*) | Warna Default |
| :--- | :--- | :--- | :--- | :--- |
| **Brand Title (.nm)** | `36px` | 800 (Extra Bold) | `letter-spacing: 7px` | `#0B2A6E` (`--navy`) |
| **Vital Value (.val)** | `48px` | 700 (Bold) | `letter-spacing: -1px` | `#0F1E3D` (`--ink`) |
| **Alert Title (.alert h1)** | `28px` | 800 (Extra Bold) | Normal (`line-height: 1.15`) | `#FFFFFF` |
| **Page Title (.ttl)** | `22px` | 800 (Extra Bold) | Normal | `#0B2A6E` (`--navy`) |
| **Group Header (.grp h2)**| `20px` | 800 (Extra Bold) | Normal | `#0B2A6E` (`--navy`) |
| **Header Brand (.brand)** | `19px` | 800 (Extra Bold) | `letter-spacing: 1.5px`| `#0B2A6E` (`--navy`) |
| **Patient Name (.wn)** | `18px` | 700 (Bold) | Normal | `#0B2A6E` (`--navy`) |
| **Tombol Utama (.btn)** | `16px` | 700 (Bold) | Normal | `#FFFFFF` |
| **Subtitle (.sub)** | `15px` | 600 (Semi Bold) | Normal | `#1E6FEB` (`--blue`) |
| **Card Heading (.h3)** | `15px` | 600 (Semi Bold) | Normal | `#0F1E3D` (`--ink`) |
| **Lead Paragraph (.lead)**| `14px` | 400 - 500 | `line-height: 1.5` | `#334155` (`--body`) |
| **Feature Item (.feat li)**| `14px` | 500 (Medium) | Normal | `#0F1E3D` / `#334155` |
| **Vital Unit (.val small)**| `12.5px` | 600 (Semi Bold) | Normal | `#64748B` (`--muted`) |
| **Caption / Tile (.cap, .t1)**| `10.5px - 12px`| 500 - 600 | Normal | `#64748B` (`--muted`) |
| **Footnote / Info (.foot)**| `12px` | 400 - 500 | Normal | `#64748B` (`--muted`) |

---

## 3. Gaya Komponen UI (UI Component Styling)

### A. Kartu Konten (*Card* - `.card`)
*   **Latar Belakang:** `#FFFFFF` (Putih murni)
*   **Border:** `1px solid #D6E6FB` (`--line`)
*   **Corner Radius:** `16px` (`BorderRadius.circular(16)`)
*   **Padding:** `16px` (pada header variasi: `16px 16px 14px`)
*   **Box Shadow:**  
    `0 3px 12px rgba(30, 111, 235, 0.07)`  
    *(Shadow biru sangat halus untuk memberikan elevasi mengapung tanpa kontras kotor)*

### B. Tombol Utama (*Primary Button* - `.btn`)
*   **Lebar (*Width*):** `100%` (*Full width / double.infinity*)
*   **Tinggi (*Height*):** `60px`
*   **Border:** Tidak ada border (`0`)
*   **Corner Radius:** `16px` (`BorderRadius.circular(16)`)
*   **Latar Belakang:** `linear-gradient(135deg, #0EA5E9, #1E6FEB)`
*   **Bayangan (*Box Shadow*):**  
    `0 10px 24px rgba(30, 111, 235, 0.30)`  
    *(Shadow biru menyala berkesan modern & premium)*
*   **Tipografi:** `16px`, Font Weight `700` (Bold), Warna `#FFFFFF`
*   **Tata Letak Internal:** `Row` horizontal tengah (*center*), jarak antar teks dan ikon panah `10px`
*   **Indikator Fokus:** `outline: 3px solid #0B2A6E; outline-offset: 3px`

### C. Wadah Ikon Fitur (*Icon Box* - `.ic`)
*   **Dimensi:** `34px x 34px`
*   **Corner Radius:** `11px` (`BorderRadius.circular(11)`)
*   **Latar Belakang:** `#E0F0FE` (`--l2`)
*   **Posisi:** Rata tengah (*center*)
*   **Gaya Ikon:** Warna `#1E6FEB` (`--blue`), *stroke width*: `2.2`

### D. Latar Belakang & Tata Letak Layar Sambutan (*Welcome Layout* - `.wel`)
*   **Latar Belakang Dasar:** `#F0F7FF` (`--l1`)
*   **Padding:** Horizontal `20px`, Vertikal atas `14px`, Vertikal bawah `28px`
*   **Ambient Glow:**  
    Radial gradient dengan lebar `520px` dan tinggi `460px`, terletak di bagian atas layar (`top: -100px`, `center`), menggunakan warna `#BAE0FD` pudar ke transparan.
*   **Logo Hero:** Tinggi `128px` (`height: 128`), proporsi lebar otomatis (*aspect ratio preserved*), margin atas `48px`.

---

## 4. Microcopy Spesifik "Layar Sambutan" (Halaman 1)

Berikut adalah salinan teks (*microcopy*) resmi yang WAJIB digunakan 100% pada Layar Sambutan:

| Komponen | Teks Resmi | Keterangan Gaya |
| :--- | :--- | :--- |
| **Logo Image** | *Logo Perisai SAVERA* | Tinggi `128px`, posisi tengah |
| **Judul Aplikasi** | `SAVERA` | `36px`, weight 800, spasi `7px`, Navy `#0B2A6E` |
| **Subjudul Aplikasi** | `Tanda Vital & Risiko Jatuh` | `15px`, weight 600, Blue `#1E6FEB` |
| **Paragraf Pengantar** | `Pantau tanda vital dan risiko jatuh lansia secara langsung, untuk ketenangan keluarga.` | `14px`, warna `#334155`, rata tengah, line height `1.5` |
| **Fitur 1** | `Denyut nadi dan saturasi oksigen` | Ikon: Jantung / Heartbeat, background `#E0F0FE` |
| **Fitur 2** | `Deteksi jatuh dari sensor gerak` | Ikon: Gelombang aktivitas / Motion Wave |
| **Fitur 3** | `Lokasi dan riwayat kejadian` | Ikon: Pin / Lokasi |
| **Tombol Aksi** | `Mulai` `->` | Tinggi 60px, gradien cyan ke biru, panah putih |
| **Catatan Kaki (Footnote)**| `Selanjutnya Anda diminta mengisi profil pasien` | `12px`, warna muted `#64748B`, rata tengah |