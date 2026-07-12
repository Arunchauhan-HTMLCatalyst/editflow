import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/foreground_service.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.uninitialized,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, User? user, String? error}) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
      );
}

class AuthProvider extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription? _authSubscription;

  AuthProvider(this._authRepository) : super(const AuthState()) {
    _init();
  }

  Future<void> _syncProfile(User user) async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      if (response == null) {
        await Supabase.instance.client.from('profiles').insert({
          'id': user.id,
          'full_name': user.userMetadata?['full_name'] ?? 'User',
          'email': user.email,
        });
        debugPrint('[AUTH SYNC] Created missing profile for user ${user.id}');
      }
    } catch (e) {
      debugPrint('[AUTH SYNC] Failed to sync profile: $e');
    }
  }

  void _startForegroundServiceIfNeeded() {
    if (!kIsWeb && Platform.isAndroid) {
      unawaited(EditFlowForegroundService.start());
    }
  }

  void _stopForegroundServiceIfNeeded() {
    if (!kIsWeb && Platform.isAndroid) {
      unawaited(EditFlowForegroundService.stop());
    }
  }

  void _init() {
    try {
      final session = _authRepository.currentSession;
      debugPrint('[AUTH PROVIDER] _init: currentSession is ${session != null ? "active" : "null"}');
      if (session != null) {
        final currentUser = _authRepository.currentUser;
        state = AuthState(
          status: AuthStatus.authenticated,
          user: currentUser,
        );
        _startForegroundServiceIfNeeded();
        if (currentUser != null) {
          unawaited(_syncProfile(currentUser));
        }
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
      
      debugPrint('[AUTH PROVIDER] _init: subscribing to onAuthChange');
      _authSubscription = _authRepository.onAuthChange().listen((event) {
        debugPrint('[AUTH PROVIDER] onAuthChange event received: $event');
        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.tokenRefreshed) {
          final user = _authRepository.currentUser;
          debugPrint('[AUTH PROVIDER] user is ${user?.id}');
          if (user != null) {
            state = AuthState(
              status: AuthStatus.authenticated,
              user: user,
            );
            _startForegroundServiceIfNeeded();
            unawaited(_syncProfile(user));
          }
        } else if (event == AuthChangeEvent.signedOut) {
          state = const AuthState(status: AuthStatus.unauthenticated);
          _stopForegroundServiceIfNeeded();
        }
      }, onError: (e, st) {
        debugPrint('[AUTH PROVIDER] error in onAuthChange subscription: $e\n$st');
      });
    } catch (e, st) {
      debugPrint('[AUTH PROVIDER] exception during _init: $e\n$st');
    }
  }

  Future<void> signIn(String email, String password) async {
    debugPrint('[AUTH PROVIDER] signIn started for email: $email');
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final response = await _authRepository.signInWithEmail(email, password);
      debugPrint('[AUTH PROVIDER] signIn successful: user=${response.user?.id}');
      state = AuthState(
        status: AuthStatus.authenticated,
        user: response.user,
      );
      if (response.user != null) {
        unawaited(_syncProfile(response.user!));
      }
    } on AuthException catch (e, st) {
      debugPrint('[AUTH PROVIDER] signIn AuthException: ${e.message}\n$st');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.message,
      );
    } catch (e, st) {
      debugPrint('[AUTH PROVIDER] signIn unexpected exception: $e\n$st');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
    }
  }

  Future<void> signUp(String email, String password) async {
    debugPrint('[AUTH PROVIDER] signUp started for email: $email');
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final response = await _authRepository.signUp(email, password);
      debugPrint('[AUTH PROVIDER] signUp response received. Identities: ${response.user?.identities?.length}');
      if (response.user?.identities?.isEmpty ?? true) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: 'An account with this email already exists.',
        );
      } else {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: response.user,
        );
        if (response.user != null) {
          unawaited(_syncProfile(response.user!));
        }
      }
    } on AuthException catch (e, st) {
      debugPrint('[AUTH PROVIDER] signUp AuthException: ${e.message}\n$st');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.message,
      );
    } catch (e, st) {
      debugPrint('[AUTH PROVIDER] signUp unexpected exception: $e\n$st');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
    }
  }

  Future<void> signInWithGoogle() async {
    debugPrint('[AUTH PROVIDER] signInWithGoogle started');
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      await _authRepository.signInWithGoogle();
      debugPrint('[AUTH PROVIDER] signInWithGoogle (auth screen launch) call completed');
    } catch (e, st) {
      debugPrint('[AUTH PROVIDER] signInWithGoogle failed: $e\n$st');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
    }
  }

  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('cached_')) {
          await prefs.remove(key);
        }
      }
      debugPrint('[AUTH SIGNOUT] Cleared local storage caches successfully');
    } catch (e) {
      debugPrint('[AUTH SIGNOUT] Failed to clear caches: $e');
    }
    _stopForegroundServiceIfNeeded();
    await _authRepository.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> resetPassword(String email) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      await _authRepository.resetPassword(email);
      state = state.copyWith(status: AuthStatus.unauthenticated);
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authProvider = StateNotifierProvider<AuthProvider, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthProvider(repo);
});
