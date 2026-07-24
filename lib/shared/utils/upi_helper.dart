import 'package:flutter/foundation.dart';

String buildFlexibleUpiUrl({
  required String upiInput,
  required double amount,
  required String payeeName,
  required String projectName,
  bool isAndroidIntent = false,
}) {
  final cleanInput = upiInput.trim();
  final nameEnc = Uri.encodeComponent(payeeName);
  final noteEnc = Uri.encodeComponent('Payment for $projectName');
  final amStr = amount.toStringAsFixed(2);

  // If the input is NOT a URL but a simple UPI ID (e.g., payee@bank)
  if (!cleanInput.startsWith('upi://') && !cleanInput.startsWith('intent://') && !cleanInput.contains('?pa=')) {
    if (isAndroidIntent) {
      return 'intent://pay?pa=$cleanInput&pn=$nameEnc&am=$amStr&cu=INR&tn=$noteEnc#Intent;scheme=upi;end';
    }
    return 'upi://pay?pa=$cleanInput&pn=$nameEnc&am=$amStr&cu=INR&tn=$noteEnc';
  }

  // If the input is already a URL (e.g. upi://pay?pa=abc@okbiz&mcc=123&mam=456)
  // Let's parse it and replace/append parameters!
  String baseUrl = cleanInput;
  String suffix = '';

  // Extract Android intent suffix if present
  if (cleanInput.contains('#Intent;')) {
    final parts = cleanInput.split('#Intent;');
    baseUrl = parts[0];
    suffix = '#Intent;' + parts[1];
  } else if (isAndroidIntent) {
    // If we need Android intent and none is present, add the default suffix
    suffix = '#Intent;scheme=upi;end';
  }

  // Convert schema between upi:// and intent:// depending on platform
  if (isAndroidIntent) {
    if (baseUrl.startsWith('upi://pay')) {
      baseUrl = baseUrl.replaceFirst('upi://pay', 'intent://pay');
    }
  } else {
    if (baseUrl.startsWith('intent://pay')) {
      baseUrl = baseUrl.replaceFirst('intent://pay', 'upi://pay');
    }
  }

  try {
    final uri = Uri.parse(baseUrl);
    final params = Map<String, String>.from(uri.queryParameters);

    // Set or overwrite amount, transaction note, payee name, and currency
    params['am'] = amStr;
    if (!params.containsKey('cu')) {
      params['cu'] = 'INR';
    }
    if (!params.containsKey('pn')) {
      params['pn'] = payeeName;
    }
    if (!params.containsKey('tn')) {
      params['tn'] = 'Payment for $projectName';
    }

    // Reconstruct query parameters
    final newQuery = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    
    // Reconstruct full URL
    final host = isAndroidIntent ? 'intent://pay' : 'upi://pay';
    return '$host?$newQuery$suffix';
  } catch (_) {
    // Fallback if parsing fails
    return cleanInput;
  }
}
