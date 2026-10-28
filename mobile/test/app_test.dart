import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrpay_bsp/main.dart';

Future<void> scrollToText(
  WidgetTester tester,
  Finder finder,
) async {
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

Future<void> openDemoPayment(WidgetTester tester) async {
  final button = find.text('Try a K25 demo payment');

  await scrollToText(tester, button);
  expect(button.hitTestable(), findsOneWidget);

  await tester.tap(button);
  await tester.pumpAndSettle();

  expect(find.text('K25.00'), findsOneWidget);
}

void main() {
  testWidgets(
    'demo authorizes without a credential field and clears on finish',
    (tester) async {
      await tester.pumpWidget(const QrPayApp());
      await tester.pumpAndSettle();

      await openDemoPayment(tester);

      expect(find.byType(TextField), findsNothing);

      final authorize = find.text('Authorize demo payment');
      await scrollToText(tester, authorize);

      expect(authorize.hitTestable(), findsOneWidget);
      await tester.tap(authorize);
      await tester.pumpAndSettle();

      expect(
        find.text('Demo completed — no money moved'),
        findsOneWidget,
      );

      final finish = find.text('Finish and clear session');
      await scrollToText(tester, finish);

      expect(finish.hitTestable(), findsOneWidget);
      await tester.tap(finish);
      await tester.pumpAndSettle();

      await scrollToText(
        tester,
        find.text('Try a K25 demo payment'),
      );

      expect(
        find.text('Try a K25 demo payment').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('K25.00'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'backgrounding clears payment session',
    (tester) async {
      await tester.pumpWidget(const QrPayApp());
      await tester.pumpAndSettle();

      await openDemoPayment(tester);

      // Confirm a payment exists before testing session clearing.
      expect(find.text('K25.00'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pumpAndSettle();

      expect(find.text('K25.00'), findsNothing);

      await scrollToText(
        tester,
        find.text('Try a K25 demo payment'),
      );

      expect(
        find.text('Try a K25 demo payment').hitTestable(),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'bottom tabs and vendor generator work on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const QrPayApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      for (final tab in [
        'Scan',
        'Activity',
        'Vendor',
        'Profile',
        'Home',
      ]) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      }

      await tester.tap(find.text('Vendor'));
      await tester.pumpAndSettle();

      final create = find.text('Create a demo merchant QR');
      await scrollToText(tester, create);

      expect(create.hitTestable(), findsOneWidget);
      await tester.tap(create);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final generate = find.text('Generate demo QR');
      await scrollToText(tester, generate);

      expect(generate.hitTestable(), findsOneWidget);
      await tester.tap(generate);
      await tester.pumpAndSettle();

      final expiry = find.textContaining('expires in 10 minutes');
      await scrollToText(tester, expiry);

      expect(expiry, findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}