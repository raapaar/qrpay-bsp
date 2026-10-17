import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrpay_bsp/main.dart';

void main() {
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