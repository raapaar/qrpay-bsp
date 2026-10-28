import 'dart:ui'
    show PictureRecorder, Canvas, Paint, ImageByteFormat, BlendMode;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../app/theme.dart';
import '../bsp_channel.dart';
import '../data/local_store.dart';
import '../payment.dart';
import '../shared/widgets.dart';

class ReviewScreen extends StatefulWidget {
  final PaymentSession session;
  final VoidCallback end;
  final LocalStore? store;
  const ReviewScreen({
    super.key,
    required this.session,
    required this.end,
    this.store,
  });
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  DemoOutcome outcome = DemoOutcome.success;
  String? message;
  bool saving = false;
  final chosenAmount = TextEditingController();
  @override
  void dispose() {
    chosenAmount.dispose();
    super.dispose();
  }

  void chooseAmount() {
    try {
      final r = widget.session.request!;
      final next = PaymentRequest(
        merchantCode: r.merchantCode,
        merchantName: r.merchantName,
        amountMinor: parseAmount(chosenAmount.text),
        reference: r.reference,
        expiresAt: r.expiresAt,
        kind: r.kind,
        bank: r.bank,
        note: r.note,
      );
      setState(() {
        widget.session.request = PaymentRequest.parse(next.encode());
      });
    } on FormatException catch (e) {
      showError(context, e.message);
    }
  }

