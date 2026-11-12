import '../utils/event_helper.dart';

/// Model data untuk satu entri catatan riwayat medis / kejadian pada SAVERA.
class HistoryEvent {
  final String id;
  final String title;
  final dynamic timestamp;
  final DateTime? dateTime;

  const HistoryEvent({
    required this.id,
    required this.title,
    required this.timestamp,
    this.dateTime,
  });

  /// Factory untuk mem-parsing data dari Firebase Realtime Database
  factory HistoryEvent.fromFirebase(dynamic key, dynamic value) {
    final String id = key?.toString() ?? '';
    String title = 'Status Sistem';
    dynamic timestamp;

    if (value is Map) {
      final map = Map<dynamic, dynamic>.from(value);
      title =
          (map['title'] ??
                  map['event'] ??
                  map['status'] ??
                  map['message'] ??
                  map['keterangan'] ??
                  map['name'] ??
                  'Status Sistem')
              .toString();

      timestamp =
          map['timestamp'] ??
          map['time'] ??
          map['date'] ??
          map['created_at'] ??
          map['waktu'] ??
          key;
    } else if (value is String) {
      title = value;
      timestamp = key;
    } else {
      title = value?.toString() ?? 'Status Sistem';
      timestamp = key;
    }

    final parsedDt = parseTimestamp(timestamp);

    return HistoryEvent(
      id: id,
      title: title,
      timestamp: timestamp,
      dateTime: parsedDt,
    );
  }
}
