import 'package:flutter/material.dart';

class EfLogo extends StatelessWidget {
  final double size;
  const EfLogo({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: const _EfLogoPainter(),
      ),
    );
  }
}

class _EfLogoPainter extends CustomPainter {
  const _EfLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100.0;
    
    // Background Teal-to-Emerald Gradient matchingbg-grad in SVG
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0D9488), Color(0xFF10B981)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(28 * scale),
    );
    canvas.drawRRect(rrect, bgPaint);

    // Shimmer Overlay for Glassy Depth
    final shimmerPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withValues(alpha: 0.13), Colors.white.withValues(alpha: 0)],
        center: const Alignment(0, -0.1),
        radius: 0.85,
      ).createShader(Offset.zero & size);
    canvas.drawRRect(rrect, shimmerPaint);

    // Monogram Stroke Paint
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 8.8 * scale
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. "e" bowl (Center x=34, y=54, Radius=15.5)
    final ePath = Path();
    final cx = 34.0 * scale;
    final cy = 54.0 * scale;
    final r = 15.5 * scale;
    
    ePath.addArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      0,
      -5.305, // ~304 degrees counter-clockwise (leaves the bottom-right gap open)
    );
    canvas.drawPath(ePath, linePaint);

    // 2. Shared crossbar (ligature) from e-left to f-right (y=54)
    canvas.drawLine(
      Offset(18.5 * scale, 54.0 * scale),
      Offset(79.34 * scale, 54.0 * scale),
      linePaint,
    );

    // 3. "f" vertical stem (x=63.5)
    canvas.drawLine(
      Offset(63.5 * scale, 22.0 * scale),
      Offset(63.5 * scale, 82.0 * scale),
      linePaint,
    );

    // 4. "f" top hook (curves right from x=63.5, y=22 to x=79, y=14)
    final fHookPath = Path()
      ..moveTo(63.5 * scale, 22.0 * scale)
      ..quadraticBezierTo(
        63.5 * scale,
        14.0 * scale,
        79.0 * scale,
        14.0 * scale,
      );
    canvas.drawPath(fHookPath, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
