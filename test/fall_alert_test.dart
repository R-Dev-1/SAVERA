import 'package:flutter_test/flutter_test.dart';

/// Helper evaluasi logika deteksi jatuh yang identik dengan logika di home_page.dart
bool evaluateFallCondition({
  required Map<dynamic, dynamic> dataMap,
  required bool isOffline,
}) {
  if (dataMap.isEmpty || isOffline) {
    return false;
  }

  final devStatus = (dataMap['DeviceStatus'] is Map)
      ? dataMap['DeviceStatus'] as Map<dynamic, dynamic>
      : ((dataMap['deviceStatus'] is Map)
            ? dataMap['deviceStatus'] as Map<dynamic, dynamic>
            : {});
  final fallDetection = (dataMap['FallDetection'] is Map)
      ? dataMap['FallDetection'] as Map<dynamic, dynamic>
      : ((dataMap['fallDetection'] is Map)
            ? dataMap['fallDetection'] as Map<dynamic, dynamic>
            : {});
  final activityData = (dataMap['Activity'] is Map)
      ? dataMap['Activity'] as Map<dynamic, dynamic>
      : ((dataMap['activity'] is Map)
            ? dataMap['activity'] as Map<dynamic, dynamic>
            : {});

  final dynamic rawW =
      devStatus['IsWorn'] ??
      devStatus['isWorn'] ??
      dataMap['IsWorn'] ??
      dataMap['isWorn'] ??
      dataMap['worn'];
  final bool isWorn =
      (rawW == true) ||
      (rawW == 1) ||
      (rawW?.toString().trim().toLowerCase() == 'true');

  final bool isWatchActive = (isWorn && !isOffline);

  final dynamic rawFallenValue =
      fallDetection['IsFallen'] ??
      fallDetection['isFallen'] ??
      dataMap['IsFallen'] ??
      dataMap['isFallen'];
  final bool rawIsFallen =
      (rawFallenValue == true) ||
      (rawFallenValue == 1) ||
      (rawFallenValue?.toString().trim().toLowerCase() == 'true');

  final String? activityType =
      activityData['Type']?.toString() ??
      activityData['type']?.toString() ??
      dataMap['Activity']?.toString();
  final bool isActivityFallen =
      activityType != null &&
      (activityType.toLowerCase().contains('jatuh') ||
          activityType.toLowerCase().contains('terjatuh'));

  return isWatchActive && (rawIsFallen || isActivityFallen);
}

void main() {
  group('Fall Detection Emergency Alert Logic Tests', () {
    test('1. Trigger Alert saat IsFallen == true dan alat aktif online', () {
      final data = {
        'DeviceStatus': {'IsWorn': true, 'Connection': 'Online'},
        'FallDetection': {'IsFallen': true},
        'Activity': {'Type': 'Diam'},
      };
      final isFallen = evaluateFallCondition(dataMap: data, isOffline: false);
      expect(isFallen, isTrue);
    });

    test('2. Trigger Alert saat Activity Type == "Terjatuh" dan alat aktif online', () {
      final data = {
        'DeviceStatus': {'IsWorn': true, 'Connection': 'Online'},
        'FallDetection': {'IsFallen': false},
        'Activity': {'Type': 'Terjatuh'},
      };
      final isFallen = evaluateFallCondition(dataMap: data, isOffline: false);
      expect(isFallen, isTrue);
    });

    test('3. Bypass Alert saat alat offline meski IsFallen == true', () {
      final data = {
        'DeviceStatus': {'IsWorn': true, 'Connection': 'Online'},
        'FallDetection': {'IsFallen': true},
        'Activity': {'Type': 'Terjatuh'},
      };
      final isFallen = evaluateFallCondition(dataMap: data, isOffline: true);
      expect(isFallen, isFalse);
    });

    test('4. Bypass Alert saat jam dilepas (IsWorn == false) meski data Firebase IsFallen true', () {
      final data = {
        'DeviceStatus': {'IsWorn': false, 'Connection': 'Online'},
        'FallDetection': {'IsFallen': true},
        'Activity': {'Type': 'Terjatuh'},
      };
      final isFallen = evaluateFallCondition(dataMap: data, isOffline: false);
      expect(isFallen, isFalse);
    });

    test('5. Auto Recovery saat status di Firebase kembali ke normal (Diam / IsFallen == false)', () {
      final normalData = {
        'DeviceStatus': {'IsWorn': true, 'Connection': 'Online'},
        'FallDetection': {'IsFallen': false},
        'Activity': {'Type': 'Diam'},
      };
      final isFallen = evaluateFallCondition(dataMap: normalData, isOffline: false);
      expect(isFallen, isFalse);
    });

    test('6. Simulasi Alur Pemberhentian (Stop): Manual Silence vs Reset Firebase', () {
      bool isAlerting = false;
      bool userSilenced = false;

      // Event 1: Pasien Jatuh terdeteksi
      final fallData = {
        'DeviceStatus': {'IsWorn': true, 'Connection': 'Online'},
        'FallDetection': {'IsFallen': true},
        'Activity': {'Type': 'Terjatuh'},
      };

      if (evaluateFallCondition(dataMap: fallData, isOffline: false)) {
        if (!userSilenced) {
          isAlerting = true;
        }
      }
      expect(isAlerting, isTrue);

      // Event 2: Pengguna menekan tombol "Matikan Alarm & Paham"
      userSilenced = true;
      isAlerting = false;
      expect(isAlerting, isFalse);

      // Stream Firebase mengirim ulang data IsFallen == true (incident yang sama)
      if (evaluateFallCondition(dataMap: fallData, isOffline: false)) {
        if (!userSilenced) {
          isAlerting = true;
        }
      }
      // Alarm tetap tidak berbunyi ulang karena sudah di-silence untuk insiden ini
      expect(isAlerting, isFalse);

      // Event 3: Pasien bangun dan status kembali Diam (IsFallen == false)
      final normalData = {
        'DeviceStatus': {'IsWorn': true, 'Connection': 'Online'},
        'FallDetection': {'IsFallen': false},
        'Activity': {'Type': 'Diam'},
      };
      if (!evaluateFallCondition(dataMap: normalData, isOffline: false)) {
        userSilenced = false; // Reset flag agar insiden baru nanti bisa membunyikan alarm lagi
        isAlerting = false;
      }
      expect(userSilenced, isFalse);
      expect(isAlerting, isFalse);

      // Event 4: Insiden jatuh baru terjadi di kemudian hari
      if (evaluateFallCondition(dataMap: fallData, isOffline: false)) {
        if (!userSilenced) {
          isAlerting = true;
        }
      }
      // Alarm harus berbunyi lagi untuk insiden baru!
      expect(isAlerting, isTrue);
    });
  });
}

