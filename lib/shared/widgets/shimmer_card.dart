import 'package:flutter/material.dart';
import 'dart:io';

/// A premium shimmer skeleton tile.
///
/// Features a fast left-to-right highlight sweep layered on top of a
/// softly-pulsing base colour, giving loading states a polished, modern feel.
class ShimmerCard extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerCard({
    super.key,
    this.width = double.infinity,
    this.height = 100.0,
    this.borderRadius = 16.0,
  });

  @override
  State<ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _sweepAnim;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _controller.repeat();
    }

    // Sweep: left-to-right across the card
    _sweepAnim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    // Pulse: gentle opacity breathe on the base card
    _pulseAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 50),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Base / highlight colours tuned for dark and light modes
    final baseColor =
        isDark ? const Color(0xFF1C1F2E) : const Color(0xFFEFF3F8);
    final borderColor =
        isDark ? const Color(0xFF2A2D3E) : const Color(0xFFDDE3ED);
    final sweepColor =
        isDark ? const Color(0xFF2E3348) : const Color(0xFFFFFFFF);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Opacity(
          opacity: _pulseAnim.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(color: borderColor, width: 0.8),
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withAlpha(50),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: const Color(0xFFD0D9E8).withAlpha(80),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: Stack(
                children: [
                  // Sweep highlight
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(_sweepAnim.value - 0.6, 0),
                          end: Alignment(_sweepAnim.value + 0.6, 0),
                          colors: [
                            sweepColor.withAlpha(0),
                            sweepColor.withAlpha(isDark ? 22 : 90),
                            sweepColor.withAlpha(isDark ? 45 : 160),
                            sweepColor.withAlpha(isDark ? 22 : 90),
                            sweepColor.withAlpha(0),
                          ],
                          stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
