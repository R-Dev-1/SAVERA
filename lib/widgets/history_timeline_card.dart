import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/history_event.dart';
import '../utils/event_helper.dart';

/// ============================================================================
/// SAVERA - MINI TIMELINE RIWAYAT KEJADIAN (CLEAN & MODULAR)
/// Terhubung secara real-time ke Firebase Realtime Database
/// Fitur:
/// - Persistensi in-memory saat offline / watch inactive (tidak pernah hilang)
/// - Filter kejadian "Hari Ini" saja (DateTime.now())
/// - Sorting descending (terbaru di urutan teratas)
/// - Format waktu 24 jam dengan zona waktu ("14:30 WIB") di bagian paling kiri
/// - Limit 3 baris teratas dengan opsi "Lihat Semua Riwayat >"
/// ============================================================================

class HistoryTimelineCard extends StatefulWidget {
  final DatabaseReference? historyRef;
  final bool isDarkMode;
  final bool isWorn;
  final bool isWatchActive;
  final bool isOffline;
  final bool isLowBattery;
  final int? batteryLevel;
  final Color? cardBg;
  final Color? cardBorder;
  final Color? textHeading;
  final Color? textSecondary;
  final Color? lineDivider;

  const HistoryTimelineCard({
    super.key,
    this.historyRef,
    this.isDarkMode = false,
    this.isWorn = true,
    this.isWatchActive = true,
    this.isOffline = false,
    this.isLowBattery = false,
    this.batteryLevel,
    this.cardBg,
    this.cardBorder,
    this.textHeading,
    this.textSecondary,
    this.lineDivider,
  });

  @override
  State<HistoryTimelineCard> createState() => _HistoryTimelineCardState();
}

