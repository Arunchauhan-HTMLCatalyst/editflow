import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/currency_config.dart';

class SettingsState {
  final CurrencyConfig currency;
  final bool isDarkMode;
  final double monthlyGoal;

  const SettingsState({
    this.currency = CurrencyConfig.usd,
    this.isDarkMode = false,
    this.monthlyGoal = 10000,
  });

  SettingsState copyWith({CurrencyConfig? currency, bool? isDarkMode, double? monthlyGoal}) =>
      SettingsState(
        currency: currency ?? this.currency,
        isDarkMode: isDarkMode ?? this.isDarkMode,
        monthlyGoal: monthlyGoal ?? this.monthlyGoal,
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
    state = SettingsState(
      currency: CurrencyConfig.fromCode(currencyCode),
      isDarkMode: isDark,
      monthlyGoal: goal,
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

  Future<void> setMonthlyGoal(double goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('monthly_goal', goal);
    state = state.copyWith(monthlyGoal: goal);
  }
}

final settingsProvider = StateNotifierProvider<SettingsProvider, SettingsState>((ref) {
  return SettingsProvider();
});

final currencyProvider = Provider<CurrencyConfig>((ref) {
  return ref.watch(settingsProvider).currency;
});
