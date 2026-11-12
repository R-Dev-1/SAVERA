import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ============================================================================
/// SAVERA - EVENT HISTORY & MEDICAL RECORD UI HELPERS
/// Helper modular untuk pemformatan waktu relatif dan pemetaan warna status klinis
/// persiapan integrasi Firebase Realtime Database.
/// ============================================================================

/// 1. Relative Time Formatter
/// Mengonversi [timestamp] dari Firebase (bisa berupa DateTime, integer milliseconds/seconds,
/// atau String ISO-8601/numeric) menjadi format waktu cerdas.
///
/// Aturan:
/// - HARI INI: kembalikan format jam saja (contoh: "10:45")
/// - KEMARIN: kembalikan format (contoh: "Kemarin, 10:45")
/// - LEBIH DARI KEMARIN: kembalikan format tanggal lengkap (contoh: "10 Nov 2026")
String formatRelativeTime(dynamic timestamp) {
  if (timestamp == null) return '-';

  final DateTime? date = parseTimestamp(timestamp);
  if (date == null) {
    return timestamp.toString();
  }

  final localDate = date.toLocal();
  final now = DateTime.now();

  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final itemDate = DateTime(localDate.year, localDate.month, localDate.day);

  final timeStr = DateFormat('HH:mm').format(localDate);

  if (itemDate == today) {
    return timeStr;
  } else if (itemDate == yesterday) {
    return 'Kemarin, $timeStr';
  } else {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final monthStr = months[localDate.month - 1];
    return '${localDate.day} $monthStr ${localDate.year}';
  }
}

/// Mengonversi [timestamp] menjadi format 24 jam dengan keterangan zona waktu
/// Contoh: "14:30 WIB" atau "08:15 WIB"
String formatEventTime24(dynamic timestamp) {
  if (timestamp == null) return '--:-- WIB';

  final DateTime? date = parseTimestamp(timestamp);
  if (date == null) {
    return timestamp.toString();
  }

  final localDate = date.toLocal();
  final timeStr = DateFormat('HH:mm').format(localDate);

  final offsetHours = localDate.timeZoneOffset.inHours;
  String zoneStr;
  if (offsetHours == 8) {
    zoneStr = 'WITA';
  } else if (offsetHours == 9) {
    zoneStr = 'WIT';
  } else {
    // Default UTC+7 / Indonesia Barat
    zoneStr = 'WIB';
  }

  return '$timeStr $zoneStr';
}

/// Memeriksa apakah suatu timestamp berada pada hari, bulan, dan tahun yang sama dengan hari ini (DateTime.now())
bool isTimestampToday(dynamic timestamp) {
  if (timestamp == null) return false;
  final DateTime? date = parseTimestamp(timestamp);
  if (date == null) return false;
  final localDate = date.toLocal();
  final now = DateTime.now();
  return localDate.year == now.year &&
      localDate.month == now.month &&
      localDate.day == now.day;
}

/// Parser fleksibel untuk berbagai format timestamp dari Firebase Realtime Database
DateTime? parseTimestamp(dynamic timestamp) {
  if (timestamp == null) return null;
  if (timestamp is DateTime) return timestamp;

  if (timestamp is int) {
    // Jika timestamp dalam satuan detik (10 digit), konversi ke milidetik
    if (timestamp < 10000000000) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    }
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  if (timestamp is String) {
    final intParsed = int.tryParse(timestamp);
    if (intParsed != null) {
      return parseTimestamp(intParsed);
    }
    return DateTime.tryParse(timestamp);
  }

  return null;
}

/// 2. Color Mapping (Dot Indikator Status Kejadian & Aktivitas)
/// Menerima parameter [statusKejadian] dan mengembalikan nilai [Color] berdasarkan
/// kata kunci klasifikasi klinis & aktivitas lansia:
/// - "Jatuh" (kedaruratan) -> Colors.red
/// - "Berlari" -> Warna Hijau Tua (Dark Green: const Color(0xFF15803D))
/// - "Berjalan" -> Warna Hijau Muda (Light Green: Colors.lightGreen)
/// - "Diam" -> Warna Biru (Blue: Colors.blue)
/// - "Alat Dilepas" -> Warna Abu-abu (Grey: Colors.grey)
/// - Kategori Sistem lainnya -> Colors.blueGrey
/// - Default -> Colors.grey
Color getEventStatusColor(String statusKejadian) {
  final status = statusKejadian.toLowerCase();

  // 1. Kategori Kedaruratan (Jatuh) -> Merah Darurat (Red)
  if (status.contains('jatuh') ||
      status.contains('fall') ||
      status.contains('kritis') ||
      status.contains('bahaya') ||
      status.contains('darurat')) {
    return Colors.red;
  }

  // 2. Kategori Peringatan Baterai Lemah -> Kuning Amber (Colors.amber)
  if (status.contains('baterai') || status.contains('battery')) {
    return Colors.amber;
  }

  // 3. Kategori Berlari -> Hijau Tua (Dark Green)
  if (status.contains('berlari') ||
      status.contains('lari') ||
      status.contains('run')) {
    return const Color(0xFF15803D);
  }

  // 3. Kategori Berjalan -> Hijau Muda (Light Green)
  if (status.contains('berjalan') ||
      status.contains('jalan') ||
      status.contains('walk')) {
    return Colors.lightGreen;
  }

  // 4. Kategori Diam -> Biru (Blue)
  if (status.contains('diam') ||
      status.contains('istirahat') ||
      status.contains('idle') ||
      status.contains('rest')) {
    return Colors.blue;
  }

  // 5. Kategori Alat Dilepas -> Abu-abu (Grey)
  if (status.contains('dilepas') ||
      status.contains('lepas') ||
      status.contains('alat dilepas') ||
      status.contains('unworn') ||
      status.contains('off')) {
    return Colors.grey;
  }

  // 6. Kategori Status Sistem
  if (status.contains('dipasang') ||
      status.contains('terhubung') ||
      status.contains('sistem') ||
      status.contains('gelang') ||
      status.contains('perangkat') ||
      status.contains('device')) {
    return Colors.blueGrey;
  }

  // Default: Abu-abu (Grey)
  return Colors.grey;
}
