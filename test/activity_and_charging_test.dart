import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savera/utils/event_helper.dart';

void main() {
  group('Aktivitas & Logika Warna Riwayat', () {
    test('Warna dinamis sesuai permintaan spesifikasi', () {
      // 1. "Alat Dilepas" -> Warna Abu-abu (Grey)
      expect(getEventStatusColor('Alat Dilepas'), Colors.grey);
      expect(getEventStatusColor('alat dilepas'), Colors.grey);
      expect(getEventStatusColor('Gelang Dilepas'), Colors.grey);

      // 2. "Diam" -> Warna Biru (Blue)
      expect(getEventStatusColor('Diam'), Colors.blue);
      expect(getEventStatusColor('Aktivitas: Diam'), Colors.blue);
      expect(getEventStatusColor('Istirahat'), Colors.blue);

      // 3. "Berjalan" -> Warna Hijau Muda (Light Green)
      expect(getEventStatusColor('Berjalan'), Colors.lightGreen);
      expect(getEventStatusColor('Aktivitas Berjalan'), Colors.lightGreen);

      // 4. "Berlari" -> Warna Hijau Tua (Dark Green)
      expect(getEventStatusColor('Berlari'), const Color(0xFF15803D));
      expect(getEventStatusColor('Aktivitas Berlari'), const Color(0xFF15803D));

      // 5. "Jatuh" -> Warna Merah Darurat (Red)
      expect(getEventStatusColor('Jatuh'), Colors.red);
      expect(getEventStatusColor('Bahaya: Jatuh Terdeteksi!'), Colors.red);
      expect(getEventStatusColor('Deteksi Jatuh'), Colors.red);

      // 6. "Baterai Lemah" -> Warna Kuning Amber (Colors.amber)
      expect(
        getEventStatusColor('Baterai Lemah • Baterai tersisa 15%'),
        Colors.amber,
      );
      expect(getEventStatusColor('Peringatan Baterai Lemah'), Colors.amber);
    });

    test('Peringatan Baterai Lemah (Low Battery Alert Logic)', () {
      bool computeIsLowBattery({
        required bool isWatchActive,
        required int? batteryLevel,
      }) {
        return (isWatchActive &&
            batteryLevel != null &&
            batteryLevel < 20 &&
            batteryLevel > 0);
      }

      // 1. Kondisi aktif dan baterai di bawah 20% (misal 15%) -> true
      expect(
        computeIsLowBattery(isWatchActive: true, batteryLevel: 15),
        isTrue,
      );

      // 2. Kondisi alat dilepas/offline (isWatchActive == false) -> false (bypass)
      expect(
        computeIsLowBattery(isWatchActive: false, batteryLevel: 15),
        isFalse,
      );

      // 3. Baterai normal (misal 50% atau 20%) -> false
      expect(
        computeIsLowBattery(isWatchActive: true, batteryLevel: 20),
        isFalse,
      );
      expect(
        computeIsLowBattery(isWatchActive: true, batteryLevel: 75),
        isFalse,
      );

      // 4. Baterai bernilai null atau 0 (data invalid) -> false
      expect(
        computeIsLowBattery(isWatchActive: true, batteryLevel: null),
        isFalse,
      );
      expect(
        computeIsLowBattery(isWatchActive: true, batteryLevel: 0),
        isFalse,
      );
    });
  });
}
