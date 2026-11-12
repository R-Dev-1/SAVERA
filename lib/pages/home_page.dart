import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/patient_profile.dart';
import '../utils/event_helper.dart';
import 'profile_page.dart';
import '../widgets/animated_savera_text.dart';
import '../widgets/history_timeline_card.dart';

/// ============================================================================
/// SAVERA - BERANDA (DASHBOARD)
/// Streaming langsung dari ESP32 via Firebase Realtime Database ("Devices/Device_01")
/// Dilengkapi Watchdog Timer 15 Detik untuk deteksi offline / alat terputus
/// ============================================================================

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Referensi Node Firebase Realtime Database untuk ESP32
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref(
    "Devices/Device_01",
  );

  StreamSubscription<DatabaseEvent>? _subscription;
  Timer? _watchdogTimer; // Timer internal untuk mendeteksi alat mati / offline
  Timer? _loadingTimeout;

  bool _isLoading = true;
  bool _isOffline = true; // Default offline sampai ada sinyal / data masuk
  Map<dynamic, dynamic> _deviceData = {};

  // Pelacakan status transisi pemasangan jam (IsWorn == false -> true) untuk sensor calibration
  bool _previousIsWorn = false;
  DateTime? _wornTransitionTime;
  Timer? _calibrationTimer;

  // Riwayat denyut nadi (BPM) untuk visualisasi kurva real-time
  final List<double> _heartRateHistory = [
    68,
    74,
    78,
    73,
    70,
    75,
    82,
    80,
    103,
    88,
    79,
    78,
  ];

  // Fitur Mode Gelap (Dark Mode)
  bool _isDarkMode = false;

  // Getter token tema dinamis (Mode Terang vs Mode Gelap)
  Color get bgPage => _isDarkMode ? const Color(0xFF0F172A) : Colors.white;
  Color get cardBg => _isDarkMode ? const Color(0xFF1E293B) : Colors.white;
  Color get cardBorder =>
      _isDarkMode ? const Color(0xFF334155) : const Color(0xFFD6E6FB);
  Color get textHeading =>
      _isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF0F1E3D);
  Color get textSecondary =>
      _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get panelBg =>
      _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get panelBorder =>
      _isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get lineDivider =>
      _isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

  // Simulasi manual override (untuk kemudahan pengujian antarmuka)
  bool _isManualOverride = false;
  bool _manualWatchOff = false;

  static const Color kNavy = Color(0xFF0B2A6E);
  static const Color kBlue = Color(0xFF1E6FEB);
  static const Color kSky = Color(0xFF0EA5E9);
  static const Color kBody = Color(0xFF334155);

  @override
  void initState() {
    super.initState();
    _startListening();

    // Batasi loading awal maksimal 2.5 detik agar pengguna tidak menunggu terlalu lama
    _loadingTimeout = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _isOffline = true;
        });
      }
    });
  }

  // 1. FUNGSI UNTUK MENDENGARKAN DATABASE (Stream Listener)
  void _startListening() {
    _subscription = _dbRef.onValue.listen(
      (DatabaseEvent event) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;

          if (event.snapshot.exists &&
              event.snapshot.value != null &&
              event.snapshot.value is Map) {
            final dataMap = Map<dynamic, dynamic>.from(
              event.snapshot.value as Map,
            );

            // Cek timestamp Heartbeat dari ESP32 untuk mendeteksi apakah data benar-benar live
            final devStatus = (dataMap['DeviceStatus'] is Map)
                ? dataMap['DeviceStatus'] as Map<dynamic, dynamic>
                : ((dataMap['deviceStatus'] is Map)
                      ? dataMap['deviceStatus'] as Map<dynamic, dynamic>
                      : {});

            final hbRaw = devStatus['Heartbeat'] ?? devStatus['heartbeat'];
            bool isLiveOnline = true;
            if (hbRaw != null) {
              final DateTime? hbDate = parseTimestamp(hbRaw);
              if (hbDate != null) {
                final int diffMs = DateTime.now()
                    .difference(hbDate)
                    .inMilliseconds
                    .abs();
                // Jika heartbeat terakhir sudah lebih dari 20 detik lalu, alat sudah MATI/OFFLINE!
                if (diffMs > 20000) {
                  isLiveOnline = false;
                }
              }
            }

            _isOffline = !isLiveOnline;
            _isManualOverride =
                false; // Sinkronkan kembali dengan data sensor nyata
            _deviceData = dataMap;

            // Pelacakan status transisi pemasangan jam (IsWorn == false -> true) untuk sensor calibration
            final dynamic rawW =
                devStatus['IsWorn'] ??
                devStatus['isWorn'] ??
                dataMap['IsWorn'] ??
                dataMap['isWorn'] ??
                dataMap['worn'];
            final bool currentWorn =
                (rawW == true) ||
                (rawW == 1) ||
                (rawW?.toString().trim().toLowerCase() == 'true');

            if (currentWorn && !_previousIsWorn) {
              _wornTransitionTime = DateTime.now();
              _calibrationTimer?.cancel();
              _calibrationTimer = Timer(const Duration(milliseconds: 3000), () {
                if (mounted) setState(() {});
              });
            } else if (!currentWorn) {
              _previousIsWorn = false;
              _wornTransitionTime = null;
              _calibrationTimer?.cancel();
            }
            _previousIsWorn = currentWorn;

            // Ekstraksi denyut nadi (HeartRate) secara live untuk memperbarui grafik garis
            final vs = (_deviceData['VitalSigns'] is Map)
                ? _deviceData['VitalSigns'] as Map<dynamic, dynamic>
                : ((_deviceData['vitalSigns'] is Map)
                      ? _deviceData['vitalSigns'] as Map<dynamic, dynamic>
                      : {});
            final hrRaw = vs['HeartRate'] ?? vs['heartRate'];
            if (hrRaw != null) {
              final double? parsedHr = double.tryParse(
                hrRaw.toString().replaceAll('BPM', '').trim(),
              );
              if (parsedHr != null && parsedHr > 0) {
                _heartRateHistory.add(parsedHr);
                // Batasi maksimal 20 data point terakhir agar grafik tetap proporsional & dinamis
                if (_heartRateHistory.length > 20) {
                  _heartRateHistory.removeAt(0);
                }
              }
            }
          } else {
            // Jika node null atau snapshot kosong, status menjadi offline/terputus
            _isOffline = true;
            _deviceData = {};
          }
        });

        // 2. RESET TIMER SETIAP ADA DATA MASUK
        if (!_isOffline) {
          _resetWatchdogTimer();
        } else {
          _watchdogTimer?.cancel();
        }
      },
      onError: (Object error) {
        debugPrint('[Firebase RTDB Error]: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isOffline = true;
            _deviceData = {};
          });
        }
      },
    );
  }

  // 3. FUNGSI PENDETEKSI ALAT MATI (Watchdog 15 Detik)
  void _resetWatchdogTimer() {
    _watchdogTimer?.cancel(); // Hapus hitung mundur yang lama

    // Mulai hitung mundur 15 detik yang baru.
    // Jika ESP32 tiba-tiba mati/terputus, fungsi ini tidak akan di-reset lagi.
    // Akibatnya timer akan meledak di detik ke-15 dan mengubah layar ke mode Terputus!
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
    _calibrationTimer?.cancel();
    _loadingTimeout?.cancel();
    _subscription?.cancel(); // Matikan langganan database saat keluar layar
    _watchdogTimer?.cancel(); // Bersihkan timer
    super.dispose();
  }

  void _openProfile() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfilePage(isSetup: false),
      ),
    );
    if (updated == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPage,
      body: StreamBuilder<DatabaseEvent>(
        stream: _dbRef.onValue,
        builder: (context, snapshot) {
          // FASE 1: Initial Loading State (Awal Buka Aplikasi)
          // Menunggu koneksi awal Firebase atau saat snapshot masih memuat
          final bool isWaiting =
              _isLoading ||
              (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) ||
              _deviceData.isEmpty;

          // Parsing data secara aman dari snapshot atau fallback ke _deviceData
          Map<dynamic, dynamic> data = _deviceData;
          if (snapshot.hasData && snapshot.data?.snapshot.value is Map) {
            data = Map<dynamic, dynamic>.from(
              snapshot.data!.snapshot.value as Map,
            );
          }

          final vitalSigns = (data['VitalSigns'] is Map)
              ? data['VitalSigns'] as Map<dynamic, dynamic>
              : ((data['vitalSigns'] is Map)
                    ? data['vitalSigns'] as Map<dynamic, dynamic>
                    : {});
          final deviceStatus = (data['DeviceStatus'] is Map)
              ? data['DeviceStatus'] as Map<dynamic, dynamic>
              : ((data['deviceStatus'] is Map)
                    ? data['deviceStatus'] as Map<dynamic, dynamic>
                    : {});
          final fallDetection = (data['FallDetection'] is Map)
              ? data['FallDetection'] as Map<dynamic, dynamic>
              : ((data['fallDetection'] is Map)
                    ? data['fallDetection'] as Map<dynamic, dynamic>
                    : {});
          final activityData = (data['Activity'] is Map)
              ? data['Activity'] as Map<dynamic, dynamic>
              : ((data['activity'] is Map)
                    ? data['activity'] as Map<dynamic, dynamic>
                    : {});
          final String? activityType =
              activityData['Type']?.toString() ??
              activityData['type']?.toString();

          // FASE 2: Prioritas Pengecekan Alat Dilepas (IsWorn == false atau null)
          // Cek boolean IsWorn secara null-safe PERTAMA KALI sebelum mengecek data akselerometer/jatuh.
          final dynamic rawWornValue =
              deviceStatus['IsWorn'] ??
              deviceStatus['isWorn'] ??
              data['IsWorn'] ??
              data['isWorn'] ??
              data['worn'];
          final bool isWornConfirmed =
              (rawWornValue == true) ||
              (rawWornValue == 1) ||
              (rawWornValue?.toString().trim().toLowerCase() == 'true');

          final bool isWorn = _isManualOverride
              ? !_manualWatchOff
              : (isWaiting ? false : isWornConfirmed);

          // 1. ATURAN UTAMA (BYPASS MUTLAK):
          // Buat variabel boolean penentu keaktifan alat:
          final bool isWatchActive = (isWorn == true && !_isOffline);

          // Ekstraksi nilai IsFallen
          final dynamic rawFallenValue =
              fallDetection['IsFallen'] ??
              fallDetection['isFallen'] ??
              data['IsFallen'] ??
              data['isFallen'];
          final bool rawIsFallen =
              (rawFallenValue == true) ||
              (rawFallenValue == 1) ||
              (rawFallenValue?.toString().trim().toLowerCase() == 'true');

          // JIKA isWatchActive == false (belum dipakai, dilepas, mati, offline, atau data baru dibuka/null),
          // maka status isFallen harus DIPAKSA 100% false dan abaikan semua data "Jatuh" yang basi dari Firebase.
          final bool isFallen = isWatchActive ? rawIsFallen : false;

          // Pengecekan Fase Kalibrasi / Transisi Awal Sensor setelah Jam Dipakai (IsWorn == true)
          final bool isWithinCalibrationWindow =
              (isWatchActive &&
              _wornTransitionTime != null &&
              DateTime.now().difference(_wornTransitionTime!).inMilliseconds <
                  3000);

          // Evaluasi detak jantung (BPM) untuk kalibrasi:
          final rawHr = vitalSigns['HeartRate'] ?? vitalSigns['heartRate'];
          double? parsedHr;
          if (rawHr != null) {
            parsedHr = double.tryParse(
              rawHr.toString().replaceAll('BPM', '').trim(),
            );
          }
          final bool hasValidHr = (parsedHr != null && parsedHr > 0);
          final bool isCalibratingHr =
              isWatchActive &&
              !isWaiting &&
              !_isOffline &&
              (!hasValidHr || isWithinCalibrationWindow);

          final rawLastUpdated =
              deviceStatus['LastUpdated'] ?? deviceStatus['lastUpdated'];
          final String? lastUpdatedStr =
              (rawLastUpdated != null &&
                  rawLastUpdated.toString().trim().isNotEmpty &&
                  rawLastUpdated.toString().trim() != 'null')
              ? rawLastUpdated.toString().trim()
              : null;

          final rawBattery = deviceStatus['Battery'] ?? deviceStatus['battery'];
          final String? batteryStr =
              (rawBattery != null &&
                  rawBattery.toString().trim().isNotEmpty &&
                  rawBattery.toString().trim() != 'null')
              ? rawBattery.toString().trim()
              : null;

          int? parsedBatteryLevel;
          if (batteryStr != null) {
            final cleanBatteryStr = batteryStr.replaceAll('%', '').trim();
            parsedBatteryLevel =
                int.tryParse(cleanBatteryStr) ??
                double.tryParse(cleanBatteryStr)?.toInt();
          }
          final int? batteryLevel = parsedBatteryLevel;
          final bool isLowBattery =
              (isWatchActive &&
              batteryLevel != null &&
              batteryLevel < 20 &&
              batteryLevel > 0);

          final bool isCharging =
              (deviceStatus['Charging'] == true) ||
              (deviceStatus['charging'] == true) ||
              (deviceStatus['Charging'] == 1) ||
              (deviceStatus['charging'] == 1);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18.0, 14.0, 18.0, 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),

                      // --- 1. Header Card ---
                      _buildHeaderCard(
                        isWaiting: isWaiting,
                        isOffline: _isOffline,
                        isWorn: isWorn,
                        isWatchActive: isWatchActive,
                        isFallen: isFallen,
                        isLowBattery: isLowBattery,
                        battery: batteryStr,
                        isCharging: isCharging,
                        lastUpdated: lastUpdatedStr,
                      ),

                      const SizedBox(height: 6),

                      // --- 1.5. Low Battery Alert Banner (Jika isLowBattery == true) ---
                      if (isLowBattery) ...[
                        _buildLowBatteryAlertBanner(
                          userName: PatientProfile.nama.trim().isNotEmpty
                              ? PatientProfile.nama.trim()
                              : 'lansia',
                          batteryLevel: batteryLevel,
                        ),
                        const SizedBox(height: 6),
                      ],

                      // --- 2. Banner Status ---
                      _buildStatusBanner(
                        isWaiting: isWaiting,
                        isOffline: _isOffline,
                        isWorn: isWorn,
                        isWatchActive: isWatchActive,
                        isWithinCalibrationWindow: isWithinCalibrationWindow,
                        isFallen: isFallen,
                        activityType: activityType,
                        fallDetection: fallDetection,
                      ),

                      const SizedBox(height: 6),

                      // --- 3. Grid Tanda Vital ---
                      _buildVitalsGrid(
                        isWaiting: isWaiting,
                        isOffline: _isOffline,
                        isWorn: isWorn,
                        isWatchActive: isWatchActive,
                        isWithinCalibrationWindow: isWithinCalibrationWindow,
                        vitalSigns: vitalSigns,
                      ),

                      const SizedBox(height: 6),

                      // --- 4. Card Tren Denyut Nadi ---
                      _buildPulseTrendCard(
                        isWaiting: isWaiting,
                        isOffline: _isOffline,
                        isWorn: isWorn,
                        isWatchActive: isWatchActive,
                        isCalibratingHr: isCalibratingHr,
                        heartRateData: _heartRateHistory,
                        currentBpm:
                            (isWaiting ||
                                _isOffline ||
                                !isWatchActive ||
                                isCalibratingHr)
                            ? '--'
                            : (parsedHr?.toInt().toString() ?? '--'),
                      ),

                      const SizedBox(height: 6),

                      // --- 5. Card Lokasi Pemantauan ---
                      _buildLocationCard(),

                      const SizedBox(height: 6),

                      // --- 6. Card Riwayat Kejadian ---
                      _buildHistoryCard(
                        isWorn: isWaiting ? false : isWorn,
                        isWatchActive: isWatchActive,
                        isOffline: _isOffline,
                        isLowBattery: isLowBattery,
                        batteryLevel: batteryLevel,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 1. HEADER CARD (.card.hdr) - Sesuai visual horizontal persegi panjang
  // ===========================================================================
  Widget _buildHeaderCard({
    bool isWaiting = false,
    required bool isOffline,
    required bool isWorn,
    required bool isWatchActive,
    required bool isFallen,
    String? battery,
    bool isCharging = false,
    String? lastUpdated,
    bool isLowBattery = false,
  }) {
    // Tentukan warna dan teks badge status di baris tengah
    Color badgeBg;
    Color badgeBorder;
    Color badgeDot;
    Color badgeTextColor;
    String badgeTitle;

    // 3. GANTI LOGIKA TRIGGERING ALERT MERAH:
    // Pastikan block widget yang merender banner merah BAHAYA JATUH di layar dan di profil benar-benar dibungkus dengan kondisi:
    // if (isWorn && isFallen) { ... tampilkan banner merah ... } else { ... tampilkan banner normal/abu-abu ... }
    if (isWatchActive && isWorn && isFallen) {
      badgeBg = _isDarkMode ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
      badgeBorder = _isDarkMode
          ? const Color(0xFFDC2626)
          : const Color(0xFFF87171);
      badgeDot = const Color(0xFFEF4444);
      badgeTextColor = _isDarkMode
          ? const Color(0xFFFCA5A5)
          : const Color(0xFF991B1B);
      badgeTitle = 'Bahaya Jatuh!';
    } else if (isWaiting) {
      badgeBg = _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      badgeBorder = _isDarkMode
          ? const Color(0xFF334155)
          : const Color(0xFFCBD5E1);
      badgeDot = const Color(0xFF64748B);
      badgeTextColor = _isDarkMode
          ? const Color(0xFFCBD5E1)
          : const Color(0xFF475569);
      badgeTitle = 'Menunggu sinkronisasi...';
    } else if (!isWatchActive) {
      // FASE 2: Mode Pasif (Alat Dilepas / Alat Mati) -> Capsule Abu-abu
      badgeBg = _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      badgeBorder = _isDarkMode
          ? const Color(0xFF334155)
          : const Color(0xFFCBD5E1);
      badgeDot = const Color(0xFF64748B);
      badgeTextColor = _isDarkMode
          ? const Color(0xFFCBD5E1)
          : const Color(0xFF475569);
      badgeTitle = isOffline ? 'Alat Mati' : 'Alat Dilepas';
    } else {
      badgeBg = _isDarkMode ? const Color(0xFF064E3B) : const Color(0xFFE8FDF0);
      badgeBorder = _isDarkMode
          ? const Color(0xFF047857)
          : const Color(0xFF86EFAC);
      badgeDot = const Color(0xFF10B981);
      badgeTextColor = _isDarkMode
          ? const Color(0xFF6EE7B7)
          : const Color(0xFF15803D);
      badgeTitle = 'Sedang Dipantau';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(borderRadius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Baris Atas: Logo Brand SAVERA di kiri & Tombol Mode Gelap di kanan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Wadah Block / Pill Brand Logo SAVERA (Rapi & simetris dengan tombol Mode Gelap)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _isDarkMode
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF0F6FE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isDarkMode
                        ? const Color(0xFF334155)
                        : const Color(0xFFDBEAFE),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isDarkMode
                          ? const Color(0x1F000000)
                          : const Color(0x0C1E6FEB),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/logo_perisai.png',
                      height: 20,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.shield_rounded,
                        size: 20,
                        color: kBlue,
                      ),
                    ),
                    const SizedBox(width: 7),
                    AnimatedSaveraText(
                      fontSize: 16.0,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w900,
                      padding: EdgeInsets.zero,
                      textAlign: TextAlign.left,
                      baseColor: _isDarkMode
                          ? const Color(0xFFF8FAFC)
                          : const Color(0xFF0B2A6E),
                      highlightColor: const Color(0xFF38BDF8),
                    ),
                  ],
                ),
              ),

              // Tombol / Chip Fitur Mode Gelap (Dark Mode Toggle)
              InkWell(
                onTap: () {
                  setState(() {
                    _isDarkMode = !_isDarkMode;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6.5,
                  ),
                  decoration: BoxDecoration(
                    color: _isDarkMode
                        ? const Color(0xFF334155)
                        : const Color(0xFFF0F6FE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isDarkMode
                          ? const Color(0xFF475569)
                          : const Color(0xFFDBEAFE),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isDarkMode
                            ? const Color(0x1F000000)
                            : const Color(0x0C1E6FEB),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        _isDarkMode
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        size: 15,
                        color: _isDarkMode ? const Color(0xFFFBBF24) : kBlue,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isDarkMode ? 'Mode Terang' : 'Mode Gelap',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _isDarkMode ? const Color(0xFFF8FAFC) : kBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 2. Baris Tengah: Profil Pasien + Status Badge di kanan
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                // Avatar Pasien dengan Glowing Ring Gradient & Mini Edit Badge
                GestureDetector(
                  onTap: _openProfile,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: (isWaiting || !isWatchActive)
                                ? [
                                    const Color(0xFF94A3B8),
                                    const Color(0xFFCBD5E1),
                                    const Color(0xFF94A3B8),
                                  ]
                                : [
                                    const Color(0xFF38BDF8),
                                    const Color(0xFF3B82F6),
                                    const Color(0xFF818CF8),
                                    const Color(0xFF06B6D4),
                                    const Color(0xFF38BDF8),
                                  ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isWaiting || !isWatchActive)
                                  ? const Color(0x1464748B)
                                  : const Color(0x2838BDF8),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(2.5),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: ClipOval(
                            child: PatientProfile.fotoBytes != null
                                ? Image.memory(
                                    PatientProfile.fotoBytes!,
                                    fit: BoxFit.cover,
                                    width: 44,
                                    height: 44,
                                  )
                                : Container(
                                    color: _isDarkMode
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFCBD5E1),
                                    child: const Icon(
                                      Icons.person_rounded,
                                      size: 32,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: _isDarkMode
                                ? const Color(0xFF334155)
                                : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: cardBorder, width: 1.2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.edit_rounded,
                            size: 10,
                            color: _isDarkMode
                                ? const Color(0xFF38BDF8)
                                : kBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Info Nama & Usia Pasien (dapat diklik untuk ke profil)
                Expanded(
                  child: InkWell(
                    onTap: _openProfile,
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          PatientProfile.nama,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textHeading,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: _isDarkMode
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isDarkMode
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFDBEAFE),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cake_outlined,
                                size: 13,
                                color: _isDarkMode
                                    ? const Color(0xFF38BDF8)
                                    : kNavy,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${PatientProfile.usia} Tahun',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: _isDarkMode
                                      ? const Color(0xFF38BDF8)
                                      : kNavy,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Status Badge Interaktif (Sedang Dipantau / Jam Dilepas / Alat Mati)
                InkWell(
                  onTap: () {
                    // Berikan opsi toggle simulasi untuk pengujian visual mandiri
                    setState(() {
                      _isManualOverride = true;
                      _manualWatchOff = !_manualWatchOff;
                      final bool newWorn = !_manualWatchOff;
                      if (newWorn && !_previousIsWorn) {
                        _wornTransitionTime = DateTime.now();
                        _calibrationTimer?.cancel();
                        _calibrationTimer = Timer(
                          const Duration(milliseconds: 3000),
                          () {
                            if (mounted) setState(() {});
                          },
                        );
                      } else if (!newWorn) {
                        _previousIsWorn = false;
                        _wornTransitionTime = null;
                        _calibrationTimer?.cancel();
                      }
                      _previousIsWorn = newWorn;
                    });
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _manualWatchOff
                              ? 'Simulasi Aktif: Jam Tangan Dilepas'
                              : 'Simulasi Aktif: Sedang Dipantau',
                        ),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: badgeBorder, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: badgeDot.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isWaiting) ...[
                          Icon(Icons.sync, size: 13, color: badgeTextColor),
                          const SizedBox(width: 5),
                        ] else ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: badgeDot,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          badgeTitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: badgeTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 3. Baris Bawah: Panel Statistik Ramping 3 Kolom (Koneksi, Baterai, Pembaruan)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: panelBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: panelBorder),
            ),
            child: Row(
              children: [
                // Kolom 1: Koneksi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Koneksi',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.sensors_rounded,
                            size: 13,
                            color: textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (isWaiting)
                            Icon(Icons.sync, size: 13, color: textSecondary)
                          else if (!isWatchActive)
                            Icon(
                              isOffline
                                  ? Icons.link_off_rounded
                                  : Icons.watch_off,
                              size: 13,
                              color: textSecondary,
                            )
                          else
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _isDarkMode
                                    ? const Color(0xFF4ADE80)
                                    : const Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                            ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              isWaiting
                                  ? 'Menunggu...'
                                  : (!isWatchActive
                                        ? (isOffline
                                              ? 'Terputus'
                                              : 'Alat Dilepas')
                                        : 'Tersambung'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: (isWaiting || !isWatchActive)
                                    ? (_isDarkMode
                                          ? const Color(0xFFCBD5E1)
                                          : const Color(0xFF475569))
                                    : (_isDarkMode
                                          ? const Color(0xFF4ADE80)
                                          : const Color(0xFF15803D)),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isWaiting
                            ? 'Sinkronisasi...'
                            : (!isWatchActive
                                  ? (isOffline
                                        ? 'Menunggu sinyal'
                                        : 'Tidak digunakan')
                                  : 'Gateway aktif'),
                        style: TextStyle(fontSize: 9.5, color: textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Pembatas Vertikal 1
                Container(
                  width: 1,
                  height: 38,
                  color: lineDivider,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),

                // Kolom 2: Baterai
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Baterai',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            (isWaiting || !isWatchActive)
                                ? '-- %'
                                : (battery == null
                                      ? '--'
                                      : (battery.endsWith('%')
                                            ? battery
                                            : '$battery%')),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color:
                                  (isWaiting ||
                                      !isWatchActive ||
                                      battery == null)
                                  ? textSecondary
                                  : (isLowBattery
                                        ? (_isDarkMode
                                              ? const Color(0xFFFBBF24)
                                              : const Color(0xFFD97706))
                                        : (_isDarkMode
                                              ? const Color(0xFF4ADE80)
                                              : const Color(0xFF16A34A))),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            (isWaiting || !isWatchActive || battery == null)
                                ? Icons.battery_unknown_rounded
                                : (isCharging
                                      ? Icons.battery_charging_full_rounded
                                      : (isLowBattery
                                            ? Icons.battery_alert_rounded
                                            : Icons.battery_5_bar_rounded)),
                            size: 14,
                            color:
                                (isWaiting || !isWatchActive || battery == null)
                                ? textSecondary
                                : (isLowBattery
                                      ? (_isDarkMode
                                            ? const Color(0xFFFBBF24)
                                            : const Color(0xFFD97706))
                                      : (_isDarkMode
                                            ? const Color(0xFF4ADE80)
                                            : const Color(0xFF16A34A))),
                          ),
                          if (!isWaiting && isWatchActive && isCharging) ...[
                            const SizedBox(width: 2),
                            Icon(
                              Icons.bolt_rounded,
                              size: 14,
                              color: _isDarkMode
                                  ? const Color(0xFFFBBF24)
                                  : const Color(0xFFD97706),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isWaiting
                            ? 'Menunggu...'
                            : (!isWatchActive
                                  ? (isOffline ? 'Alat mati' : 'Tidak aktif')
                                  : (battery == null
                                        ? 'Menunggu...'
                                        : (isCharging
                                              ? 'Mengisi daya'
                                              : (isLowBattery
                                                    ? 'Baterai lemah'
                                                    : 'Jam tangan')))),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight:
                              (!isWaiting &&
                                  isWatchActive &&
                                  (isCharging || isLowBattery))
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: (!isWaiting && isWatchActive)
                              ? (isLowBattery
                                    ? (_isDarkMode
                                          ? const Color(0xFFFBBF24)
                                          : const Color(0xFFD97706))
                                    : (isCharging
                                          ? (_isDarkMode
                                                ? const Color(0xFF4ADE80)
                                                : const Color(0xFF16A34A))
                                          : textSecondary))
                              : textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Pembatas Vertikal 2
                Container(
                  width: 1,
                  height: 38,
                  color: lineDivider,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),

                // Kolom 3: Pembaruan
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Pembaruan',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.refresh_rounded,
                            size: 13,
                            color: textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isWaiting
                            ? '--'
                            : (!isWatchActive
                                  ? (isOffline ? 'Terputus' : '--')
                                  : (lastUpdated ?? 'Menunggu sinyal...')),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: (isWaiting || !isWatchActive)
                              ? textSecondary
                              : (lastUpdated != null
                                    ? textHeading
                                    : textSecondary),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isWaiting
                            ? 'Menunggu...'
                            : (!isWatchActive
                                  ? (isOffline
                                        ? '15 dtk timeout'
                                        : 'Tidak aktif')
                                  : (lastUpdated != null
                                        ? 'Real-time'
                                        : 'Menunggu sinyal')),
                        style: TextStyle(fontSize: 9.5, color: textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1.5. BANNER PERINGATAN BATERAI LEMAH (Low Battery Alert)
  // ===========================================================================
  Widget _buildLowBatteryAlertBanner({
    required String userName,
    required int batteryLevel,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF3B1D04) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDarkMode
              ? const Color(0xFFB45309)
              : const Color(0xFFFCD34D),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode
                ? const Color(0x30000000)
                : const Color(0x15D97706),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.battery_alert_rounded,
            size: 36,
            color: _isDarkMode
                ? const Color(0xFFFBBF24)
                : const Color(0xFF92400E),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PERINGATAN BATERAI LEMAH',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _isDarkMode
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFF78350F),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Baterai jam tangan $userName tersisa $batteryLevel%. Harap segera diisi ulang agar pemantauan tidak terputus.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _isDarkMode
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFF92400E),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. BANNER STATUS (.banner ok / sb / alert / offline) - Format Ramping & Teks BA/BG
  // ===========================================================================
  Widget _buildStatusBanner({
    bool isWaiting = false,
    required bool isOffline,
    required bool isWorn,
    required bool isWatchActive,
    required bool isWithinCalibrationWindow,
    required bool isFallen,
    String? activityType,
    required Map<dynamic, dynamic> fallDetection,
  }) {
    // Penentuan styling berdasarkan status: Waiting, Alat Dilepas, Offline, Jatuh, Kalibrasi Awal, Aktivitas Dinamis
    LinearGradient bannerGradient;
    Color borderColor;
    Color shadowColor;
    List<Color> iconGradient;
    IconData iconData;
    Widget titleWidget;
    String subText;
    Color subTextColor;
    String baValue = '--';
    String? baSub;
    String bgValue = '--';
    String? bgSub;

    final rawBa =
        fallDetection['BA'] ?? fallDetection['ba'] ?? fallDetection['Accel'];
    final rawBg =
        fallDetection['BG'] ?? fallDetection['bg'] ?? fallDetection['Gyro'];

    double? parsedBa;
    if (rawBa != null) {
      final cleaned = rawBa.toString().replaceAll('g', '').trim();
      parsedBa = double.tryParse(cleaned);
    }
    final bool hasValidBa = (parsedBa != null && parsedBa > 0);

    double? parsedBg;
    if (rawBg != null) {
      final cleaned = rawBg
          .toString()
          .replaceAll('°/s', '')
          .replaceAll('deg/s', '')
          .trim();
      parsedBg = double.tryParse(cleaned);
    }
    final bool hasValidBg = (parsedBg != null && parsedBg > 0);

    // 3. GANTI LOGIKA TRIGGERING ALERT MERAH:
    // Pastikan block widget yang merender banner merah BAHAYA JATUH di layar dan di profil benar-benar dibungkus dengan kondisi:
    // if (isWorn && isFallen) { ... tampilkan banner merah ... } else { ... tampilkan banner normal/abu-abu ... }
    if (isWatchActive && isWorn && isFallen) {
      // "Jatuh" -> Warna Merah Darurat (Red) - Hanya jika isWorn == true dan isWatchActive == true
      bannerGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _isDarkMode
            ? [const Color(0xFF500707), const Color(0xFF350404)]
            : [const Color(0xFFFEE2E2), const Color(0xFFFECACA)],
      );
      borderColor = _isDarkMode
          ? const Color(0xFFDC2626)
          : const Color(0xFFF87171);
      shadowColor = const Color(0x20DC2626);
      iconGradient = [const Color(0xFFDC2626), const Color(0xFF991B1B)];
      iconData = Icons.warning_rounded;
      titleWidget = Text(
        'BAHAYA: JATUH TERDETEKSI!',
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w900,
          color: _isDarkMode
              ? const Color(0xFFFCA5A5)
              : const Color(0xFF7F1D1D),
          letterSpacing: 0.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
      subText = 'Benturan terdeteksi, cek lansia';
      subTextColor = _isDarkMode
          ? const Color(0xFFF87171)
          : const Color(0xFFB91C1C);
      baValue = rawBa != null ? '$rawBa' : '-- g';
      bgValue = rawBg != null ? '$rawBg' : '-- °/s';
    } else if (isWaiting) {
      // FASE 1: Initial Loading State (UI Netral)
      bannerGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _isDarkMode
            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
            : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
      );
      borderColor = _isDarkMode
          ? const Color(0xFF334155)
          : const Color(0xFFE2E8F0);
      shadowColor = const Color(0x06000000);
      iconGradient = [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)];
      iconData = Icons.sync;
      titleWidget = Text(
        'Menunggu Sinkronisasi... (Mohon tunggu)',
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w900,
          color: _isDarkMode
              ? const Color(0xFF93C5FD)
              : const Color(0xFF1E40AF),
          letterSpacing: 0.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
      subText = 'Menghubungkan ke smartwatch SAVERA...';
      subTextColor = textSecondary;
      baValue = '-- g';
      baSub = '(Menunggu sinkronisasi)';
      bgValue = '-- °/s';
      bgSub = '(Menunggu sinkronisasi)';
    } else if (!isWatchActive) {
      // FASE 2: Offline / Disconnected / Removed (isWorn == false or _isOffline == true / Alat Mati)
      // Gunakan warna netral abu-abu pasif (BUKAN MERAH/PANIK)
      bannerGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _isDarkMode
            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
            : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
      );
      borderColor = _isDarkMode
          ? const Color(0xFF334155)
          : const Color(0xFFCBD5E1);
      shadowColor = const Color(0x0A000000);
      iconGradient = [const Color(0xFF64748B), const Color(0xFF475569)];
      iconData = isOffline ? Icons.wifi_off_rounded : Icons.watch_off_rounded;
      titleWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
        decoration: BoxDecoration(
          color: _isDarkMode
              ? const Color(0xFF334155)
              : const Color(0xFF475569),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isOffline ? 'PERANGKAT TERPUTUS' : 'ALAT DILEPAS',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
      );
      subText = isOffline
          ? 'Alat mati atau sinyal terputus'
          : 'Jam tangan tidak digunakan oleh lansia';
      subTextColor = _isDarkMode
          ? const Color(0xFF94A3B8)
          : const Color(0xFF64748B);
      baValue = '-- g';
      baSub = '(Pemantauan dijeda)';
      bgValue = '-- °/s';
      bgSub = '(Pemantauan dijeda)';
    } else if (isWithinCalibrationWindow) {
      // 3. JEDA / DELAY 3 DETIK SETELAH IsWorn == true: "Menganalisis aktivitas awal..."
      bannerGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _isDarkMode
            ? [const Color(0xFF172554), const Color(0xFF1E293B)]
            : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
      );
      borderColor = _isDarkMode
          ? const Color(0xFF1E40AF)
          : const Color(0xFFBFDBFE);
      shadowColor = const Color(0x101D4ED8);
      iconGradient = [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)];
      iconData = Icons.tune_rounded;
      titleWidget = Text(
        'Menganalisis aktivitas awal...',
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w900,
          color: _isDarkMode
              ? const Color(0xFF93C5FD)
              : const Color(0xFF1D4ED8),
          letterSpacing: 0.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
      subText = 'Menstabilkan sensor gerak lansia...';
      subTextColor = _isDarkMode
          ? const Color(0xFF60A5FA)
          : const Color(0xFF2563EB);

      baValue = '-- g';
      baSub = '(Mengkalibrasi posisi...)';
      bgValue = '-- °/s';
      bgSub = '(Mengkalibrasi posisi...)';
    } else {
      // Aktivitas Dinamis secara Real-Time ("Diam", "Berjalan", "Berlari")
      final act = (activityType ?? 'Diam').trim().toLowerCase();

      // Penanganan Sensor Latency & Calibration untuk BA & BG
      if (!hasValidBa) {
        baValue = '-- g';
        baSub = '(Mengkalibrasi posisi...)';
      } else {
        baValue = rawBa.toString().endsWith('g')
            ? rawBa.toString()
            : '$rawBa g';
        baSub = null;
      }

      if (!hasValidBg) {
        bgValue = '-- °/s';
        bgSub = '(Mengkalibrasi posisi...)';
      } else {
        bgValue = rawBg.toString().contains('°')
            ? rawBg.toString()
            : '$rawBg°/s';
        bgSub = null;
      }

      if (act.contains('berlari') ||
          act.contains('lari') ||
          act.contains('run')) {
        bannerGradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode
              ? [const Color(0xFF052E16), const Color(0xFF022C22)]
              : [const Color(0xFFDCFCE7), const Color(0xFFBBF7D0)],
        );
        borderColor = _isDarkMode
            ? const Color(0xFF166534)
            : const Color(0xFF4ADE80);
        shadowColor = const Color(0x1514532D);
        iconGradient = [const Color(0xFF15803D), const Color(0xFF14532D)];
        iconData = Icons.directions_run_rounded;
        titleWidget = Text(
          'Berlari',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
            color: _isDarkMode
                ? const Color(0xFF4ADE80)
                : const Color(0xFF14532D),
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
        subText = 'Lansia terpantau bergerak cepat / berlari';
        subTextColor = _isDarkMode
            ? const Color(0xFF86EFAC)
            : const Color(0xFF166534);
      } else if (act.contains('berjalan') ||
          act.contains('jalan') ||
          act.contains('walk')) {
        bannerGradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode
              ? [const Color(0xFF064E3B), const Color(0xFF022C22)]
              : [const Color(0xFFE8FDF2), const Color(0xFFDCFCE7)],
        );
        borderColor = _isDarkMode
            ? const Color(0xFF059669)
            : const Color(0xFF86EFAC);
        shadowColor = const Color(0x1016A34A);
        iconGradient = [const Color(0xFF22C55E), const Color(0xFF16A34A)];
        iconData = Icons.directions_walk_rounded;
        titleWidget = Text(
          'Berjalan',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
            color: _isDarkMode
                ? const Color(0xFF86EFAC)
                : const Color(0xFF15803D),
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
        subText = 'Lansia terpantau sedang berjalan';
        subTextColor = _isDarkMode
            ? const Color(0xFF4ADE80)
            : const Color(0xFF16A34A);
      } else {
        bannerGradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode
              ? [const Color(0xFF172554), const Color(0xFF1E293B)]
              : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
        );
        borderColor = _isDarkMode
            ? const Color(0xFF1E40AF)
            : const Color(0xFFBFDBFE);
        shadowColor = const Color(0x101D4ED8);
        iconGradient = [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)];
        iconData = Icons.airline_seat_recline_normal_rounded;
        titleWidget = Text(
          'Diam',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
            color: _isDarkMode
                ? const Color(0xFF93C5FD)
                : const Color(0xFF1D4ED8),
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
        subText = 'Lansia terpantau sedang diam / istirahat';
        subTextColor = _isDarkMode
            ? const Color(0xFF60A5FA)
            : const Color(0xFF2563EB);
      }
    }

    return InkWell(
      onTap: () {
        setState(() {
          _isManualOverride = true;
          _manualWatchOff = !_manualWatchOff;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: bannerGradient,
          border: Border.all(color: borderColor, width: 1.1),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Baris 1: Ikon Status & Teks Aktivitas dengan AnimatedSwitcher
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: Row(
                key: ValueKey<String>('banner-hdr-${subText.hashCode}'),
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Ikon Status Compact
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: iconGradient,
                      ),
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: iconGradient.first.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(iconData, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),

                  // Judul & Status Subteks
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        titleWidget,
                        const SizedBox(height: 2),
                        Text(
                          subText,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: subTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 9),

            // Baris 2: Panel Metrik Sensor BA & BG (Layout Vertikal Bertumpuk Sesuai Desain) dengan AnimatedSwitcher
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: _isDarkMode
                      ? const Color(0xFF334155)
                      : (isOffline ? const Color(0xFFFCA5A5) : borderColor),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 4,
                    offset: Offset(0, 1.5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Kolom Kiri: Akselerasi Tubuh (BA)
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: Column(
                        key: ValueKey<String>('ba-$baValue-$baSub'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Akselerasi Tubuh (BA)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: (isWaiting || !isWatchActive)
                                  ? const Color(0xFF64748B)
                                  : (isOffline
                                        ? const Color(0xFFEF4444)
                                        : (isFallen
                                              ? const Color(0xFFDC2626)
                                              : (_isDarkMode
                                                    ? const Color(0xFF94A3B8)
                                                    : kBody))),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            baValue,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                              color: (isWaiting || !isWatchActive)
                                  ? (_isDarkMode
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF475569))
                                  : (isOffline
                                        ? (_isDarkMode
                                              ? const Color(0xFFFCA5A5)
                                              : const Color(0xFF991B1B))
                                        : (isFallen
                                              ? (_isDarkMode
                                                    ? const Color(0xFFFCA5A5)
                                                    : const Color(0xFF7F1D1D))
                                              : (_isDarkMode
                                                    ? const Color(0xFF34D399)
                                                    : const Color(
                                                        0xFF064E3B,
                                                      )))),
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (baSub != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              baSub,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Garis Pembatas Vertikal Halus (Vertical Divider)
                  Container(
                    width: 1,
                    height: 34,
                    color: _isDarkMode ? const Color(0xFF334155) : borderColor,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),

                  // Kolom Kanan: Rotasi Tubuh (BG)
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: Column(
                        key: ValueKey<String>('bg-$bgValue-$bgSub'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Rotasi Tubuh (BG)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: (isWaiting || !isWatchActive)
                                  ? const Color(0xFF64748B)
                                  : (isOffline
                                        ? const Color(0xFFEF4444)
                                        : (isFallen
                                              ? const Color(0xFFDC2626)
                                              : (_isDarkMode
                                                    ? const Color(0xFF94A3B8)
                                                    : kBody))),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            bgValue,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                              color: (isWaiting || !isWatchActive)
                                  ? (_isDarkMode
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF475569))
                                  : (isOffline
                                        ? (_isDarkMode
                                              ? const Color(0xFFFCA5A5)
                                              : const Color(0xFF991B1B))
                                        : (isFallen
                                              ? (_isDarkMode
                                                    ? const Color(0xFFFCA5A5)
                                                    : const Color(0xFF7F1D1D))
                                              : (_isDarkMode
                                                    ? const Color(0xFF34D399)
                                                    : const Color(
                                                        0xFF064E3B,
                                                      )))),
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (bgSub != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              bgSub,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. GRID TANDA VITAL (1fr 1fr) - Terhubung dengan Real-time Firebase
  // ===========================================================================
  Widget _buildVitalsGrid({
    bool isWaiting = false,
    required bool isOffline,
    required bool isWorn,
    required bool isWatchActive,
    required bool isWithinCalibrationWindow,
    required Map<dynamic, dynamic> vitalSigns,
  }) {
    final bool isOff = isWaiting || isOffline || !isWatchActive;

    final rawHr = vitalSigns['HeartRate'] ?? vitalSigns['heartRate'];
    double? parsedHr;
    if (rawHr != null) {
      parsedHr = double.tryParse(rawHr.toString().replaceAll('BPM', '').trim());
    }
    final bool hasValidHr = (parsedHr != null && parsedHr > 0);
    final bool isCalibratingHr =
        isWatchActive &&
        !isWaiting &&
        !isOffline &&
        (!hasValidHr || isWithinCalibrationWindow);

    final String heartRateVal = (isOff || isCalibratingHr || !hasValidHr)
        ? '--'
        : parsedHr.toInt().toString();

    final rawSpo2 =
        vitalSigns['SpO2'] ?? vitalSigns['spO2'] ?? vitalSigns['spo2'];
    double? parsedSpo2;
    if (rawSpo2 != null) {
      parsedSpo2 = double.tryParse(
        rawSpo2.toString().replaceAll('%', '').trim(),
      );
    }
    final bool hasValidSpo2 = (parsedSpo2 != null && parsedSpo2 > 0);
    final bool isCalibratingSpo2 =
        isWatchActive &&
        !isWaiting &&
        !isOffline &&
        (!hasValidSpo2 || isWithinCalibrationWindow);

    final String spO2Val = (isOff || isCalibratingSpo2 || !hasValidSpo2)
        ? '--'
        : parsedSpo2.toInt().toString();

    return Row(
      children: [
        // Kartu 1: Denyut Nadi
        Expanded(
          child: _buildVitalCard(
            title: 'Denyut Nadi',
            icon: Icons.favorite,
            iconColor: kBlue,
            value: heartRateVal,
            unit: 'BPM',
            isOff: isOff,
            isOffline: isOffline,
            isCalibrating: isCalibratingHr,
          ),
        ),
        const SizedBox(width: 8),

        // Kartu 2: Saturasi Oksigen
        Expanded(
          child: _buildVitalCard(
            title: 'Saturasi Oksigen',
            icon: Icons.water_drop,
            iconColor: kSky,
            value: spO2Val,
            unit: '%',
            isOff: isOff,
            isOffline: isOffline,
            isCalibrating: isCalibratingSpo2,
          ),
        ),
      ],
    );
  }

  Widget _buildVitalCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String value,
    required String unit,
    required bool isOff,
    required bool isOffline,
    bool isCalibrating = false,
    Color? borderColor,
  }) {
    Widget substatusWidget;
    if (isOffline) {
      substatusWidget = Container(
        key: const ValueKey('substatus-offline'),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: _isDarkMode
              ? const Color(0xFF1E293B)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _isDarkMode
                ? const Color(0xFF334155)
                : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          'Alat Mati',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: textSecondary,
          ),
        ),
      );
    } else if (isOff) {
      substatusWidget = Container(
        key: const ValueKey('substatus-off'),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: _isDarkMode
              ? const Color(0xFF1E293B)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _isDarkMode
                ? const Color(0xFF334155)
                : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          'Alat Dilepas',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: textSecondary,
          ),
        ),
      );
    } else if (isCalibrating) {
      substatusWidget = Container(
        key: const ValueKey('substatus-calibrating'),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: _isDarkMode
              ? const Color(0xFF0F172A)
              : const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _isDarkMode
                ? const Color(0xFF0284C7)
                : const Color(0xFFBAE6FD),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 11,
              color: _isDarkMode
                  ? const Color(0xFF38BDF8)
                  : const Color(0xFF0284C7),
            ),
            const SizedBox(width: 3),
            Text(
              'Mengkalibrasi...',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: _isDarkMode
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFF0284C7),
              ),
            ),
          ],
        ),
      );
    } else {
      substatusWidget = Text(
        'Normal',
        key: const ValueKey('substatus-normal'),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(borderColor: borderColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header Vital
          Row(
            children: [
              Icon(
                icon,
                color: (isOff || isCalibrating)
                    ? const Color(0xFF94A3B8)
                    : iconColor,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Nilai Angka Besar dengan AnimatedSwitcher & FittedBox (Aman dari Overflow)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: RichText(
                key: ValueKey<String>('vital-num-$title-$value-$isCalibrating'),
                text: TextSpan(
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                    color: (isOff || isCalibrating)
                        ? textSecondary
                        : textHeading,
                    height: 1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  children: [
                    TextSpan(text: value),
                    TextSpan(
                      text: ' $unit',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: unit == 'BPM' ? 0.3 : 0,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Substatus Chip dengan AnimatedSwitcher & FittedBox (Aman dari Overflow)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: substatusWidget,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. CARD TREN DENYUT NADI (Waveform Curve Chart Dinamis Real-Time)
  // ===========================================================================
  Widget _buildPulseTrendCard({
    bool isWaiting = false,
    required bool isOffline,
    required bool isWorn,
    required bool isWatchActive,
    required bool isCalibratingHr,
    required List<double> heartRateData,
    required String currentBpm,
  }) {
    final bool isOff = isWaiting || isOffline || !isWatchActive;

    // Menghitung Skala Sumbu Y Dinamis (Responsive Auto-Scaling):
    // 1. Default Bounds: minY = 60, maxY = 120
    // 2. Dynamic Upper Bound: jika maxBpm > 120, maxY = maxBpm + 10 (ruang bernapas di atas grafik)
    // 3. Dynamic Lower Bound: jika minBpm < 60, minY = minBpm - 10 (ruang bernapas di bawah grafik)
    final bounds = computePulseTrendYBounds(
      heartRateData: heartRateData,
      currentBpm: currentBpm,
      isOff: isOff,
      isCalibratingHr: isCalibratingHr,
    );
    final double targetMinY = bounds.minY;
    final double targetMaxY = bounds.maxY;

    Widget badgeWidget;
    if (isOff) {
      badgeWidget = Container(
        key: const ValueKey('badge-off'),
        padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
        decoration: BoxDecoration(
          color: _isDarkMode
              ? const Color(0xFF334155)
              : const Color(0xFF64748B),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'TIDAK AKTIF',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      );
    } else if (isCalibratingHr) {
      badgeWidget = Container(
        key: const ValueKey('badge-reading'),
        padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
        decoration: BoxDecoration(
          color: _isDarkMode
              ? const Color(0xFF0284C7)
              : const Color(0xFF0284C7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5.5,
              height: 5.5,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'MEMBACA...',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    } else {
      badgeWidget = Container(
        key: const ValueKey('badge-live'),
        padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF1E6FEB),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5.5,
              height: 5.5,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'LIVE',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    String bpmDisplay;
    String rightSubtext;
    if (isWaiting) {
      bpmDisplay = '-- BPM';
      rightSubtext = '• Menunggu';
    } else if (isCalibratingHr) {
      bpmDisplay = '-- BPM';
      rightSubtext = '• Mengkalibrasi nadi...';
    } else if (!isWatchActive || isOffline) {
      bpmDisplay = '-- BPM';
      rightSubtext = '• Terputus';
    } else {
      bpmDisplay = '$currentBpm BPM';
      rightSubtext = '• Real-time';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Card: Tren Denyut Nadi + Badge di Kiri, Angka BPM Besar & Bold di Kanan (Tanpa Ikon Hati)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Kiri: Judul & Badge (Responsif & Anti-Overflow)
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Tren Denyut Nadi',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textHeading,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: badgeWidget,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Kanan: Angka BPM Jauh Lebih Besar & Tebal (Bold), Berdampingan dengan Teks Kecil Subteks
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: Row(
                    key: ValueKey<String>(
                      'pulse-hdr-$bpmDisplay-$rightSubtext',
                    ),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        bpmDisplay,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: (isWaiting || !isWatchActive || isOffline)
                              ? FontWeight.w400
                              : FontWeight.w900,
                          color: (isWaiting || !isWatchActive || isOffline)
                              ? textSecondary
                              : textHeading,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          rightSubtext,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: isCalibratingHr
                                ? (_isDarkMode
                                      ? const Color(0xFF38BDF8)
                                      : const Color(0xFF0284C7))
                                : textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Area Grafik dengan Sumbu Y di Kiri (Label Angka Dinamis dengan Animasi Peregangan Mulus)
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: targetMaxY),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, animatedMaxY, _) {
              return TweenAnimationBuilder<double>(
                tween: Tween<double>(end: targetMinY),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, animatedMinY, _) {
                  return SizedBox(
                    height: 74,
                    child: Row(
                      children: [
                        // Sumbu Y: Angka maxY (batas atas) & minY (batas bawah) dinamis (Hanya saat isWatchActive)
                        if (isWatchActive) ...[
                          SizedBox(
                            width: 28,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 1.0),
                                  child: Text(
                                    '${animatedMaxY.round()}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textSecondary,
                                      fontWeight: FontWeight.w500,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 1.0),
                                  child: Text(
                                    '${animatedMinY.round()}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textSecondary,
                                      fontWeight: FontWeight.w500,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],

                        // Kanvas Kurva Gelombang & Text Overlay saat Pasif / Waiting / Kalibrasi
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: PulseTrendCurvePainter(
                                    isOff: isOff || isCalibratingHr,
                                    isDarkMode: _isDarkMode,
                                    data: heartRateData,
                                    minScale: animatedMinY,
                                    maxScale: animatedMaxY,
                                  ),
                                ),
                              ),
                              if (isOff || isCalibratingHr)
                                Center(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 400),
                                    transitionBuilder: (child, animation) =>
                                        FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        ),
                                    child: Container(
                                      key: ValueKey<String>(
                                        'chart-overlay-${isCalibratingHr ? "calib" : (isWaiting ? "wait" : "off")}',
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _isDarkMode
                                            ? const Color(0xFF0F172A)
                                                  .withValues(alpha: 0.85)
                                            : Colors.white.withValues(
                                                alpha: 0.9,
                                              ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _isDarkMode
                                              ? const Color(0xFF334155)
                                              : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Text(
                                        isCalibratingHr
                                            ? 'Menyesuaikan sensor ke pergelangan...'
                                            : (isWaiting
                                                  ? 'Menunggu sinkronisasi...'
                                                  : 'Menunggu alat dipasang...'),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isCalibratingHr
                                              ? (_isDarkMode
                                                    ? const Color(0xFF38BDF8)
                                                    : const Color(0xFF0284C7))
                                              : textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 6),

          // 3. Sumbu X: Keterangan "60 detik terakhir" di kanan bawah grafik (Hanya saat isWatchActive)
          if (isWatchActive)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '60 detik terakhir',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. CARD LOKASI PEMANTAUAN (Diambil dari Data Profil Pasien)
  // ===========================================================================
  Widget _buildLocationCard() {
    return InkWell(
      onTap: _openProfile,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Icon(
              Icons.location_on_rounded,
              size: 24,
              color: _isDarkMode ? const Color(0xFF38BDF8) : kBlue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lokasi Pemantauan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textHeading,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    PatientProfile.lokasi.isNotEmpty
                        ? PatientProfile.lokasi
                        : 'Rumah - Jl. Merdeka No. 12, Bandung',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: textSecondary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 6. CARD RIWAYAT KEJADIAN (.tl)
  // ===========================================================================
  Widget _buildHistoryCard({
    required bool isWorn,
    bool isWatchActive = true,
    bool isOffline = false,
    bool isLowBattery = false,
    int? batteryLevel,
  }) {
    return HistoryTimelineCard(
      isWorn: isWorn,
      isWatchActive: isWatchActive,
      isOffline: isOffline,
      isLowBattery: isLowBattery,
      batteryLevel: batteryLevel,
      isDarkMode: _isDarkMode,
      cardBg: cardBg,
      cardBorder: cardBorder,
      textHeading: textHeading,
      textSecondary: textSecondary,
      lineDivider: lineDivider,
    );
  }

  BoxDecoration _cardDecoration({
    Color? borderColor,
    double borderRadius = 16,
  }) {
    return BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: _isDarkMode ? cardBorder : (borderColor ?? cardBorder),
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: _isDarkMode
              ? const Color(0x28000000)
              : const Color(0x121E6FEB),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }
}

/// ============================================================================
/// LOGIKA AUTO-SCALING SKALA SUMBU Y GRAFIK DENYUT NADI (60 Detik Terakhir)
/// 1. Default Bounds: minY = 60, maxY = 120 jika seluruh nilai di rentang [60, 120]
/// 2. Dynamic Upper Bound: jika maxBpm > 120, maxY = maxBpm + 10 (ruang bernapas atas)
/// 3. Dynamic Lower Bound: jika minBpm < 60, minY = minBpm - 10 (ruang bernapas bawah)
/// ============================================================================
({double minY, double maxY}) computePulseTrendYBounds({
  required List<double> heartRateData,
  String? currentBpm,
  bool isOff = false,
  bool isCalibratingHr = false,
}) {
  final List<double> validPoints = heartRateData.where((v) => v > 0).toList();
  if (currentBpm != null) {
    final double? parsedCurr = double.tryParse(currentBpm);
    if (parsedCurr != null && parsedCurr > 0) {
      validPoints.add(parsedCurr);
    }
  }

  double targetMinY = 60.0;
  double targetMaxY = 120.0;

  if (!isOff && !isCalibratingHr && validPoints.isNotEmpty) {
    final double maxBpm = validPoints.reduce(math.max);
    final double minBpm = validPoints.reduce(math.min);

    // 1. Dynamic Upper Bound: jika maxBpm > 120, ubah maxY menjadi maxBpm + 10
    if (maxBpm > 120.0) {
      targetMaxY = (maxBpm + 10.0).roundToDouble();
    }

    // 2. Dynamic Lower Bound: jika minBpm < 60, ubah minY menjadi minBpm - 10
    if (minBpm < 60.0) {
      targetMinY = math.max(0.0, (minBpm - 10.0).roundToDouble());
    }
  }

  return (minY: targetMinY, maxY: targetMaxY);
}

/// ============================================================================
/// PAINTER GRAFIK TREN DENYUT NADI (Grid, Skala Sumbu Y Dinamis, Kurva & Marker)
/// ============================================================================
class PulseTrendCurvePainter extends CustomPainter {
  final bool isOff;
  final bool isDarkMode;
  final List<double> data;
  final double minScale;
  final double maxScale;

  const PulseTrendCurvePainter({
    required this.isOff,
    this.isDarkMode = false,
    required this.data,
    this.minScale = 60.0,
    this.maxScale = 120.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double yTop = 5.0;
    final double yBottom = size.height - 4.0;
    final double chartHeight = yBottom - yTop;

    // 1. Gambar Garis Grid Vertikal Tipis (Sesuai Referensi Gambar)
    final gridLinePaint = Paint()
      ..color = isDarkMode ? const Color(0x2A334155) : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const int verticalCols = 12;
    final double colWidth = size.width / verticalCols;
    for (int i = 0; i <= verticalCols; i++) {
      final double x = (i * colWidth).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, yTop), Offset(x, yBottom), gridLinePaint);
    }

    // 2. Gambar Garis Grid Horizontal
    // a. Garis bawah padat (Baseline skala minY BPM)
    final baselinePaint = Paint()
      ..color = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, yBottom),
      Offset(size.width, yBottom),
      baselinePaint,
    );

    // b. Garis atas putus-putus / dashed (Batas skala maxY BPM)
    final dashedTopPaint = Paint()
      ..color = isDarkMode ? const Color(0xFF475569) : const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    _drawDashedLine(
      canvas,
      Offset(0, yTop),
      Offset(size.width, yTop),
      dashedTopPaint,
      dashWidth: 3.0,
      dashSpace: 3.0,
    );

    // FASE 3: Jika isOff (Alat Dilepas / Menunggu / Terputus), hilangkan kurva gelombang dan gambar garis horizontal putus-putus
    if (isOff) {
      final dashedMiddlePaint = Paint()
        ..color = isDarkMode ? const Color(0xFF475569) : const Color(0xFFCBD5E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      final double yMiddle = (yTop + yBottom) / 2;
      _drawDashedLine(
        canvas,
        Offset(0, yMiddle),
        Offset(size.width, yMiddle),
        dashedMiddlePaint,
        dashWidth: 4.0,
        dashSpace: 4.0,
      );
      return;
    }

    // 3. Normalisasi & Pemetaan Titik Koordinat Kurva (BPM Skala Dinamis minScale s/d maxScale)
    final pointsData = (data.length >= 2) ? data : [75.0, 75.0];
    final double scaleRange = (maxScale > minScale)
        ? (maxScale - minScale)
        : 60.0;

    final List<Offset> points = [];
    final int count = pointsData.length;
    for (int i = 0; i < count; i++) {
      final double x = (i / (count - 1)) * size.width;
      final double val = pointsData[i];
      final double normalized = (val - minScale) / scaleRange;
      final double y = yBottom - (normalized.clamp(0.02, 0.98) * chartHeight);
      points.add(Offset(x, y));
    }

    // 4. Bangun Kurva Halus (Catmull-Rom Spline)
    final curvePath = Path();
    curvePath.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = (i + 2 < points.length) ? points[i + 2] : p2;

      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );

      curvePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    // 5. Fill Area di Bawah Kurva (Efek Gradasi Biru Pudar ke Transparan)
    if (!isOff) {
      final fillPath = Path.from(curvePath);
      fillPath.lineTo(size.width, yBottom);
      fillPath.lineTo(0, yBottom);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode
              ? const [Color(0x3538BDF8), Color(0x000F172A)]
              : const [Color(0x320EA5E9), Color(0x00FFFFFF)],
        ).createShader(Rect.fromLTWH(0, yTop, size.width, chartHeight))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);
    }

    // 6. Garis Kurva Gelombang (Stroke Biru Halus)
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (isOff) {
      strokePaint.color = const Color(0xFF94A3B8);
    } else {
      strokePaint.shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: isDarkMode
            ? const [Color(0xFF38BDF8), Color(0xFF60A5FA)]
            : const [Color(0xFF0EA5E9), Color(0xFF1E6FEB)],
      ).createShader(Rect.fromLTWH(0, yTop, size.width, chartHeight));
    }

    canvas.drawPath(curvePath, strokePaint);

    // 7. Garis Vertikal Dotted & Titik Puncak Marker (Sesuai Referensi Gambar)
    if (!isOff && points.isNotEmpty) {
      // Cari titik puncak tertinggi (peak)
      int peakIdx = 0;
      double peakVal = pointsData[0];
      for (int i = 0; i < pointsData.length; i++) {
        if (pointsData[i] >= peakVal) {
          peakVal = pointsData[i];
          peakIdx = i;
        }
      }
      final peakPoint = points[peakIdx];

      // Garis vertikal putus-putus turun ke batas bawah grafik
      final dropLinePaint = Paint()
        ..color = isDarkMode ? const Color(0xFF0284C7) : const Color(0xFF93C5FD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      _drawDashedLine(
        canvas,
        Offset(peakPoint.dx, peakPoint.dy),
        Offset(peakPoint.dx, yBottom),
        dropLinePaint,
        dashWidth: 2.5,
        dashSpace: 2.5,
      );

      // Dot marker di titik puncak (Lingkaran biru dengan halo pudar & border putih)
      final haloPaint = Paint()
        ..color = isDarkMode ? const Color(0x5538BDF8) : const Color(0x351E6FEB)
        ..style = PaintingStyle.fill;

      final dotPaint = Paint()
        ..color = isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF1E6FEB)
        ..style = PaintingStyle.fill;

      final ringPaint = Paint()
        ..color = isDarkMode ? const Color(0xFF1E293B) : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;

      canvas.drawCircle(peakPoint, 7.5, haloPaint);
      canvas.drawCircle(peakPoint, 4.0, dotPaint);
      canvas.drawCircle(peakPoint, 4.0, ringPaint);
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint, {
    double dashWidth = 3.0,
    double dashSpace = 3.0,
  }) {
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double distance = math.sqrt(dx * dx + dy * dy);
    if (distance <= 0) return;
    final double unitX = dx / distance;
    final double unitY = dy / distance;

    double currentDist = 0;
    while (currentDist < distance) {
      final double endDist = math.min(currentDist + dashWidth, distance);
      canvas.drawLine(
        Offset(p1.dx + unitX * currentDist, p1.dy + unitY * currentDist),
        Offset(p1.dx + unitX * endDist, p1.dy + unitY * endDist),
        paint,
      );
      currentDist += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant PulseTrendCurvePainter oldDelegate) =>
      oldDelegate.isOff != isOff ||
      oldDelegate.isDarkMode != isDarkMode ||
      oldDelegate.data != data ||
      oldDelegate.minScale != minScale ||
      oldDelegate.maxScale != maxScale;
}
