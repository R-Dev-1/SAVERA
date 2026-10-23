import 'package:flutter/material.dart';
import '../models/patient_profile.dart';
import 'profile_page.dart';
import '../widgets/animated_savera_text.dart';

/// ============================================================================
/// SAVERA - BERANDA (DASHBOARD)
/// Berdasarkan spesifikasi 100% dari SAVERA_Semua_Halaman.html
/// (Mendukung Halaman 4: Beranda - Normal & Halaman 5: Beranda - Jam Dilepas)
/// ============================================================================

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Status apakah jam tangan dilepas (Halaman 5) atau normal (Halaman 4)
  bool _isWatchOff = false;

  static const Color kNavy = Color(0xFF0B2A6E);
  static const Color kInk = Color(0xFF0F1E3D);
  static const Color kBlue = Color(0xFF1E6FEB);
  static const Color kSky = Color(0xFF0EA5E9);
  static const Color kL1 = Color(0xFFF0F7FF);
  static const Color kLine = Color(0xFFD6E6FB);
  static const Color kMuted = Color(0xFF64748B);
  static const Color kBody = Color(0xFF334155);

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
      backgroundColor: kL1,
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
                  _buildHeaderCard(),

                  const SizedBox(height: 10),

                  // --- 2. Banner Status (.banner ok / sb) ---
                  _buildStatusBanner(),

                  const SizedBox(height: 10),

                  // --- 3. Grid Tanda Vital (1fr 1fr) ---
                  _buildVitalsGrid(),

                  const SizedBox(height: 10),

                  // --- 4. Card Tren Denyut Nadi ---
                  _buildPulseTrendCard(),

                  const SizedBox(height: 10),

                  // --- 5. Card Lokasi Pemantauan ---
                  _buildLocationCard(),

                  const SizedBox(height: 10),

                  // --- 6. Card Riwayat Kejadian (.tl) ---
                  _buildHistoryCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. HEADER CARD (.card.hdr)
  // ===========================================================================
  // ===========================================================================
  // 1. HEADER CARD (.card.hdr) - Sesuai rancangan visual header.jpg
  // ===========================================================================
  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD6E6FB), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x101E6FEB),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Baris Atas: Logo Brand SAVERA di kiri & Tombol Profil di kanan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/logo_perisai.png',
                    height: 28,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.shield_rounded,
                      size: 26,
                      color: kBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const AnimatedSaveraText(
                    fontSize: 19,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w900,
                    padding: EdgeInsets.zero,
                    textAlign: TextAlign.left,
                  ),
                ],
              ),

              // Tombol / Chip Profil di Kanan Atas
              InkWell(
                onTap: _openProfile,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Profil',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kBlue,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 15,
                        color: kBlue,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Baris Tengah: Profil Pasien (Avatar Ring Glowing + Nama & Usia) + Status Badge (Sedang Dipantau) di kanan
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
                            colors: _isWatchOff
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
                              color: _isWatchOff
                                  ? const Color(0x1464748B)
                                  : const Color(0x2838BDF8),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(2.5),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: ClipOval(
                            child: PatientProfile.fotoFile != null
                                ? Image.file(
                                    PatientProfile.fotoFile!,
                                    fit: BoxFit.cover,
                                    width: 44,
                                    height: 44,
                                  )
                                : Container(
                                    color: const Color(0xFFCBD5E1),
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
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFD6E6FB), width: 1.2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 10,
                            color: kBlue,
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
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: kNavy,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFDBEAFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cake_outlined, size: 13, color: kNavy),
                              const SizedBox(width: 4),
                              Text(
                                '${PatientProfile.usia} Tahun',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: kNavy,
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

                // Status Badge Interaktif (🟢 Sedang Dipantau / ⏸ Jam Dilepas)
                InkWell(
                  onTap: () {
                    setState(() {
                      _isWatchOff = !_isWatchOff;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _isWatchOff ? const Color(0xFFFEF3C7) : const Color(0xFFE8FDF0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isWatchOff ? const Color(0xFFFCD34D) : const Color(0xFF86EFAC),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isWatchOff
                              ? const Color(0x14D97706)
                              : const Color(0x1416A34A),
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
                            color: _isWatchOff
                                ? const Color(0xFFD97706)
                                : const Color(0xFF16A34A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isWatchOff ? 'Jam Dilepas' : 'Sedang Dipantau',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _isWatchOff
                                ? const Color(0xFFB45309)
                                : const Color(0xFF15803D),
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
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                // Kolom 1: Koneksi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'Koneksi',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(Icons.sensors_rounded, size: 13, color: Color(0xFF475569)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _isWatchOff ? const Color(0xFF94A3B8) : const Color(0xFF0284C7),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _isWatchOff ? 'Dilepas' : 'Terhubung',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _isWatchOff ? const Color(0xFF64748B) : const Color(0xFF0284C7),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _isWatchOff ? 'Sensor nonaktif' : 'Gateway aktif',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: _isWatchOff ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                  color: const Color(0xFFE2E8F0),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),

                // Kolom 2: Baterai
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Baterai',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _isWatchOff ? '--' : '85%',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: _isWatchOff ? const Color(0xFF94A3B8) : const Color(0xFF16A34A),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            _isWatchOff ? Icons.battery_unknown_rounded : Icons.battery_5_bar_rounded,
                            size: 14,
                            color: _isWatchOff ? const Color(0xFF94A3B8) : const Color(0xFF16A34A),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _isWatchOff ? 'Dilepas' : 'Jam tangan',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: _isWatchOff ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                  color: const Color(0xFFE2E8F0),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),

                // Kolom 3: Pembaruan
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'Pembaruan',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(Icons.refresh_rounded, size: 13, color: Color(0xFF475569)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isWatchOff ? 'Dijeda' : 'Baru saja',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _isWatchOff ? const Color(0xFF64748B) : kInk,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _isWatchOff ? 'Menunggu' : '120 ms',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: _isWatchOff ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
  // 2. BANNER STATUS (.banner ok / sb) - Format Persegi Panjang Ramping (Fokus Teks BA & BG)
  // ===========================================================================
  Widget _buildStatusBanner() {
    return InkWell(
      onTap: () {
        setState(() {
          _isWatchOff = !_isWatchOff;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: _isWatchOff
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFEF9C3), Color(0xFFFEF3C7)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE8FDF2), Color(0xFFE0F8EC)],
                ),
          border: Border.all(
            color: _isWatchOff ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: _isWatchOff ? const Color(0x0F000000) : const Color(0x10059669),
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
                // Ikon Status Compact (Checkmark / Pause)
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _isWatchOff
                          ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                          : [const Color(0xFF10B981), const Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: _isWatchOff ? const Color(0x28D97706) : const Color(0x28059669),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isWatchOff ? Icons.pause_rounded : Icons.check_rounded,
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
                        _isWatchOff ? 'JEDA: JAM TANGAN DILEPAS' : 'AKTIVITAS NORMAL / AMAN',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: _isWatchOff ? const Color(0xFF78350F) : const Color(0xFF064E3B),
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            _isWatchOff ? Icons.pause_circle_rounded : Icons.shield_rounded,
                            size: 13,
                            color: _isWatchOff ? const Color(0xFFD97706) : const Color(0xFF059669),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isWatchOff ? 'Deteksi Dijeda' : 'Status: Normal',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _isWatchOff ? const Color(0xFF92400E) : const Color(0xFF065F46),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '• (Ketuk ganti mode)',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                              color: _isWatchOff ? const Color(0xFFB45309) : const Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 9),

            // Baris 2: Panel BA & BG Murni Teks (Tanpa Ikon)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: _isWatchOff ? const Color(0xFFFDE68A) : const Color(0xFFD1FAE5),
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
                  // Kolom 1: BA (Fokus Teks, Tanpa Ikon)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'BA: ',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _isWatchOff ? const Color(0xFF92400E) : kBody,
                          ),
                        ),
                        Text(
                          _isWatchOff ? '--' : '1.02g',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: _isWatchOff ? const Color(0xFF78350F) : const Color(0xFF064E3B),
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
                    color: _isWatchOff ? const Color(0xFFFDE68A) : const Color(0xFFD1FAE5),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),

                  // Kolom 2: BG (Fokus Teks, Tanpa Ikon)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'BG: ',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _isWatchOff ? const Color(0xFF92400E) : kBody,
                          ),
                        ),
                        Text(
                          _isWatchOff ? '--' : '3°/s',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: _isWatchOff ? const Color(0xFF78350F) : const Color(0xFF064E3B),
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
  // 3. GRID TANDA VITAL (1fr 1fr)
  // ===========================================================================
  Widget _buildVitalsGrid() {
    return Row(
      children: [
        // Kartu 1: Denyut Nadi
        Expanded(
          child: _buildVitalCard(
            title: 'Denyut Nadi',
            icon: Icons.favorite,
            iconColor: kBlue,
            value: _isWatchOff ? '--' : '76',
            unit: 'x/menit',
            isOff: _isWatchOff,
          ),
        ),
        const SizedBox(width: 12),

        // Kartu 2: Saturasi Oksigen
        Expanded(
          child: _buildVitalCard(
            title: 'Saturasi Oksigen',
            icon: Icons.water_drop,
            iconColor: kSky,
            value: _isWatchOff ? '--' : '98',
            unit: '%',
            isOff: _isWatchOff,
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
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
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
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Nilai Angka Besar
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 48,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                color: isOff ? const Color(0xFF94A3B8) : kInk,
                height: 1.0,
              ),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    color: kMuted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Substatus
          if (isOff)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF94A3B8)),
              ),
              child: const Text(
                'Sensor Terlepas',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
            )
          else
            const Text(
              'Normal',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kMuted),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. CARD TREN DENYUT NADI (Waveform Curve Chart persis CSS SVG path)
  // ===========================================================================
  Widget _buildPulseTrendCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tren Denyut Nadi',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kInk),
              ),
              Text(
                _isWatchOff ? 'Data dijeda' : 'Beberapa jam terakhir',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 70,
            width: double.infinity,
            child: CustomPaint(
              painter: PulseTrendCurvePainter(isOff: _isWatchOff),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. CARD LOKASI PEMANTAUAN
  // ===========================================================================
  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: const Row(
        children: [
          Icon(Icons.location_on_rounded, size: 24, color: kBlue),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lokasi Pemantauan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kInk),
                ),
                SizedBox(height: 2),
                Text(
                  'Rumah - Jl. Merdeka No. 12, Bandung',
                  style: TextStyle(fontSize: 12, color: kMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 6. CARD RIWAYAT KEJADIAN (.tl)
  // ===========================================================================
  Widget _buildHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Riwayat Kejadian',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kInk),
          ),
          const SizedBox(height: 14),

          // Timeline items
          if (_isWatchOff) ...[
            _buildTimelineItem(
              title: 'Gelang Dilepas',
              time: '10.42',
              dotColor: kNavy,
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
              time: '10.15',
              dotColor: kBlue,
              isLast: false,
            ),
            _buildTimelineItem(
              title: 'Gelang Dipasang',
              time: '08.00',
              dotColor: kBlue,
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
                    color: kLine,
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
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kInk),
                  ),
                  const Spacer(),
                  Text(
                    time,
                    style: const TextStyle(fontSize: 11.5, color: kMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: kLine),
      boxShadow: const [
        BoxShadow(color: Color(0x121E6FEB), blurRadius: 12, offset: Offset(0, 3)),
      ],
    );
  }
}

/// ============================================================================
/// PAINTER GRAFIK TREN DENYUT NADI (M0 62 C25 46 38 68 66 52...)
/// ============================================================================
class PulseTrendCurvePainter extends CustomPainter {
  final bool isOff;
  const PulseTrendCurvePainter({required this.isOff});

  @override
  void paint(Canvas canvas, Size size) {
    const double svgW = 262.0;
    const double svgH = 70.0;
    final double scaleX = size.width / svgW;
    final double scaleY = size.height / svgH;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Path persis dari HTML: M0 62 C25 46 38 68 66 52 S106 26 130 40 S172 64 200 42 S240 20 262 34
    final curvePath = Path();
    curvePath.moveTo(0, 62);
    curvePath.cubicTo(25, 46, 38, 68, 66, 52);
    curvePath.cubicTo(94, 36, 106, 26, 130, 40);
    curvePath.cubicTo(154, 54, 172, 64, 200, 42);
    curvePath.cubicTo(228, 20, 240, 20, 262, 34);

    // 1. Fill Area di bawah kurva (Gradient fill ke dasar)
    if (!isOff) {
      final fillPath = Path.from(curvePath);
      fillPath.lineTo(262, 70);
      fillPath.lineTo(0, 70);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x2E0EA5E9), // 18% opacity sky
            Color(0x00FFFFFF), // Fades to white
          ],
        ).createShader(const Rect.fromLTWH(0, 0, svgW, svgH))
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
      strokePaint.shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFF0EA5E9), Color(0xFF1E6FEB)],
      ).createShader(const Rect.fromLTWH(0, 0, svgW, svgH));
    }

    canvas.drawPath(curvePath, strokePaint);

    // 3. Dot Marker di ujung kurva (hanya saat normal)
    if (!isOff) {
      final dotPaint = Paint()
        ..color = const Color(0xFF1E6FEB)
        ..style = PaintingStyle.fill;

      final ringPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      const center = Offset(262, 34);
      canvas.drawCircle(center, 4.5, dotPaint);
      canvas.drawCircle(center, 4.5, ringPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PulseTrendCurvePainter oldDelegate) => oldDelegate.isOff != isOff;
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