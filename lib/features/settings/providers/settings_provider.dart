import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/currency_config.dart';

class SettingsState {
  final CurrencyConfig currency;
  final bool isDarkMode;
  final double monthlyGoal;
  final bool isClientMode;
  final String upiId;

  const SettingsState({
    this.currency = CurrencyConfig.usd,
    this.isDarkMode = false,
    this.monthlyGoal = 10000,
    this.isClientMode = false,
    this.upiId = '',
  });

  SettingsState copyWith({
    CurrencyConfig? currency,
    bool? isDarkMode,
    double? monthlyGoal,
    bool? isClientMode,
    String? upiId,
  }) =>
      SettingsState(
        currency: currency ?? this.currency,
        isDarkMode: isDarkMode ?? this.isDarkMode,
        monthlyGoal: monthlyGoal ?? this.monthlyGoal,
        isClientMode: isClientMode ?? this.isClientMode,
        upiId: upiId ?? this.upiId,
      );
}

class SettingsProvider extends StateNotifier<SettingsState> {
  SettingsProvider() : super(const SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final currencyCode = prefs.getString('currency') ?? 'USD';
    final isDark = prefs.getBool('dark_mode') ?? false;
    final goal = prefs.getDouble('monthly_goal') ?? 10000;
    final isClient = prefs.getBool('is_client_mode') ?? false;
    
    var upi = prefs.getString('upi_id') ?? '';
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final metaUpi = user.userMetadata?['upi_id'] as String?;
        if (metaUpi != null && metaUpi.isNotEmpty) {
          upi = metaUpi;
          await prefs.setString('upi_id', upi);
        }
      }
    } catch (_) {}

    state = SettingsState(
      currency: CurrencyConfig.fromCode(currencyCode),
      isDarkMode: isDark,
      monthlyGoal: goal,
      isClientMode: isClient,
      upiId: upi,
    );
  }

  Future<void> setCurrency(CurrencyConfig currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', currency.code);
    state = state.copyWith(currency: currency);
  }

  Future<void> toggleDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !state.isDarkMode;
    await prefs.setBool('dark_mode', newValue);
    state = state.copyWith(isDarkMode: newValue);
  }

  Future<void> toggleClientMode() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !state.isClientMode;
    await prefs.setBool('is_client_mode', newValue);
    state = state.copyWith(isClientMode: newValue);
  }

  Future<void> setMonthlyGoal(double goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('monthly_goal', goal);
    state = state.copyWith(monthlyGoal: goal);
  }

  Future<void> setUpiId(String upi) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('upi_id', upi);
    state = state.copyWith(upiId: upi);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            data: {'upi_id': upi},
          ),
        );
      }
    } catch (_) {}
  }
}

final settingsProvider = StateNotifierProvider<SettingsProvider, SettingsState>((ref) {
  return SettingsProvider();
});

final currencyProvider = Provider<CurrencyConfig>((ref) {
  return ref.watch(settingsProvider).currency;
});
