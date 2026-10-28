import 'package:flutter/material.dart';
import '../app/theme.dart';

class AppNavigation extends InheritedWidget {
  final void Function(int) select;
  final int index;
  const AppNavigation({
    super.key,
    required this.select,
    required this.index,
    required super.child,
  });
  static AppNavigation of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppNavigation>()!;
  @override
  bool updateShouldNotify(AppNavigation oldWidget) => index != oldWidget.index;
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset('assets/brand/qrpay_mark.png', width: 30, height: 30),
      const SizedBox(width: 9),
      const Text(
        'QRpay',
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: -.6,
        ),
      ),
    ],
  );
}

class BottomDock extends StatelessWidget {
  const BottomDock({super.key});
  @override
  Widget build(BuildContext context) {
    final nav = AppNavigation.of(context);
    const labels = ['Home', 'Activity', 'Scan', 'Vendor', 'Profile'];
    const icons = [
      Icons.home_outlined,
      Icons.receipt_long_outlined,
      Icons.qr_code_scanner_rounded,
      Icons.storefront_outlined,
      Icons.person_outline_rounded,
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: QrColors.surface,
        border: Border(top: BorderSide(color: QrColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: [
              for (var i = 0; i < 5; i++)
                Expanded(
                  child: Semantics(
                    selected: nav.index == i,
                    button: true,
                    label: labels[i],
                    child: InkWell(
                      key: ValueKey('nav-$i'),
                      onTap: () => nav.select(i),
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        height: 66,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: i == 2 ? 58 : 40,
                              height: i == 2 ? 48 : 32,
                              decoration: BoxDecoration(
                                color:
                                    i == 2
                                        ? QrColors.accent
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(17),
                              ),
                              child: Icon(
                                icons[i],
                                size: i == 2 ? 34 : 23,
                                color:
                                    i == 2
                                        ? QrColors.background
                                        : nav.index == i
                                        ? QrColors.accent
                                        : QrColors.muted,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              labels[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color:
                                    nav.index == i
                                        ? QrColors.accent
                                        : QrColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class QrScaffold extends StatelessWidget {
  final Widget body;
  final Widget? actions;
  final bool back;
  const QrScaffold({
    super.key,
    required this.body,
    this.actions,
    this.back = false,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      leadingWidth: 48,
      leading:
          back
              ? IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.maybePop(context),
              )
              : null,
      title: const Brand(),
      centerTitle: true,
      actions: back ? [const SizedBox(width: 48)] : null,
    ),
    body: body,
    bottomNavigationBar: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (actions != null)
          ColoredBox(
            color: QrColors.background,
            child: SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: actions!,
              ),
            ),
          ),
        const BottomDock(),
      ],
    ),
  );
}

class PageBody extends StatefulWidget {
  final List<Widget> children;
  const PageBody({super.key, required this.children});
  @override
  State<PageBody> createState() => _PageBodyState();
}

class _PageBodyState extends State<PageBody> {
  bool fade = false;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) {
          final next = n.metrics.extentAfter > 4;
          if (next != fade) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => fade = next);
              }
            });
          }
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.depth == 0) {
              final next = n.metrics.extentAfter > 4;
              if (next != fade) {
                setState(() => fade = next);
              }
            }
            return false;
          },
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                children: widget.children,
              ),
            ),
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity:
                MediaQuery.disableAnimationsOf(context)
                    ? 0
                    : fade
                    ? 1
                    : 0,
            duration: const Duration(milliseconds: 180),
            child: Container(
              height: 28,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, QrColors.background],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class DemoLabel extends StatelessWidget {
  const DemoLabel({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Icon(Icons.science_outlined, size: 16, color: QrColors.accent),
        SizedBox(width: 7),
        Expanded(
          child: Text(
            'DEMO • NO MONEY MOVES',
            style: TextStyle(
              color: QrColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget heading(String title, String subtitle) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 29,
          fontWeight: FontWeight.w700,
          letterSpacing: -.8,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        subtitle,
        style: const TextStyle(color: QrColors.muted, height: 1.5),
      ),
    ],
  ),
);
Widget panel(List<Widget> children, {Color? color}) => Container(
  width: double.infinity,
  margin: const EdgeInsets.only(bottom: 16),
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: color ?? QrColors.surface,
    borderRadius: BorderRadius.circular(24),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: children,
  ),
);
Widget gap() => const SizedBox(height: 16);
Widget primary(String text, VoidCallback? action, {Key? key}) => FilledButton(
  key: key,
  onPressed: action,
  child: Text(text, textAlign: TextAlign.center),
);

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const InfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: QrColors.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Text(
                text,
                style: const TextStyle(color: QrColors.muted, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void showError(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
