// imu_activity.h - IMU QMI8658 @100 Hz: klasifikasi DIAM / BERJALAN / BERLARI + pencatatan data CSV
#pragma once
#include <Arduino.h>
#include "app_state.h"

void imu_init();     // mulai task IMU + task penulis log

// --- pencatatan data (untuk dataset pelatihan ML) ---
bool log_start(const char* label, LogMode mode, char* err, size_t errn);
void log_stop();
void log_marker();   // tandai momen (mis. awal berlari) -> kolom Marker=1 pada baris berikutnya
bool log_fs_ok();
