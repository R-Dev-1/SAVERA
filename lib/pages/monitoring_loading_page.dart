import 'package:flutter/material.dart';
import 'home_page.dart';

/// Layar transisi "Membuka beranda pemantauan..." setelah pengisian profil
class MonitoringLoadingPage extends StatefulWidget {
  const MonitoringLoadingPage({super.key});

  @override
  State<MonitoringLoadingPage> createState() => _MonitoringLoadingPageState();
}

class _MonitoringLoadingPageState extends State<MonitoringLoadingPage>
    with SingleTickerProviderStateMixin {
  static const Color kNavy = Color(0xFF0B2A6E);
  static const Color kBlue = Color(0xFF1E6FEB);
  static const Color kSky = Color(0xFF0EA5E9);
  static const Color kL1 = Color(0xFFF0F7FF);

  late AnimationController _controller;
  late Animation<double> _progressAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _progressAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _pulseAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const DashboardScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kL1,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo pulse
                    ScaleTransition(
                      scale: _pulseAnim,
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [kSky, kBlue],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: kBlue.withValues(alpha: 0.28),
                              blurRadius: 28,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Image.asset(
                          'assets/images/logo_perisai.png',
                          width: 46,
                          height: 46,
                          fit: BoxFit.contain,
                          color: Colors.white,
                          colorBlendMode: BlendMode.srcIn,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.shield_rounded,
                                  size: 46, color: Colors.white),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Teks SAVERA
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [kNavy, kBlue],
                      ).createShader(bounds),
                      child: const Text(
                        'SAVERA',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Teks status
                    Text(
                      'Membuka beranda pemantauan...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: kNavy.withValues(alpha: 0.65),
                        letterSpacing: 0.2,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Progress bar
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD6E6FB),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          value: _progressAnim.value,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation<Color>(kBlue),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Persen
                    Text(
                      '${(_progressAnim.value * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kBlue.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
