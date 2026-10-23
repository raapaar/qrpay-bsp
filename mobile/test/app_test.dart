import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrpay_bsp/main.dart';

void main() {
  navigationTests();
  testWidgets(
    'demo authorizes without a credential field and clears on finish',
    (tester) async {
      await tester.pumpWidget(const QrPayApp());

      await tester.tap(find.text('Try a K25 demo payment'));
      await tester.pumpAndSettle();

      expect(find.text('K25.00'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      // Scroll until the lazily built button becomes available.
      await tester.scrollUntilVisible(
        find.text('Authorize demo payment'),
        200,
        scrollable: find.byType(Scrollable).last,
      );

      await tester.tap(find.text('Authorize demo payment'));
      await tester.pumpAndSettle();

      expect(
        find.text('Demo completed — no money moved'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('Finish and clear session'),
        200,
        scrollable: find.byType(Scrollable).last,
      );

      await tester.tap(find.text('Finish and clear session'));
      await tester.pumpAndSettle();

      expect(find.text('Try a K25 demo payment'), findsOneWidget);
      expect(find.text('K25.00'), findsNothing);

      // Dispose the app and cancel its inactivity timer.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'backgrounding clears payment session',
    (tester) async {
      await tester.pumpWidget(const QrPayApp());

      await tester.tap(find.text('Try a K25 demo payment'));
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pumpAndSettle();

      expect(find.text('K25.00'), findsNothing);
      expect(find.text('Try a K25 demo payment'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
// Exercise the public navigation and QR creation at a narrow phone size.
void navigationTests() {
  testWidgets('bottom tabs and vendor generator work on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const QrPayApp());
    await tester.pumpAndSettle();
    for (final tab in ['Scan', 'Activity', 'Vendor', 'Profile', 'Home']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Vendor'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Create a demo merchant QR'), 180,
      scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Create a demo merchant QR'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Generate demo QR'), 180,
      scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Generate demo QR'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('expires in 10 minutes'), 180,
      scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('expires in 10 minutes'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
