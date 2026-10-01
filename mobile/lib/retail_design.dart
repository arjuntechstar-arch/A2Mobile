import 'package:flutter/material.dart';

/// Native adaptations of the supplied Kinetic Retail templates.
class RetailBanner extends StatelessWidget {
  const RetailBanner(
      {super.key,
      required this.eyebrow,
      required this.title,
      required this.description,
      required this.icon,
      this.action,
      this.onTap,
      this.coral = false});

  final String eyebrow, title, description;
  final IconData icon;
  final String? action;
  final VoidCallback? onTap;
  final bool coral;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: coral
                  ? const [Color(0xFFFF5925), Color(0xFFB02F00)]
                  : const [Color(0xFF2563EB), Color(0xFF004AC6)]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color:
                    (coral ? const Color(0xFFB02F00) : const Color(0xFF004AC6))
                        .withValues(alpha: .16),
                blurRadius: 18,
                offset: const Offset(0, 6))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(eyebrow.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1))),
            Icon(icon, color: Colors.white, size: 30),
          ]),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.7)),
          const SizedBox(height: 10),
          Text(description,
              style: const TextStyle(
                  color: Colors.white, height: 1.5, fontSize: 13)),
          if (action != null && onTap != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: coral
                        ? const Color(0xFFB02F00)
                        : const Color(0xFF004AC6),
                    shape: const StadiumBorder()),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(action!)),
          ],
        ]),
      );
}

class RetailSectionHeading extends StatelessWidget {
  const RetailSectionHeading(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon});
  final String title, subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: const Color(0xFF004AC6))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.5)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 13, height: 1.4)),
              ])),
        ]),
      );
}

class RetailShortcut extends StatelessWidget {
  const RetailShortcut(
      {super.key,
      required this.label,
      required this.icon,
      required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
      width: 92,
      child: Column(children: [
        IconButton.filledTonal(
            onPressed: onTap,
            tooltip: label,
            style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFEFF6FF),
                foregroundColor: const Color(0xFF004AC6),
                padding: const EdgeInsets.all(17),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18))),
            icon: Icon(icon)),
        const SizedBox(height: 6),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]));
}
