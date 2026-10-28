import 'dart:async';

import 'package:flutter/material.dart';

import '../features/payment_flow.dart';
import '../payment.dart';
import '../shared/widgets.dart';
import 'theme.dart';

class QrPayApp extends StatefulWidget {
  const QrPayApp({super.key});

  @override
  State<QrPayApp> createState() => _QrPayAppState();
}

class _QrPayAppState extends State<QrPayApp>
    with WidgetsBindingObserver {
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

    if (mounted) {
      setState(() => generation++);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) {
      setState(() => shield = state != AppLifecycleState.resumed);
    }

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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QRpay Demo',
      navigatorKey: navigator,
      debugShowCheckedModeBanner: false,
      theme: buildQrTheme(),
      builder: (context, child) {
        return Listener(
          onPointerDown: (_) => touch(),
          child: Stack(
            children: [
              child!,
              if (shield)
                const Positioned.fill(
                  child: ColoredBox(color: QrColors.background),
                ),
            ],
          ),
        );
      },
      home: AppShell(
        key: ValueKey(generation),
        session: session,
        end: endSession,
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  final PaymentSession session;
  final VoidCallback end;

  const AppShell({
    super.key,
    required this.session,
    required this.end,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int tab = 0;

  static const labels = [
    'Home',
    'Scan',
    'Activity',
    'Vendor',
    'Profile',
  ];

  static const icons = [
    Icons.home_outlined,
    Icons.qr_code_scanner,
    Icons.receipt_long_outlined,
    Icons.storefront_outlined,
    Icons.person_outline,
  ];

  Future<void> review(String raw) async {
    try {
      widget.session.load(raw);

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ReviewScreen(
            session: widget.session,
            end: widget.end,
          ),
        ),
      );

      widget.session.clear();
    } on FormatException catch (e) {
      if (mounted) {
        showError(context, e.message);
      }
    } on StateError {
      if (mounted) {
        showError(context, 'End the current session first.');
      }
    }
  }

  Future<void> scan() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(),
      ),
    );

    if (mounted && raw != null) {
      await review(raw);
    }
  }

  void merchant() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const MerchantScreen(),
      ),
    );
  }

  Widget heading(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 32,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: const TextStyle(
              color: QrColors.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget panel(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: QrColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: QrColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // Wrap allows long button labels to move below the icon on narrow screens.
  Widget buttonContent(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          Icon(icon),
          Text(
            label,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Widget> home() {
    return [
      const DemoLabel(),
      heading(
        'Your money.\nFewer steps.',
        'Scan a code. Check the details. Stay in control.',
      ),
      panel([
        const Text(
          'READY WHEN YOU ARE',
          style: TextStyle(
            color: QrColors.muted,
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'A simpler way\nto pay.',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: scan,
          child: buttonContent(
            Icons.qr_code_scanner,
            'Scan & Pay',
          ),
        ),
      ]),
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: () => review(PaymentRequest.example().encode()),
        child: buttonContent(
          Icons.play_arrow_outlined,
          'Try a K25 demo payment',
        ),
      ),
      const SizedBox(height: 30),
      const InfoRow(
        icon: Icons.wifi_off,
        title: 'Made for offline use',
        text: 'Scan, generate QR codes and try simulated payments '
            'without mobile data.',
      ),
      const InfoRow(
        icon: Icons.lock_outline,
        title: 'You stay in control',
        text: 'Review every request before authorizing. '
            'No banking PIN is collected.',
      ),
      const InfoRow(
        icon: Icons.cloud_off_outlined,
        title: 'Local demo',
        text: 'Online accounts and synchronization are not connected yet.',
      ),
    ];
  }

  List<Widget> scanPage() {
    return [
      const DemoLabel(),
      heading(
        'Scan. Review. Pay.',
        'Use a QR generated by this demo on another phone.',
      ),
      panel([
        const Center(
          child: Icon(
            Icons.qr_code_scanner,
            size: 88,
            color: QrColors.accent,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: scan,
          child: buttonContent(
            Icons.camera_alt_outlined,
            'Open camera',
          ),
        ),
      ]),
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: () => review(PaymentRequest.example().encode()),
        child: const Text(
          'Try a K25 demo payment',
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: 28),
      const InfoRow(
        icon: Icons.swap_horiz,
        title: 'Peer transfers are next',
        text: 'Personal receiving QR codes and the transfer journey '
            'are planned for the next milestone.',
      ),
      const InfoRow(
        icon: Icons.info_outline,
        title: 'Demo codes only',
        text: 'Real bank QR formats and live payments are not supported.',
      ),
    ];
  }

  List<Widget> activity() {
    return [
      const DemoLabel(),
      heading(
        'Your activity',
        'A clear view of your payments and transfers.',
      ),
      panel([
        const Icon(
          Icons.receipt_long_outlined,
          size: 44,
          color: QrColors.accent,
        ),
        const SizedBox(height: 20),
        const Text(
          'No saved activity yet',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'This demo clears each payment session. Offline history '
          'and categories will be added in the storage milestone.',
          style: TextStyle(
            color: QrColors.muted,
            height: 1.5,
          ),
        ),
      ]),
      const SizedBox(height: 28),
      const InfoRow(
        icon: Icons.insights_outlined,
        title: 'Insights will follow your records',
        text: 'Spending summaries and optional peer comparisons '
            'are not available yet.',
      ),
    ];
  }

  List<Widget> vendor() {
    return [
      const DemoLabel(),
      heading(
        'Your vendor space',
        'Let customers scan instead of typing.',
      ),
      panel([
        const Icon(
          Icons.qr_code_2,
          size: 64,
          color: QrColors.accent,
        ),
        const SizedBox(height: 20),
        const Text(
          'Create a receiving QR',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Use a test merchant name, test code and amount. '
          'Generated codes expire after 10 minutes.',
          style: TextStyle(
            color: QrColors.muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: merchant,
          child: buttonContent(
            Icons.add,
            'Create a demo merchant QR',
          ),
        ),
      ]),
      const SizedBox(height: 28),
      const InfoRow(
        icon: Icons.inventory_2_outlined,
        title: 'QR inventory',
        text: 'Saved receiving profiles and named QR collections '
            'are planned. This version retains no QR inventory.',
      ),
      const InfoRow(
        icon: Icons.print_outlined,
        title: 'Print and export',
        text: 'PNG and PDF export will be added with vendor QR management.',
      ),
    ];
  }

  List<Widget> profile() {
    return [
      const DemoLabel(),
      heading(
        'Your profile',
        'Privacy and connection settings, in one place.',
      ),
      panel([
        const Icon(
          Icons.person_outline,
          size: 44,
          color: QrColors.accent,
        ),
        const SizedBox(height: 16),
        const Text(
          'Local demo',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'No sign-in required • Version 0.3.0',
          style: TextStyle(color: QrColors.muted),
        ),
      ]),
      const SizedBox(height: 28),
      const InfoRow(
        icon: Icons.sim_card_outlined,
        title: 'Banking connection • not connected',
        text: 'SIM registration is not verified. This demo does not '
            'read banking SMS or run background USSD sessions.',
      ),
      const InfoRow(
        icon: Icons.cloud_off_outlined,
        title: 'Sync • not connected',
        text: 'No customer information is uploaded. Online accounts '
            'and data controls will follow in a later milestone.',
      ),
      const InfoRow(
        icon: Icons.feedback_outlined,
        title: 'Feedback • planned',
        text: 'Offline feedback drafts and consented submission '
            'will be added with the server.',
      ),
      OutlinedButton(
        onPressed: widget.end,
        child: const Text(
          'Clear demo session',
          textAlign: TextAlign.center,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/brand/qrpay_coin.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'QRpay',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: widget.end,
            tooltip: 'End session',
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: PageBody(
        key: ValueKey(tab),
        children: switch (tab) {
          0 => home(),
          1 => scanPage(),
          2 => activity(),
          3 => vendor(),
          _ => profile(),
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) {
          setState(() => tab = value);
        },
        destinations: [
          for (var i = 0; i < labels.length; i++)
            NavigationDestination(
              icon: Icon(icons[i]),
              label: labels[i],
            ),
        ],
      ),
    );
  }
}