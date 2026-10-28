import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../data/local_store.dart';
import '../data/cloud_client.dart';
import '../features/payment_flow.dart';
import '../payment.dart';
import '../shared/widgets.dart';
import 'theme.dart';

class QrPayApp extends StatefulWidget {
  final LocalStore? store;
  const QrPayApp({super.key, this.store});
  @override
  State<QrPayApp> createState() => _QrPayAppState();
}

class _QrPayAppState extends State<QrPayApp> with WidgetsBindingObserver {
  final navigator = GlobalKey<NavigatorState>();
  final session = PaymentSession();
  late final LocalStore store = widget.store ?? LocalStore.memory();
  Timer? expiry;
  bool shield = false;
  int generation = 0;
  int tab = 0;
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
    navigator.currentState?.popUntil((r) => r.isFirst);
    if (mounted) {
      setState(() {
        generation++;
        tab = 0;
      });
    }
  }

  void select(int value) {
    session.clear();
    navigator.currentState?.popUntil((r) => r.isFirst);
    setState(() => tab = value);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) {
      setState(() => shield = state != AppLifecycleState.resumed);
    }
    if ([
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ].contains(state)) {
      expiry?.cancel();
      endSession();
    } else if (state == AppLifecycleState.resumed) {
      touch();
      if (store.enabled('cloudConsent')) {
        unawaited(CloudClient(store).sync().catchError((Object _) {}));
      }
    }
  }

  @override
  void dispose() {
    expiry?.cancel();
    session.clear();
    WidgetsBinding.instance.removeObserver(this);
    if (widget.store == null) {
      store.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'QRpay Demo',
    navigatorKey: navigator,
    debugShowCheckedModeBanner: false,
    theme: buildQrTheme(),
    builder:
        (c, child) => AppNavigation(
          index: tab,
          select: select,
          child: Listener(
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
          ),
        ),
    home: AppShell(
      key: ValueKey(generation),
      tab: tab,
      store: store,
      session: session,
      end: endSession,
    ),
  );
}