class _HistoryTimelineCardState extends State<HistoryTimelineCard> {
  // Static in-memory cache agar data riwayat tidak pernah hilang/reset saat offline/rebuild
  static List<HistoryEvent> _inMemoryHistoryEvents = [];
  Stream<DatabaseEvent>? _stream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didUpdateWidget(covariant HistoryTimelineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.historyRef != oldWidget.historyRef) {
      _initStream();
    }
  }

  void _initStream() {
    final ref =
        widget.historyRef ??
        FirebaseDatabase.instance.ref("Devices/Device_01/History");
    _stream = ref.onValue;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveCardBg =
        widget.cardBg ??
        (widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white);
    final effectiveCardBorder =
        widget.cardBorder ??
        (widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFD6E6FB));
    final effectiveHeading =
        widget.textHeading ??
        (widget.isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF0F1E3D));
    final effectiveSecondary =
        widget.textSecondary ??
        (widget.isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B));
    final effectiveDivider =
        widget.lineDivider ??
        (widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: effectiveCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: effectiveCardBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode
                ? const Color(0x28000000)
                : const Color(0x121E6FEB),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Judul Kartu: Riwayat Kejadian (Hari Ini)
          Text(
            'Riwayat Kejadian (Hari Ini)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: effectiveHeading,
            ),
          ),
          const SizedBox(height: 14),

          // Realtime StreamBuilder dari Firebase dengan In-Memory Persistence
          StreamBuilder<DatabaseEvent>(
            stream: _stream,
            builder: (context, snapshot) {
              // 1. Parsing data dari snapshot jika ada pembaruan data masuk
              final rawValue = snapshot.data?.snapshot.value;
              if (rawValue != null) {
                final List<HistoryEvent> parsedEvents = [];
                if (rawValue is Map) {
                  rawValue.forEach((key, val) {
                    if (val != null) {
                      parsedEvents.add(HistoryEvent.fromFirebase(key, val));
                    }
                  });
                } else if (rawValue is List) {
                  for (int i = 0; i < rawValue.length; i++) {
                    final item = rawValue[i];
                    if (item != null) {
                      parsedEvents.add(HistoryEvent.fromFirebase(i, item));
                    }
                  }
                }
                if (parsedEvents.isNotEmpty) {
                  _inMemoryHistoryEvents = parsedEvents;
                }
              }

              // 2. Persistensi Offline: Jangan pernah mengosongkan riwayat saat offline atau watch inactive
              final List<HistoryEvent> allEvents = List<HistoryEvent>.from(
                _inMemoryHistoryEvents,
              );

              // 3. Filter Waktu: HANYA tampilkan kejadian yang hari, bulan, dan tahunnya sama dengan hari ini (DateTime.now())
              final List<HistoryEvent> todayEvents = allEvents.where((event) {
                return isTimestampToday(event.timestamp) ||
                    (event.dateTime != null &&
                        isTimestampToday(event.dateTime));
              }).toList();

              // 4. Sorting Descending (Kejadian paling baru/terakhir wajib berada di urutan teratas)
              todayEvents.sort((a, b) {
                final dtA = a.dateTime ?? parseTimestamp(a.timestamp);
                final dtB = b.dateTime ?? parseTimestamp(b.timestamp);
                if (dtA != null && dtB != null) {
                  return dtB.compareTo(dtA);
                }
                if (dtA != null) return -1;
                if (dtB != null) return 1;
                return b.id.compareTo(a.id);
              });

              // 5. Peringatan Baterai Lemah: Jika low battery aktif, masukkan ke riwayat hari ini (Anti-Duplikasi)
              if (widget.isLowBattery) {
                final bool hasLowBattery = todayEvents.any(
                  (e) =>
                      e.id == 'state_low_battery' ||
                      e.title.toLowerCase().contains('baterai lemah'),
                );
                if (!hasLowBattery) {
                  final int level = widget.batteryLevel ?? 15;
                  todayEvents.insert(
                    0,
                    HistoryEvent(
                      id: 'state_low_battery',
                      title: 'Baterai Lemah • Baterai tersisa $level%',
                      timestamp: DateTime.now().millisecondsSinceEpoch,
                      dateTime: DateTime.now(),
                    ),
                  );
                }
              }

              // 6. Status Pasif: Jika jam sedang dilepas (!isWorn), pastikan entri teratas adalah "Alat Dilepas"
              if (!widget.isWorn) {
                final bool hasTopPassive =
                    todayEvents.isNotEmpty &&
                    todayEvents.first.title.toLowerCase().contains(
                      'alat dilepas',
                    );
                if (!hasTopPassive) {
                  todayEvents.insert(
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

              // Loading State HANYA jika memori benar-benar masih kosong saat pertama kali buka
              if (snapshot.connectionState == ConnectionState.waiting &&
                  todayEvents.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                );
              }

              // Jika hari ini belum ada riwayat sama sekali
              if (todayEvents.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18.0),
                  child: Center(
                    child: Text(
                      'Belum ada riwayat hari ini',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: effectiveSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }

              // 6. LIMIT data: maksimal hanya 3 baris teratas untuk widget ringkas di beranda
              final displayedEvents = todayEvents.take(3).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Daftar baris mini timeline
                  for (int i = 0; i < displayedEvents.length; i++)
                    _buildTimelineRow(
                      event: displayedEvents[i],
                      isLast: i == displayedEvents.length - 1,
                      textHeading: effectiveHeading,
                      textSecondary: effectiveSecondary,
                      lineDivider: effectiveDivider,
                    ),

                  const SizedBox(height: 6),

                  // Tombol "Lihat Semua Riwayat >" di bagian paling bawah
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        _showAllHistorySheet(
                          context: context,
                          events: todayEvents,
                          isDarkMode: widget.isDarkMode,
                          cardBg: effectiveCardBg,
                          cardBorder: effectiveCardBorder,
                          textHeading: effectiveHeading,
                          textSecondary: effectiveSecondary,
                          lineDivider: effectiveDivider,
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        'Lihat Semua Riwayat >',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: widget.isDarkMode
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF1E6FEB),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Komponen baris mini-timeline tunggal
  /// Waktu kejadian diletakkan di bagian paling kiri dengan format 24 jam + zona waktu ("14:30 WIB")
  Widget _buildTimelineRow({
    required HistoryEvent event,
    required bool isLast,
    required Color textHeading,
    required Color textSecondary,
    required Color lineDivider,
  }) {
    final dotColor = getEventStatusColor(event.title);
    final timeFormatted = formatEventTime24(event.timestamp);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Waktu Kejadian di Bagian Paling Kiri (Format 24 jam dengan zona waktu, misal: "14:30 WIB")
          SizedBox(
            width: 68,
            child: Padding(
              padding: const EdgeInsets.only(top: 1.0),
              child: Text(
                timeFormatted,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 2. Kolom Garis & Dot Indikator Warna
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: lineDivider)),
            ],
          ),
          const SizedBox(width: 10),

          // 3. Teks Kejadian (diletakkan rapi di sebelah kanan setelah waktu dan dot)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 2.0 : 16.0),
              child: Text(
                event.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textHeading,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom Sheet untuk menampilkan seluruh riwayat kejadian secara lengkap
  void _showAllHistorySheet({
    required BuildContext context,
    required List<HistoryEvent> events,
    required bool isDarkMode,
    required Color cardBg,
    required Color cardBorder,
    required Color textHeading,
    required Color textSecondary,
    required Color lineDivider,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header Modal
                  Row(
                    children: [
                      Text(
                        'Riwayat Kejadian (Hari Ini)',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: textHeading,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: textSecondary, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Daftar Lengkap Riwayat Hari Ini
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        return _buildTimelineRow(
                          event: events[index],
                          isLast: index == events.length - 1,
                          textHeading: textHeading,
                          textSecondary: textSecondary,
                          lineDivider: lineDivider,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
