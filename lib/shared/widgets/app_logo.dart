import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Premium code-based logo widget. Renders a flowing **"ef"** monogram
/// ligature inside a gradient rounded-rect container.
///
/// The design uses bold monoline strokes with rounded caps.
/// The 'e' bowl opens on the right into a shared crossbar that flows
/// seamlessly into the 'f' stem — embodying the "flow" in EditFlow.
///
/// Usage:
/// ```dart
/// AppLogo(size: 88, borderRadius: 24)  // Auth screens
/// AppLogo(size: 104, borderRadius: 28) // Splash screen
/// AppLogo(size: 36, borderRadius: 8)   // Invoice header
/// ```
class AppLogo extends StatelessWidget {
  final double size;
  final double borderRadius;

  const AppLogo({
    super.key,
    this.size = 88,
    this.borderRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CustomPaint(
          size: Size(size, size),
          painter: _EFLogoPainter(),
        ),
      ),
    );
  }
}

class _EFLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Subtle top-right shimmer for glass depth ──
    final shinePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.5, -0.55),
        radius: 0.85,
        colors: [
          Colors.white.withValues(alpha: 0.13),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), shinePaint);

    // ── Stroke setup ──
    final sw = w * 0.088; // Bold stroke weight (~9% of size)

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Soft glow layer behind the strokes for premium depth
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw * 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sw * 0.8);

    // ── Proportional layout ──
    //
    //  "e" sits in the left ~45% of the canvas.
    //  "f" sits in the right ~55%.
    //  A shared crossbar at the 'e' center height creates the ligature.
    //
    final eRadius = w * 0.155;        // 'e' bowl radius
    final eCx = w * 0.34;             // 'e' center x
    final eCy = h * 0.54;             // slightly below center (optical balance)

    final fX = w * 0.635;             // 'f' vertical stem x
    final fTop = h * 0.22;            // 'f' stem top
    final fBot = h * 0.82;            // 'f' stem bottom

    final crossY = eCy;               // shared crossbar y

    // ─────────────────────────────────────────
    //  Draw glow layer first, then sharp layer
    // ─────────────────────────────────────────

    // ── "e" bowl — open arc, gap clearly visible at lower-right ──
    final eRect = Rect.fromCircle(center: Offset(eCx, eCy), radius: eRadius);
    // Start exactly at crossbar height (0 rad = 3 o'clock), sweep 304° CCW
    // leaving a clear 56° opening below the crossbar on the right
    canvas.drawArc(eRect, 0, -5.3, false, glowPaint);
    canvas.drawArc(eRect, 0, -5.3, false, paint);

    // ── Shared crossbar (the "flow" ligature) ──
    // Runs from e's left edge, through the opening, across to past f's stem
    final crossLeft = eCx - eRadius;
    final crossRight = fX + sw * 1.8;
    canvas.drawLine(Offset(crossLeft, crossY), Offset(crossRight, crossY), glowPaint);
    canvas.drawLine(Offset(crossLeft, crossY), Offset(crossRight, crossY), paint);

    // ── "f" vertical stem ──
    canvas.drawLine(Offset(fX, fTop), Offset(fX, fBot), glowPaint);
    canvas.drawLine(Offset(fX, fTop), Offset(fX, fBot), paint);

    // ── "f" elegant top hook (curves right) ──
    final hookPath = Path()
      ..moveTo(fX, fTop)
      ..quadraticBezierTo(fX, h * 0.14, w * 0.79, h * 0.14);
    canvas.drawPath(hookPath, glowPaint);
    canvas.drawPath(hookPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
