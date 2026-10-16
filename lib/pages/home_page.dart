import 'dart:async'; // Tambahkan ini untuk menggunakan Timer
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

// --- Variabel Warna ---
final Color navy = Colors.blue[900]!;
final Color blue = Colors.blue[700]!;
final Color sky = Colors.lightBlue[400]!;
final Color muted = Colors.grey;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("Devices/Device_01");
  
  late StreamSubscription _subscription;
  Timer? _watchdogTimer; // Timer internal untuk mendeteksi alat mati
  
  bool _isLoading = true;
  bool _isOffline = true; // Anggap mati sampai ada "detak jantung" (data) pertama
  Map<dynamic, dynamic> _deviceData = {};

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  // 1. FUNGSI UNTUK MENDENGARKAN DATABASE (Menggantikan StreamBuilder)
  void _startListening() {
    _subscription = _dbRef.onValue.listen((event) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _isOffline = false; // Begitu data masuk, alat dipastikan ONLINE!
        
        if (event.snapshot.value != null) {
          _deviceData = event.snapshot.value as Map<dynamic, dynamic>;
        }
      });

      // 2. RESET TIMER SETIAP ADA DATA MASUK
      _resetWatchdogTimer();
    });
  }

  // 3. FUNGSI PENDETEKSI ALAT MATI (Watchdog)
  void _resetWatchdogTimer() {
    _watchdogTimer?.cancel(); // Hapus hitung mundur yang lama
    
    // Mulai hitung mundur 15 detik yang baru.
    // Jika ESP32 tiba-tiba mati/terputus, fungsi ini tidak akan di-reset lagi.
    // Akibatnya, timer akan meledak di detik ke-15 dan mengubah layar jadi Merah!
    _watchdogTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) {
        setState(() {
          _isOffline = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel(); // Matikan langganan database saat keluar aplikasi
    _watchdogTimer?.cancel(); // Bersihkan timer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: blue)));
    }

    // Ambil data dari map dengan aman
    final vitalSigns = _deviceData['VitalSigns'] ?? {};
    final deviceStatus = _deviceData['DeviceStatus'] ?? {};
    final fallDetection = _deviceData['FallDetection'] ?? {};
    
    final bool isWorn = deviceStatus['IsWorn'] ?? false; 
    final String? lastUpdatedStr = deviceStatus['LastUpdated'];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // HEADER CARD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardStyle(),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.monitor_heart, color: blue),
                            const SizedBox(width: 8),
                            Text('SAVERA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: navy)),
                          ],
                        ),
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Pak Budi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: navy)),
                                Text('72 Tahun', style: TextStyle(fontSize: 12, color: muted)),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: [sky, blue]),
                              ),
                              child: const Center(child: Text('PB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            )
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (_isOffline)
                          _buildChip('TERPUTUS', Colors.red)
                        else
                          _buildChip(isWorn ? 'TERHUBUNG' : 'DILEPAS', isWorn ? sky : muted),
                        
                        const SizedBox(width: 8),
                        
                        _buildChip('Baterai ${_isOffline ? '--' : (deviceStatus['Battery'] ?? '--')}%', null),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (lastUpdatedStr != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Icon(Icons.access_time, size: 12, color: _isOffline ? Colors.red : muted),
                          const SizedBox(width: 4),
                          Text('Update Terakhir: $lastUpdatedStr', style: TextStyle(fontSize: 11, color: _isOffline ? Colors.red : muted)),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // BANNER STATUS
              _buildStatusBanner(_isOffline, isWorn, fallDetection),
              
              const SizedBox(height: 16),

              // KARTU TANDA VITAL
              Row(
                children: [
                  Expanded(
                    child: _buildVitalCard(
                      'Denyut Nadi', Icons.favorite, blue,
                      (_isOffline || !isWorn) ? '--' : '${vitalSigns['HeartRate'] ?? '--'}', 
                      'BPM', 
                      (!_isOffline && isWorn),
                      _isOffline
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildVitalCard(
                      'Saturasi Oksigen', Icons.water_drop, sky,
                      (_isOffline || !isWorn) ? '--' : '${vitalSigns['SpO2'] ?? '--'}', 
                      '%', 
                      (!_isOffline && isWorn),
                      _isOffline
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // KARTU LOKASI
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardStyle(),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: blue, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lokasi Pemantauan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: navy)),
                          Text('Rumah - Jl. Merdeka No. 12, Bandung', style: TextStyle(fontSize: 13, color: muted)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // WIDGET-WIDGET BANTUAN
  // ==========================================

  Widget _buildStatusBanner(bool isOffline, bool isWorn, Map fallDetection) {
    if (isOffline) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red[300]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.red, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PERANGKAT TERPUTUS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.red[900])),
                  const Text('Alat mati atau kehilangan sinyal internet. Pemantauan terhenti.', style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          ],
        ),
      );
    }

    if (!isWorn) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: Row(
          children: [
            Icon(Icons.pause_circle_outline, color: Colors.grey[700], size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('STANDBY: JAM DILEPAS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: navy)),
                  Text('Sensor dan deteksi jatuh sedang dijeda sementara.', style: TextStyle(fontSize: 13, color: muted)),
                ],
              ),
            )
          ],
        ),
      );
    }

    bool isFallen = fallDetection['IsFallen'] == true;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isFallen ? Colors.red[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isFallen ? Colors.red[200]! : Colors.green[300]!),
      ),
      child: Row(
        children: [
          Icon(
            isFallen ? Icons.warning : Icons.shield, 
            color: isFallen ? Colors.red : Colors.green[700], 
            size: 40
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFallen ? 'BAHAYA TERDETEKSI!' : 'AKTIVITAS NORMAL / SAFE', 
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isFallen ? Colors.red : navy)
                ),
                Text(
                  fallDetection['StatusText'] ?? 'Tidak ada jatuh terdeteksi', 
                  style: const TextStyle(fontSize: 13, color: Colors.grey)
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildVitalCard(String title, IconData icon, Color iconColor, String value, String unit, bool active, bool isOffline) {
    String badgeText = 'Normal';
    if (isOffline) {
       badgeText = 'Alat Mati';
    } else if (!active) {
       badgeText = 'Sensor Dilepas';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardStyle(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: active ? iconColor : muted, size: 20),
              const SizedBox(width: 8),
              Flexible(child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: active ? muted : muted))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: active ? navy : muted, height: 1.0, letterSpacing: -1)),
              const SizedBox(width: 4),
              Text(unit, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: active ? muted : muted)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: active ? Colors.transparent : Colors.white,
              border: Border.all(color: active ? Colors.transparent : Colors.grey[300]!),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badgeText,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isOffline ? Colors.red : (active ? muted : navy)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color? dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: navy)),
        ],
      ),
    );
  }

  BoxDecoration _cardStyle() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.blue[100]!),
      boxShadow: [
        BoxShadow(color: blue, blurRadius: 10, offset: const Offset(0, 4)),
      ],
    );
  }
}