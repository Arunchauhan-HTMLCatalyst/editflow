import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────
// TRANSITION DURATIONS
// ─────────────────────────────────────────────
const _tabDuration     = Duration(milliseconds: 220);
const _pushDuration    = Duration(milliseconds: 320);
const _sheetDuration   = Duration(milliseconds: 380);

// Helper to apply smooth animated image blur during page transitions
Widget _applyBlurTransition(Animation<double> animation, Widget child) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final double sigma = (1.0 - animation.value) * 10.0;
      if (sigma <= 0.15) return child!;
      return ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
        child: child,
      );
    },
    child: child,
  );
}

// ─────────────────────────────────────────────
// TAB SWITCH — fade only (instant, no slide)
// Used for bottom nav: Dashboard ↔ Clients ↔ Calendar ↔ Payments
// ─────────────────────────────────────────────
Page<void> fadeTabPage(Widget child) {
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: _tabDuration,
    reverseTransitionDuration: _tabDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        ),
        child: child,
      );
    },
  );
}

// ─────────────────────────────────────────────
// DETAIL PUSH — slide in from right + fade + blur
// Used for: project detail, client detail
// ─────────────────────────────────────────────
Page<void> slidePushPage(Widget child) {
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: _pushDuration,
    reverseTransitionDuration: _pushDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Incoming: slides in from right
      final slideIn = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ));

      // Outgoing: slightly slides left (parallax depth)
      final slideOut = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.25, 0.0),
      ).animate(CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeInCubic,
      ));

      final fadeIn = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
      );

      return SlideTransition(
        position: slideOut,
        child: SlideTransition(
          position: slideIn,
          child: FadeTransition(
            opacity: fadeIn,
            child: _applyBlurTransition(animation, child),
          ),
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────
// SHEET PUSH — slide up from bottom + fade + blur
// Used for: add project, add client, settings, auth screens
// ─────────────────────────────────────────────
Page<void> slideUpPage(Widget child) {
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: _sheetDuration,
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slideIn = Tween<Offset>(
        begin: const Offset(0.0, 0.06),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ));

      final fadeIn = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );

      return SlideTransition(
        position: slideIn,
        child: FadeTransition(
          opacity: fadeIn,
          child: _applyBlurTransition(animation, child),
        ),
      );
    },
  );
}
// ─────────────────────────────────────────────
// SETTINGS PUSH — slide in from right, no parallax on background + blur
// Used for: settings screen (sits outside ShellRoute so bottom nav
// disappears — the background must NOT move to avoid a visual jump)
// ─────────────────────────────────────────────
Page<void> settingsPage(Widget child) {
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: _pushDuration,
    reverseTransitionDuration: _pushDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Settings slides in from the right
      final slideIn = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ));

      final fadeIn = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
      );

      // Background dims slightly behind settings (no slide)
      final dimOut = Tween<double>(begin: 1.0, end: 0.85).animate(
        CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeInCubic,
        ),
      );

      return FadeTransition(
        opacity: dimOut,
        child: SlideTransition(
          position: slideIn,
          child: FadeTransition(
            opacity: fadeIn,
            child: _applyBlurTransition(animation, child),
          ),
        ),
      );
    },
  );
}

