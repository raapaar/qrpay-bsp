import 'package:flutter/material.dart';
import 'app/qrpay_app.dart';
import 'data/local_store.dart';
export 'app/qrpay_app.dart' show QrPayApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final store = await LocalStore.open();
    runApp(QrPayApp(store: store));
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'QRpay could not open local storage. Restart the app. Your data has not been reset.',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
