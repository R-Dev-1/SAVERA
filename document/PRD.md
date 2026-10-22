# Product Requirements Document (PRD) - SAVERA

## 1. Ikhtisar Proyek (Project Overview)
**Nama Proyek:** SAVERA (Senior And Vital Emergency Response Alert)
**Platform:** Aplikasi Mobile (Android/iOS) berbasis Flutter
**Deskripsi:** 
SAVERA adalah aplikasi dasbor pemantauan kesehatan dan pendeteksi jatuh yang dirancang khusus untuk pengasuh (caregiver) lansia. Aplikasi ini menampilkan data secara real-time yang dikirimkan dari sensor perangkat keras (ESP32) ke Firebase Realtime Database, memungkinkan tindakan cepat dan pemantauan jarak jauh saat terjadi kondisi darurat.

## 2. Tujuan (Objectives)
*   **Pemantauan Real-time:** Menyediakan antarmuka yang membaca data detak jantung (BPM) dan status pergerakan/jatuh secara langsung (tanpa delay).
*   **Peringatan Visual Darurat:** Memberikan indikator warna dan peringatan visual yang mencolok ketika sistem mendeteksi lansia terjatuh.
*   **Aksesibilitas UI/UX:** Memiliki desain antarmuka yang bersih (clean), teks yang besar dan mudah dibaca (high contrast), serta navigasi yang tidak membingungkan pengasuh.

## 3. Arsitektur Sistem & Tech Stack
*   **Frontend (UI/UX):** Flutter (Dart)
*   **Backend & Database:** Firebase Realtime Database
*   **Hardware (IoT):** ESP32, Sensor Detak Jantung, Sensor Accelerometer/Gyroscope
*   **Alur Data:** Hardware membaca data -> Mengirim ke Firebase -> Aplikasi Flutter menerima data melalui `StreamBuilder`.

## 4. Fitur Utama (Key Features)

### 4.1. Landing Page (Layar Sambutan)
*   **Lokasi File:** `lib/pages/landing_page.dart`
*   **Fungsi:** Sebagai *splash screen* dan pengenalan aplikasi saat pertama kali dibuka.
*   **Elemen UI:** 
    *   Logo SAVERA terbaru.
    *   Nama aplikasi dan tagline singkat.
    *   Tombol navigasi transisi untuk masuk ke Dasbor Utama.

### 4.2. Home Page (Dasbor Utama)
*   **Lokasi File:** `lib/pages/home_page.dart`
*   **Fungsi:** Layar pemantauan utama.
*   **Elemen UI:**
    *   **Kartu Indikator BPM:** Menampilkan angka detak jantung (Beats Per Minute) secara real-time.
    *   **Kartu Status Pergerakan (Fall Detection):** Menampilkan status "Aman" atau "Bahaya/Jatuh". Komponen ini harus reaktif (berubah warna menjadi merah/peringatan jika terdeteksi jatuh).
    *   **Tombol Darurat (Emergency Action):** Tombol aksi cepat untuk melakukan panggilan atau merespons notifikasi bahaya.

## 5. Batasan & Aturan Pengembangan (Constraints & Rules)
*   **Jangan Rusak Koneksi Backend:** Dilarang menghapus atau mengubah logika inisialisasi Firebase yang sudah dibuat sebelumnya.
*   **Penggunaan Dummy Data:** Jika file konfigurasi Firebase belum sepenuhnya terhubung di *local environment*, gunakan data statis (*dummy data*) sementara khusus untuk keperluan penyesuaian tata letak (layouting) UI.
*   **Modularitas:** Jika ada komponen UI yang dipakai berulang (misal: desain kartu informasi), pisahkan menjadi *widget* mandiri di folder `lib/widgets`.