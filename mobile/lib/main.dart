import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'bsp_channel.dart';
import 'payment.dart';

void main() => runApp(const QrPayApp());

const green = Color(0xFF125C47);
const paper = Color(0xFFF5F6F0);

class QrPayApp extends StatefulWidget {
  const QrPayApp({super.key});
  @override
  State<QrPayApp> createState() => _QrPayAppState();
}

class _QrPayAppState extends State<QrPayApp> with WidgetsBindingObserver {
  final navigator = GlobalKey<NavigatorState>();
  final session = PaymentSession();
  Timer? expiry;
  bool shield = false;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    touch();
  }

  void touch() {
    expiry?.cancel();
    expiry = Timer(const Duration(minutes: 2), endSession);
  }

  void endSession() {
    session.clear();
    navigator.currentState?.popUntil((route) => route.isFirst);
    if (mounted) { setState(() => generation++); }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) { setState(() => shield = state != AppLifecycleState.resumed); }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      expiry?.cancel();
      endSession();
    } else if (state == AppLifecycleState.resumed) {
      touch();
    }
  }

  @override
  void dispose() {
    expiry?.cancel();
    session.clear();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'QRpay Demo',
    navigatorKey: navigator,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: green),
      scaffoldBackgroundColor: paper,
      appBarTheme: const AppBarTheme(backgroundColor: paper),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        backgroundColor: green, minimumSize: const Size.fromHeight(54))),
    ),
    builder: (context, child) => Listener(
      onPointerDown: (_) => touch(),
      child: Stack(children: [
        child!,
        if (shield) const Positioned.fill(child: ColoredBox(color: paper)),
      ]),
    ),
    home: Home(key: ValueKey(generation), session: session, end: endSession),
  );
}

class Home extends StatelessWidget {
  final PaymentSession session;
  final VoidCallback end;
  const Home({super.key, required this.session, required this.end});

  Future<void> review(BuildContext context, String raw) async {
    try {
      session.load(raw);
      await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => ReviewScreen(session: session, end: end)));
      session.clear();
    } on FormatException catch (e) {
      if (context.mounted) { showError(context, e.message); }
    } on StateError {
      if (context.mounted) { showError(context, 'End the current session first.'); }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('QRpay'), actions: [
      TextButton(onPressed: end, child: const Text('End session')),
    ]),
    body: PageBody(children: [
      const DemoLabel(),
      const SizedBox(height: 28),
      const Text('Less typing.\nA simpler payment.', style:
        TextStyle(fontSize: 34, height: 1.1, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      const Text('BSP merchant payments • *131*6#',
        style: TextStyle(color: green, fontWeight: FontWeight.w600)),
      const SizedBox(height: 24),
      FilledButton.icon(icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan merchant QR'), onPressed: () async {
          final raw = await Navigator.of(context).push<String>(
            MaterialPageRoute(builder: (_) => const ScannerScreen()));
          if (context.mounted && raw != null) { await review(context, raw); }
        }),
      const SizedBox(height: 12),
      OutlinedButton.icon(icon: const Icon(Icons.play_arrow_outlined),
        label: const Text('Try a K25 demo payment'),
        onPressed: () => review(context, PaymentRequest.example().encode())),
      const SizedBox(height: 12),
      OutlinedButton.icon(icon: const Icon(Icons.storefront_outlined),
        label: const Text('Create a demo merchant QR'),
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const MerchantScreen()))),
      const SizedBox(height: 28),
      const InfoRow(icon: Icons.wifi_off, title: 'No mobile data needed',
        text: 'Scanning and the demo run on your phone. No server is contacted.'),
      const InfoRow(icon: Icons.lock_outline, title: 'Session only',
        text: 'No accounts, saved history, analytics, or banking credentials.'),
      const InfoRow(icon: Icons.info_outline, title: 'Prototype, not a bank app',
        text: 'Live background transfers are not connected. Do not enter a real PIN.'),
    ]),
  );
}

