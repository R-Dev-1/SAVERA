import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/patient_profile.dart';
import 'profile_page.dart';
import '../widgets/animated_savera_text.dart';

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
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("Devices/Device_01");

  StreamSubscription<DatabaseEvent>? _subscription;
  Timer? _watchdogTimer; // Timer internal untuk mendeteksi alat mati / offline
  Timer? _loadingTimeout;

  bool _isLoading = true;
  bool _isOffline = true; // Default offline sampai ada sinyal / data masuk
  Map<dynamic, dynamic> _deviceData = {};

  // Riwayat denyut nadi (BPM) untuk visualisasi kurva real-time
  final List<double> _heartRateHistory = [72, 73, 74, 73, 75, 76, 75, 76, 77, 76];

  // Fitur Mode Gelap (Dark Mode)
  bool _isDarkMode = false;

  // Getter token tema dinamis (Mode Terang vs Mode Gelap)
  Color get bgPage => _isDarkMode ? const Color(0xFF0F172A) : Colors.white;
  Color get cardBg => _isDarkMode ? const Color(0xFF1E293B) : Colors.white;
  Color get cardBorder => _isDarkMode ? const Color(0xFF334155) : const Color(0xFFD6E6FB);
  Color get textPrimary => _isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF0B2A6E);
  Color get textHeading => _isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF0F1E3D);
  Color get textSecondary => _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get panelBg => _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get panelBorder => _isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get lineDivider => _isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

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
    _subscription = _dbRef.onValue.listen((DatabaseEvent event) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isOffline = false; // Begitu data masuk, alat dipastikan ONLINE!
        _isManualOverride = false; // Sinkronkan kembali dengan data sensor nyata

        if (event.snapshot.exists && event.snapshot.value != null) {
          if (event.snapshot.value is Map) {
            _deviceData = Map<dynamic, dynamic>.from(event.snapshot.value as Map);

            // Ekstraksi denyut nadi (HeartRate) secara live untuk memperbarui grafik garis
            final vs = (_deviceData['VitalSigns'] is Map)
                ? _deviceData['VitalSigns'] as Map<dynamic, dynamic>
                : {};
            final hrRaw = vs['HeartRate'];
            if (hrRaw != null) {
              final double? parsedHr = double.tryParse(hrRaw.toString());
              if (parsedHr != null && parsedHr > 0) {
                _heartRateHistory.add(parsedHr);
                // Batasi maksimal 20 data point terakhir agar grafik tetap proporsional & dinamis
                if (_heartRateHistory.length > 20) {
                  _heartRateHistory.removeAt(0);
                }
              }
            }
          }
        }
      });

      // 2. RESET TIMER SETIAP ADA DATA MASUK
      _resetWatchdogTimer();
    }, onError: (Object error) {
      debugPrint('⚠️ [Firebase RTDB Error]: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = true;
        });
      }
    });
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgPage,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo_perisai.png',
                height: 56,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.shield_rounded,
                  size: 52,
                  color: kBlue,
                ),
              ),
              const SizedBox(height: 16),
              const AnimatedSaveraText(
                fontSize: 22,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w900,
              ),
              const SizedBox(height: 22),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(kBlue),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Menghubungkan ke Perangkat ESP32...',
                style: TextStyle(
                  fontSize: 12.5,
                  color: textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Parsing data dari Firebase secara aman
    final vitalSigns = (_deviceData['VitalSigns'] is Map)
        ? _deviceData['VitalSigns'] as Map<dynamic, dynamic>
        : {};
    final deviceStatus = (_deviceData['DeviceStatus'] is Map)
        ? _deviceData['DeviceStatus'] as Map<dynamic, dynamic>
        : {};
    final fallDetection = (_deviceData['FallDetection'] is Map)
        ? _deviceData['FallDetection'] as Map<dynamic, dynamic>
        : {};

    final bool rawIsWorn = (deviceStatus['IsWorn'] == true) ||
        (deviceStatus['isWorn'] == true) ||
        (deviceStatus['IsWorn'] == 1);
    final bool isWorn = _isManualOverride ? !_manualWatchOff : rawIsWorn;
    final bool isFallen = (fallDetection['IsFallen'] == true) ||
        (fallDetection['isFallen'] == true) ||
        (fallDetection['IsFallen'] == 1);
    final String? lastUpdatedStr = deviceStatus['LastUpdated']?.toString() ??
        deviceStatus['lastUpdated']?.toString();
    final String? batteryStr = deviceStatus['Battery']?.toString() ??
        deviceStatus['battery']?.toString();

    return Scaffold(
      backgroundColor: bgPage,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18.0, 14.0, 18.0, 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),

                  // --- 1. Header Card (.card.hdr) ---
                  _buildHeaderCard(
                    isOffline: _isOffline,
                    isWorn: isWorn,
                    isFallen: isFallen,
                    battery: batteryStr,
                    lastUpdated: lastUpdatedStr,
                  ),

                  const SizedBox(height: 6),

                  // --- 2. Banner Status (.banner ok / sb / alert / offline) ---
                  _buildStatusBanner(
                    isOffline: _isOffline,
                    isWorn: isWorn,
                    isFallen: isFallen,
                    fallDetection: fallDetection,
                  ),

                  const SizedBox(height: 6),

                  // --- 3. Grid Tanda Vital (1fr 1fr) ---
                  _buildVitalsGrid(
                    isOffline: _isOffline,
                    isWorn: isWorn,
                    vitalSigns: vitalSigns,
                  ),

                  const SizedBox(height: 6),

                  // --- 4. Card Tren Denyut Nadi ---
                  _buildPulseTrendCard(
                    isOffline: _isOffline,
                    isWorn: isWorn,
                    heartRateData: _heartRateHistory,
                    currentBpm: (_isOffline || !isWorn)
                        ? '--'
                        : (vitalSigns['HeartRate']?.toString() ?? '76'),
                  ),

                  const SizedBox(height: 6),

                  // --- 5. Card Lokasi Pemantauan ---
                  _buildLocationCard(),

                  const SizedBox(height: 6),

                  // --- 6. Card Riwayat Kejadian (.tl) ---
                  _buildHistoryCard(
                    isOffline: _isOffline,
                    isWorn: isWorn,
                    isFallen: isFallen,
                    lastUpdated: lastUpdatedStr,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. HEADER CARD (.card.hdr) - Sesuai visual horizontal persegi panjang
  // ===========================================================================
  Widget _buildHeaderCard({
    required bool isOffline,
    required bool isWorn,
    required bool isFallen,
    String? battery,
    String? lastUpdated,
  }) {
    // Tentukan warna dan teks badge status di baris tengah
    Color badgeBg;
    Color badgeBorder;
    Color badgeDot;
    Color badgeTextColor;
    String badgeTitle;

    if (isOffline) {
      badgeBg = _isDarkMode ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2);
      badgeBorder = _isDarkMode ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5);
      badgeDot = const Color(0xFFEF4444);
      badgeTextColor = _isDarkMode ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);
      badgeTitle = 'Alat Mati';
    } else if (isFallen) {
      badgeBg = _isDarkMode ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
      badgeBorder = _isDarkMode ? const Color(0xFFDC2626) : const Color(0xFFF87171);
      badgeDot = const Color(0xFFEF4444);
      badgeTextColor = _isDarkMode ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);
      badgeTitle = 'Bahaya Jatuh!';
    } else if (!isWorn) {
      badgeBg = _isDarkMode ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
      badgeBorder = _isDarkMode ? const Color(0xFF92400E) : const Color(0xFFFCD34D);
      badgeDot = const Color(0xFFF59E0B);
      badgeTextColor = _isDarkMode ? const Color(0xFFFDE68A) : const Color(0xFFB45309);
      badgeTitle = 'Jam Dilepas';
    } else {
      badgeBg = _isDarkMode ? const Color(0xFF064E3B) : const Color(0xFFE8FDF0);
      badgeBorder = _isDarkMode ? const Color(0xFF047857) : const Color(0xFF86EFAC);
      badgeDot = const Color(0xFF10B981);
      badgeTextColor = _isDarkMode ? const Color(0xFF6EE7B7) : const Color(0xFF15803D);
      badgeTitle = 'Sedang Dipantau';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(
        borderRadius: 20,
      ),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                      baseColor: _isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF0B2A6E),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
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
                        color: _isDarkMode
                            ? const Color(0xFFFBBF24)
                            : kBlue,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isDarkMode ? 'Mode Terang' : 'Mode Gelap',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _isDarkMode
                              ? const Color(0xFFF8FAFC)
                              : kBlue,
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
                            colors: isOffline
                                ? [
                                    const Color(0xFFEF4444),
                                    const Color(0xFFFCA5A5),
                                    const Color(0xFFEF4444),
                                  ]
                                : (!isWorn
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
                                      ]),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isOffline
                                  ? const Color(0x28EF4444)
                                  : (!isWorn
                                      ? const Color(0x1464748B)
                                      : const Color(0x2838BDF8)),
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
                            color: _isDarkMode ? const Color(0xFF334155) : Colors.white,
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
                            color: _isDarkMode ? const Color(0xFF38BDF8) : kBlue,
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isDarkMode ? const Color(0xFF334155) : const Color(0xFFDBEAFE),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cake_outlined,
                                size: 13,
                                color: _isDarkMode ? const Color(0xFF38BDF8) : kNavy,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${PatientProfile.usia} Tahun',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: _isDarkMode ? const Color(0xFF38BDF8) : kNavy,
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

                // Status Badge Interaktif (🟢 Sedang Dipantau / ⏸ Jam Dilepas / 🔴 Alat Mati)
                InkWell(
                  onTap: () {
                    // Berikan opsi toggle simulasi untuk pengujian visual mandiri
                    setState(() {
                      _isManualOverride = true;
                      _manualWatchOff = !_manualWatchOff;
                    });
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_manualWatchOff
                            ? 'Simulasi Aktif: Jam Tangan Dilepas'
                            : 'Simulasi Aktif: Sedang Dipantau'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: badgeBorder,
                        width: 1.0,
                      ),
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
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: badgeDot,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
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
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isOffline
                                  ? const Color(0xFFEF4444)
                                  : (!isWorn
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF0284C7)),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              isOffline ? 'Terputus' : (!isWorn ? 'Dilepas' : 'Terhubung'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isOffline
                                    ? const Color(0xFFDC2626)
                                    : (!isWorn
                                        ? textSecondary
                                        : (_isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isOffline
                            ? 'Menunggu sinyal'
                            : (!isWorn ? 'Sensor nonaktif' : 'Gateway aktif'),
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isOffline
                              ? const Color(0xFFEF4444)
                              : textSecondary,
                        ),
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
                            isOffline ? '--' : (battery != null ? '$battery%' : (!isWorn ? '--' : '85%')),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isOffline
                                  ? textSecondary
                                  : (!isWorn
                                      ? textSecondary
                                      : (_isDarkMode ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            isOffline
                                ? Icons.battery_unknown_rounded
                                : (!isWorn
                                    ? Icons.battery_unknown_rounded
                                    : Icons.battery_5_bar_rounded),
                            size: 14,
                            color: isOffline
                                ? textSecondary
                                : (!isWorn
                                    ? textSecondary
                                    : (_isDarkMode ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isOffline ? 'Alat mati' : (!isWorn ? 'Dilepas' : 'Jam tangan'),
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isOffline
                              ? const Color(0xFFEF4444)
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
                        isOffline
                            ? 'Terputus'
                            : (!isWorn
                                ? 'Dijeda'
                                : (lastUpdated ?? 'Baru saja')),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isOffline
                              ? const Color(0xFFDC2626)
                              : (!isWorn ? textSecondary : textHeading),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isOffline
                            ? '15 dtk timeout'
                            : (!isWorn ? 'Menunggu' : 'Real-time'),
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isOffline
                              ? const Color(0xFFEF4444)
                              : textSecondary,
                        ),
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
  // 2. BANNER STATUS (.banner ok / sb / alert / offline) - Format Ramping & Teks BA/BG
  // ===========================================================================
  Widget _buildStatusBanner({
    required bool isOffline,
    required bool isWorn,
    required bool isFallen,
    required Map<dynamic, dynamic> fallDetection,
  }) {
    // Penentuan styling berdasarkan 4 status: Offline, Jatuh, Jam Dilepas, Normal
    LinearGradient bannerGradient;
    Color borderColor;
    Color shadowColor;
    List<Color> iconGradient;
    IconData iconData;
    String titleText;
    Color titleColor;
    String subText;
    Color subTextColor;

    if (isOffline) {
      bannerGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _isDarkMode
            ? [const Color(0xFF450A0A), const Color(0xFF2C0707)]
            : [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)],
      );
      borderColor = _isDarkMode ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5);
      shadowColor = const Color(0x15DC2626);
      iconGradient = [const Color(0xFFEF4444), const Color(0xFFDC2626)];
      iconData = Icons.wifi_off_rounded;
      titleText = 'PERANGKAT TERPUTUS';
      titleColor = _isDarkMode ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);
      subText = 'Alat mati atau sinyal terputus';
      subTextColor = _isDarkMode ? const Color(0xFFF87171) : const Color(0xFFDC2626);
    } else if (isFallen) {
      bannerGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _isDarkMode
            ? [const Color(0xFF500707), const Color(0xFF350404)]
            : [const Color(0xFFFEE2E2), const Color(0xFFFECACA)],
      );
      borderColor = _isDarkMode ? const Color(0xFFDC2626) : const Color(0xFFF87171);
      shadowColor = const Color(0x20DC2626);
      iconGradient = [const Color(0xFFDC2626), const Color(0xFF991B1B)];
      iconData = Icons.warning_rounded;
      titleText = 'BAHAYA: JATUH TERDETEKSI!';
      titleColor = _isDarkMode ? const Color(0xFFFCA5A5) : const Color(0xFF7F1D1D);
      subText = 'Benturan terdeteksi, cek lansia';
      subTextColor = _isDarkMode ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
    } else if (!isWorn) {
      bannerGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _isDarkMode
            ? [const Color(0xFF451A03), const Color(0xFF2C1002)]
            : [const Color(0xFFFEF9C3), const Color(0xFFFEF3C7)],
      );
      borderColor = _isDarkMode ? const Color(0xFF92400E) : const Color(0xFFFDE68A);
      shadowColor = const Color(0x0F000000);
      iconGradient = [const Color(0xFFF59E0B), const Color(0xFFD97706)];
      iconData = Icons.pause_rounded;
      titleText = 'STANDBY: JAM TANGAN DILEPAS';
      titleColor = _isDarkMode ? const Color(0xFFFDE68A) : const Color(0xFF78350F);
      subText = 'Sensor dijeda sementara';
      subTextColor = _isDarkMode ? const Color(0xFFFCD34D) : const Color(0xFF92400E);
    } else {
      bannerGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _isDarkMode
            ? [const Color(0xFF064E3B), const Color(0xFF022C22)]
            : [const Color(0xFFE8FDF2), const Color(0xFFE0F8EC)],
      );
      borderColor = _isDarkMode ? const Color(0xFF047857) : const Color(0xFFA7F3D0);
      shadowColor = const Color(0x10059669);
      iconGradient = [const Color(0xFF10B981), const Color(0xFF059669)];
      iconData = Icons.check_rounded;
      titleText = 'AKTIVITAS NORMAL / AMAN';
      titleColor = _isDarkMode ? const Color(0xFF6EE7B7) : const Color(0xFF064E3B);
      subText = 'Kondisi terpantau aman';
      subTextColor = _isDarkMode ? const Color(0xFFA7F3D0) : const Color(0xFF065F46);
    }

    // Ekstraksi nilai BA & BG
    String baValue = '--';
    String bgValue = '--';

    if (!isOffline && isWorn) {
      final rawBa = fallDetection['BA'] ?? fallDetection['ba'] ?? fallDetection['Accel'];
      final rawBg = fallDetection['BG'] ?? fallDetection['bg'] ?? fallDetection['Gyro'];

      if (isFallen) {
        baValue = rawBa != null ? '$rawBa' : '2.45g';
        bgValue = rawBg != null ? '$rawBg' : '180°/s';
      } else {
        baValue = rawBa != null ? '$rawBa' : '1.02g';
        bgValue = rawBg != null ? '$rawBg' : '3°/s';
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
          border: Border.all(
            color: borderColor,
            width: 1.1,
          ),
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
            // Baris 1: Ikon Status & Teks Aktivitas
            Row(
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
                  child: Icon(
                    iconData,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),

                // Judul & Status Subteks
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        titleText,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: titleColor,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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

            const SizedBox(height: 9),

            // Baris 2: Panel BA & BG Murni Teks (Tanpa Ikon) Sesuai Permintaan
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                  // Kolom 1: BA (Fokus Teks)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'BA: ',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isOffline
                                ? const Color(0xFFEF4444)
                                : (isFallen
                                    ? const Color(0xFFDC2626)
                                    : (!isWorn
                                        ? const Color(0xFFF59E0B)
                                        : (_isDarkMode ? const Color(0xFF94A3B8) : kBody))),
                          ),
                        ),
                        Text(
                          baValue,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: isOffline
                                ? (_isDarkMode ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B))
                                : (isFallen
                                    ? (_isDarkMode ? const Color(0xFFFCA5A5) : const Color(0xFF7F1D1D))
                                    : (!isWorn
                                        ? (_isDarkMode ? const Color(0xFFFDE68A) : const Color(0xFF78350F))
                                        : (_isDarkMode ? const Color(0xFF34D399) : const Color(0xFF064E3B)))),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Garis Pembatas Vertikal Halus
                  Container(
                    width: 1,
                    height: 22,
                    color: _isDarkMode
                        ? const Color(0xFF334155)
                        : (isOffline ? const Color(0xFFFCA5A5) : borderColor),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),

                  // Kolom 2: BG (Fokus Teks)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'BG: ',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isOffline
                                ? const Color(0xFFEF4444)
                                : (isFallen
                                    ? const Color(0xFFDC2626)
                                    : (!isWorn
                                        ? const Color(0xFFF59E0B)
                                        : (_isDarkMode ? const Color(0xFF94A3B8) : kBody))),
                          ),
                        ),
                        Text(
                          bgValue,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: isOffline
                                ? (_isDarkMode ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B))
                                : (isFallen
                                    ? (_isDarkMode ? const Color(0xFFFCA5A5) : const Color(0xFF7F1D1D))
                                    : (!isWorn
                                        ? (_isDarkMode ? const Color(0xFFFDE68A) : const Color(0xFF78350F))
                                        : (_isDarkMode ? const Color(0xFF34D399) : const Color(0xFF064E3B)))),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
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
    required bool isOffline,
    required bool isWorn,
    required Map<dynamic, dynamic> vitalSigns,
  }) {
    final bool isOff = isOffline || !isWorn;

    final String heartRateVal = isOff
        ? '--'
        : (vitalSigns['HeartRate']?.toString() ?? '76');

    final String spO2Val = isOff
        ? '--'
        : (vitalSigns['SpO2']?.toString() ?? '98');

    return Row(
      children: [
        // Kartu 1: Denyut Nadi
        Expanded(
          child: _buildVitalCard(
            title: 'Denyut Nadi',
            icon: Icons.favorite,
            iconColor: kBlue,
            value: heartRateVal,
            unit: 'x/menit',
            isOff: isOff,
            isOffline: isOffline,
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
    Color? borderColor,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(
        borderColor: borderColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header Vital
          Row(
            children: [
              Icon(icon, color: isOff ? const Color(0xFF94A3B8) : iconColor, size: 20),
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

          // Nilai Angka Besar
          RichText(
            text: TextSpan(
              style: GoogleFonts.plusJakartaSans(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                color: isOff ? textSecondary : textHeading,
                height: 1.0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: ' $unit',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Substatus Chip
          if (isOffline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _isDarkMode ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5),
                ),
              ),
              child: Text(
                'Alat Mati',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _isDarkMode ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                ),
              ),
            )
          else if (isOff)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _isDarkMode ? const Color(0xFF334155) : const Color(0xFF94A3B8),
                ),
              ),
              child: Text(
                'Sensor Dilepas',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                ),
              ),
            )
          else
            Text(
              'Normal',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textSecondary,
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
    required bool isOffline,
    required bool isWorn,
    required List<double> heartRateData,
    required String currentBpm,
  }) {
    final bool isOff = isOffline || !isWorn;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tren Denyut Nadi',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textHeading,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!isOff)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isDarkMode
                            ? const Color(0xFF0C4A6E)
                            : const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _isDarkMode
                              ? const Color(0xFF0284C7)
                              : const Color(0xFFBAE6FD),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0284C7),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: _isDarkMode
                                  ? const Color(0xFF38BDF8)
                                  : const Color(0xFF0369A1),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              Text(
                isOffline
                    ? 'Alat terputus'
                    : (isOff ? 'Data dijeda' : '$currentBpm BPM • Real-time'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isOff ? FontWeight.w500 : FontWeight.w700,
                  color: isOff ? textSecondary : (_isDarkMode ? const Color(0xFF38BDF8) : kBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 70,
            width: double.infinity,
            child: CustomPaint(
              painter: PulseTrendCurvePainter(
                isOff: isOff,
                isDarkMode: _isDarkMode,
                data: heartRateData,
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
    required bool isOffline,
    required bool isWorn,
    required bool isFallen,
    String? lastUpdated,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Riwayat Kejadian',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textHeading,
            ),
          ),
          const SizedBox(height: 14),

          // Timeline items berdasarkan status alat
          if (isFallen) ...[
            _buildTimelineItem(
              title: 'Bahaya: Jatuh Terdeteksi!',
              time: lastUpdated ?? 'Baru saja',
              dotColor: const Color(0xFFEF4444),
              isLast: false,
            ),
            _buildTimelineItem(
              title: 'Status Normal',
              time: '10.15',
              dotColor: const Color(0xFF94A3B8),
              isLast: false,
            ),
            _buildTimelineItem(
              title: 'Gelang Dipasang',
              time: '08.00',
              dotColor: const Color(0xFF94A3B8),
              isLast: true,
            ),
          ] else if (isOffline) ...[
            _buildTimelineItem(
              title: 'Perangkat Terputus',
              time: lastUpdated ?? 'Baru saja',
              dotColor: const Color(0xFFEF4444),
              isLast: false,
            ),
            _buildTimelineItem(
              title: 'Status Normal Terakhir',
              time: '10.15',
              dotColor: const Color(0xFF94A3B8),
              isLast: true,
            ),
          ] else if (!isWorn) ...[
            _buildTimelineItem(
              title: 'Gelang Dilepas',
              time: lastUpdated ?? '10.42',
              dotColor: _isDarkMode ? const Color(0xFFF59E0B) : kNavy,
              isLast: false,
            ),
            _buildTimelineItem(
              title: 'Status Normal',
              time: '10.15',
              dotColor: const Color(0xFF94A3B8),
              isLast: false,
            ),
            _buildTimelineItem(
              title: 'Alarm Dimatikan Pendamping',
              time: '09.30',
              dotColor: const Color(0xFF94A3B8),
              isLast: true,
            ),
          ] else ...[
            _buildTimelineItem(
              title: 'Status Normal',
              time: lastUpdated ?? '10.15',
              dotColor: _isDarkMode ? const Color(0xFF38BDF8) : kBlue,
              isLast: false,
            ),
            _buildTimelineItem(
              title: 'Gelang Dipasang',
              time: '08.00',
              dotColor: _isDarkMode ? const Color(0xFF38BDF8) : kBlue,
              isLast: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required String title,
    required String time,
    required Color dotColor,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kolom Garis & Dot
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: lineDivider,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Teks & Waktu
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16.0),
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textHeading,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    time,
                    style: TextStyle(fontSize: 11.5, color: textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
          color: _isDarkMode ? const Color(0x28000000) : const Color(0x121E6FEB),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }
}

/// ============================================================================
/// PAINTER GRAFIK TREN DENYUT NADI (M0 62 C25 46 38 68 66 52...)
/// ============================================================================
class PulseTrendCurvePainter extends CustomPainter {
  final bool isOff;
  final bool isDarkMode;
  final List<double> data;

  const PulseTrendCurvePainter({
    required this.isOff,
    this.isDarkMode = false,
    required this.data,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final pointsData = (data.length >= 2) ? data : [75.0, 75.0];

    // Hitung min dan max BPM untuk penskalaan dinamis vertikal
    double minBpm = pointsData.reduce(math.min);
    double maxBpm = pointsData.reduce(math.max);

    // Padding vertikal agar garis tidak mentok atau flat jika data konstan
    if (maxBpm - minBpm < 14) {
      final mid = (maxBpm + minBpm) / 2;
      minBpm = mid - 7;
      maxBpm = mid + 7;
    } else {
      minBpm -= 4;
      maxBpm += 4;
    }

    // Pemetaan titik koordinat (x, y)
    final List<Offset> points = [];
    final int count = pointsData.length;
    for (int i = 0; i < count; i++) {
      final double x = (i / (count - 1)) * size.width;
      final double normalized = (pointsData[i] - minBpm) / (maxBpm - minBpm);
      final double y = size.height - (normalized.clamp(0.12, 0.88) * size.height);
      points.add(Offset(x, y));
    }

    // Bangun kurva halus menggunakan interpolasi Spline Catmull-Rom
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

    // 1. Fill Area di bawah kurva (Gradient fade ke dasar)
    if (!isOff) {
      final fillPath = Path.from(curvePath);
      fillPath.lineTo(size.width, size.height);
      fillPath.lineTo(0, size.height);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode
              ? const [
                  Color(0x3538BDF8),
                  Color(0x000F172A),
                ]
              : const [
                  Color(0x350EA5E9),
                  Color(0x00FFFFFF),
                ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);
    }

    // 2. Garis Kurva Stroke
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
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
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    }

    canvas.drawPath(curvePath, strokePaint);

    // 3. Dot Marker di ujung kanan (menandai titik data terbaru)
    if (!isOff && points.isNotEmpty) {
      final lastPoint = points.last;

      final dotPaint = Paint()
        ..color = isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF1E6FEB)
        ..style = PaintingStyle.fill;

      final ringPaint = Paint()
        ..color = isDarkMode ? const Color(0xFF1E293B) : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      // Halo cahaya di sekitar dot
      final haloPaint = Paint()
        ..color = isDarkMode ? const Color(0x4438BDF8) : const Color(0x331E6FEB)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(lastPoint, 8.0, haloPaint);
      canvas.drawCircle(lastPoint, 4.5, dotPaint);
      canvas.drawCircle(lastPoint, 4.5, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PulseTrendCurvePainter oldDelegate) =>
      oldDelegate.isOff != isOff ||
      oldDelegate.isDarkMode != isDarkMode ||
      oldDelegate.data != data;
}

/// ============================================================================
/// PAINTER IKON BANNER (Perisai dengan Ceklis & Pause Circle)
/// ============================================================================
class ShieldCheckPainter extends CustomPainter {
  final Color color;
  const ShieldCheckPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * scaleX
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Kontur Perisai: M12 3l8 3v6c0 4.5-3.2 7.8-8 9-4.8-1.2-8-4.5-8-9V6z
    final shield = Path();
    shield.moveTo(12, 3);
    shield.lineTo(20, 6);
    shield.lineTo(20, 12);
    shield.cubicTo(20, 16.5, 16.8, 19.8, 12, 21);
    shield.cubicTo(7.2, 19.8, 4, 16.5, 4, 12);
    shield.lineTo(4, 6);
    shield.close();
    canvas.drawPath(shield, paint);

    // Ceklis di dalam perisai: M8.5 12l2.5 2.5 4.5-5
    final check = Path();
    check.moveTo(8.5, 12);
    check.lineTo(11, 14.5);
    check.lineTo(15.5, 9.5);
    canvas.drawPath(check, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ShieldCheckPainter oldDelegate) => oldDelegate.color != color;
}

class PauseCirclePainter extends CustomPainter {
  final Color color;
  const PauseCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * scaleX
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Lingkaran: cx 12, cy 12, r 9
    canvas.drawCircle(const Offset(12, 12), 9, paint);

    // Dua garis jeda: M10 9v6M14 9v6
    canvas.drawLine(const Offset(10, 9), const Offset(10, 15), paint);
    canvas.drawLine(const Offset(14, 9), const Offset(14, 15), paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PauseCirclePainter oldDelegate) => oldDelegate.color != color;
}