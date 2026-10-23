import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../bsp_channel.dart';
import '../payment.dart';
import '../app/theme.dart';
import '../shared/widgets.dart';

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
        const Icon(Icons.storefront_outlined, color: QrColors.accent, size: 44),
        const SizedBox(height: 12),
        Text(request.merchantName, style: const TextStyle(
          fontSize: 26, fontWeight: FontWeight.w600)),
        Text('Test merchant ${request.merchantCode}'),
        const SizedBox(height: 16),
        Text(request.amountLabel, style: const TextStyle(
          fontSize: 48, color: QrColors.accent, fontWeight: FontWeight.w700)),
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
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
            OutlinedButton(onPressed: handoff,
              child: const Text('Open BSP menu (assisted)')),
        ] else if (phase == PaymentPhase.processing) ...[
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          const Text('Simulating bank response… No money is moving.'),
        ] else ...[
          Icon(phase == PaymentPhase.demoSuccess ? Icons.check_circle_outline :
            Icons.info_outline, color: QrColors.accent, size: 52),
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
          child: Text(message!, style: const TextStyle(color: QrColors.error))),
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
        child: Text(error!, style: const TextStyle(color: QrColors.error))),
      if (request != null) ...[
        const SizedBox(height: 24),
        Center(child: QrImageView(data: request!.encode(), size: 220,
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

