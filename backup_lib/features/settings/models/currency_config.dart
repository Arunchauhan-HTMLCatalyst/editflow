class CurrencyConfig {
  final String code;
  final String symbol;
  final String name;
  final int decimalDigits;

  const CurrencyConfig({
    required this.code,
    required this.symbol,
    required this.name,
    this.decimalDigits = 2,
  });

  static const List<CurrencyConfig> supported = [
    CurrencyConfig(code: 'USD', symbol: '\$', name: 'US Dollar'),
    CurrencyConfig(code: 'EUR', symbol: '€', name: 'Euro'),
    CurrencyConfig(code: 'GBP', symbol: '£', name: 'British Pound'),
    CurrencyConfig(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
    CurrencyConfig(code: 'JPY', symbol: '¥', name: 'Japanese Yen', decimalDigits: 0),
    CurrencyConfig(code: 'CAD', symbol: 'CA\$', name: 'Canadian Dollar'),
    CurrencyConfig(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar'),
    CurrencyConfig(code: 'BRL', symbol: 'R\$', name: 'Brazilian Real'),
    CurrencyConfig(code: 'CHF', symbol: 'CHF', name: 'Swiss Franc'),
    CurrencyConfig(code: 'CNY', symbol: '¥', name: 'Chinese Yuan'),
    CurrencyConfig(code: 'NZD', symbol: 'NZ\$', name: 'New Zealand Dollar'),
    CurrencyConfig(code: 'SEK', symbol: 'kr', name: 'Swedish Krona'),
    CurrencyConfig(code: 'KRW', symbol: '₩', name: 'South Korean Won', decimalDigits: 0),
    CurrencyConfig(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar'),
    CurrencyConfig(code: 'NOK', symbol: 'kr', name: 'Norwegian Krone'),
    CurrencyConfig(code: 'MXN', symbol: 'MX\$', name: 'Mexican Peso'),
    CurrencyConfig(code: 'ZAR', symbol: 'R', name: 'South African Rand'),
    CurrencyConfig(code: 'TRY', symbol: '₺', name: 'Turkish Lira'),
    CurrencyConfig(code: 'RUB', symbol: '₽', name: 'Russian Ruble'),
    CurrencyConfig(code: 'PLN', symbol: 'zł', name: 'Polish Zloty'),
  ];

  static const usd = CurrencyConfig(code: 'USD', symbol: '\$', name: 'US Dollar');

  static CurrencyConfig fromCode(String code) =>
      supported.firstWhere((c) => c.code == code, orElse: () => usd);

  String format(double amount) {
    final negative = amount < 0;
    final abs = amount.abs();
    final formatted = abs.toStringAsFixed(decimalDigits);
    if (code == 'EUR') return '${negative ? '-' : ''}${symbol}${formatted}';
    if (code == 'JPY' || code == 'KRW') return '${negative ? '-' : ''}${symbol}${abs.toStringAsFixed(0)}';
    return '${negative ? '-' : ''}${symbol}${formatted}';
  }

  String formatShort(double amount) {
    final abs = amount.abs();
    if (abs >= 1000000) {
      return '${format(abs / 1000000)}M';
    }
    if (abs >= 1000) {
      return '${format(abs / 1000)}K';
    }
    return format(amount);
  }
}
