import 'package:flutter_test/flutter_test.dart';
import 'package:savera/pages/home_page.dart';

void main() {
  group('Pulse Trend Y-Axis Auto-Scaling Tests', () {
    test('1. Default Bounds: Data BPM di rentang 60 - 120 -> minY = 60, maxY = 120', () {
      final bounds = computePulseTrendYBounds(
        heartRateData: [68, 74, 78, 73, 70, 75, 82, 80, 103, 88, 79, 78],
        currentBpm: '78',
        isOff: false,
        isCalibratingHr: false,
      );

      expect(bounds.minY, equals(60.0));
      expect(bounds.maxY, equals(120.0));
    });

    test('2. Dynamic Upper Bound: Nilai BPM tertinggi 135 melewati 120 -> maxY = 145 (maxBpm + 10)', () {
      final bounds = computePulseTrendYBounds(
        heartRateData: [70, 85, 110, 125, 135],
        currentBpm: '135',
        isOff: false,
        isCalibratingHr: false,
      );

      expect(bounds.minY, equals(60.0));
      expect(bounds.maxY, equals(145.0));
    });

    test('3. Dynamic Lower Bound: Nilai BPM terendah 50 di bawah 60 -> minY = 40 (minBpm - 10)', () {
      final bounds = computePulseTrendYBounds(
        heartRateData: [55, 52, 50, 65, 75],
        currentBpm: '50',
        isOff: false,
        isCalibratingHr: false,
      );

      expect(bounds.minY, equals(40.0));
      expect(bounds.maxY, equals(120.0));
    });

    test('4. Both Bounds Exceeded: BPM terendah 45 dan tertinggi 140 -> minY = 35, maxY = 150', () {
      final bounds = computePulseTrendYBounds(
        heartRateData: [45, 80, 95, 140],
        currentBpm: '140',
        isOff: false,
        isCalibratingHr: false,
      );

      expect(bounds.minY, equals(35.0));
      expect(bounds.maxY, equals(150.0));
    });

    test('5. CurrentBpm baru masuk melewati batas (130 BPM) saat history masih normal -> maxY = 140', () {
      final bounds = computePulseTrendYBounds(
        heartRateData: [70, 75, 80],
        currentBpm: '130',
        isOff: false,
        isCalibratingHr: false,
      );

      expect(bounds.minY, equals(60.0));
      expect(bounds.maxY, equals(140.0));
    });

    test('6. Mode Pasif / Terputus / Alat Dilepas (isOff == true) -> kembali ke default 60 dan 120', () {
      final bounds = computePulseTrendYBounds(
        heartRateData: [40, 145],
        currentBpm: '--',
        isOff: true,
        isCalibratingHr: false,
      );

      expect(bounds.minY, equals(60.0));
      expect(bounds.maxY, equals(120.0));
    });

    test('7. Mode Kalibrasi (isCalibratingHr == true) -> kembali ke default 60 dan 120', () {
      final bounds = computePulseTrendYBounds(
        heartRateData: [35, 150],
        currentBpm: '--',
        isOff: false,
        isCalibratingHr: true,
      );

      expect(bounds.minY, equals(60.0));
      expect(bounds.maxY, equals(120.0));
    });
  });
}