class ReviewScreen extends StatefulWidget {
  final PaymentSession session;
  final VoidCallback end;
  const ReviewScreen({super.key, required this.session, required this.end});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  DemoOutcome outcome = DemoOutcome.success;
  String? message;

  Future<void> confirm() async {
    try {
      final pending = widget.session.confirm(DemoBspProvider(outcome));
      setState(() {});
      await pending;
      if (mounted) { setState(() {}); }
    } on FormatException catch (e) {
      if (mounted) { setState(() => message = e.message); }
    }
  }

  Future<void> handoff() async {
    final approved = await showDialog<bool>(context: context, builder: (context) =>
      AlertDialog(title: const Text('Open the BSP menu?'), content: const Text(
        'This leaves the GUI and opens *131*6# in the Android dialler. '
        'It sends no QR details or PIN, does not dial automatically, and '
        'cannot confirm payment. This is an assisted handoff only.'), actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay here')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Open dialler')),
        ]));
    if (approved != true || !mounted) { return; }
    try { await BspChannel().openMerchantMenu(); }
    on PlatformException { if (mounted) { showError(context, 'No phone app is available.'); } }
    on MissingPluginException { if (mounted) { showError(context, 'Run Android setup first.'); } }
    on UnsupportedError { if (mounted) { showError(context, 'This handoff is Android only.'); } }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final request = session.request;
    if (request == null) { return const Scaffold(body: Center(child: Text('Session ended.'))); }
    final phase = session.phase;
    return PopScope(canPop: phase != PaymentPhase.processing, child: Scaffold(
      appBar: AppBar(title: const Text('Review payment'), actions: [
        TextButton(onPressed: widget.end, child: const Text('End session')),
      ]),
      body: PageBody(children: [
        const DemoLabel(),
        const SizedBox(height: 24),
        const Icon(Icons.storefront_outlined, color: green, size: 44),
        const SizedBox(height: 12),
        Text(request.merchantName, style: const TextStyle(
          fontSize: 26, fontWeight: FontWeight.w600)),
        Text('Test merchant ${request.merchantCode}'),
        const SizedBox(height: 16),
        Text(request.amountLabel, style: const TextStyle(
          fontSize: 48, color: green, fontWeight: FontWeight.w700)),
        const Text('PGK • BSP demo provider'),
        const SizedBox(height: 12),
        const Text('Merchant details come from an unsigned demo QR. '
          'They have not been verified by BSP.'),
        const SizedBox(height: 24),
        if (phase == PaymentPhase.review) ...[
          DropdownButtonFormField<DemoOutcome>(
            initialValue: outcome,
            decoration: const InputDecoration(labelText: 'Demo scenario'),
            items: const [
              DropdownMenuItem(value: DemoOutcome.success, child: Text('Simulated success')),
              DropdownMenuItem(value: DemoOutcome.declined, child: Text('Simulated decline')),
              DropdownMenuItem(value: DemoOutcome.unknown, child: Text('Uncertain outcome')),
            ],
            onChanged: (value) { if (value != null) { setState(() => outcome = value); } }),
          const SizedBox(height: 16),
          const Text('Authorization is simulated. No PIN is requested or sent.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: confirm, child: const Text('Authorize demo payment')),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: handoff,
            child: const Text('Android: open BSP menu (assisted)')),
        ] else if (phase == PaymentPhase.processing) ...[
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          const Text('Simulating bank response… No money is moving.'),
        ] else ...[
          Icon(phase == PaymentPhase.demoSuccess ? Icons.check_circle_outline :
            Icons.info_outline, color: green, size: 52),
          const SizedBox(height: 12),
          Text(switch (phase) {
            PaymentPhase.demoSuccess => 'Demo completed — no money moved',
            PaymentPhase.declined => 'Demo declined — no money moved',
            _ => 'Demo outcome unknown — do not retry blindly',
          }, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text('Application reference: ${session.attemptId ?? "Unavailable"}'),
          const Text('This is not a bank receipt or proof of payment.'),
          const SizedBox(height: 24),
          FilledButton(onPressed: widget.end, child: const Text('Finish and clear session')),
        ],
        if (message != null) Padding(padding: const EdgeInsets.only(top: 16),
          child: Text(message!, style: const TextStyle(color: Colors.red))),
      ]),
    ));
  }
}