class AppShell extends StatefulWidget {
  final int tab;
  final LocalStore store;
  final PaymentSession session;
  final VoidCallback end;
  const AppShell({
    super.key,
    required this.tab,
    required this.store,
    required this.session,
    required this.end,
  });
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  LocalStore get store => widget.store;
  String filter = 'All';
  Future<void> review(String raw) async {
    try {
      widget.session.load(raw);
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder:
              (_) => ReviewScreen(
                session: widget.session,
                end: widget.end,
                store: store,
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
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (mounted && raw != null) {
      await review(raw);
    }
  }

  void create({
    bool personal = false,
    bool transfer = false,
    PaymentRequest? saved,
  }) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder:
            (_) => MerchantScreen(
              store: store,
              personal: personal,
              transferEntry: transfer,
              saved: saved,
              onReview: review,
            ),
      ),
    );
  }

  void settings() => Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => SettingsScreen(store: store)),
  );
  Future<void> safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        showError(context, 'Could not save changes. Please try again.');
      }
    }
  }

  Future<bool> confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder:
            (c) => AlertDialog(
              title: Text(title),
              content: Text(text),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Continue'),
                ),
              ],
            ),
      ) ??
      false;
  int get spend => store
      .items('activity')
      .where(
        (a) =>
            a['kind'] == 'pay' &&
            a['status'] == 'demoSuccess' &&
            (a['createdAt'] as String).startsWith(
              DateTime.now().toUtc().toIso8601String().substring(0, 7),
            ),
      )
      .fold(0, (n, a) => n + (a['amountMinor'] as int));
  String money(int n) => 'K${n ~/ 100}.${(n % 100).toString().padLeft(2, '0')}';
  List<Widget> home() => [
    const DemoLabel(),
    heading(
      store.setting('displayName').isEmpty
          ? 'Hello, welcome back.'
          : 'Hello, ${store.setting('displayName')}.',
      'Your everyday payments, with fewer steps.',
    ),
    panel([
      const Text(
        'MONTHLY DEMO PURCHASES',
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.6,
          color: QrColors.muted,
        ),
      ),
      gap(),
      Text(
        money(spend),
        style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w700),
      ),
      const Text('Recorded successful simulations • not a bank balance'),
      gap(),
      if (store.setting('budget').isNotEmpty) ...[
        LinearProgressIndicator(
          value: (spend / int.parse(store.setting('budget'))).clamp(0, 1),
        ),
        const SizedBox(height: 8),
        Text('Demo budget: ${money(int.parse(store.setting('budget')))}'),
      ],
    ], color: const Color(0xFF024751)),
    Row(
      children: [
        for (final item in [
          (
            Icons.swap_horiz_rounded,
            'Transfer',
            () => create(personal: true, transfer: true),
          ),
          (
            Icons.call_received_rounded,
            'Receive',
            () => create(personal: true),
          ),
          (Icons.qr_code_2_rounded, 'Vendor QR', () => create()),
        ])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: InkWell(
                onTap: item.$3,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        backgroundColor: QrColors.surface,
                        foregroundColor: QrColors.accent,
                        child: Icon(item.$1),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.$2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
    gap(),
    heading(
      'Recent activity',
      store.enabled('history')
          ? 'Saved on this device.'
          : 'Enable history in Profile to retain demo records.',
    ),
    ...store.items('activity').take(3).map(activityTile),
    if (store.items('activity').isEmpty)
      const InfoRow(
        icon: Icons.receipt_long_outlined,
        title: 'Your next demo starts here',
        text: 'Tap the scan icon below or try a sample payment.',
      ),
  ];
  Widget activityTile(Map<String, dynamic> a) => Card(
    color: QrColors.surface,
    child: ListTile(
      leading: Icon(
        a['kind'] == 'transfer'
            ? Icons.swap_horiz
            : Icons.shopping_bag_outlined,
        color: QrColors.accent,
      ),
      title: Text(
        a['name'] as String,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${a['kind'] == 'transfer' ? 'Transfer' : a['category']} • ${a['status']}\n${a['createdAt'].toString().substring(0, 16).replaceAll('T', ' ')} UTC',
      ),
      isThreeLine: true,
      trailing: Text(money(a['amountMinor'] as int)),
      onTap:
          () => showModalBottomSheet<void>(
            context: context,
            builder:
                (c) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${a['name']} • ${money(a['amountMinor'] as int)}',
                        ),
                        gap(),
                        Text('${a['reference']}\nDEMO — not a bank receipt.'),
                        gap(),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final category in [
                              'Food',
                              'Travel',
                              'Study',
                              'Other',
                              'Transfer',
                            ])
                              ActionChip(
                                label: Text(category),
                                onPressed: () {
                                  Navigator.pop(c);
                                  safely(
                                    () => store.put('activity', {
                                      ...a,
                                      'category': category,
                                    }),
                                  );
                                },
                              ),
                          ],
                        ),
                        gap(),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(c);
                            safely(
                              () => store.remove('activity', a['id'] as String),
                            );
                          },
                          child: const Text('Delete local record'),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    ),
  );
  List<Widget> activity() {
    final list =
        store
            .items('activity')
            .where(
              (a) =>
                  filter == 'All' ||
                  (filter == 'Transfers'
                      ? a['kind'] == 'transfer'
                      : a['kind'] == 'pay'),
            )
            .toList();
    return [
      const DemoLabel(),
      heading('Activity', 'Purchases and transfers remain separate.'),
      Wrap(
        spacing: 8,
        children: [
          for (final x in ['All', 'Purchases', 'Transfers'])
            ChoiceChip(
              label: Text(x),
              selected: filter == x,
              onSelected: (_) => setState(() => filter = x),
            ),
        ],
      ),
      gap(),
      if (list.isEmpty)
        panel([
          const Text('No saved activity yet'),
          gap(),
          const Text(
            'Turn on history in Profile, then complete a demo transaction.',
          ),
        ]),
      ...list.map(activityTile),
      heading(
        'Spending insights',
        'Only recorded successful demo purchases count in the total.',
      ),
      panel([
        Text('This month: ${money(spend)}'),
        gap(),
        const Text(
          'Transfers, declines and uncertain results are excluded. Low spending does not prove high saving.',
        ),
      ]),
      const InfoRow(
        icon: Icons.groups_outlined,
        title: 'Peer comparisons',
        text:
            'Unavailable: demo records never enter real spending rankings. A verified, consenting comparison group is required.',
      ),
    ];
  }

  List<Widget> scanPage() => [
    const DemoLabel(),
    heading(
      'Scan to pay or transfer',
      'Review the name, bank and amount. A scan never authorizes a transaction.',
    ),
    panel([
      const Center(
        child: Icon(
          Icons.qr_code_scanner_rounded,
          size: 120,
          color: QrColors.accent,
        ),
      ),
      gap(),
      const Text('Camera controls stay at the bottom of the screen.'),
    ]),
    OutlinedButton(
      onPressed: () => review(PaymentRequest.example().encode()),
      child: const Text('Try a K25 demo payment'),
    ),
    gap(),
    const InfoRow(
      icon: Icons.wifi_off_rounded,
      title: 'Works without mobile data',
      text:
          'Scanning, saved QR codes, local activity and simulation run on your phone. Live USSD automation is not connected.',
    ),
  ];
  List<Widget> vendor() => [
    const DemoLabel(),
    heading('QR inventory', 'Your vendor and personal receiving codes.'),
    const Text(
      'Saved codes retain their original expiry. Regenerate to create a fresh request. '
      'Deleting a saved code cannot disable a printed offline copy.',
    ),
    gap(),
    if (store.items('qrs').isEmpty)
      panel([
        const Icon(Icons.qr_code_2, size: 48, color: QrColors.accent),
        gap(),
        const Text('No saved QR codes'),
        const Text('Create a code and choose Save QR.'),
      ]),
    ...store
        .items('qrs')
        .map(
          (q) => Card(
            child: ListTile(
              leading: const Icon(Icons.qr_code_2, color: QrColors.accent),
              title: Text(q['name'] as String),
              subtitle: Text(
                '${q['kind']} • ${money(q['amountMinor'] as int)} • check expiry',
              ),
              onTap: () {
                try {
                  create(
                    personal: q['kind'] == 'transfer',
                    saved: PaymentRequest.parse(
                      q['raw'] as String,
                      now: DateTime.fromMillisecondsSinceEpoch(0),
                    ),
                  );
                } on FormatException {
                  showError(context, 'This saved code is not supported.');
                }
              },
              trailing: IconButton(
                tooltip: 'Delete QR',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await confirm(
                    'Delete saved QR?',
                    'Printed copies still exist until they expire.',
                  )) {
                    await safely(() => store.remove('qrs', q['id'] as String));
                  }
                },
              ),
            ),
          ),
        ),
  ];
  List<Widget> profile() => [
    const DemoLabel(),
    heading('Profile & privacy', 'Your data. Your choice.'),
    panel([
      Text(
        store.setting('displayName', 'Local profile'),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      gap(),
      Text('Bank: ${store.setting('bankLabel', 'Not selected')}'),
      Text('SIM label: ${store.setting('simLabel', 'Not selected')}'),
      const Text(
        'Bank registration is not verified. These are user-entered preferences.',
      ),
    ]),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Save demo activity'),
      subtitle: const Text(
        'Stores selected demo records locally. Turning this off does not delete existing records.',
      ),
      value: store.enabled('history'),
      onChanged: (v) => safely(() => store.set('history', v)),
    ),
    ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('My receiving QR'),
      leading: const Icon(Icons.qr_code_2),
      onTap: () => create(personal: true),
    ),
    ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Savings goals'),
      leading: const Icon(Icons.savings_outlined),
      onTap:
          () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => GoalsScreen(store: store)),
          ),
    ),
    ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Feedback'),
      leading: const Icon(Icons.feedback_outlined),
      onTap:
          () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => FeedbackScreen(store: store)),
          ),
    ),
    ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Cloud backup & updates'),
      leading: const Icon(Icons.cloud_outlined),
      subtitle: Text(
        store.setting('lastSync').isEmpty
            ? 'Not synchronized'
            : 'Last sync: ${store.setting('lastSync')}',
      ),
      onTap:
          () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => CloudScreen(store: store)),
          ),
    ),
    const InfoRow(
      icon: Icons.sim_card_outlined,
      title: 'SIM / SMS connection',
      text:
          'No banking messages or SIM identifiers are read. Registered SIM selection and bank verification need supported integration.',
    ),
    TextButton(
      onPressed:
          () => safely(() async {
            await SharePlus.instance.share(
              ShareParams(
                files: [
                  XFile.fromData(
                    utf8.encode(jsonEncode(store.state)),
                    mimeType: 'application/json',
                  ),
                ],
                fileNameOverrides: ['QRpay-local-data.json'],
              ),
            );
          }),
      child: const Text('Export my local data'),
    ),
    TextButton(
      onPressed: () async {
        if (await confirm(
          'Delete all local data?',
          'This deletes saved QR codes, activity, feedback and settings on this phone. Cloud copies remain until deleted separately.',
        )) {
          await safely(() async {
            await CloudClient(store).signOut();
            await store.clear();
          });
        }
      },
      child: const Text('Delete local data'),
    ),
    const Text(
      'QRpay 0.4.0 • Independent prototype, not an official bank app.',
    ),
  ];
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder:
        (_, _) => QrScaffold(
          actions: switch (widget.tab) {
            0 => primary(
              'Try a K25 demo payment',
              () => review(PaymentRequest.example().encode()),
            ),
            1 => primary(
              'Transfer to a peer',
              () => create(personal: true, transfer: true),
            ),
            2 => primary('Open camera', scan),
            3 => primary('Create a demo merchant QR', () => create()),
            _ => primary('Edit profile & budget', settings),
          },
          body: PageBody(
            key: ValueKey(widget.tab),
            children: switch (widget.tab) {
              0 => home(),
              1 => activity(),
              2 => scanPage(),
              3 => vendor(),
              _ => profile(),
            },
          ),
        ),
  );
}

