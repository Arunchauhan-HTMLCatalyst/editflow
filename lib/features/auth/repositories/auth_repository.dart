import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/supabase_service.dart';
import '../../../core/constants/app_constants.dart';

class AuthRepository {
  Future<AuthResponse> signInWithEmail(String email, String password) =>
      SupabaseService.instance.auth.signInWithPassword(email: email, password: password);

  Future<AuthResponse> signUp(String email, String password) =>
      SupabaseService.instance.auth.signUp(email: email, password: password);

  Future<void> signOut() => SupabaseService.instance.auth.signOut();

  Future<void> resetPassword(String email) =>
      SupabaseService.instance.auth.resetPasswordForEmail(email);

  Future<void> signInWithGoogle() async {
    final String redirectTo = kIsWeb
        ? (Uri.base.origin + Uri.base.path)
        : AppConstants.supabaseRedirectUrl;

    await SupabaseService.instance.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
  }

  User? get currentUser => SupabaseService.instance.auth.currentUser;

  Session? get currentSession => SupabaseService.instance.auth.currentSession;

  Stream<AuthChangeEvent> onAuthChange() =>
      SupabaseService.instance.auth.onAuthStateChange.map((d) => d.event);
}
