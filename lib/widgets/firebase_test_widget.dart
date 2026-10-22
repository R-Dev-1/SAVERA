import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

/// Modal / BottomSheet pembantu untuk menampilkan dialog uji coba
void showFirebaseTestModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const FirebaseRealtimeTestSheet(),
  );
}

/// Widget uji coba membaca data real-time dari Firebase Realtime Database
class FirebaseRealtimeTestSheet extends StatefulWidget {
  const FirebaseRealtimeTestSheet({super.key});

  @override
  State<FirebaseRealtimeTestSheet> createState() => _FirebaseRealtimeTestSheetState();
}

class _FirebaseRealtimeTestSheetState extends State<FirebaseRealtimeTestSheet> {
  final DatabaseReference _testRef = FirebaseDatabase.instance.ref('test_connection');
  bool _isSending = false;
  String? _statusMessage;

  // Palet Warna SAVERA
  static const Color kNavy = Color(0xFF0B2A6E);
  static const Color kBlue = Color(0xFF1E6FEB);
  static const Color kL1 = Color(0xFFF0F7FF);
  static const Color kLine = Color(0xFFD6E6FB);
  static const Color kMuted = Color(0xFF64748B);

  Future<void> _sendPingTest() async {
    setState(() {
      _isSending = true;
      _statusMessage = null;
    });

    try {
      final now = DateTime.now();
      await _testRef.update({
        'status': 'online',
        'message': 'Uji coba koneksi berhasil!',
        'updated_at': now.toIso8601String(),
        'test_id': 'TEST-${now.millisecondsSinceEpoch.toString().substring(7)}',
      });
      if (mounted) {
        setState(() {
          _statusMessage = '✅ Berhasil mengirim data uji ke Firebase!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = '❌ Gagal menulis: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _sendSampleVitalData() async {
    setState(() {
      _isSending = true;
      _statusMessage = null;
    });

    try {
      final randomBpm = 70 + Random().nextInt(20);
      await FirebaseDatabase.instance.ref('sensors').update({
        'bpm': randomBpm,
        'fall_detected': false,
        'battery': 95,
        'timestamp': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        setState(() {
          _statusMessage = '✅ Berhasil update sensor/bpm ($randomBpm BPM) ke Firebase!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = '❌ Gagal update sensor: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: kLine,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF3FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.cloud_sync_rounded, color: kBlue, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uji Koneksi Real-time Firebase',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kNavy,
                      ),
                    ),
                    Text(
                      'Membaca stream node /test_connection',
                      style: TextStyle(
                        fontSize: 12,
                        color: kMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: kMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Real-time Stream Viewer
          StreamBuilder<DatabaseEvent>(
            stream: _testRef.onValue,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Koneksi Realtime Database Error',
                            style: TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${snapshot.error}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '💡 Catatan: Jika error bertuliskan "Permission Denied", pastikan Security Rules di Firebase Console telah diset .read dan .write: true untuk tahap pengujian.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF7F1D1D)),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kL1,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kLine),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kBlue),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Menghubungkan ke stream Firebase...',
                        style: TextStyle(fontSize: 13, color: kNavy),
                      ),
                    ],
                  ),
                );
              }

              final value = snapshot.data?.snapshot.value;
              final hasData = value != null;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: hasData ? const Color(0xFFF0FDF4) : kL1,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasData ? const Color(0xFF86EFAC) : kLine,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasData ? const Color(0xFF16A34A) : Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          hasData ? 'Terhubung (Live Real-time)' : 'Menunggu Data (Node Kosong)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: hasData ? const Color(0xFF166534) : Colors.orange[800],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          DateTime.now().toLocal().toString().split('.').first.split(' ').last,
                          style: const TextStyle(fontSize: 11, color: kMuted),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Text(
                      'Snapshot Data:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        hasData ? value.toString() : '(Belum ada data di path /test_connection)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          if (_statusMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _statusMessage!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _sendPingTest,
                  icon: _isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Kirim Ping Test'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSending ? null : _sendSampleVitalData,
                  icon: const Icon(Icons.favorite_rounded, size: 16, color: Color(0xFFEF4444)),
                  label: const Text('Simulasi BPM'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kNavy,
                    side: const BorderSide(color: kLine),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
