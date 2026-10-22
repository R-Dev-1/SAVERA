# Konteks Proyek (Project Context) - SAVERA

## 1. Latar Belakang Proyek
SAVERA (Senior And Vital Emergency Response Alert) adalah sistem pemantauan terpadu berbasis Internet of Things (IoT). Sistem ini menggabungkan perangkat keras (sensor yang dipasang pada lansia) dan perangkat lunak (aplikasi dasbor untuk pengasuh) guna memantau detak jantung dan mendeteksi jika lansia terjatuh secara *real-time*.

## 2. Pembagian Peran Pengembang
Proyek ini dikerjakan secara kolaboratif:
*   **Radit (Backend & Hardware):** Mengembangkan perangkat keras (ESP32, sensor), simulasi Wokwi, mengatur Firebase Realtime Database, dan menulis kerangka awal koneksi Firebase di Flutter.
*   **Faiq (Frontend & UI/UX):** Fokus pada perancangan antarmuka, *microcopy*, pengalaman pengguna (UX), tata letak (*layouting*), dan penyempurnaan desain visual di aplikasi Flutter. **(Agen AI saat ini membantu Faiq di ranah ini)**.

## 3. Alur Kerja Sistem (System Flow)
1.  **Pengumpulan Data:** Perangkat keras membaca tanda vital (BPM) dan pergerakan fisik (akselerometer/giroskop).
2.  **Transmisi:** Data dikirim secara terus-menerus (*stream*) ke node Firebase Realtime Database.
3.  **Visualisasi:** Aplikasi Flutter *mendengarkan* (listen) perubahan data di Firebase menggunakan `StreamBuilder` dan memperbarui tampilan UI di layar secara instan.

## 4. Arahan Utama untuk Agen AI (AI Agent Directives)
Sebagai agen AI yang membantu pengerjaan proyek ini, Anda **DIWAJIBKAN** untuk mematuhi aturan berikut:
*   **Hormati Batas Backend:** Jangan pernah menghapus, memodifikasi, atau menimpa logika inisialisasi Firebase (`Firebase.initializeApp`), *rules*, atau struktur `StreamBuilder` yang sudah ditulis, kecuali diminta secara eksplisit.
*   **Fokus Visual & UX:** Tugas utama Anda adalah membantu merombak antarmuka, mengatur *padding*, *margin*, tipografi, warna, dan memecah *widget* agar kode lebih rapi dan modular.
*   **Penanganan Error Sementara:** Jika saat diuji coba (run) aplikasi mengalami *error* karena *credential* Firebase belum diunduh ke lingkungan lokal, Anda diizinkan untuk memberi *comment* (`//`) pada logika Firebase dan menggantinya dengan data statis (UI statis) sementara, HANYA untuk keperluan pratinjau desain.