  Future<void> confirm() async {
    try {
      final pending = widget.session.confirm(DemoBspProvider(outcome));
      setState(() {});
      await pending;
      final s = widget.session;
      final r = s.request;
      if (r != null &&
          s.attemptId != null &&
          widget.store?.enabled('history') == true) {
        saving = true;
        await widget.store!.put('activity', {
          'id': s.attemptId!,
          'name': r.merchantName,
          'kind': r.kind,
          'bank': r.bank,
          'amountMinor': r.amountMinor,
          'note': r.note,
          'reference': r.reference,
          'status': s.phase.name,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'category': r.kind == 'transfer' ? 'Transfer' : 'Uncategorized',
          'demo': true,
        });
      }
      if (mounted) {
        setState(() => saving = false);
      }
    } on FormatException catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          message = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          message = 'Could not save activity. The demo was not resubmitted.';
        });
      }
    }
  }

  Future<void> handoff() async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('Open BSP banking?'),
            content: const Text(
              'The phone dialler opens *131*6#. Continue manually in the bank menu. '
              'No QR data or PIN is sent, and QRpay cannot verify the result.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Open menu'),
              ),
            ],
          ),
    );
    if (yes != true || !mounted) {
      return;
    }
    try {
      await BspChannel().openMerchantMenu();
    } catch (_) {
      if (mounted) {
        showError(context, 'Bank menu could not be opened on this device.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final r = s.request;
    if (r == null) {
      return QrScaffold(
        back: true,
        body: const Center(child: Text('Session ended.')),
      );
    }
    final ready = s.phase == PaymentPhase.review;
    final busy = s.phase == PaymentPhase.processing || saving;
    final transfer = r.kind == 'transfer';
    return PopScope(
      canPop: !busy,
      child: QrScaffold(
        back: !busy,
        actions:
            busy
                ? const SizedBox(
                  height: 52,
                  child: Center(child: CircularProgressIndicator()),
                )
                : primary(
                  ready && r.amountMinor == 0
                      ? 'Set amount'
                      : ready
                      ? (transfer
                          ? 'Authorize demo transfer'
                          : 'Authorize demo payment')
                      : 'Finish and clear session',
                  ready
                      ? (r.amountMinor == 0 ? chooseAmount : confirm)
                      : widget.end,
                ),
        body: PageBody(
          children: [
            const DemoLabel(),
            heading(
              transfer ? 'Review transfer' : 'Review payment',
              'Check the recipient and amount before you authorize.',
            ),
            panel([
              Icon(
                transfer ? Icons.person_outline : Icons.storefront_outlined,
                color: QrColors.accent,
                size: 40,
              ),
              gap(),
              Text(
                r.merchantName,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${r.bank} • ${r.merchantCode}',
                style: const TextStyle(color: QrColors.muted),
              ),
              gap(),
              Text(
                r.amountLabel,
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text('PGK • Simulated transaction'),
              if (r.note.isNotEmpty) ...[gap(), Text(r.note)],
            ]),
            const Text(
              'This unsigned demo QR does not verify recipient identity. Never enter a bank PIN in QRpay.',
            ),
            gap(),
            if (ready && r.amountMinor == 0) ...[
              TextField(
                controller: chosenAmount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount to send (PGK)',
                ),
              ),
              gap(),
            ],
            if (ready) ...[
              DropdownButtonFormField<DemoOutcome>(
                initialValue: outcome,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Demo scenario'),
                items: const [
                  DropdownMenuItem(
                    value: DemoOutcome.success,
                    child: Text('Simulated success'),
                  ),
                  DropdownMenuItem(
                    value: DemoOutcome.declined,
                    child: Text('Simulated decline'),
                  ),
                  DropdownMenuItem(
                    value: DemoOutcome.unknown,
                    child: Text('Uncertain outcome'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => outcome = v);
                  }
                },
              ),
              gap(),
              Text(
                widget.store?.enabled('history') == true
                    ? 'Demo activity will be saved on this phone.'
                    : 'History is off. This session will not be saved.',
              ),
              if (!kIsWeb &&
                  defaultTargetPlatform == TargetPlatform.android &&
                  !transfer &&
                  r.bank == 'BSP') ...[
                gap(),
                OutlinedButton(
                  onPressed: handoff,
                  child: const Text('Open BSP menu (assisted)'),
                ),
              ],
            ] else if (!busy) ...[
              Text(
                switch (s.phase) {
                  PaymentPhase.demoSuccess => 'Demo completed — no money moved',
                  PaymentPhase.declined => 'Demo declined — no money moved',
                  _ => 'Demo outcome unknown — do not retry blindly',
                },
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              gap(),
              Text('Application reference: ${s.attemptId ?? "Unavailable"}'),
              const Text('This is not a bank receipt.'),
            ],
            if (message != null) ...[
              gap(),
              Text(message!, style: const TextStyle(color: QrColors.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class MerchantScreen extends StatefulWidget {
  final LocalStore? store;
  final bool personal;
  final PaymentRequest? saved;
  final bool transferEntry;
  final void Function(String)? onReview;
  const MerchantScreen({
    super.key,
    this.store,
    this.personal = false,
    this.saved,
    this.transferEntry = false,
    this.onReview,
  });
  @override
  State<MerchantScreen> createState() => _MerchantScreenState();
}

class _MerchantScreenState extends State<MerchantScreen> {
  late final name = TextEditingController(
    text:
        widget.saved?.merchantName ??
        (widget.personal ? 'Sample recipient' : 'Sample Madang Store'),
  );
  late final code = TextEditingController(
    text: widget.saved?.merchantCode ?? 'TEST-56997',
  );
  late final amount = TextEditingController(
    text:
        widget.saved == null
            ? '25.00'
            : '${widget.saved!.amountMinor ~/ 100}.${(widget.saved!.amountMinor % 100).toString().padLeft(2, '0')}',
  );
  late final note = TextEditingController(text: widget.saved?.note ?? '');
  late String bank = widget.saved?.bank ?? 'BSP';
  PaymentRequest? request;
  String? error;
  bool working = false;
  bool reusable = false;
  int expiryMinutes = 10;
  @override
  void initState() {
    super.initState();
    request = widget.saved;
    reusable = widget.saved?.amountMinor == 0;
  }

  @override
  void dispose() {
    for (final c in [name, code, amount, note]) {
      c.dispose();
    }
    super.dispose();
  }

  void generate() {
    try {
      final now = DateTime.now();
      final candidate = PaymentRequest(
        merchantCode: code.text.trim(),
        merchantName: name.text.trim(),
        amountMinor:
            reusable && !widget.transferEntry ? 0 : parseAmount(amount.text),
        reference: 'DEMO-${newId()}',
        expiresAt: now.add(Duration(minutes: expiryMinutes)),
        bank: bank,
        note: note.text.trim(),
        kind: widget.personal ? 'transfer' : 'pay',
      );
      final checked = PaymentRequest.parse(candidate.encode());
      if (widget.transferEntry) {
        widget.onReview?.call(checked.encode());
        return;
      }
      setState(() {
        request = checked;
        error = null;
      });
    } on FormatException catch (e) {
      setState(() {
        error = e.message;
        request = null;
      });
    }
  }

  Future<void> save() async {
    if (request == null || widget.store == null) {
      return;
    }
    await safeWork(() async {
      await widget.store!.put('qrs', {
        'id': request!.reference,
        'raw': request!.encode(),
        'name': request!.merchantName,
        'kind': request!.kind,
        'amountMinor': request!.amountMinor,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) {
        showError(context, 'QR saved to your inventory.');
      }
    });
  }

  Future<void> safeWork(Future<void> Function() work) async {
    setState(() => working = true);
    try {
      await work();
    } catch (_) {
      if (mounted) {
        showError(context, 'Could not complete the action. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => working = false);
      }
    }
  }

  Future<void> exportPng() => safeWork(() async {
    // Render an explicit quiet zone around the modules for printed scanning.
    final image = await QrPainter(
      data: request!.encode(),
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    ).toImage(900);
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    canvas.drawImage(image, const Offset(62, 62), Paint());
    final out = await recorder.endRecording().toImage(1024, 1024);
    final bytes = await out.toByteData(format: ImageByteFormat.png);
    image.dispose();
    out.dispose();
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes!.buffer.asUint8List(), mimeType: 'image/png'),
        ],
        fileNameOverrides: ['QRpay-demo.png'],
        text:
            'QRpay DEMO — no real payments. Check the expiry shown in the app.',
      ),
    );
  });
  Future<void> exportPdf() => safeWork(() async {
    final r = request!;
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build:
            (_) => pw.Column(
              children: [
                pw.Text(
                  'QRpay DEMO',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(r.merchantName),
                pw.Text('${r.bank} | ${r.merchantCode}'),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(30),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: r.encode(),
                    width: 240,
                    height: 240,
                  ),
                ),
                pw.Text(r.amountLabel),
                pw.SizedBox(height: 15),
                pw.Text(
                  'NO MONEY MOVES. Not bank verified.\nExpires: ${r.expiresAt.toUtc().toIso8601String()}',
                ),
                pw.Text(
                  'Printed QR codes cannot be remotely revoked while offline.',
                ),
              ],
            ),
      ),
    );
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'QRpay-demo.pdf',
    );
  });
  @override
  Widget build(BuildContext context) => QrScaffold(
    back: true,
    actions:
        working
            ? const Center(child: CircularProgressIndicator())
            : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                primary(
                  widget.transferEntry ? 'Review transfer' : 'Generate demo QR',
                  generate,
                ),
                if (request != null && !widget.transferEntry) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      if (widget.store != null)
                        TextButton(
                          onPressed: save,
                          child: const Text('Save QR'),
                        ),
                      TextButton(
                        onPressed: exportPng,
                        child: const Text('Export PNG'),
                      ),
                      TextButton(
                        onPressed: exportPdf,
                        child: const Text('Print / PDF'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    body: PageBody(
      children: [
        const DemoLabel(),
        heading(
          widget.transferEntry
              ? 'Transfer to a peer'
              : widget.personal
              ? 'My receiving QR'
              : 'Create a vendor QR',
          'Use invented test details. All banks listed here are simulation labels.',
        ),
        TextField(
          controller: name,
          maxLength: 80,
          decoration: InputDecoration(
            labelText:
                widget.personal ? 'Recipient name' : 'Demo merchant name',
          ),
        ),
        gap(),
        TextField(
          controller: code,
          maxLength: 15,
          decoration: const InputDecoration(
            labelText: 'Test receiving code',
            helperText: 'Example: TEST-56997',
          ),
        ),
        gap(),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: bank,
          decoration: const InputDecoration(labelText: 'Bank (demo)'),
          items: const [
            DropdownMenuItem(value: 'BSP', child: Text('BSP')),
            DropdownMenuItem(value: 'KINA', child: Text('Kina Bank')),
            DropdownMenuItem(value: 'OTHER', child: Text('Other bank')),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() {
                bank = v;
                request = null;
              });
            }
          },
        ),
        gap(),
        if (!widget.transferEntry) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Let the sender choose the amount'),
            value: reusable,
            onChanged:
                (v) => setState(() {
                  reusable = v;
                  request = null;
                }),
          ),
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: expiryMinutes,
            decoration: const InputDecoration(labelText: 'QR validity'),
            items: const [
              DropdownMenuItem(value: 10, child: Text('10 minutes')),
              DropdownMenuItem(value: 1440, child: Text('24 hours')),
              DropdownMenuItem(
                value: 43200,
                child: Text('30 days (reusable demo)'),
              ),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  expiryMinutes = v;
                  request = null;
                });
              }
            },
          ),
          gap(),
        ],
        if (!reusable || widget.transferEntry)
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount in kina'),
          ),
        gap(),
        TextField(
          controller: note,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
          ),
        ),
        gap(),
        if (error != null)
          Text(error!, style: const TextStyle(color: QrColors.error)),
        if (request != null) ...[
          Center(
            child: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: QrImageView(
                  data: request!.encode(),
                  size: 200,
                  backgroundColor: Colors.white,
                  semanticsLabel: 'Demo merchant payment QR',
                ),
              ),
            ),
          ),
          gap(),
          Text(
            '${request!.merchantName} • ${request!.amountLabel}',
            textAlign: TextAlign.center,
          ),
          Text(
            'Demo only • expires ${request!.expiresAt.toLocal()} • not BSP verified',
            textAlign: TextAlign.center,
          ),
          const Text(
            'Editing fields does not change this QR until you generate again.',
          ),
        ],
      ],
    ),
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
  void dispose() {
    unawaited(controller.dispose());
    super.dispose();
  }

  Future<void> control(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        showError(context, 'Camera control unavailable.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => QrScaffold(
    back: true,
    actions: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          tooltip: 'Flash',
          icon: const Icon(Icons.flash_on_outlined),
          onPressed: () => control(controller.toggleTorch),
        ),
        IconButton(
          tooltip: 'Switch camera',
          icon: const Icon(Icons.cameraswitch_outlined),
          onPressed: () => control(controller.switchCamera),
        ),
        TextButton(
          onPressed: () => Navigator.maybePop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Scan a QRpay demo code. Scanning never authorizes a payment.',
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              MobileScanner(
                controller: controller,
                errorBuilder:
                    (c, e) => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Camera unavailable. Allow camera access in Android Settings, then reopen Scan.',
                        ),
                      ),
                    ),
                onDetect: (capture) {
                  if (returned || !mounted) {
                    return;
                  }
                  for (final barcode in capture.barcodes) {
                    if (barcode.rawValue != null) {
                      returned = true;
                      Navigator.pop(context, barcode.rawValue);
                      break;
                    }
                  }
                },
              ),
              IgnorePointer(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    border: Border.all(color: QrColors.accent, width: 3),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