class GoalsScreen extends StatefulWidget {
  final LocalStore store;
  const GoalsScreen({super.key, required this.store});
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final name = TextEditingController();
  final target = TextEditingController();
  @override
  void dispose() {
    name.dispose();
    target.dispose();
    super.dispose();
  }

  Future<void> add() async {
    try {
      if (name.text.trim().isEmpty) {
        throw const FormatException('Name your goal.');
      }
      await widget.store.put('goals', {
        'id': newId(),
        'name': name.text.trim(),
        'target': parseAmount(target.text),
        'saved': 0,
      });
      name.clear();
      target.clear();
      if (mounted) {
        setState(() {});
      }
    } on FormatException catch (e) {
      if (mounted) {
        showError(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        showError(context, 'Could not save goal.');
      }
    }
  }

  Future<void> contribute(Map<String, dynamic> goal) async {
    final input = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('Record a contribution'),
            content: TextField(
              controller: input,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount (PGK)'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, input.text),
                child: const Text('Record'),
              ),
            ],
          ),
    );
    // Dispose after the dialog route has completed its closing animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
    if (value == null) {
      return;
    }
    try {
      final saved = (goal['saved'] as int) + parseAmount(value);
      if (saved > 1000000) {
        throw const FormatException('Goal records are limited to K10,000.');
      }
      await widget.store.put('goals', {...goal, 'saved': saved});
      if (mounted) {
        setState(() {});
      }
    } on FormatException catch (e) {
      if (mounted) {
        showError(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        showError(context, 'Could not save contribution.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => QrScaffold(
    back: true,
    actions: primary('Create savings goal', add),
    body: PageBody(
      children: [
        heading(
          'Savings goals',
          'Self-recorded contributions, not verified bank savings or a peer ranking.',
        ),
        TextField(
          controller: name,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Goal name'),
        ),
        gap(),
        TextField(
          controller: target,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Target (PGK)'),
        ),
        gap(),
        ...widget.store
            .items('goals')
            .map(
              (g) => panel([
                Text(
                  g['name'] as String,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                gap(),
                LinearProgressIndicator(
                  value: ((g['saved'] as int) / (g['target'] as int)).clamp(
                    0,
                    1,
                  ),
                ),
                gap(),
                Text(
                  'Recorded: K${((g['saved'] as int) / 100).toStringAsFixed(2)} / K${((g['target'] as int) / 100).toStringAsFixed(2)}',
                ),
                Wrap(
                  children: [
                    TextButton(
                      onPressed: () => contribute(g),
                      child: const Text('Record contribution'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await widget.store.remove('goals', g['id'] as String);
                        if (mounted) {
                          setState(() {});
                        }
                      },
                      child: const Text('Delete goal'),
                    ),
                  ],
                ),
              ]),
            ),
      ],
    ),
  );
}

class SettingsScreen extends StatefulWidget {
  final LocalStore store;
  const SettingsScreen({super.key, required this.store});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final name = TextEditingController(
    text: widget.store.setting('displayName'),
  );
  late final bank = TextEditingController(
    text: widget.store.setting('bankLabel'),
  );
  late final sim = TextEditingController(
    text: widget.store.setting('simLabel'),
  );
  late final budget = TextEditingController(
    text:
        widget.store.setting('budget').isEmpty
            ? ''
            : (int.parse(widget.store.setting('budget')) / 100).toStringAsFixed(
              2,
            ),
  );
  @override
  void dispose() {
    for (final c in [name, bank, sim, budget]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    try {
      final value =
          budget.text.trim().isEmpty ? '' : parseAmount(budget.text).toString();
      await widget.store.set('displayName', name.text.trim());
      await widget.store.set('bankLabel', bank.text.trim());
      await widget.store.set('simLabel', sim.text.trim());
      await widget.store.set('budget', value);
      if (mounted) {
        Navigator.pop(context);
      }
    } on FormatException catch (e) {
      if (mounted) {
        showError(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        showError(context, 'Could not save profile.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => QrScaffold(
    back: true,
    actions: primary('Save profile', save),
    body: PageBody(
      children: [
        heading(
          'Your preferences',
          'Use a nickname. Do not enter PINs or account credentials.',
        ),
        TextField(
          controller: name,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        gap(),
        TextField(
          controller: bank,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Bank label'),
        ),
        gap(),
        TextField(
          controller: sim,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'SIM label',
            helperText: 'Example: SIM 1 — Telikom. This does not select a SIM.',
          ),
        ),
        gap(),
        TextField(
          controller: budget,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monthly demo budget (PGK)',
            helperText: 'Optional. Not an income or savings estimate.',
          ),
        ),
      ],
    ),
  );
}

class FeedbackScreen extends StatefulWidget {
  final LocalStore store;
  const FeedbackScreen({super.key, required this.store});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final text = TextEditingController();
  bool diagnostics = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (text.text.trim().isEmpty) {
      showError(context, 'Write some feedback first.');
      return;
    }
    try {
      await widget.store.put('feedback', {
        'id': newId(),
        'text': text.text.trim(),
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        if (diagnostics) 'appVersion': '0.4.0',
        'status': 'queued',
      });
      text.clear();
      if (mounted) {
        setState(() {});
        showError(
          context,
          'Feedback saved offline. Cloud backup submits it only with consent.',
        );
      }
    } catch (_) {
      if (mounted) {
        showError(context, 'Feedback could not be saved.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => QrScaffold(
    back: true,
    actions: primary('Save feedback offline', save),
    body: PageBody(
      children: [
        heading(
          'Help improve QRpay',
          'Do not include bank PINs, OTPs or sensitive banking details.',
        ),
        TextField(
          controller: text,
          maxLength: 2000,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Your feedback'),
        ),
        gap(),
        SwitchListTile(
          title: const Text('Include app version'),
          subtitle: const Text(
            'No SMS, device identifiers or banking diagnostics are attached.',
          ),
          value: diagnostics,
          onChanged: (v) => setState(() => diagnostics = v),
        ),
        ...widget.store
            .items('feedback')
            .map(
              (f) => ListTile(
                title: Text(f['text'] as String),
                subtitle: const Text('Saved draft'),
                trailing: IconButton(
                  tooltip: 'Delete feedback',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await widget.store.remove('feedback', f['id'] as String);
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
              ),
            ),
      ],
    ),
  );
}

class CloudScreen extends StatefulWidget {
  final LocalStore store;
  const CloudScreen({super.key, required this.store});
  @override
  State<CloudScreen> createState() => _CloudScreenState();
}

class _CloudScreenState extends State<CloudScreen> {
  late final client = CloudClient(widget.store);
  late final server = TextEditingController(
    text: widget.store.setting('server'),
  );
  final username = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool register = false;
  String status = '';
  @override
  void dispose() {
    server.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      status =
          e is StateError
              ? e.message.toString()
              : e is FormatException
              ? e.message
              : 'Connection failed. Your local data is unchanged.';
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<bool> confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder:
            (c) => AlertDialog(
              title: const Text('Confirm data action'),
              content: Text(text),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Continue'),
                ),
              ],
            ),
      ) ??
      false;
  @override
  Widget build(BuildContext context) => QrScaffold(
    back: true,
    actions: primary(
      busy ? 'Working…' : 'Sync consented records',
      busy
          ? null
          : () => run(() async {
            if (!widget.store.enabled('cloudConsent')) {
              throw StateError('Enable cloud backup consent first.');
            }
            await client.sync();
            status = 'Backup synchronized. No payment was submitted.';
          }),
    ),
    body: PageBody(
      children: [
        heading(
          'Cloud backup',
          'Optional. Offline features continue without an account or server.',
        ),
        const Text(
          'Enter the HTTPS address of your deployed QRpay backend. No hosted server is configured in this build.',
        ),
        gap(),
        TextField(
          controller: server,
          decoration: const InputDecoration(labelText: 'HTTPS server address'),
        ),
        gap(),
        if (widget.store.setting('account').isEmpty) ...[
          TextField(
            controller: username,
            decoration: const InputDecoration(labelText: 'App username'),
          ),
          gap(),
          TextField(
            controller: password,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'App password — never your bank PIN',
            ),
          ),
          gap(),
          SwitchListTile(
            title: const Text('Create a new app account'),
            value: register,
            onChanged: busy ? null : (v) => setState(() => register = v),
          ),
          OutlinedButton(
            onPressed:
                busy
                    ? null
                    : () => run(() async {
                      await widget.store.set('server', server.text.trim());
                      await client.signIn(
                        username.text,
                        password.text,
                        register: register,
                      );
                      password.clear();
                      status =
                          'Signed in. Review backup consent before syncing.';
                    }),
            child: Text(register ? 'Create app account' : 'Sign in'),
          ),
        ] else ...[
          Text('Signed in as ${widget.store.setting('account')}'),
          SwitchListTile(
            title: const Text('Allow cloud backup'),
            subtitle: const Text(
              'Uploads local profile, QR inventory, demo activity and feedback to the configured server. Never submits or repeats a payment.',
            ),
            value: widget.store.enabled('cloudConsent'),
            onChanged:
                busy
                    ? null
                    : (v) => run(() async {
                      if (!v ||
                          await confirm(
                            'Upload the records currently on this phone to this app account?',
                          )) {
                        await widget.store.set('cloudConsent', v);
                      }
                    }),
          ),
          OutlinedButton(
            onPressed:
                busy
                    ? null
                    : () => run(() async {
                      if (await confirm(
                        'Replace local profile, inventory, activity and feedback with the server backup? Export local data first if needed.',
                      )) {
                        await client.restore();
                        status = 'Backup restored.';
                      }
                    }),
            child: const Text('Restore server backup'),
          ),
          TextButton(
            onPressed:
                busy
                    ? null
                    : () => run(() async {
                      await client.signOut();
                      status = 'Signed out. Local records remain.';
                    }),
            child: const Text('Sign out'),
          ),
          TextButton(
            onPressed:
                busy
                    ? null
                    : () => run(() async {
                      if (await confirm(
                        'Permanently delete this cloud account, backup and all local data?',
                      )) {
                        await client.deleteAccount();
                        password.clear();
                        status = 'Account deleted.';
                      }
                    }),
            child: const Text('Delete cloud account & local data'),
          ),
        ],
        gap(),
        OutlinedButton(
          onPressed:
              busy
                  ? null
                  : () => run(() async {
                    await widget.store.set('server', server.text.trim());
                    final r = await client.call('updates', auth: false);
                    status = 'Latest version: ${r['version']}. ${r['message']}';
                  }),
          child: const Text('Check update notice'),
        ),
        const Text(
          'Native updates use a newly signed APK. QRpay does not download or run executable updates from the server.',
        ),
        gap(),
        Text(status),
        Text('Last sync: ${widget.store.setting('lastSync', 'Never')}'),
      ],
    ),
  );
}
