import 'package:flutter/material.dart';
import '../app/theme.dart';

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
    Icon(Icons.science_outlined, size: 18, color: QrColors.accent),
    SizedBox(width: 8),
    Expanded(child: Text('DEMO • NO REAL PAYMENTS',
      style: TextStyle(color: QrColors.accent, fontSize: 12,
        letterSpacing: 1, fontWeight: FontWeight.w700))),
  ]);
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const InfoRow({super.key, required this.icon, required this.title, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24), child: Row(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: QrColors.accent), const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(color: QrColors.muted, height: 1.5)),
        ])),
      ]));
}

void showError(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
