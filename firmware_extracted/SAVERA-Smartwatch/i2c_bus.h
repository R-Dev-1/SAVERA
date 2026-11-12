// i2c_bus.h - satu bus I2C dipakai bersama (touch, RTC, IMU, MAX30102) => wajib mutex
#pragma once
#include <Arduino.h>
#include <Wire.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>
#include "config.h"

extern SemaphoreHandle_t g_i2c_mtx;
void i2c_init();
bool i2c_watchdog();    // panggil berkala: bila SDA/SCL tertahan LOW saat idle => pulihkan bus. true = bus dipulihkan
void i2c_recover();     // lepaskan bus yang macet (9 pulsa SCL + STOP) lalu mulai ulang Wire
uint8_t i2c_lines();    // 0 = SDA & SCL HIGH (sehat), bit0 = SDA LOW, bit1 = SCL LOW
bool i2c_bus_ok();      // false bila bus sedang macet: task I2C harus mundur (jangan menghantam bus)
uint8_t i2c_devmask();  // hasil pemindaian boot (bit0 touch, bit1 RTC, bit2 IMU, bit3 codec, bit4 MAX30102)
bool i2c_take_recover_event();   // true sekali setelah bus dipulihkan (dipakai UI untuk init ulang panel)

struct I2cLock {
  I2cLock()  { xSemaphoreTake(g_i2c_mtx, portMAX_DELAY); }
  ~I2cLock() { xSemaphoreGive(g_i2c_mtx); }
};
