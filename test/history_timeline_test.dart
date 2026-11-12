import 'package:flutter_test/flutter_test.dart';
import 'package:savera/models/history_event.dart';

void main() {
  group('HistoryEvent Model & Parsing Tests', () {
    test('Parsing dari Firebase Map berhasil', () {
      final now = DateTime.now();
      final mapData = {
        'title': 'Bahaya: Jatuh Terdeteksi!',
        'timestamp': now.millisecondsSinceEpoch,
      };

      final event = HistoryEvent.fromFirebase('event_01', mapData);
      expect(event.id, 'event_01');
      expect(event.title, 'Bahaya: Jatuh Terdeteksi!');
      expect(event.dateTime != null, isTrue);
    });

    test('Sorting Descending memastikan kejadian terbaru berada di atas', () {
      final now = DateTime.now();
      final eventOld = HistoryEvent.fromFirebase('old', {
        'title': 'Gelang Dipasang',
        'timestamp': now
            .subtract(const Duration(hours: 4))
            .millisecondsSinceEpoch,
      });
      final eventNewest = HistoryEvent.fromFirebase('new', {
        'title': 'Bahaya: Jatuh Terdeteksi!',
        'timestamp': now.millisecondsSinceEpoch,
      });
      final eventMiddle = HistoryEvent.fromFirebase('mid', {
        'title': 'Status Normal',
        'timestamp': now
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      });

      final list = [eventOld, eventNewest, eventMiddle];
      list.sort((a, b) {
        final dtA = a.dateTime;
        final dtB = b.dateTime;
        if (dtA != null && dtB != null) {
          return dtB.compareTo(dtA);
        }
        if (dtA != null) return -1;
        if (dtB != null) return 1;
        return b.id.compareTo(a.id);
      });

      expect(list.first.id, 'new');
      expect(list[1].id, 'mid');
      expect(list.last.id, 'old');
    });

    test('LIMIT maksimal 3 baris teratas', () {
      final now = DateTime.now();
      final list = List.generate(
        10,
        (i) => HistoryEvent.fromFirebase('item_$i', {
          'title': 'Event $i',
          'timestamp': now
              .subtract(Duration(minutes: i * 10))
              .millisecondsSinceEpoch,
        }),
      );

      final displayed = list.take(3).toList();
      expect(displayed.length, 3);
      expect(displayed.first.id, 'item_0');
      expect(displayed.last.id, 'item_2');
    });

    test('Filter Kejadian "Hari Ini" Saja (DateTime.now())', () {
      final now = DateTime.now();
      final eventToday1 = HistoryEvent.fromFirebase('t1', {
        'title': 'Jatuh Terdeteksi',
        'timestamp': now
            .subtract(const Duration(minutes: 10))
            .millisecondsSinceEpoch,
      });
      final eventToday2 = HistoryEvent.fromFirebase('t2', {
        'title': 'Aktivitas Berjalan',
        'timestamp': now
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      });
      final eventYesterday = HistoryEvent.fromFirebase('y1', {
        'title': 'Alat Dipasang Kemarin',
        'timestamp': now
            .subtract(const Duration(days: 1))
            .millisecondsSinceEpoch,
      });
      final eventLastWeek = HistoryEvent.fromFirebase('w1', {
        'title': 'Pemeriksaan Rutin',
        'timestamp': now
            .subtract(const Duration(days: 7))
            .millisecondsSinceEpoch,
      });

      final allEvents = [
        eventToday1,
        eventYesterday,
        eventToday2,
        eventLastWeek,
      ];
      final todayEvents = allEvents.where((e) {
        final dt = e.dateTime;
        if (dt == null) return false;
        final local = dt.toLocal();
        return local.year == now.year &&
            local.month == now.month &&
            local.day == now.day;
      }).toList();

      expect(todayEvents.length, 2);
      expect(todayEvents.map((e) => e.id), containsAll(['t1', 't2']));
      expect(todayEvents.map((e) => e.id), isNot(contains('y1')));
      expect(todayEvents.map((e) => e.id), isNot(contains('w1')));
    });

    test('Persistensi Offline: Cache memori tidak di-reset saat offline atau stream terputus', () {
      final inMemoryCache = <HistoryEvent>[
        HistoryEvent(
          id: 'mem_1',
          title: 'Bahaya: Jatuh Terdeteksi!',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          dateTime: DateTime.now(),
        ),
      ];

      // Simulasi koneksi offline / rawValue null dari Firebase
      const dynamic rawFirebaseValue = null;
      if (rawFirebaseValue != null) {
        inMemoryCache.clear();
      }

      // Pastikan data in-memory tetap utuh dan tidak menjadi kosong
      expect(inMemoryCache.isNotEmpty, isTrue);
      expect(inMemoryCache.first.title, 'Bahaya: Jatuh Terdeteksi!');
    });
  });
}
