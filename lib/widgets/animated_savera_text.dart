import 'package:flutter/material.dart';

/// Widget teks "SAVERA" tebal (bold) dengan animasi siluet cahaya / shimmer berkilau elegan
class AnimatedSaveraText extends StatefulWidget {
  final double fontSize;
  final double letterSpacing;
  final Color baseColor;
  final Color highlightColor;
  final FontWeight fontWeight;
  final EdgeInsetsGeometry padding;
  final TextAlign textAlign;

  const AnimatedSaveraText({
    super.key,
    this.fontSize = 36,
    this.letterSpacing = 7.0,
    this.baseColor = const Color(0xFF0B2A6E), // kNavy
    this.highlightColor = const Color(0xFF38BDF8), // kSky glow
    this.fontWeight = FontWeight.w900,
    this.padding = const EdgeInsets.only(left: 7.0),
    this.textAlign = TextAlign.center,
  });

  @override
  State<AnimatedSaveraText> createState() => _AnimatedSaveraTextState();
}

class _AnimatedSaveraTextState extends State<AnimatedSaveraText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          // Pergeseran siluet cahaya dari kiri (-2.5) ke kanan (+2.5)
          final x = -2.5 + (5.0 * t);

          return ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment(x - 1.2, -0.2),
                end: Alignment(x + 1.2, 0.2),
                colors: [
                  widget.baseColor,
                  widget.baseColor,
                  widget.highlightColor,
                  const Color(0xFFE0F2FE), // Siluet cahaya putih kebiruan berkilau
                  widget.highlightColor,
                  widget.baseColor,
                  widget.baseColor,
                ],
                stops: const [0.0, 0.25, 0.42, 0.50, 0.58, 0.75, 1.0],
              ).createShader(bounds);
            },
            child: Text(
              'SAVERA',
              textAlign: widget.textAlign,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: widget.fontSize,
                fontWeight: widget.fontWeight,
                letterSpacing: widget.letterSpacing,
                color: Colors.white, // Dibutuhkan oleh ShaderMask
              ),
            ),
          );
        },
      ),
    );
  }
}
