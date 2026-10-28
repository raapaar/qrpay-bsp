import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrpay_bsp/payment.dart';

class ControlledProvider implements PaymentProvider {
  int calls = 0;
  final pending = Completer<DemoOutcome>();
  @override
  Future<DemoOutcome> submit(PaymentRequest request, String attemptId) {
    calls++;
    return pending.future;
  }
}

void main() {
  final now = DateTime.utc(2026, 10, 17);
  String sample() => PaymentRequest.example(now: now).encode();
  Map<String, dynamic> payload() =>
      jsonDecode(sample()) as Map<String, dynamic>;

  test(
    'PGK amounts use exact minor units and reject exponent/fraction overflow',
    () {
      expect(parseAmount('25.10'), 2510);
      expect(parseAmount('0.01'), 1);
      expect(parseAmount('10000.00'), 1000000);
      for (final invalid in ['0', '-1', '1.001', '1e3', 'NaN', '10000.01']) {
        expect(() => parseAmount(invalid), throwsFormatException);
      }
    },
  );

  test('QR roundtrip preserves recipient, currency amount and reference', () {
    final parsed = PaymentRequest.parse(sample(), now: now);
    expect(parsed.amountLabel, 'K25.00');
    expect(parsed.merchantCode, 'TEST-56997');
    expect(parsed.encode(), sample());
  });

  test(
    'QR rejects bank commands, credential fields and real merchant codes',
    () {
      for (final change in <Map<String, dynamic>>[
        {'pin': '0000'},
        {'command': '*131*6#'},
        {'merchant': '56997'},
        {'bank': 'KINA'},
        {'currency': 'USD'},
        {'v': 2},
        {'name': 'Store\nPay someone else'},
        {'amountMinor': 25.5},
        {'amountMinor': -1},
        {'reference': 'ref\nInjected'},
      ]) {
        expect(
          () => PaymentRequest.parse(
            jsonEncode({...payload(), ...change}),
            now: now,
          ),
          throwsFormatException,
        );
      }
    },
  );

  test('QR rejects oversized, malformed and expired data', () {
    for (final raw in [
      'not json',
      '[]',
      List.filled(2049, 'x').join(),
      jsonEncode({...payload(), 'expiresAt': now.toIso8601String()}),
    ]) {
      expect(() => PaymentRequest.parse(raw, now: now), throwsFormatException);
    }
  });

  test('double confirm invokes provider only once', () async {
    final session = PaymentSession()..load(sample(), now: now);
    final provider = ControlledProvider();
    final first = session.confirm(provider, now: now);
    await session.confirm(provider, now: now);
    expect(provider.calls, 1);
    provider.pending.complete(DemoOutcome.success);
    await first;
    expect(session.phase, PaymentPhase.demoSuccess);
    await session.confirm(provider, now: now);
    expect(provider.calls, 1);
  });

  test(
    'clear prevents late callback from restoring sensitive session',
    () async {
      final session = PaymentSession()..load(sample(), now: now);
      final provider = ControlledProvider();
      final pending = session.confirm(provider, now: now);
      session.clear();
      provider.pending.complete(DemoOutcome.success);
      await pending;
      expect(session.phase, PaymentPhase.empty);
      expect(session.request, isNull);
      expect(session.attemptId, isNull);
    },
  );

  test('cannot replace an in-flight payment by scanning again', () async {
    final session = PaymentSession()..load(sample(), now: now);
    final provider = ControlledProvider();
    final pending = session.confirm(provider, now: now);
    expect(() => session.load(sample(), now: now), throwsStateError);
    provider.pending.complete(DemoOutcome.unknown);
    await pending;
    expect(session.phase, PaymentPhase.unknown);
    expect(session.canSubmit, isFalse);
  });

  test('expiry is rechecked on confirm', () async {
    final session = PaymentSession()..load(sample(), now: now);
    final provider = ControlledProvider();
    await expectLater(
      session.confirm(provider, now: now.add(const Duration(minutes: 11))),
      throwsFormatException,
    );
    expect(provider.calls, 0);
  });

  test('live provider cannot fabricate a success', () async {
    await expectLater(
      LiveBspProvider().submit(PaymentRequest.example(now: now), 'test'),
      throwsUnsupportedError,
    );
  });

  test('decline and unknown remain distinct non-success outcomes', () async {
    for (final outcome in [DemoOutcome.declined, DemoOutcome.unknown]) {
      final session = PaymentSession()..load(sample(), now: now);
      await session.confirm(
        DemoBspProvider(outcome, delay: Duration.zero),
        now: now,
      );
      expect(
        session.phase,
        outcome == DemoOutcome.declined
            ? PaymentPhase.declined
            : PaymentPhase.unknown,
      );
      expect(session.canSubmit, isFalse);
    }
  });
}
