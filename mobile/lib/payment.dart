import 'dart:convert';

// This schema belongs to QRpay, not BSP. Only test merchant codes are accepted
// for simulation. No PIN, bank command, account credential or URL is accepted.
class PaymentRequest {
  final String merchantCode;
  final String merchantName;
  final int amountMinor;
  final String reference;
  final DateTime expiresAt;

  const PaymentRequest({
    required this.merchantCode,
    required this.merchantName,
    required this.amountMinor,
    required this.reference,
    required this.expiresAt,
  });

  String get amountLabel =>
      'K${amountMinor ~/ 100}.${(amountMinor % 100).toString().padLeft(2, '0')}';

  String encode() => jsonEncode({
    'schema': 'qrpay-demo', 'v': 1, 'bank': 'BSP',
    'merchant': merchantCode, 'name': merchantName,
    'amountMinor': amountMinor, 'currency': 'PGK',
    'reference': reference, 'expiresAt': expiresAt.toUtc().toIso8601String(),
  });

  static PaymentRequest parse(String raw, {DateTime? now}) {
    if (utf8.encode(raw).length > 2048) {
      throw const FormatException('QR code is too large.');
    }
    dynamic value;
    try { value = jsonDecode(raw); } catch (_) {
      throw const FormatException('This is not a QRpay demo code.');
    }
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid payment data.');
    }
    const allowed = {'schema', 'v', 'bank', 'merchant', 'name',
      'amountMinor', 'currency', 'reference', 'expiresAt'};
    if (value.keys.any((key) => !allowed.contains(key)) ||
        value['schema'] != 'qrpay-demo' || value['v'] != 1 ||
        value['bank'] != 'BSP' || value['currency'] != 'PGK') {
      throw const FormatException('Unsupported payment code.');
    }
    final code = value['merchant'];
    final name = value['name'];
    final amount = value['amountMinor'];
    final reference = value['reference'];
    final expiry = value['expiresAt'];
    if (code is! String || !RegExp(r'^TEST-[0-9]{4,10}$').hasMatch(code)) {
      throw const FormatException('Use a test merchant code such as TEST-56997.');
    }
    if (name is! String || name.trim().isEmpty || name.length > 80 ||
        RegExp(r'[\x00-\x1F\x7F]').hasMatch(name)) {
      throw const FormatException('Invalid merchant name.');
    }
    if (amount is! int || amount <= 0 || amount > 1000000) {
      throw const FormatException('Demo amount must be K0.01 to K10,000.00.');
    }
    if (reference is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(reference)) {
      throw const FormatException('Invalid payment reference.');
    }
    final expiresAt = expiry is String && expiry.endsWith('Z')
        ? DateTime.tryParse(expiry) : null;
    if (expiresAt == null || !expiresAt.isAfter(now ?? DateTime.now())) {
      throw const FormatException('Payment code has expired or has no UTC expiry.');
    }
    return PaymentRequest(merchantCode: code, merchantName: name.trim(),
      amountMinor: amount, reference: reference, expiresAt: expiresAt);
  }

  static PaymentRequest example({DateTime? now}) {
    final time = now ?? DateTime.now();
    return PaymentRequest(merchantCode: 'TEST-56997',
      merchantName: 'Sample Madang Store', amountMinor: 2500,
      reference: 'DEMO-${time.microsecondsSinceEpoch}',
      expiresAt: time.add(const Duration(minutes: 10)));
  }
}

int parseAmount(String input) {
  if (!RegExp(r'^[0-9]{1,5}(\.[0-9]{1,2})?$').hasMatch(input.trim())) {
    throw const FormatException('Enter an amount such as 25.00.');
  }
  final parts = input.trim().split('.');
  final minor = int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  if (minor <= 0 || minor > 1000000) {
    throw const FormatException('Demo amount must be K0.01 to K10,000.00.');
  }
  return minor;
}

enum PaymentPhase { empty, review, processing, demoSuccess, declined, unknown }
enum DemoOutcome { success, declined, unknown }

abstract interface class PaymentProvider {
  Future<DemoOutcome> submit(PaymentRequest request, String attemptId);
}

class DemoBspProvider implements PaymentProvider {
  final DemoOutcome outcome;
  final Duration delay;
  const DemoBspProvider(this.outcome,
      {this.delay = const Duration(milliseconds: 900)});
  @override
  Future<DemoOutcome> submit(PaymentRequest request, String attemptId) async {
    await Future<void>.delayed(delay);
    return outcome;
  }
}

// No live command format is invented. Implement only after BSP documents the
// authorization, submission, idempotency and status mechanisms.
class LiveBspProvider implements PaymentProvider {
  @override
  Future<DemoOutcome> submit(PaymentRequest request, String attemptId) =>
      Future.error(UnsupportedError('Live BSP payment transport is not configured.'));
}

class PaymentSession {
  PaymentRequest? request;
  PaymentPhase phase = PaymentPhase.empty;
  String? attemptId;
  int _generation = 0;
  bool get canSubmit => phase == PaymentPhase.review;

  void load(String raw, {DateTime? now}) {
    if (phase != PaymentPhase.empty) {
      throw StateError('End the current session before loading another payment.');
    }
    request = PaymentRequest.parse(raw, now: now);
    phase = PaymentPhase.review;
  }

  Future<void> confirm(PaymentProvider provider, {DateTime? now}) async {
    if (!canSubmit || request == null) { return; }
    if (!request!.expiresAt.isAfter(now ?? DateTime.now())) {
      throw const FormatException('Payment code has expired. Scan a new code.');
    }
    final generation = _generation;
    final current = request!;
    attemptId = 'DEMO-${DateTime.now().microsecondsSinceEpoch}';
    phase = PaymentPhase.processing;
    DemoOutcome outcome;
    try {
      outcome = await provider.submit(current, attemptId!)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      outcome = DemoOutcome.unknown;
    }
    // Ending/backgrounding a session must not let a late callback restore it.
    if (generation != _generation) { return; }
    phase = switch (outcome) {
      DemoOutcome.success => PaymentPhase.demoSuccess,
      DemoOutcome.declined => PaymentPhase.declined,
      DemoOutcome.unknown => PaymentPhase.unknown,
    };
  }

  void clear() {
    _generation++;
    request = null;
    attemptId = null;
    phase = PaymentPhase.empty;
  }
}
