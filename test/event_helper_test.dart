import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:savera/utils/event_helper.dart';

void main() {
  group('Event Helper - formatRelativeTime', () {
    test('HARI INI -> format jam saja (HH:mm)', () {
      final now = DateTime.now();
      final todayTime = DateTime(now.year, now.month, now.day, 10, 45);
      expect(formatRelativeTime(todayTime), '10:45');
    });

    test('KEMARIN -> format Kemarin, HH:mm', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayTime = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
        10,
        45,
      );
      expect(formatRelativeTime(yesterdayTime), 'Kemarin, 10:45');
    });

    test(
      'LEBIH DARI KEMARIN -> format tanggal lengkap (contoh: 10 Nov 2026)',
      () {
        final olderDate = DateTime(2026, 11, 8, 10, 45);
        expect(formatRelativeTime(olderDate), '8 Nov 2026');

        final pastDate = DateTime(2026, 11, 10, 10, 45);
        final now = DateTime.now();
        final itemDate = DateTime(pastDate.year, pastDate.month, pastDate.day);
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));

        if (itemDate != today && itemDate != yesterday) {
          expect(formatRelativeTime(pastDate), '10 Nov 2026');
        }
      },
    );

    test('Mendukung timestamp integer milliseconds & seconds', () {
      final now = DateTime.now();
      final todayTime = DateTime(now.year, now.month, now.day, 14, 30);
      final millis = todayTime.millisecondsSinceEpoch;
      expect(formatRelativeTime(millis), DateFormat('HH:mm').format(todayTime));
    });
  });

  group('Event Helper - getEventStatusColor', () {
    test('Mengandung kata Jatuh -> Colors.red', () {
      expect(
        getEventStatusColor('Bahaya: Lansia Jatuh di Kamar Tidur'),
        Colors.red,
      );
      expect(getEventStatusColor('Deteksi Jatuh Terkonfirmasi'), Colors.red);
      expect(getEventStatusColor('Kondisi Kritis Terdeteksi'), Colors.red);
    });

    test('Status aktivitas dinamis: Alat Dilepas, Diam, Berjalan, Berlari', () {
      expect(getEventStatusColor('Alat Dilepas'), Colors.grey);
      expect(getEventStatusColor('Gelang Dilepas'), Colors.grey);
      expect(getEventStatusColor('Diam'), Colors.blue);
      expect(getEventStatusColor('Istirahat di Kamar'), Colors.blue);
      expect(getEventStatusColor('Aktivitas Berjalan'), Colors.lightGreen);
      expect(getEventStatusColor('Aktivitas Berlari'), const Color(0xFF15803D));
    });

    test('Status sistem (dipasang, terhubung, sistem) -> Colors.blueGrey', () {
      expect(getEventStatusColor('Gelang Telah Dipasang'), Colors.blueGrey);
      expect(getEventStatusColor('Gelang Dipasang'), Colors.blueGrey);
      expect(getEventStatusColor('Sensor Berhasil Terhubung'), Colors.blueGrey);
      expect(getEventStatusColor('Pembaruan Sistem Dimulai'), Colors.blueGrey);
    });

    test('Kondisi lainnya (sisanya) -> Colors.grey', () {
      expect(getEventStatusColor('Status Normal'), Colors.grey);
      expect(getEventStatusColor('Laporan Rutin Selesai'), Colors.grey);
    });

    test('Status peringatan baterai lemah -> Colors.amber', () {
      expect(
        getEventStatusColor('Baterai Lemah • Baterai tersisa 15%'),
        Colors.amber,
      );
      expect(getEventStatusColor('Peringatan Baterai Lemah'), Colors.amber);
      expect(getEventStatusColor('Battery Low'), Colors.amber);
    });
  });

  group('Event Helper - formatEventTime24 & isTimestampToday', () {
    test('formatEventTime24 format 24 jam dengan zona waktu (WIB)', () {
      final now = DateTime.now();
      final dt1 = DateTime(now.year, now.month, now.day, 14, 30);
      expect(formatEventTime24(dt1), '14:30 WIB');

      final dt2 = DateTime(now.year, now.month, now.day, 8, 15);
      expect(formatEventTime24(dt2), '08:15 WIB');
    });

    test('isTimestampToday membedakan hari ini vs hari lain', () {
      final now = DateTime.now();
      expect(isTimestampToday(now), isTrue);
      expect(isTimestampToday(now.subtract(const Duration(hours: 2))), isTrue);

      final yesterday = now.subtract(const Duration(days: 1));
      expect(isTimestampToday(yesterday), isFalse);

      final lastWeek = now.subtract(const Duration(days: 7));
      expect(isTimestampToday(lastWeek), isFalse);
    });
  });
}
