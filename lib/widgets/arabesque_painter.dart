import 'package:flutter/material.dart';

class ArabesquePainter extends CustomPainter {
  final Color color;
  final double opacity;
  final double tileSize;

  static final Path _tilePath = Path()
    ..moveTo(30, 0)
    ..lineTo(32.5, 15)
    ..lineTo(45, 5)
    ..lineTo(35, 17.5)
    ..lineTo(60, 30)
    ..lineTo(35, 32.5)
    ..lineTo(45, 55)
    ..lineTo(32.5, 45)
    ..lineTo(30, 60)
    ..lineTo(27.5, 45)
    ..lineTo(15, 55)
    ..lineTo(25, 42.5)
    ..lineTo(0, 30)
    ..lineTo(25, 27.5)
    ..lineTo(15, 5)
    ..lineTo(27.5, 15)
    ..close();

  ArabesquePainter({
    required this.color,
    this.opacity = 0.04,
    this.tileSize = 80.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final double width = size.width;
    final double height = size.height;

    // Iterate to tile across the canvas width and height
    for (double x = 0; x < width + tileSize; x += tileSize) {
      for (double y = 0; y < height + tileSize; y += tileSize) {
        canvas.save();
        canvas.translate(x, y);

        // Scale our 60x60 original path design to the tile size
        final double scale = tileSize / 60.0;
        canvas.scale(scale, scale);

        canvas.drawPath(_tilePath, paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant ArabesquePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.opacity != opacity ||
        oldDelegate.tileSize != tileSize;
  }
}

class ArabesqueBackground extends StatelessWidget {
  final Widget child;

  const ArabesqueBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Choose appropriate accent color for patterns
    final Color patternColor = isDark
        ? const Color(0xFFD4AF37) // gold
        : theme.colorScheme.primary; // primary green

    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: ArabesquePainter(
                color: patternColor,
                opacity: isDark ? 0.03 : 0.025,
                tileSize: 120.0,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
