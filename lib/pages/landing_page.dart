import 'package:flutter/material.dart';
import 'profile_page.dart'; // Navigasi ke Halaman Isi Profil Pasien
import '../widgets/firebase_test_widget.dart'; // Modal pengujian real-time Firebase
import '../widgets/animated_savera_text.dart'; // Teks animasi siluet SAVERA

/// ============================================================================
/// SAVERA - LAYAR SAMBUTAN (WELCOME SCREEN)
/// Berdasarkan spesifikasi 100% dari file acuan SAVERA_Semua_Halaman (1).html
/// ============================================================================

// --- Skema Warna Desain SAVERA (Tokens :root) ---
const Color kNavy = Color(0xFF0B2A6E); // Brand utama, heading, judul aplikasi
const Color kInk = Color(0xFF0F1E3D);  // Teks judul gelap
const Color kBlue = Color(0xFF1E6FEB); // Biru primer, aksen, ikon
const Color kSky = Color(0xFF0EA5E9);  // Cyan aksen cerah, gradien awal
const Color kL1 = Color(0xFFF0F7FF);   // Latar belakang layar (ice light blue)
const Color kL2 = Color(0xFFE0F0FE);   // Latar wadah ikon
const Color kL3 = Color(0xFFBAE0FD);   // Ambient glow radial
const Color kMuted = Color(0xFF64748B);// Teks sekunder, footnote
const Color kBody = Color(0xFF334155); // Teks paragraf pengantar

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kL1,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Ambient Glow Radial Gradient (Sesuai .wel:before pada CSS)
              Positioned(
                top: -100,
                left: -60,
                right: -60,
                height: 460,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.55,
                      colors: [
                        kL3,
                        Color(0x00BAE0FD), // Transparan
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Konten Utama Layar Sambutan
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 14.0, 20.0, 28.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 18),

                                // --- Hero Section (.hero) ---
                                Column(
                                  children: [
                                    // Logo SAVERA (Tinggi 128px persis sesuai CSS .hero img)
                                    Image.asset(
                                      'assets/images/logo_perisai.png',
                                      height: 128,
                                      fit: BoxFit.contain,
                                    ),
                                    const SizedBox(height: 20),

                                    // Judul Aplikasi (.nm) dengan animasi siluet cahaya & bold
                                    const AnimatedSaveraText(
                                      fontSize: 38,
                                      letterSpacing: 7.0,
                                      fontWeight: FontWeight.w900,
                                    ),
                                    const SizedBox(height: 6),

                                    // Subjudul Aplikasi (.sub)
                                    const Text(
                                      'Tanda Vital & Risiko Jatuh',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: kBlue,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 28),

                                // --- Paragraf Pengantar (.lead) ---
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text(
                                    'Pantau tanda vital dan risiko jatuh lansia secara langsung, untuk ketenangan keluarga.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      fontWeight: FontWeight.w400,
                                      color: kBody,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 22),

                                // --- Daftar Fitur (.feat) ---
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Column(
                                    children: [
                                      _buildFeatureItem(
                                        iconPainter: const HeartPulsePainter(color: kBlue),
                                        text: 'Denyut nadi dan saturasi oksigen',
                                      ),
                                      const SizedBox(height: 12),
                                      _buildFeatureItem(
                                        iconPainter: const MotionWavePainter(color: kBlue),
                                        text: 'Deteksi jatuh dari sensor gerak',
                                      ),
                                      const SizedBox(height: 12),
                                      _buildFeatureItem(
                                        iconPainter: const LocationPinPainter(color: kBlue),
                                        text: 'Lokasi dan riwayat kejadian',
                                      ),
                                    ],
                                  ),
                                ),

                                const Spacer(),

                                // --- Bagian Aksi & Tombol (.act) ---
                                Padding(
                                  padding: const EdgeInsets.only(top: 22.0),
                                  child: Column(
                                    children: [
                                      // Tombol Mulai (.btn)
                                      Container(
                                        width: double.infinity,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [kSky, kBlue],
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x4D1E6FEB), // rgba(30, 111, 235, 0.3)
                                              blurRadius: 24,
                                              offset: Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(16),
                                            onTap: () {
                                              // Navigasi ke Halaman 2: Isi Profil Pasien
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => const ProfilePage(isSetup: true),
                                                ),
                                              );
                                            },
                                            child: const Center(
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'Mulai',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  SizedBox(width: 10),
                                                  CustomPaint(
                                                    size: Size(20, 20),
                                                    painter: ArrowPainter(color: Colors.white),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 12),

                                      // Catatan Kaki (.foot)
                                      const Text(
                                        'Selanjutnya Anda diminta mengisi profil pasien',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: kMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'firebase_test_btn',
        onPressed: () => showFirebaseTestModal(context),
        backgroundColor: kBlue,
        icon: const Icon(Icons.cloud_sync, color: Colors.white, size: 20),
        label: const Text(
          'Tes Firebase',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Komponen baris fitur dengan wadah ikon 34x34 radius 11 (.ic)
  Widget _buildFeatureItem({
    required CustomPainter iconPainter,
    required String text,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: kL2,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: CustomPaint(
            size: const Size(20, 20),
            painter: iconPainter,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: kInk,
            ),
          ),
        ),
      ],
    );
  }
}

/// ============================================================================
/// CUSTOM VECTOR PAINTERS (Mereproduksi 100% path SVG acuan HTML)
/// ============================================================================

/// 1. Ikon Jantung & Denyut Nadi (D.heart)
class HeartPulsePainter extends CustomPainter {
  final Color color;
  const HeartPulsePainter({required this.color});

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

    // Kontur Jantung: M12 20s-8-4.6-8-10.5A4.5 4.5 0 0 1 12 7a4.5 4.5 0 0 1 8 2.5C20 15.4 12 20 12 20z
    final heart = Path();
    heart.moveTo(12, 20);
    heart.cubicTo(4, 15.4, 4, 9.5, 4, 9.5);
    heart.arcToPoint(const Offset(12, 7), radius: const Radius.circular(4.5));
    heart.arcToPoint(const Offset(20, 9.5), radius: const Radius.circular(4.5));
    heart.cubicTo(20, 15.4, 12, 20, 12, 20);
    canvas.drawPath(heart, paint);

    // Garis EKG / Pulsa Tengah: M6 12h3l1.5-3 3 6 1.5-3h3
    final pulse = Path();
    pulse.moveTo(6, 12);
    pulse.lineTo(9, 12);
    pulse.lineTo(10.5, 9);
    pulse.lineTo(13.5, 15);
    pulse.lineTo(15, 12);
    pulse.lineTo(18, 12);
    canvas.drawPath(pulse, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 2. Ikon Gelombang Gerak Sensor (D.wave)
class MotionWavePainter extends CustomPainter {
  final Color color;
  const MotionWavePainter({required this.color});

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

    // Path: M3 12h4l2-6 4 12 2-6h6
    final path = Path();
    path.moveTo(3, 12);
    path.lineTo(7, 12);
    path.lineTo(9, 6);
    path.lineTo(13, 18);
    path.lineTo(15, 12);
    path.lineTo(21, 12);
    canvas.drawPath(path, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 3. Ikon Pin Lokasi (D.pin)
class LocationPinPainter extends CustomPainter {
  final Color color;
  const LocationPinPainter({required this.color});

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

    // Pin: M12 22s7-6.5 7-12a7 7 0 0 0-14 0c0 5.5 7 12 7 12z
    final pin = Path();
    pin.moveTo(12, 22);
    pin.cubicTo(19, 15.5, 19, 10, 19, 10);
    pin.arcToPoint(const Offset(5, 10), radius: const Radius.circular(7));
    pin.cubicTo(5, 15.5, 12, 22, 12, 22);
    canvas.drawPath(pin, paint);

    // Lingkaran dalam: circle cx 12, cy 10, r 2.5
    canvas.drawCircle(const Offset(12, 10), 2.5, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 4. Ikon Panah Kanan Tombol (D.arrow)
class ArrowPainter extends CustomPainter {
  final Color color;
  const ArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * scaleX
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Path: M5 12h14M13 6l6 6-6 6
    final path = Path();
    path.moveTo(5, 12);
    path.lineTo(19, 12);
    path.moveTo(13, 6);
    path.lineTo(19, 12);
    path.lineTo(13, 18);
    canvas.drawPath(path, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}