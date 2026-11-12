import 'package:flutter_test/flutter_test.dart';

bool computeIsWithinCalibrationWindow({
  required bool isWatchActive,
  required DateTime? wornTransitionTime,
  required DateTime currentTime,
}) {
  return (isWatchActive &&
      wornTransitionTime != null &&
      currentTime.difference(wornTransitionTime).inMilliseconds < 3000);
}

bool computeIsCalibratingHr({
  required bool isWatchActive,
  required bool isWaiting,
  required bool isOffline,
  required double? parsedHr,
  required bool isWithinCalibrationWindow,
}) {
  final bool hasValidHr = (parsedHr != null && parsedHr > 0);
  return isWatchActive &&
      !isWaiting &&
      !isOffline &&
      (!hasValidHr || isWithinCalibrationWindow);
}

void main() {
  group('Sensor Latency & Calibration Logic Tests', () {
    test('1. Baru dipakai (IsWorn == true), dalam jendela 3 detik -> isWithinCalibrationWindow == true', () {
      final transitionTime = DateTime.now();
      final withinWindow = computeIsWithinCalibrationWindow(
        isWatchActive: true,
        wornTransitionTime: transitionTime,
        currentTime: transitionTime.add(const Duration(milliseconds: 1500)),
      );
      expect(withinWindow, isTrue);
    });

    test(
      '2. Setelah lebih dari 3 detik -> isWithinCalibrationWindow == false',
      () {
        final transitionTime = DateTime.now();
        final outsideWindow = computeIsWithinCalibrationWindow(
          isWatchActive: true,
          wornTransitionTime: transitionTime,
          currentTime: transitionTime.add(const Duration(milliseconds: 3100)),
        );
        expect(outsideWindow, isFalse);
      },
    );

    test('3. BPM bernilai 0 atau null saat jam baru dipakai -> isCalibratingHr == true', () {
      final isCalibratingNull = computeIsCalibratingHr(
        isWatchActive: true,
        isWaiting: false,
        isOffline: false,
        parsedHr: null,
        isWithinCalibrationWindow: true,
      );
      expect(isCalibratingNull, isTrue);

      final isCalibratingZero = computeIsCalibratingHr(
        isWatchActive: true,
        isWaiting: false,
        isOffline: false,
        parsedHr: 0.0,
        isWithinCalibrationWindow: false,
      );
      expect(isCalibratingZero, isTrue);
    });

    test('4. Detak jantung valid (> 0) setelah 3 detik kalibrasi selesai -> isCalibratingHr == false (Auto-recovery)', () {
      final isCalibratingLive = computeIsCalibratingHr(
        isWatchActive: true,
        isWaiting: false,
        isOffline: false,
        parsedHr: 78.0,
        isWithinCalibrationWindow: false,
      );
      expect(isCalibratingLive, isFalse);
    });

    test('5. Alat dilepas (isWatchActive == false) -> tidak dalam status kalibrasi aktif', () {
      final isCalibratingNotWorn = computeIsCalibratingHr(
        isWatchActive: false,
        isWaiting: false,
        isOffline: false,
        parsedHr: null,
        isWithinCalibrationWindow: true,
      );
      expect(isCalibratingNotWorn, isFalse);
    });
  });
}
