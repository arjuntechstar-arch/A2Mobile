import 'package:flutter/material.dart';

/// Layout adapted from the supplied VoltMart authentication template.
class LoginDesign extends StatelessWidget {
  const LoginDesign(
      {super.key,
      required this.form,
      required this.onRegister,
      required this.onSignIn,
      required this.registering,
      this.recovering = false,
      required this.legal});

  final Widget form, legal;
  final VoidCallback onRegister, onSignIn;
  final bool registering;
  final bool recovering;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFFAF8FF),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                    gradient: LinearGradient(
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                        colors: [
                          Color(0xFFD5DEFF),
                          Color(0xFFFAF8FF),
                          Color(0xFFFFE3D9)
                        ])),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                                color: const Color(0xFF1558E6),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0x332563EB),
                                      blurRadius: 12,
                                      offset: Offset(0, 5))
                                ]),
                            child: const Icon(Icons.bolt_rounded,
                                color: Colors.white, size: 30)),
                        const SizedBox(width: 12),
                        const Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('A2Mobile',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.8)),
                              Text('SAVE. PLAN. UPGRADE.',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                      color: Color(0xFF737686))),
                            ])),
                      ]),
                      const SizedBox(height: 16),
                      const Text('Welcome back!',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                              color: Color(0xFF131B2E))),
                      const SizedBox(height: 6),
                      const Text(
                          'Your next upgrade starts with a smart savings plan.',
                          style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: Color(0xFF434655))),
                    ]),
              ),
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                                color: const Color(0xFFEAEDFF),
                                borderRadius: BorderRadius.circular(32)),
                            child: Row(children: [
                              for (final entry in [
                                (false, 'Sign in'),
                                (true, 'Register')
                              ])
                                Expanded(
                                  child: Semantics(
                                    selected:
                                        !recovering && registering == entry.$1,
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        backgroundColor: !recovering &&
                                                registering == entry.$1
                                            ? const Color(0xFF1558E6)
                                            : Colors.transparent,
                                        foregroundColor: !recovering &&
                                                registering == entry.$1
                                            ? Colors.white
                                            : const Color(0xFF434655),
                                        textStyle: TextStyle(
                                            fontSize: 15,
                                            fontWeight: !recovering &&
                                                    registering == entry.$1
                                                ? FontWeight.w800
                                                : FontWeight.w500),
                                        minimumSize: const Size(0, 48),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 13),
                                      ),
                                      onPressed:
                                          entry.$1 ? onRegister : onSignIn,
                                      child: Text(entry.$2),
                                    ),
                                  ),
                                ),
                            ])),
                        const SizedBox(height: 16),
                        Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0x160F172A),
                                      blurRadius: 24,
                                      offset: Offset(0, 12))
                                ]),
                            child: form),
                        const SizedBox(height: 16),
                        Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(colors: [
                                  Color(0xFFFFDBD1),
                                  Color(0xFFDBE1FF)
                                ])),
                            child: const Row(children: [
                              CircleAvatar(
                                  backgroundColor: Color(0xFFFF5925),
                                  foregroundColor: Colors.white,
                                  child: Icon(Icons.redeem_rounded)),
                              SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text('Make room for your next upgrade',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14)),
                                    SizedBox(height: 4),
                                    Text(
                                        'Discover monthly schemes and eligible store benefits after signing in.',
                                        style: TextStyle(
                                            color: Color(0xFF434655),
                                            fontSize: 12,
                                            height: 1.4)),
                                  ])),
                            ])),
                        const SizedBox(height: 16),
                        const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: _Feature(
                                      icon: Icons.savings_outlined,
                                      label: 'Monthly plans',
                                      color: Color(0xFF004AC6))),
                              SizedBox(width: 8),
                              Expanded(
                                  child: _Feature(
                                      icon: Icons.receipt_long_outlined,
                                      label: 'Digital receipts',
                                      color: Color(0xFF006242))),
                              SizedBox(width: 8),
                              Expanded(
                                  child: _Feature(
                                      icon: Icons.redeem_rounded,
                                      label: 'Store benefits',
                                      color: Color(0xFFFF5925))),
                            ]),
                        const SizedBox(height: 16),
                        legal,
                      ])),
            ],
          )),
        ))),
      );
}

class _Feature extends StatelessWidget {
  const _Feature(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
        decoration: BoxDecoration(
            color: const Color(0xFFF2F3FF),
            borderRadius: BorderRadius.circular(18)),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, height: 1.4))
        ]),
      );
}