class MerchantScreen extends StatefulWidget {
  const MerchantScreen({super.key});
  @override
  State<MerchantScreen> createState() => _MerchantScreenState();
}

class _MerchantScreenState extends State<MerchantScreen> {
  final name = TextEditingController(text: 'Sample Madang Store');
  final code = TextEditingController(text: 'TEST-56997');
  final amount = TextEditingController(text: '25.00');
  PaymentRequest? request;
  String? error;
  @override
  void dispose() {
    name.clear(); code.clear(); amount.clear();
    name.dispose(); code.dispose(); amount.dispose();
    request = null;
    super.dispose();
  }

  void generate() {
    try {
      final now = DateTime.now();
      final candidate = PaymentRequest(merchantCode: code.text,
        merchantName: name.text, amountMinor: parseAmount(amount.text),
        reference: 'DEMO-${now.microsecondsSinceEpoch}',
        expiresAt: now.add(const Duration(minutes: 10)));
      final validated = PaymentRequest.parse(candidate.encode());
      setState(() { request = validated; error = null; });
    } on FormatException catch (e) {
      setState(() { error = e.message; request = null; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Demo merchant QR')),
    body: PageBody(children: [
      const DemoLabel(),
      const SizedBox(height: 20),
      const Text('Display this QR on a second phone, then scan it with QRpay. '
        'Use invented test details only.'),
      const SizedBox(height: 20),
      TextField(controller: name, maxLength: 80,
        decoration: const InputDecoration(labelText: 'Demo merchant name')),
      TextField(controller: code, maxLength: 15,
        decoration: const InputDecoration(labelText: 'Test merchant code')),
      const SizedBox(height: 12),
      TextField(controller: amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Amount in kina')),
      const SizedBox(height: 20),
      FilledButton(onPressed: generate, child: const Text('Generate demo QR')),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12),
        child: Text(error!, style: const TextStyle(color: Colors.red))),
      if (request != null) ...[
        const SizedBox(height: 24),
        Center(child: QrImageView(data: request!.encode(), size: 260,
          backgroundColor: Colors.white, semanticsLabel: 'Demo merchant payment QR')),
        Text('${request!.merchantName} • ${request!.amountLabel}',
          textAlign: TextAlign.center),
        const Text('Demo only • expires in 10 minutes • not BSP verified',
          textAlign: TextAlign.center),
      ],
    ]),
  );
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool returned = false;
  @override
  void dispose() { unawaited(controller.dispose()); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan demo merchant QR')),
    body: Column(children: [
      const Padding(padding: EdgeInsets.all(16), child: Text(
        'Scan a QR generated by this prototype. Real bank QR formats are not supported.')),
      Expanded(child: MobileScanner(controller: controller, onDetect: (capture) {
        if (returned || !mounted) { return; }
        for (final barcode in capture.barcodes) {
          final raw = barcode.rawValue;
          if (raw != null) {
            returned = true;
            Navigator.of(context).pop(raw);
            break;
          }
        }
      })),
    ]),
  );
}

class PageBody extends StatelessWidget {
  final List<Widget> children;
  const PageBody({super.key, required this.children});
  @override
  Widget build(BuildContext context) => SafeArea(child: Align(
    alignment: Alignment.topCenter, child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540),
      child: ListView(padding: const EdgeInsets.all(24), children: children))));
}

class DemoLabel extends StatelessWidget {
  const DemoLabel({super.key});
  @override
  Widget build(BuildContext context) => const Row(children: [
    Icon(Icons.science_outlined, size: 20, color: green), SizedBox(width: 8),
    Expanded(child: Text('DEMO • NO REAL PAYMENTS',
      style: TextStyle(color: green, fontWeight: FontWeight.w700))),
  ]);
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const InfoRow({super.key, required this.icon, required this.title, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20), child: Row(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: green), const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4), Text(text),
        ])),
      ]));
}

void showError(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
