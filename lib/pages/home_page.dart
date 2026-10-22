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
  static const Color kL3 = Color(0xFFBAE0FD);
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
  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris Brand & Profil
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Brand Logo & Teks
              Row(
                children: [
                  Image.asset(
                    'assets/images/logo_perisai.png',
                    height: 34,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.shield_rounded,
                      size: 32,
                      color: kBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const AnimatedSaveraText(
                    fontSize: 20,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w900,
                    padding: EdgeInsets.zero,
                    textAlign: TextAlign.left,
                  ),
                ],
              ),

              // Tombol Avatar Profil (.pf) dengan Badge Pensil (.pen)
              InkWell(
                onTap: _openProfile,
                borderRadius: BorderRadius.circular(23),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [kSky, kBlue],
                        ),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: kL3, spreadRadius: 2),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        PatientProfile.initials,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: kLine),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.edit, size: 11, color: kBlue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Garis Pembatas & Data Pasien (.who)
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: kLine)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sedang dipantau',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kMuted),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontFamily: 'Inter', color: kNavy),
                    children: [
                      TextSpan(
                        text: PatientProfile.nama,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: ' • ${PatientProfile.usia} Tahun',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3 Tiles Grid (.tiles)
          const SizedBox(height: 14),
          Row(
            children: [
              // Tile 1: Koneksi
              Expanded(
                child: _buildTile(
                  title: 'Koneksi',
                  content: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isWatchOff ? const Color(0xFF94A3B8) : kSky,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isWatchOff ? 'Dilepas' : 'Terhubung',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kInk),
                      ),
                    ],
                  ),
                  subtitle: 'Gateway aktif',
                ),
              ),
              const SizedBox(width: 8),

              // Tile 2: Baterai
              Expanded(
                child: _buildTile(
                  title: 'Baterai',
                  content: const Text(
                    '85%',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kInk),
                  ),
                  subtitle: 'Jam tangan',
                ),
              ),
              const SizedBox(width: 8),

              // Tile 3: Pembaruan
              Expanded(
                child: _buildTile(
                  title: 'Pembaruan',
                  content: const Text(
                    'Baru saja',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kInk),
                  ),
                  subtitle: '120 ms',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required String title,
    required Widget content,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: kL1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: kMuted),
          ),
          const SizedBox(height: 3),
          content,
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10.5, color: kMuted),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. BANNER STATUS (.banner ok / sb) - Dapat diklik untuk simulasi jam dilepas
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _isWatchOff ? const Color(0xFFE8EDF3) : null,
          gradient: _isWatchOff
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFBBF7D0), Color(0xFFECFDF5)],
                ),
          border: _isWatchOff
              ? Border.all(color: const Color(0xFF94A3B8), width: 1.2)
              : Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          children: [
            // Ikon Banner (Shield dengan Ceklis untuk normal, Pause untuk dilepas)
            CustomPaint(
              size: const Size(40, 40),
              painter: _isWatchOff
                  ? const PauseCirclePainter(color: Color(0xFF475569))
                  : const ShieldCheckPainter(color: Color(0xFF059669)),
            ),
            const SizedBox(width: 14),

            // Teks Banner
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isWatchOff ? 'JEDA: JAM TANGAN DILEPAS' : 'AKTIVITAS NORMAL / AMAN',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _isWatchOff ? const Color(0xFF1E293B) : const Color(0xFF065F46),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _isWatchOff ? 'Deteksi jatuh dijeda (Ketuk untuk ganti mode)' : 'Status jatuh: Normal (Ketuk untuk ganti mode)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: _isWatchOff ? const Color(0xFF475569) : kBody,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Badge IMU
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xD9FFFFFF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _isWatchOff ? 'BA: -- • BG: --' : 'BA: 1.02g • BG: 3°/s',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: kInk,
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