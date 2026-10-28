import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrpay_bsp/main.dart';
import 'package:qrpay_bsp/data/local_store.dart';
import 'package:qrpay_bsp/payment.dart';
import 'package:qrpay_bsp/features/payment_flow.dart';

Future<void> showText(WidgetTester t, String text) async {
  await t.scrollUntilVisible(
    find.text(text),
    160,
    scrollable:
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'peer transfer saves a separate demo record and leaves purchase total zero',
    (t) async {
      final store = LocalStore.memory();
      await store.set('history', true);
      await t.pumpWidget(QrPayApp(store: store));
      await t.pumpAndSettle();
      await showText(t, 'Transfer');
      await t.tap(find.text('Transfer'));
      await t.pumpAndSettle();
      await t.tap(find.text('Review transfer').last);
      await t.pumpAndSettle();
      expect(find.text('K25.00'), findsOneWidget);
      await t.tap(find.text('Authorize demo transfer'));
      await t.pumpAndSettle();
      expect(store.items('activity').single['kind'], 'transfer');
      expect(store.items('activity').single['status'], 'demoSuccess');
      expect(store.items('activity').single['demo'], isTrue);
      await t.tap(find.text('Finish and clear session'));
      await t.pumpAndSettle();
      expect(find.text('K0.00'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
  testWidgets('history remains off by default and scan is exactly centered', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 806);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final store = LocalStore.memory();
    await t.pumpWidget(QrPayApp(store: store));
    await t.pumpAndSettle();
    expect(
      t.getCenter(find.byKey(const ValueKey('nav-2'))).dx,
      closeTo(180, .1),
    );
    await t.tap(find.text('Try a K25 demo payment'));
    await t.pumpAndSettle();
    await t.tap(find.text('Authorize demo payment'));
    await t.pumpAndSettle();
    expect(store.items('activity'), isEmpty);
    await t.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
  testWidgets(
    'saved reusable QR requires amount selection before authorization',
    (t) async {
      final store = LocalStore.memory();
      final session =
          PaymentSession()..load(
            PaymentRequest(
              merchantCode: 'TEST-1234',
              merchantName: 'Reusable',
              amountMinor: 0,
              reference: 'DEMO-static',
              expiresAt: DateTime.now().add(const Duration(days: 1)),
            ).encode(),
          );
      // Exercise inside the real app navigator so every page retains the dock.
      await t.pumpWidget(QrPayApp(store: store));
      await t.pumpAndSettle();
      final context = t.element(find.byType(Scaffold).first);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder:
              (_) => ReviewScreen(
                session: session,
                end: () => Navigator.of(context).pop(),
              ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Set amount'), findsOneWidget);
      expect(session.canSubmit, isFalse);
      await showText(t, 'Amount to send (PGK)');
      await t.enterText(find.byType(TextField), '17.50');
      await t.tap(find.text('Set amount'));
      await t.pumpAndSettle();
      expect(session.request!.amountMinor, 1750);
      expect(session.canSubmit, isTrue);
      expect(find.text('Authorize demo payment'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
}
