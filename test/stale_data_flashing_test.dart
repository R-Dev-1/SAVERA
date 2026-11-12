import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savera/models/history_event.dart';
import 'package:savera/utils/event_helper.dart';

bool computeIsWatchActive({
  required bool isWaiting,
  required dynamic rawWornValue,
  bool isManualOverride = false,
  bool manualWatchOff = false,
}) {
  final bool isWornConfirmed =
      (rawWornValue == true) ||
      (rawWornValue == 1) ||
      (rawWornValue?.toString().trim().toLowerCase() == 'true');

  final bool isWorn = isManualOverride
      ? !manualWatchOff
      : (isWaiting ? false : isWornConfirmed);

  return (isWorn == true);
}

bool computeIsFallen({
  required bool isWaiting,
  required bool isOffline,
  required bool isWatchActive,
  required dynamic rawFallenValue,
}) {
  final bool rawIsFallen =
      (rawFallenValue == true) ||
      (rawFallenValue == 1) ||
      (rawFallenValue?.toString().trim().toLowerCase() == 'true');

  // Aturan Utama (Bypass Mutlak):
  // Jika isWatchActive == false, isFallen DIPAKSA 100% false!
  return (isWatchActive && !isWaiting && !isOffline) ? rawIsFallen : false;
}

void main() {
  group('Stale Data Flashing & Strict Bypass Logic Tests', () {
    test('Aturan Utama 1: isWatchActive false saat IsWorn null/kosong membypass 100% isFallen', () {
      final bool isWatchActive = computeIsWatchActive(
        isWaiting: false,
        rawWornValue: null,
      );
      expect(isWatchActive, isFalse);

      final bool isFallen = computeIsFallen(
        isWaiting: false,
        isOffline: false,
        isWatchActive: isWatchActive,
        rawFallenValue: true,
      );
      expect(isFallen, isFalse);
    });

    test('Aturan Utama 2: isWatchActive false saat IsWorn == false membypass isFallen lama di Firebase', () {
      final bool isWatchActive = computeIsWatchActive(
        isWaiting: false,
        rawWornValue: false,
      );
      expect(isWatchActive, isFalse);

      final bool isFallen = computeIsFallen(
        isWaiting: false,
        isOffline: false,
        isWatchActive: isWatchActive,
        rawFallenValue: true,
      );
      expect(isFallen, isFalse);
    });

    test('Aturan Utama 3: isWatchActive false saat string "false" atau 0', () {
      final bool isWatchActiveStr = computeIsWatchActive(
        isWaiting: false,
        rawWornValue: 'false',
      );
      expect(isWatchActiveStr, isFalse);

      final bool isWatchActiveZero = computeIsWatchActive(
        isWaiting: false,
        rawWornValue: 0,
      );
      expect(isWatchActiveZero, isFalse);
    });

    test(
      'Fase 1: Initial Waiting State membypass isWatchActive dan isFallen',
      () {
        final bool isWatchActive = computeIsWatchActive(
          isWaiting: true,
          rawWornValue: true,
        );
        expect(isWatchActive, isFalse);

        final bool isFallen = computeIsFallen(
          isWaiting: true,
          isOffline: false,
          isWatchActive: isWatchActive,
          rawFallenValue: true,
        );
        expect(isFallen, isFalse);
      },
    );

    test('Alat Offline: isOffline == true membypass isFallen meski IsWorn dan IsFallen true dari data lama', () {
      final bool isWatchActive = computeIsWatchActive(
        isWaiting: false,
        rawWornValue: true,
      );
      expect(isWatchActive, isTrue);

      final bool isFallen = computeIsFallen(
        isWaiting: false,
        isOffline: true,
        isWatchActive: isWatchActive,
        rawFallenValue: true,
      );
      expect(isFallen, isFalse);
    });

    test('Kondisi Aktif Nyata: isWatchActive == true, online, dan rawFallen true memicu isFallen true', () {
      final bool isWatchActive = computeIsWatchActive(
        isWaiting: false,
        rawWornValue: true,
      );
      expect(isWatchActive, isTrue);

      final bool isFallen = computeIsFallen(
        isWaiting: false,
        isOffline: false,
        isWatchActive: isWatchActive,
        rawFallenValue: true,
      );
      expect(isFallen, isTrue);
    });

    test('Fase 3: Entri teratas riwayat adalah Alat Dilepas jika isWatchActive == false', () {
      final events = <HistoryEvent>[
        HistoryEvent(
          id: '1',
          title: 'Sedang Berjalan',
          timestamp: DateTime.now()
              .subtract(const Duration(minutes: 5))
              .millisecondsSinceEpoch,
          dateTime: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ];

      const bool isWatchActive = false;
      if (!isWatchActive) {
        final bool hasTopPassive =
            events.isNotEmpty &&
            events.first.title.toLowerCase().contains('alat dilepas');
        if (!hasTopPassive) {
          events.insert(
            0,
            HistoryEvent(
              id: 'state_alat_dilepas',
              title: 'Alat Dilepas',
              timestamp: DateTime.now().millisecondsSinceEpoch,
              dateTime: DateTime.now(),
            ),
          );
        }
      }

      expect(events.first.title, 'Alat Dilepas');
      expect(getEventStatusColor(events.first.title), Colors.grey);
    });
  });
}
