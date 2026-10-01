import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'retail_design.dart';
import 'login_design.dart';
import 'firebase_phone.dart';
import 'checkout.dart';
import 'push.dart';
import 'package:url_launcher/url_launcher.dart';
export 'api.dart';

void main() => runApp(const SchemeApp());

String money(dynamic value) =>
    '\u20b9${((value as num? ?? 0) / 100).toStringAsFixed(2)}';

String dueDate(dynamic value, Map<String, dynamic> terms) {
  final utc = DateTime.parse(value.toString()).toUtc();
  final calendar = terms['policy']?['timezone'] == 'UTC'
      ? utc
      : utc.add(const Duration(hours: 5, minutes: 30));
  return calendar.toIso8601String().substring(0, 10);
}

String message(Object error) =>
    error.toString().replaceFirst('Exception: ', '');

void showMessage(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

Future<void> openPage(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

class A2BrandHeader extends StatelessWidget {
  const A2BrandHeader({super.key, this.subtitle});
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Text(
            'A2',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'A2Mobile',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.4,
                color: Color(0xFF0F172A),
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toUpperCase();
    Color bg;
    Color fg;
    if (['ACTIVE', 'COMPLETED', 'CAPTURED', 'VERIFIED', 'RESOLVED', 'SUCCESS']
        .contains(s)) {
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF059669);
    } else if ([
      'DUE',
      'PENDING',
      'OPEN',
      'IN_PROGRESS',
      'REQUIRES_REVIEW',
      'PENDING_APPROVAL'
    ].contains(s)) {
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFD97706);
    } else {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFDC2626);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class SchemeApp extends StatelessWidget {
  const SchemeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'A2Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        textTheme: Typography.material2021().black.apply(
            bodyColor: const Color(0xFF0F172A),
            displayColor: const Color(0xFF0F172A)),
        listTileTheme:
            const ListTileThemeData(dense: true, iconColor: Color(0xFF2563EB)),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          primary: const Color(0xFF2563EB),
          secondary: const Color(0xFF0D9488),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shadowColor: const Color(0x140F172A),
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
          ),
          labelStyle: const TextStyle(
              color: Color(0xFF434655),
              fontSize: 14,
              fontWeight: FontWeight.w600),
          floatingLabelStyle: const TextStyle(
              color: Color(0xFF434655),
              fontSize: 14,
              fontWeight: FontWeight.w600),
          errorMaxLines: 3,
          prefixIconColor: const Color(0xFF004AC6),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 3,
          indicatorColor: const Color(0xFF2563EB),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              );
            }
            return const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
              fontSize: 12,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Colors.white);
            }
            return const IconThemeData(color: Color(0xFF64748B));
          }),
        ),
      ),
      home: const SessionGate());
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key, this.auth});
  final AuthService? auth;
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final AuthService _auth;
  Future<String?>? _session;
  String? _linkError;
  @override
  void initState() {
    super.initState();
    _auth = widget.auth ?? AuthService();
    _session = _restore();
  }

  Future<String?> _restore() async {
    final token = Uri.base.queryParameters['verify_email'];
    if (token != null) {
      try {
        await _auth.request('/auth/verify-email',
            method: 'POST', body: {'token': token});
      } catch (e) {
        _linkError = message(e);
      }
    }
    return _auth.restoreEmail();
  }

  void refresh() => setState(() {
        _session = _auth.restoreEmail();
      });

  @override
  Widget build(BuildContext context) {
    final reset = Uri.base.queryParameters['reset_password'];
    if (reset != null) {
      return ResetPasswordPage(auth: _auth, token: reset);
    }
    return FutureBuilder<String?>(
        future: _session,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError) {
            return Scaffold(
                body: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(message(snapshot.error!))),
              FilledButton(
                  onPressed: refresh, child: const Text('Retry connection')),
            ])));
          }
          return snapshot.data == null
              ? LoginPage(
                  auth: _auth, onSignedIn: refresh, linkError: _linkError)
              : HomePage(
                  email: snapshot.data!, auth: _auth, onSignedOut: refresh);
        });
  }
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.auth, required this.token});
  final AuthService auth;
  final String token;
  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false, _hide = true;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? passwordError(String? value) {
    final password = value ?? '';
    if (password.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Use letters, a number, and a special character';
    }
    return null;
  }

  Future<void> submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.request('/auth/reset-password',
          method: 'POST',
          body: {'token': widget.token, 'password': _password.text});
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
              builder: (_) => LoginPage(auth: widget.auth, onSignedIn: () {})),
          (_) => false);
    } catch (error) {
      if (mounted) setState(() => _error = message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LoginDesign(
        registering: false,
        recovering: true,
        onSignIn: () {},
        onRegister: () {},
        legal: const SizedBox.shrink(),
        form: Form(
            key: _form,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Set a new password',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1558E6))),
                  const SizedBox(height: 8),
                  const Text(
                      'Use 8+ characters with letters, a number, and a special character.'),
                  const SizedBox(height: 18),
                  TextFormField(
                      controller: _password,
                      obscureText: _hide,
                      decoration: authFieldDecoration('New password',
                          icon: Icons.lock_outline_rounded,
                          suffix: IconButton(
                              onPressed: () => setState(() => _hide = !_hide),
                              icon: Icon(_hide
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined))),
                      validator: passwordError),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: _confirm,
                      obscureText: _hide,
                      decoration: authFieldDecoration('Confirm new password',
                          icon: Icons.lock_reset_rounded),
                      validator: (value) => value == _password.text
                          ? null
                          : 'Passwords do not match'),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(_error!,
                            style: const TextStyle(color: Color(0xFFDC2626)))),
                  const SizedBox(height: 20),
                  FilledButton(
                      onPressed: _busy ? null : submit,
                      child: Text(
                          _busy ? 'Updating password...' : 'Update password')),
                ])),
      );
}

InputDecoration authFieldDecoration(String label,
        {String? hint, IconData? icon, Widget? suffix}) =>
    InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        suffixIcon: suffix);

class LoginPage extends StatefulWidget {
  const LoginPage(
      {super.key,
      required this.auth,
      required this.onSignedIn,
      this.linkError});
  final AuthService auth;
  final VoidCallback onSignedIn;
  final String? linkError;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;
  String _mode = 'signin';

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.auth.login(_email.text.trim(), _password.text);
      if (mounted) widget.onSignedIn();
    } catch (e) {
      if (mounted) showMessage(context, message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LoginDesign(
        registering: _mode == 'register',
        recovering: _mode == 'forgot',
        onSignIn: () => setState(() => _mode = 'signin'),
        onRegister: () => setState(() => _mode = 'register'),
        legal: Wrap(
            alignment: WrapAlignment.center,
            children: ['terms', 'privacy']
                .map((key) => TextButton(
                    onPressed: () => openPage(context,
                        ContentPage(auth: widget.auth, contentKey: key)),
                    child: Text(key == 'terms' ? 'Terms' : 'Privacy')))
                .toList()),
        form: _mode == 'register'
            ? RegistrationPage(
                auth: widget.auth,
                embedded: true,
                onSignIn: () => setState(() => _mode = 'signin'))
            : _mode == 'forgot'
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        FormPage(
                            embedded: true,
                            title: 'Forgot password',
                            description:
                                'Enter your email to receive a password reset link.',
                            fields: [
                              InputField('email', 'Email',
                                  email: true, initial: _email.text)
                            ],
                            buttonLabel: 'Send reset link',
                            submit: (values) => widget.auth.request(
                                '/auth/forgot-password',
                                method: 'POST',
                                body: values),
                            success:
                                'If this account exists, a reset email has been sent.'),
                        TextButton(
                            onPressed: () => setState(() => _mode = 'signin'),
                            child: const Text('Back to sign in')),
                      ])
                : Form(
                    key: _form,
                    child: AutofillGroup(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.linkError != null) ...[
                          Text(widget.linkError!,
                              style: const TextStyle(color: Color(0xFFDC2626))),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            decoration: authFieldDecoration('Email',
                                hint: 'you@example.com',
                                icon: Icons.alternate_email_rounded),
                            validator: (v) => v != null && v.contains('@')
                                ? null
                                : 'Enter a valid email'),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: _password,
                            obscureText: _hidePassword,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!_busy) _submit();
                            },
                            decoration: authFieldDecoration('Password',
                                hint: 'Enter your password',
                                icon: Icons.lock_outline_rounded,
                                suffix: IconButton(
                                    tooltip: _hidePassword
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: () => setState(
                                        () => _hidePassword = !_hidePassword),
                                    icon: Icon(_hidePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined))),
                            validator: (v) => v != null && v.length >= 8
                                ? null
                                : 'Enter at least 8 characters'),
                        Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                                onPressed: () =>
                                    setState(() => _mode = 'forgot'),
                                child: const Text('Forgot password?'))),
                        const SizedBox(height: 12),
                        Container(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(32),
                                gradient: const LinearGradient(colors: [
                                  Color(0xFF2563EB),
                                  Color(0xFF004AC6)
                                ]),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0x332563EB),
                                      blurRadius: 16,
                                      offset: Offset(0, 7))
                                ]),
                            child: FilledButton(
                                onPressed: _busy ? null : _submit,
                                style: FilledButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    disabledForegroundColor: Colors.white70,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 18),
                                    shape: const StadiumBorder()),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                          child: Text(
                                              _busy
                                                  ? 'Signing in...'
                                                  : 'Sign in',
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                      FontWeight.w700))),
                                      const SizedBox(width: 12),
                                      const Icon(Icons.arrow_forward_rounded,
                                          size: 20),
                                    ]))),
                        const SizedBox(height: 16),
                        const Text(
                            'Sign in to manage your savings, payments and store benefits.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color(0xFF737686),
                                fontSize: 12,
                                height: 1.5)),
                      ],
                    ))),
      );
}

class RegistrationPage extends StatefulWidget {
  const RegistrationPage(
      {super.key, required this.auth, this.embedded = false, this.onSignIn});
  final bool embedded;
  final VoidCallback? onSignIn;
  final AuthService auth;
  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController(text: '+91');
  final password = TextEditingController();
  final emailCode = TextEditingController();
  final phoneCode = TextEditingController();
  PhoneVerification? verification;
  bool busy = false, codesRequested = false, finished = false;
  bool hidePassword = true;
  String? error, notice;

  @override
  void dispose() {
    for (final c in [name, email, phone, password, emailCode, phoneCode]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> run(Future<void> Function() work) async {
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> sendCodes() async {
    if (!form.currentState!.validate()) return;
    await run(() async {
      await widget.auth.request('/auth/registration/email',
          method: 'POST', body: {'email': email.text.trim()});
      verification = PhoneVerification(widget.auth, phone.text.trim());
      if (mounted) {
        setState(() {
          codesRequested = true;
          notice = 'Email code sent. Request the phone code below.';
        });
      }
    });
  }

  Future<void> create() async {
    if (emailCode.text.trim().length != 8 ||
        phoneCode.text.trim().length != 6) {
      setState(() =>
          error = 'Enter the 8-character email code and 6-digit phone code.');
      return;
    }
    await run(() async {
      final token = await verification!.confirmToken(phoneCode.text.trim());
      await widget.auth.request('/auth/register', method: 'POST', body: {
        'name': name.text.trim(),
        'email': email.text.trim(),
        'phone': phone.text.trim(),
        'password': password.text,
        'email_code': emailCode.text.trim(),
        'firebase_id_token': token,
      });
      if (mounted) {
        setState(() {
          finished = true;
          notice =
              'Account created. Both contacts are verified. Return to sign in.';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final content =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Create account',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      if (!finished) ...[
        const Text(
            'Verify your email and phone before creating your account. Google processes your phone number for verification and abuse prevention.'),
        const SizedBox(height: 16),
        Form(
            key: form,
            child: Column(children: [
              TextFormField(
                  controller: name,
                  enabled: !codesRequested && !busy,
                  decoration: authFieldDecoration('Full name',
                      hint: 'Enter your full name', icon: Icons.person_outline),
                  validator:
                      const InputField('name', 'Name', minLength: 2).validate),
              const SizedBox(height: 16),
              TextFormField(
                  controller: email,
                  enabled: !codesRequested && !busy,
                  keyboardType: TextInputType.emailAddress,
                  decoration: authFieldDecoration('Email',
                      hint: 'you@example.com',
                      icon: Icons.alternate_email_rounded),
                  validator:
                      const InputField('email', 'Email', email: true).validate),
              const SizedBox(height: 16),
              TextFormField(
                  controller: phone,
                  enabled: !codesRequested && !busy,
                  keyboardType: TextInputType.phone,
                  decoration: authFieldDecoration('Indian mobile number',
                      hint: '+919876543210', icon: Icons.phone_outlined),
                  validator:
                      const InputField('phone', 'Phone', phone: true).validate),
              const SizedBox(height: 16),
              TextFormField(
                  controller: password,
                  enabled: !codesRequested && !busy,
                  obscureText: hidePassword,
                  decoration: authFieldDecoration('Password',
                      hint: 'Enter your password',
                      icon: Icons.lock_outline_rounded,
                      suffix: IconButton(
                          tooltip:
                              hidePassword ? 'Show password' : 'Hide password',
                          onPressed: codesRequested || busy
                              ? null
                              : () =>
                                  setState(() => hidePassword = !hidePassword),
                          icon: Icon(hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined))),
                  validator: const InputField('password', 'Password',
                          secret: true, minLength: 8)
                      .validate),
              const SizedBox(height: 8),
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      'Use 8+ characters with letters, a number, and a special character.',
                      style:
                          TextStyle(fontSize: 12, color: Color(0xFF434655)))),
            ])),
      ],
      const SizedBox(height: 16),
      if (!codesRequested)
        FilledButton(
            onPressed: busy ? null : sendCodes,
            child: const Text('Send email verification code')),
      if (codesRequested && !finished) ...[
        TextFormField(
            controller: emailCode,
            decoration:
                const InputDecoration(labelText: 'Email code (8 characters)')),
        TextButton(
            onPressed: busy
                ? null
                : () => run(() async {
                      await widget.auth.request('/auth/registration/email',
                          method: 'POST', body: {'email': email.text.trim()});
                      if (mounted) {
                        setState(() => notice = 'New email code sent.');
                      }
                    }),
            child: const Text('Resend email code')),
        FilledButton(
            onPressed: busy
                ? null
                : () => run(() async {
                      await verification!.send();
                      if (mounted) setState(() => notice = 'Phone code sent.');
                    }),
            child: const Text('Send phone verification code')),
        TextFormField(
            controller: phoneCode,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Phone OTP (6 digits)')),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: busy ? null : create,
            child: const Text('Verify and create account')),
        TextButton(
            onPressed: busy
                ? null
                : () => setState(() {
                      codesRequested = false;
                      verification = null;
                      emailCode.clear();
                      phoneCode.clear();
                    }),
            child: const Text('Edit contact details')),
      ],
      if (busy) const LinearProgressIndicator(),
      if (error != null)
        Text(error!, style: const TextStyle(color: Colors.red)),
      if (notice != null) Text(notice!),
      if (finished) ...[
        const SizedBox(height: 20),
        FilledButton(
            onPressed: widget.onSignIn ?? () => Navigator.pop(context),
            child: const Text('Return to sign in')),
      ],
    ]);
    if (widget.embedded) return content;
    return Scaffold(
        appBar: AppBar(title: const Text('Create account')),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(20), child: content));
  }
}

class InputField {
  const InputField(this.key, this.label,
      {this.secret = false,
      this.email = false,
      this.multiline = false,
      this.initial = '',
      this.minLength = 0,
      this.phone = false,
      this.optional = false});
  final String key, label, initial;
  final bool secret, email, multiline, optional;
  final int minLength;
  final bool phone;

  String? validate(String? input) {
    final value = secret ? (input ?? '') : (input ?? '').trim();
    if (value.isEmpty) return optional ? null : 'This field is required';
    if (value.length < minLength) return 'Enter at least $minLength characters';
    if (phone && !RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value)) {
      return 'Enter a valid Indian mobile number after +91';
    }
    if (email && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }
}

class FormPage extends StatefulWidget {
  const FormPage(
      {super.key,
      required this.title,
      required this.fields,
      required this.submit,
      this.success = 'Saved successfully.',
      this.description,
      this.embedded = false,
      this.buttonLabel = 'Submit'});
  final bool embedded;
  final String title, success, buttonLabel;
  final String? description;
  final List<InputField> fields;
  final Future<dynamic> Function(Map<String, dynamic>) submit;
  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _inputs;
  bool _busy = false;
  String? _result;
  String? _error;
  @override
  void initState() {
    super.initState();
    _inputs = {
      for (final f in widget.fields)
        f.key: TextEditingController(text: f.initial)
    };
  }

  @override
  void dispose() {
    for (final c in _inputs.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      await widget.submit({
        for (final f in widget.fields)
          f.key: f.secret ? _inputs[f.key]!.text : _inputs[f.key]!.text.trim()
      });
      if (mounted) setState(() => _result = widget.success);
    } catch (e) {
      if (mounted) setState(() => _error = message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.embedded) ...[
        Text(widget.title,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1558E6))),
        const SizedBox(height: 16),
      ],
      if (widget.description != null)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFC7D2FE)),
          ),
          child: Text(
            widget.description!,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF3730A3), height: 1.4),
          ),
        ),
      Card(
        margin: widget.embedded ? EdgeInsets.zero : null,
        elevation: widget.embedded ? 0 : null,
        color: widget.embedded ? Colors.transparent : null,
        shape: widget.embedded ? const RoundedRectangleBorder() : null,
        child: Padding(
          padding: widget.embedded ? EdgeInsets.zero : const EdgeInsets.all(20),
          child: Form(
              key: _form,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final f in widget.fields)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: TextFormField(
                              controller: _inputs[f.key],
                              decoration: InputDecoration(labelText: f.label),
                              obscureText: f.secret,
                              maxLines: f.multiline ? 4 : 1,
                              keyboardType: f.email
                                  ? TextInputType.emailAddress
                                  : TextInputType.text,
                              validator: f.validate)),
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(_error!,
                            style: const TextStyle(
                                color: Color(0xFFDC2626), fontSize: 13)),
                      ),
                    if (_result != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(_result!,
                            style: const TextStyle(
                                color: Color(0xFF065F46), fontSize: 13)),
                      ),
                    const SizedBox(height: 6),
                    FilledButton(
                        style: widget.embedded
                            ? FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 16),
                                textStyle: const TextStyle(
                                    fontSize: 16,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700))
                            : null,
                        onPressed: _busy ? null : submit,
                        child:
                            Text(_busy ? 'Please wait…' : widget.buttonLabel))
                  ])),
        ),
      ),
    ]);
    if (widget.embedded) return content;
    return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20), child: content))));
  }
}

class DataView extends StatefulWidget {
  const DataView(
      {super.key,
      required this.auth,
      required this.path,
      required this.builder});
  final AuthService auth;
  final String path;
  final Widget Function(dynamic, VoidCallback) builder;
  @override
  State<DataView> createState() => _DataViewState();
}

class _DataViewState extends State<DataView> {
  late Future<dynamic> _data;
  @override
  void initState() {
    super.initState();
    _data = widget.auth.request(widget.path);
  }

  @override
  void didUpdateWidget(DataView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _data = widget.auth.request(widget.path);
  }

  void reload() => setState(() {
        _data = widget.auth.request(widget.path);
      });
  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(message(snapshot.error!)),
                    const SizedBox(height: 12),
                    OutlinedButton(
                        onPressed: reload, child: const Text('Try again'))
                  ])));
        }
        return widget.builder(snapshot.data, reload);
      });
}

class HomePage extends StatefulWidget {
  const HomePage(
      {super.key,
      required this.email,
      required this.auth,
      required this.onSignedOut});
  final String email;
  final AuthService auth;
  final VoidCallback onSignedOut;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _refreshNotifications();
    if (Uri.base.queryParameters.containsKey('notifications')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openNotifications();
      });
    }
  }

  Future<void> _refreshNotifications() async {
    try {
      final items = await widget.auth.request('/notifications') as List;
      if (mounted) {
        setState(
            () => _unread = items.where((item) => item['read'] != true).length);
      }
    } catch (_) {
      // The inbox has its own retry action if notifications cannot be loaded.
    }
  }

  Future<void> _openNotifications() async {
    await openPage(context, NotificationsPage(auth: widget.auth));
    if (mounted) await _refreshNotifications();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: const A2BrandHeader(),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: _openNotifications,
            icon: Badge(
              isLabelVisible: _unread > 0,
              backgroundColor: const Color(0xFF2563EB),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _tab, children: [
        Dashboard(
            auth: widget.auth,
            email: widget.email,
            onBrowse: () => setState(() => _tab = 1),
            onPayments: () => setState(() => _tab = 2)),
        SchemesPage(auth: widget.auth),
        PaymentsPage(auth: widget.auth),
        ProfilePage(auth: widget.auth, onSignedOut: widget.onSignedOut),
      ]),
      bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (value) => setState(() => _tab = value),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront_rounded),
                label: 'Schemes'),
            NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Payments'),
            NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile')
          ]));
}

String notificationDate(dynamic value) {
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return '';
  final date = parsed.toUtc().add(const Duration(hours: 5, minutes: 30));
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day.toString().padLeft(2, '0')}-${months[date.month - 1]}-${date.year} '
      '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}

class SchemePromotionCard extends StatelessWidget {
  const SchemePromotionCard(
      {super.key,
      required this.scheme,
      required this.onTap,
      this.imageAsset = 'assets/images/retail-products.png'});
  final String imageAsset;
  final Map<String, dynamic> scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, constraints) => ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(children: [
              Positioned.fill(
                  child: Image.asset(imageAsset,
                      fit: BoxFit.cover, alignment: Alignment.centerRight)),
              Positioned.fill(
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  const Color(0xFF071A40).withValues(alpha: .88),
                  const Color(0xFF071A40).withValues(alpha: .52),
                  const Color(0xFF071A40).withValues(alpha: .02),
                ], stops: const [
                  0,
                  .6,
                  1
                ]),
              ))),
              Padding(
                  padding: EdgeInsets.fromLTRB(
                      20, 22, constraints.maxWidth * .28, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('MOBILES · ELECTRONICS · APPLIANCES',
                          style: TextStyle(
                              color: Color(0xFFBDD7FF),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .7)),
                      const SizedBox(height: 12),
                      Text(scheme['name'] ?? 'Savings scheme',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              height: 1.15,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 14),
                      Text(money(scheme['monthly_amount_paise']),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800)),
                      const Text('per month',
                          style: TextStyle(
                              color: Color(0xFFDCE8FF), fontSize: 12)),
                      const SizedBox(height: 5),
                      Text('${scheme['installment_count']} installments',
                          style: const TextStyle(
                              color: Color(0xFFDCE8FF), fontSize: 13)),
                      const SizedBox(height: 9),
                      Text('Shop benefit: ${money(scheme['benefit_paise'])}',
                          style: const TextStyle(
                              color: Color(0xFFB8E8FF),
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 18),
                      FilledButton(
                          onPressed: onTap,
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF15366D)),
                          child: const Text('View scheme')),
                    ],
                  )),
            ]),
          ));
}

class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key, required this.auth});
  final AuthService auth;
  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late Future<dynamic> _banner;
  final _controller = PageController();
  final Map<String, double> _ratios = {};
  final List<(ImageStream, ImageStreamListener)> _imageListeners = [];
  int _index = 0;

  String imageUrl(String path) => path.startsWith('http')
      ? path
      : '${apiBaseUrl.replaceFirst('/api', '')}$path';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _clearImages() {
    for (final (stream, listener) in _imageListeners) {
      stream.removeListener(listener);
    }
    _imageListeners.clear();
    _ratios.clear();
  }

  void _load() {
    _clearImages();
    _index = 0;
    _banner = widget.auth.request('/banner').then((banner) {
      if (!mounted) return banner;
      for (final slide in banner['slides'] as List? ?? []) {
        final url = imageUrl(slide['image'].toString());
        final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
        final listener = ImageStreamListener((info, synchronousCall) {
          if (mounted) {
            setState(() => _ratios[url] = info.image.width / info.image.height);
          }
        }, onError: (error, stackTrace) {});
        _imageListeners.add((stream, listener));
        stream.addListener(listener);
      }
      return banner;
    });
  }

  @override
  void didUpdateWidget(BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auth != widget.auth) _load();
  }

  @override
  void dispose() {
    _clearImages();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
        future: _banner,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final banner = Map<String, dynamic>.from(snapshot.data as Map);
          if (banner['mode'] == 'images') {
            final slides = List<Map<String, dynamic>>.from(
                (banner['slides'] as List? ?? [])
                    .map((item) => Map<String, dynamic>.from(item as Map)));
            if (slides.isEmpty) return const SizedBox.shrink();
            final selected = _index.clamp(0, slides.length - 1);
            final ratio =
                _ratios[imageUrl(slides[selected]['image'].toString())] ?? 2;
            return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    LayoutBuilder(
                        builder: (context, constraints) => AnimatedContainer(
                              key: const ValueKey('banner-image-section'),
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                              height: (constraints.maxWidth / ratio)
                                  .clamp(100, 520)
                                  .toDouble(),
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                        color: const Color(0xFF15366D)
                                            .withValues(alpha: .10),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6))
                                  ]),
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: PageView.builder(
                                    key: const ValueKey(
                                        'uploaded-banner-carousel'),
                                    controller: _controller,
                                    itemCount: slides.length,
                                    onPageChanged: (index) =>
                                        setState(() => _index = index),
                                    itemBuilder: (context, index) {
                                      final slide = slides[index];
                                      final body =
                                          (slide['body'] ?? '').toString();
                                      return Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.network(
                                                imageUrl(
                                                    slide['image'].toString()),
                                                fit: BoxFit.contain,
                                                errorBuilder: (context, error,
                                                        stackTrace) =>
                                                    const Center(
                                                        child: Icon(Icons
                                                            .broken_image_outlined))),
                                            if (body.isNotEmpty)
                                              Align(
                                                  alignment:
                                                      Alignment.bottomCenter,
                                                  child: Container(
                                                      width: double.infinity,
                                                      padding:
                                                          const EdgeInsets.all(
                                                              16),
                                                      decoration: const BoxDecoration(
                                                          gradient: LinearGradient(
                                                              colors: [
                                                            Color(0x000F172A),
                                                            Color(0xCC0F172A)
                                                          ],
                                                              begin: Alignment
                                                                  .topCenter,
                                                              end: Alignment
                                                                  .bottomCenter)),
                                                      child: Text(body,
                                                          maxLines: 3,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: const TextStyle(
                                                              color: Colors
                                                                  .white)))),
                                          ]);
                                    },
                                  )),
                            )),
                    if (slides.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              border:
                                  Border.all(color: const Color(0xFFE5EAF5))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            for (var index = 0; index < slides.length; index++)
                              Semantics(
                                  selected: selected == index,
                                  button: true,
                                  label:
                                      'Show banner ${index + 1} of ${slides.length}',
                                  child: InkWell(
                                    key: ValueKey('banner-indicator-$index'),
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: () => _controller.animateToPage(
                                        index,
                                        duration:
                                            const Duration(milliseconds: 350),
                                        curve: Curves.easeOutCubic),
                                    child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 12),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 250),
                                          width: selected == index ? 28 : 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              gradient: selected == index
                                                  ? const LinearGradient(
                                                      colors: [
                                                          Color(0xFF2563EB),
                                                          Color(0xFF06B6D4)
                                                        ])
                                                  : null,
                                              color: selected == index
                                                  ? null
                                                  : const Color(0xFFD7E0F3)),
                                        )),
                                  )),
                            const SizedBox(width: 8),
                            Text('${selected + 1}/${slides.length}',
                                key: const ValueKey('banner-slide-count'),
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B))),
                            const SizedBox(width: 4),
                          ]),
                        ),
                      ),
                  ]),
                ));
          }
          final title = (banner['title'] ?? '').toString();
          final body = (banner['body'] ?? '').toString();
          if (title.isEmpty && body.isEmpty) return const SizedBox.shrink();
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF06B6D4)]),
                borderRadius: BorderRadius.circular(20)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (title.isNotEmpty)
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20)),
              if (body.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(body,
                        style: const TextStyle(color: Colors.white))),
            ]),
          );
        },
      );
}

const schemeProductImages = [
  'assets/images/scheme-mobile.png',
  'assets/images/scheme-tv.png',
  'assets/images/scheme-appliances.png',
  'assets/images/scheme-kitchen.png',
  'assets/images/retail-products.png',
];

class Dashboard extends StatelessWidget {
  const Dashboard(
      {super.key,
      required this.auth,
      required this.email,
      required this.onBrowse,
      required this.onPayments});
  final VoidCallback onBrowse, onPayments;
  final AuthService auth;
  final String email;

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        BannerCarousel(auth: auth),
        const SizedBox(height: 20),
        ActiveSchemeCard(auth: auth, onBrowse: onBrowse),
        const SizedBox(height: 24),
        Wrap(spacing: 10, runSpacing: 16, children: [
          RetailShortcut(
              label: 'Find a plan',
              icon: Icons.savings_outlined,
              onTap: onBrowse),
          RetailShortcut(
              label: 'My payments',
              icon: Icons.receipt_long_outlined,
              onTap: onPayments),
          RetailShortcut(
              label: 'Redemptions',
              icon: Icons.card_giftcard_rounded,
              onTap: () => openPage(context, RedemptionsPage(auth: auth))),
          RetailShortcut(
              label: 'Get help',
              icon: Icons.support_agent_rounded,
              onTap: () => openPage(context, SupportPage(auth: auth))),
        ]),
      ]);
}

class ActiveSchemeCard extends StatefulWidget {
  const ActiveSchemeCard(
      {super.key, required this.auth, required this.onBrowse});
  final AuthService auth;
  final VoidCallback onBrowse;
  @override
  State<ActiveSchemeCard> createState() => _ActiveSchemeCardState();
}

class _ActiveSchemeCardState extends State<ActiveSchemeCard> {
  String? _selectedId;
  List<Map<String, dynamic>> _enrollments = [];
  bool _refreshing = false, _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(ActiveSchemeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auth != widget.auth) {
      _enrollments = [];
      _selectedId = null;
      _loaded = false;
      _refreshing = false;
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    final auth = widget.auth;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final data = await auth.request('/dashboard');
      if (!mounted || auth != widget.auth) return;
      setState(() {
        _enrollments = List<Map<String, dynamic>>.from(
            (data['enrollments'] as List)
                .map((item) => Map<String, dynamic>.from(item)));
        final active =
            _enrollments.where((item) => item['status'] == 'ACTIVE').toList();
        if (!active.any((item) => item['id'].toString() == _selectedId)) {
          _selectedId = active.isEmpty ? null : active.first['id'].toString();
        }
        _loaded = true;
        _refreshing = false;
      });
    } catch (error) {
      if (!mounted || auth != widget.auth) return;
      setState(() {
        _error = message(error);
        _refreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final active =
        _enrollments.where((item) => item['status'] == 'ACTIVE').toList();
    final enrollment = active.isEmpty
        ? null
        : active.firstWhere((item) => item['id'] == _selectedId,
            orElse: () => active.first);
    return Card(
      key: const ValueKey('active-scheme-card'),
      margin: EdgeInsets.zero,
      child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.savings_outlined, color: Color(0xFF4F70BE)),
                const SizedBox(width: 10),
                const Expanded(
                    child: Text('Your active scheme',
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF15366D)))),
                IconButton(
                    tooltip: 'Refresh active scheme',
                    onPressed: _refreshing ? null : _refresh,
                    icon: _refreshing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh_rounded)),
              ]),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
                TextButton(
                    onPressed: _refreshing ? null : _refresh,
                    child: const Text('Try again')),
              ],
              if (!_loaded && _refreshing) ...[
                const SizedBox(height: 12),
                const Text('Loading your enrolled schemes…'),
              ] else if (_loaded && enrollment == null) ...[
                const SizedBox(height: 12),
                const Text(
                    'You have no active scheme. Choose a published scheme to start saving.',
                    style: TextStyle(color: Color(0xFF64748B), height: 1.5)),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: widget.onBrowse,
                    child: const Text('Explore schemes')),
              ] else if (enrollment != null) ...[
                if (active.length > 1)
                  DropdownButton<String>(
                    isExpanded: true,
                    value: enrollment['id'].toString(),
                    items: active
                        .map((item) => DropdownMenuItem<String>(
                              value: item['id'].toString(),
                              child: Text(item['terms']['name'],
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedId = value),
                  )
                else ...[
                  const SizedBox(height: 12),
                  Text(enrollment['terms']['name'],
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 20),
                const Text('Total saved',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                Text(money(enrollment['paid_paise']),
                    style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -.8)),
                const SizedBox(height: 12),
                Text(
                    "${enrollment['paid_installments']} of ${enrollment['terms']['installment_count']} installments",
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569))),
                const SizedBox(height: 10),
                ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                        minHeight: 8,
                        value:
                            (enrollment['terms']['installment_count'] as num) >
                                    0
                                ? ((enrollment['paid_installments'] as num) /
                                        (enrollment['terms']
                                            ['installment_count'] as num))
                                    .clamp(0, 1)
                                    .toDouble()
                                : 0,
                        backgroundColor: const Color(0xFFE9EFFF),
                        color: const Color(0xFF2563EB))),
                const SizedBox(height: 16),
                Wrap(spacing: 28, runSpacing: 12, children: [
                  _metric('Shop benefit',
                      money(enrollment['terms']['benefit_paise'])),
                ]),
                if (enrollment['next_due'] != null) ...[
                  const SizedBox(height: 16),
                  Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(
                          'Next payment: ${money(enrollment['next_due']['amount_paise'])} on '
                          '${dueDate(enrollment['next_due']['due_date'], Map<String, dynamic>.from(enrollment['terms']))}',
                          style: const TextStyle(
                              color: Color(0xFF1D4ED8),
                              fontSize: 14,
                              fontWeight: FontWeight.w600))),
                ],
                const SizedBox(height: 16),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: () async {
                          await openPage(
                              context,
                              EnrollmentPage(
                                  auth: widget.auth, enrollment: enrollment));
                          if (mounted) _refresh();
                        },
                        child: const Text('View installments'))),
              ],
            ],
          )),
    );
  }

  Widget _metric(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      );
}

class SchemesPage extends StatelessWidget {
  const SchemesPage({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) => DataView(
      auth: auth,
      path: '/schemes',
      builder: (data, reload) =>
          ListView(padding: const EdgeInsets.all(20), children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available schemes',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A))),
                  Text('Choose an A2Mobile scheme to start saving',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              )),
              IconButton(
                  onPressed: reload, icon: const Icon(Icons.refresh_rounded))
            ]),
            const SizedBox(height: 16),
            if ((data as List).isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 48, color: Color(0xFF94A3B8)),
                    SizedBox(height: 12),
                    Text(
                      'The store has not published any schemes yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                    ),
                  ],
                ),
              ),
            for (var index = 0; index < data.length; index++) ...[
              SchemePromotionCard(
                imageAsset:
                    schemeProductImages[index % schemeProductImages.length],
                scheme: Map<String, dynamic>.from(data[index]),
                onTap: () => openPage(
                    context,
                    SchemeDetails(
                        auth: auth,
                        scheme: Map<String, dynamic>.from(data[index]))),
              ),
              const SizedBox(height: 18),
            ],
          ]));
}

class SchemeDetails extends StatefulWidget {
  const SchemeDetails({super.key, required this.auth, required this.scheme});
  final AuthService auth;
  final Map<String, dynamic> scheme;
  @override
  State<SchemeDetails> createState() => _SchemeDetailsState();
}

class _SchemeDetailsState extends State<SchemeDetails> {
  bool _accepted = false, _busy = false;
  final _key =
      // A bit shift by 32 wraps on the web; use the exact numeric bound.
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(4294967296)}';
  Future<void> join() async {
    setState(() => _busy = true);
    try {
      final result =
          await widget.auth.request('/enrollments', method: 'POST', headers: {
        'Idempotency-Key': _key
      }, body: {
        'scheme_id': widget.scheme['id'],
        'scheme_version': widget.scheme['version'],
        'accepted_terms': _accepted
      });
      if (mounted) {
        await openPage(
            context,
            EnrollmentPage(
                auth: widget.auth,
                enrollment: Map<String, dynamic>.from(result)));
      }
    } catch (e) {
      if (mounted) showMessage(context, message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scheme;
    final p = s['policy'];
    final eligibleTotal =
        s['monthly_amount_paise'] * s['installment_count'] + s['benefit_paise'];
    return Scaffold(
        appBar: AppBar(title: Text(s['name'])),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Plan Summary',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Text('${money(s['monthly_amount_paise'])} per month',
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2563EB))),
                  const SizedBox(height: 4),
                  Text(
                      '${s['installment_count']} installments • bonus ${money(s['benefit_paise'])}',
                      style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Eligible purchase value:',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF065F46))),
                        Text(money(eligibleTotal),
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF059669))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Terms Â· version ${s['version']}',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A))),
                  const SizedBox(height: 12),
                  Text(p['terms_text'],
                      style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF334155),
                          height: 1.5)),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  _ruleRow(
                      'Due Rule',
                      p['due_rule'] == 'ANNIVERSARY'
                          ? 'Joining-day anniversary'
                          : 'Day ${p['due_day']} of each month'),
                  _ruleRow('Grace Period', '${p['grace_days']} days'),
                  _ruleRow('Late Payments',
                      p['late_payments_allowed'] ? 'Allowed' : 'Not allowed'),
                  _ruleRow(
                      'Cancellation',
                      p['cancellation_allowed']
                          ? 'Allowed with approval'
                          : 'Not allowed'),
                  _ruleRow(
                      'Refund Deduction', money(p['refund_deduction_paise'])),
                  _ruleRow('Redemption Validity',
                      '${p['redemption_valid_days']} days'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Color(0xFF2563EB), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Verify your email in Profile before joining. Complete phone verification and KYC if requested when you enroll.',
                    style: TextStyle(
                        fontSize: 12.5, color: Color(0xFF1E40AF), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _accepted,
              onChanged: (v) => setState(() => _accepted = v ?? false),
              title: const Text(
                'I accept these terms and the installment schedule.',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              )),
          const SizedBox(height: 10),
          FilledButton(
              onPressed: _accepted && !_busy ? join : null,
              child: Text(_busy ? 'Enrolling…' : 'Join scheme'))
        ]));
  }

  Widget _ruleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}

class EnrollmentPage extends StatefulWidget {
  const EnrollmentPage(
      {super.key, required this.auth, required this.enrollment});
  final AuthService auth;
  final Map<String, dynamic> enrollment;
  @override
  State<EnrollmentPage> createState() => _EnrollmentPageState();
}

class _EnrollmentPageState extends State<EnrollmentPage> {
  bool _busy = false;
  Future<void> pay(dynamic installment, VoidCallback reload) async {
    setState(() => _busy = true);
    try {
      final order = Map<String, dynamic>.from(
          await widget.auth.request('/payments/orders', method: 'POST', body: {
        'enrollment_id': widget.enrollment['id'],
        'installment_number': installment['number']
      }));
      final response = await checkout(order);
      final verified = await widget.auth.request(
          '/payments/${order['order_id']}/verify',
          method: 'POST',
          body: response);
      if (mounted) {
        showMessage(
            context,
            verified['status'] == 'captured'
                ? 'Payment reconciled. Your receipt is in Payments.'
                : 'Payment is pending. Check Payments for confirmation.');
      }
    } catch (e) {
      if (mounted) showMessage(context, message(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.enrollment['terms']['name'])),
      body: DataView(
          auth: widget.auth,
          path: '/enrollments/${widget.enrollment['id']}/installments',
          builder: (data, reload) =>
              ListView(padding: const EdgeInsets.all(20), children: [
                const Text('Installments schedule',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A))),
                const SizedBox(height: 12),
                for (final i in data)
                  Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          title: Text(
                            'Installment ${i['number']} Â· ${money(i['amount_paise'])}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          subtitle: Text(
                            '${dueDate(i['due_date'], Map<String, dynamic>.from(widget.enrollment['terms']))} Â· ${i['status']}',
                            style: const TextStyle(
                                fontSize: 12.5, color: Color(0xFF64748B)),
                          ),
                          trailing: ['DUE', 'OVERDUE'].contains(i['status'])
                              ? FilledButton(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                  ),
                                  onPressed:
                                      _busy ? null : () => pay(i, reload),
                                  child: const Text('Pay'))
                              : const Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF10B981), size: 28))),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await widget.auth.request('/redemptions',
                            method: 'POST',
                            body: {'enrollment_id': widget.enrollment['id']});
                        if (context.mounted) {
                          await openPage(
                              context, RedemptionsPage(auth: widget.auth));
                        }
                      } catch (e) {
                        if (context.mounted) showMessage(context, message(e));
                      }
                    },
                    icon: const Icon(Icons.redeem_rounded, size: 18),
                    label: const Text('Request redemption')),
                const SizedBox(height: 10),
                TextButton(
                    onPressed: () => openPage(
                        context,
                        FormPage(
                            title: 'Request cancellation',
                            description:
                                'Your accepted terms determine eligibility and deductions. Store approval is required.',
                            fields: const [
                              InputField('reason', 'Reason', multiline: true)
                            ],
                            submit: (values) => widget.auth.request(
                                '/enrollments/${widget.enrollment['id']}/cancel',
                                method: 'POST',
                                body: values),
                            success:
                                'Cancellation request submitted for review.')),
                    child: const Text('Request cancellation'))
              ])));
}

class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) => DataView(
      auth: auth,
      path: '/payments',
      builder: (data, reload) =>
          ListView(padding: const EdgeInsets.all(20), children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payment history',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A))),
                  Text('All your scheme installment receipts',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              IconButton(
                  onPressed: reload, icon: const Icon(Icons.refresh_rounded))
            ]),
            const SizedBox(height: 16),
            RetailBanner(
                eyebrow: 'Recent payment total',
                title: money((data as List).fold<num>(
                    0,
                    (total, payment) =>
                        total + (payment['amount_paise'] as num? ?? 0))),
                description:
                    '${data.length} most recent payments shown. Open a transaction below to view its receipt.',
                icon: Icons.account_balance_wallet_outlined),
            const SizedBox(height: 24),
            if (data.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 48, color: Color(0xFF94A3B8)),
                    SizedBox(height: 12),
                    Text(
                      'No reconciled payments yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                    ),
                  ],
                ),
              ),
            for (final p in data)
              Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.receipt_outlined,
                            color: Color(0xFF2563EB)),
                      ),
                      title: Text(
                        money(p['amount_paise']),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: Color(0xFF0F172A)),
                      ),
                      subtitle: Text(
                        'Installment ${p['installment_number']}',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StatusPill(status: p['status']),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded,
                              color: Color(0xFF94A3B8)),
                        ],
                      ),
                      onTap: () => openPage(context,
                          ReceiptPage(auth: auth, paymentId: p['id'])))),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: () => openPage(
                    context,
                    RecordsPage(
                        auth: auth, title: 'Refunds', path: '/refunds')),
                icon: const Icon(Icons.assignment_return_outlined, size: 18),
                label: const Text('View refunds'))
          ]));
}

class ReceiptPage extends StatelessWidget {
  const ReceiptPage({super.key, required this.auth, required this.paymentId});
  final AuthService auth;
  final String paymentId;

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Contribution receipt')),
      body: DataView(
          auth: auth,
          path: '/payments/$paymentId/receipt',
          builder: (data, reload) {
            final text =
                'A2Mobile\nContribution receipt ${data['id']}\nPayment: ${data['payment_id']}\nEnrollment: ${data['enrollment_id']}\nInstallment: ${data['installment_number']}\nAmount: ${money(data['amount_paise'])}\nIssued: ${data['issued_at']}\nThis contribution receipt is not a product tax invoice.';
            return ListView(padding: const EdgeInsets.all(20), children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                          child: A2BrandHeader(
                              subtitle: 'Official Contribution Receipt')),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                      _receiptRow('Receipt ID', '${data['id']}'),
                      _receiptRow('Payment ID', '${data['payment_id']}'),
                      _receiptRow('Enrollment ID', '${data['enrollment_id']}'),
                      _receiptRow(
                          'Installment', '#${data['installment_number']}'),
                      _receiptRow('Amount', money(data['amount_paise']),
                          isHighlight: true),
                      _receiptRow('Issued At', '${data['issued_at']}'),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text(
                        'Note: This contribution receipt is not a product tax invoice. Store purchase invoice will be issued upon redemption.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      showMessage(context, 'Receipt copied.');
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy receipt'))
            ]);
          }));

  Widget _receiptRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: isHighlight ? 16 : 13,
                fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
                color: isHighlight
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const A2BrandHeader(subtitle: 'Notifications')),
      body: DataView(
          auth: auth,
          path: '/notifications',
          builder: (data, reload) =>
              ListView(padding: const EdgeInsets.all(20), children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Latest updates',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A))),
                          Text('Updates on your installments and schemes',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      )),
                      IconButton(
                          onPressed: reload,
                          icon: const Icon(Icons.refresh_rounded))
                    ]),
                const SizedBox(height: 16),
                if ((data as List).isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.notifications_none_rounded,
                            size: 48, color: Color(0xFF94A3B8)),
                        SizedBox(height: 12),
                        Text(
                          'You have no notifications.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Color(0xFF64748B), fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                for (final n in data)
                  Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          trailing: n['read'] == true
                              ? null
                              : const Badge(backgroundColor: Color(0xFF2563EB)),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: n['read'] == true
                                  ? const Color(0xFFF1F5F9)
                                  : const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              n['read'] == true
                                  ? Icons.notifications_none_rounded
                                  : Icons.notifications_active_rounded,
                              color: n['read'] == true
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF2563EB),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            n['title'],
                            style: TextStyle(
                              fontWeight: n['read'] == true
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              fontSize: 15,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text(n['body'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: Color(0xFF334155))),
                              if (n['created_at'] != null) ...[
                                const SizedBox(height: 10),
                                Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                        notificationDate(n['created_at']),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF4F70BE)))),
                              ],
                            ],
                          ),
                          onTap: () async {
                            try {
                              await auth.request(
                                  '/notifications/${Uri.encodeComponent(n['id'])}/read',
                                  method: 'PATCH');
                              reload();
                              final route = n['route'] as String? ?? '';
                              if (route.startsWith('/enrollments/')) {
                                final e = await auth.request(route);
                                if (context.mounted) {
                                  await openPage(
                                      context,
                                      EnrollmentPage(
                                          auth: auth,
                                          enrollment:
                                              Map<String, dynamic>.from(e)));
                                }
                              } else if (route.startsWith('/payments/')) {
                                if (context.mounted) {
                                  await openPage(
                                      context,
                                      ReceiptPage(
                                          auth: auth,
                                          paymentId: route.split('/').last));
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                showMessage(context, message(e));
                              }
                            }
                          }))
              ])));
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.auth, this.onSignedOut});
  final AuthService auth;
  final VoidCallback? onSignedOut;

  @override
  Widget build(BuildContext context) => DataView(
      auth: auth,
      path: '/me',
      builder: (data, reload) {
        final displayName = (data['name'] == null || data['name'] == '')
            ? data['email']
            : data['name'];
        final initial =
            (displayName.isNotEmpty ? displayName[0] : 'U').toUpperCase();
        return ListView(padding: const EdgeInsets.all(20), children: [
          Card(
            key: const ValueKey('profile-identity'),
            color: const Color(0xFFE9EFFF),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Profile settings',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4F70BE),
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(
                          displayName,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data['email'],
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data['phone'] ?? 'No phone saved',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('VERIFICATION & IDENTITY',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.8)),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_iphone_rounded,
                      color: Color(0xFF2563EB)),
                  title: const Text('Phone verification'),
                  subtitle: Text(data['phone_verified'] == true
                      ? 'Verified'
                      : 'Verification required'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openPage(context,
                      VerificationPage(auth: auth, phone: data['phone'] ?? '')),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.mail_outline_rounded,
                      color: Color(0xFF2563EB)),
                  title: const Text('Email verification'),
                  subtitle: Text(data['email_verified'] == true
                      ? 'Verified'
                      : 'Verification required'),
                  trailing: TextButton(
                    onPressed: () async {
                      try {
                        await auth.request('/auth/send-email-verification',
                            method: 'POST');
                        if (context.mounted) {
                          showMessage(context, 'Verification email sent.');
                        }
                      } catch (e) {
                        if (context.mounted) showMessage(context, message(e));
                      }
                    },
                    child: const Text('Send link'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined,
                      color: Color(0xFF2563EB)),
                  title: const Text('KYC verification'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openPage(context, KycPage(auth: auth)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.badge_outlined,
                      color: Color(0xFF2563EB)),
                  title: const Text('DigiLocker identity verification'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openPage(context, IdentityPage(auth: auth)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('ACCOUNT & PREFERENCES',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.8)),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.edit_outlined, color: Color(0xFF2563EB)),
                  title: const Text('Edit profile'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final profile = data['profile'] as Map;
                    await openPage(
                      context,
                      FormPage(
                        title: 'Profile',
                        fields: [
                          InputField('name', 'Full name',
                              initial: data['name']),
                          InputField('phone', 'Phone with country code',
                              initial: data['phone'] ?? ''),
                          InputField('address', 'Address',
                              initial: profile['address'] ?? '',
                              multiline: true,
                              optional: true),
                          InputField('nominee_name', 'Nominee name',
                              initial: profile['nominee_name'] ?? '',
                              optional: true),
                          InputField(
                              'nominee_relationship', 'Nominee relationship',
                              initial: profile['nominee_relationship'] ?? '',
                              optional: true)
                        ],
                        submit: (values) =>
                            auth.request('/me', method: 'PATCH', body: values),
                      ),
                    );
                    reload();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined,
                      color: Color(0xFF2563EB)),
                  title: const Text('Notifications'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openPage(context, NotificationsPage(auth: auth)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined,
                      color: Color(0xFF2563EB)),
                  title: const Text('Enable push notifications'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    try {
                      await enablePush(auth);
                      if (context.mounted) {
                        showMessage(context, 'Notifications enabled.');
                      }
                    } catch (e) {
                      if (context.mounted) showMessage(context, message(e));
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.redeem_rounded,
                      color: Color(0xFF2563EB)),
                  title: const Text('Redemptions'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openPage(context, RedemptionsPage(auth: auth)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.support_agent_rounded,
                      color: Color(0xFF2563EB)),
                  title: const Text('Support'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openPage(context, SupportPage(auth: auth)),
                ),
                if (onSignedOut != null) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded,
                        color: Color(0xFF64748B)),
                    title: const Text('Sign out'),
                    onTap: () async {
                      try {
                        await auth.logout();
                      } catch (e) {
                        if (context.mounted) showMessage(context, message(e));
                      } finally {
                        if (context.mounted) onSignedOut!();
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('ABOUT & POLICIES',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.8)),
          ),
          Card(
            child: Column(
              children: [
                for (final key in ['faq', 'contact', 'terms', 'privacy']) ...[
                  ListTile(
                    leading: Icon(
                      key == 'faq'
                          ? Icons.help_outline_rounded
                          : key == 'contact'
                              ? Icons.store_outlined
                              : key == 'terms'
                                  ? Icons.gavel_rounded
                                  : Icons.privacy_tip_outlined,
                      color: const Color(0xFF64748B),
                    ),
                    title: Text({
                      'faq': 'FAQ',
                      'contact': 'Store contact',
                      'terms': 'Terms',
                      'privacy': 'Privacy policy'
                    }[key]!),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => openPage(
                        context, ContentPage(auth: auth, contentKey: key)),
                  ),
                  if (key != 'privacy') const Divider(height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: reload,
            icon: const Icon(Icons.sync_rounded, size: 18),
            label: const Text('Refresh verification status'),
          ),
          const SizedBox(height: 24),
        ]);
      });
}

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key, required this.auth, required this.phone});
  final AuthService auth;
  final String phone;

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  late final verification = PhoneVerification(widget.auth, widget.phone);
  bool sending = false;

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Verify phone')),
      body: Column(children: [
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              const Icon(Icons.phone_android_rounded,
                  size: 48, color: Color(0xFF2563EB)),
              const SizedBox(height: 12),
              Text(
                'Verification for ${widget.phone}',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Send a code to verify your phone. By continuing, you agree that Google processes your number for verification and abuse prevention.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                  onPressed: sending
                      ? null
                      : () async {
                          setState(() => sending = true);
                          try {
                            await verification.send();
                            if (context.mounted) {
                              showMessage(context, 'Code sent.');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              showMessage(context, message(e));
                            }
                          } finally {
                            if (mounted) setState(() => sending = false);
                          }
                        },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Send verification code')),
            ],
          ),
        ),
        Expanded(
            child: FormPage(
                title: 'Enter code',
                fields: const [InputField('code', 'Six-digit code')],
                submit: (values) => verification.confirm(values['code']),
                success: 'Phone verified. Return to Profile and refresh.'))
      ]));
}

class KycPage extends StatelessWidget {
  const KycPage({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('KYC verification')),
      body: DataView(
          auth: auth,
          path: '/kyc/status',
          builder: (data, reload) =>
              ListView(padding: const EdgeInsets.all(20), children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Current Status',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600)),
                            StatusPill(status: '${data['status']}'),
                          ],
                        ),
                        if (data['pan_last4'] != null) ...[
                          const SizedBox(height: 12),
                          Text('PAN ending with ${data['pan_last4']}',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A))),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined,
                          color: Color(0xFF2563EB), size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'With your consent, your PAN and legal name are sent securely to our verification provider. The full PAN is not stored by this application.',
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1E40AF),
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                    onPressed: () async {
                      await openPage(
                          context,
                          FormPage(
                              title: 'Verify PAN',
                              fields: const [
                                InputField('pan', 'PAN'),
                                InputField('name', 'Legal name matching PAN')
                              ],
                              description:
                                  'By selecting “Consent and verify”, you authorize this identity verification.',
                              buttonLabel: 'Consent and verify',
                              submit: (values) => auth.request(
                                      '/kyc/pan/verify',
                                      method: 'POST',
                                      body: {
                                        ...values,
                                        'pan': values['pan']
                                            .toString()
                                            .toUpperCase(),
                                        'consent': true
                                      }),
                              success:
                                  'Verification processed. Return to view your status.'));
                      reload();
                    },
                    icon: const Icon(Icons.verified_outlined, size: 18),
                    label: const Text('Submit PAN for verification')),
                const SizedBox(height: 12),
                OutlinedButton(
                    onPressed: reload, child: const Text('Refresh status'))
              ])));
}

class RedemptionsPage extends StatelessWidget {
  const RedemptionsPage({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Redemptions')),
      body: DataView(
          auth: auth,
          path: '/redemptions',
          builder: (data, reload) =>
              ListView(padding: const EdgeInsets.all(20), children: [
                if ((data as List).isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.redeem_outlined,
                            size: 48, color: Color(0xFF94A3B8)),
                        SizedBox(height: 12),
                        Text(
                          'No redemptions yet. Request one from a completed enrollment.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Color(0xFF64748B), fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                for (final r in data)
                  Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      money(r['eligible_value_paise']),
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A)),
                                    ),
                                    StatusPill(status: r['status']),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  'Reference: ${r['id']}',
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF64748B),
                                      fontFamily: 'monospace'),
                                ),
                                if (r['status'] == 'PENDING') ...[
                                  const SizedBox(height: 16),
                                  FilledButton.tonal(
                                      onPressed: () async {
                                        try {
                                          await auth.request(
                                              '/redemptions/${r['id']}/send-otp',
                                              method: 'POST');
                                          if (context.mounted) {
                                            showMessage(context,
                                                'Code sent. Share it with store staff only when collecting your purchase.');
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            showMessage(context, message(e));
                                          }
                                        }
                                      },
                                      child: const Text('Send collection OTP')),
                                ]
                              ]))),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: reload, child: const Text('Refresh'))
              ])));
}

class SupportPage extends StatelessWidget {
  const SupportPage({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Support')),
      floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          onPressed: () => openPage(
              context,
              FormPage(
                  title: 'New support ticket',
                  fields: const [
                    InputField('subject', 'Subject'),
                    InputField('message', 'How can we help?', multiline: true)
                  ],
                  submit: (values) => auth.request('/support/tickets',
                      method: 'POST', body: values),
                  success: 'Ticket created.')),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New ticket')),
      body: DataView(
          auth: auth,
          path: '/support/tickets',
          builder: (data, reload) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Support tickets',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A))),
                        IconButton(
                            onPressed: reload,
                            icon: const Icon(Icons.refresh_rounded)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if ((data as List).isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.support_agent_outlined,
                                size: 48, color: Color(0xFF94A3B8)),
                            SizedBox(height: 12),
                            Text(
                              'No support tickets.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Color(0xFF64748B), fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    for (final t in data)
                      Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(t['subject'],
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0F172A))),
                                        ),
                                        StatusPill(status: t['status']),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(t['message'],
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF334155),
                                            height: 1.4)),
                                    for (final reply in t['replies'] ?? [])
                                      Container(
                                          margin:
                                              const EdgeInsets.only(top: 12),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                  Icons
                                                      .store_mall_directory_rounded,
                                                  size: 18,
                                                  color: Color(0xFF2563EB)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                    'Store reply: ${reply['message']}',
                                                    style: const TextStyle(
                                                        fontSize: 13,
                                                        color:
                                                            Color(0xFF1E293B))),
                                              ),
                                            ],
                                          ))
                                  ])))
                  ])));
}

class ContentPage extends StatelessWidget {
  const ContentPage({super.key, required this.auth, required this.contentKey});
  final AuthService auth;
  final String contentKey;

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(contentKey.toUpperCase())),
      body: DataView(
          auth: auth,
          path: '/content/$contentKey',
          builder: (data, reload) =>
              ListView(padding: const EdgeInsets.all(20), children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['title'],
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A))),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        SelectableText(
                          data['body'],
                          style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF334155),
                              height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ),
              ])));
}

class RecordsPage extends StatelessWidget {
  const RecordsPage(
      {super.key, required this.auth, required this.title, required this.path});
  final AuthService auth;
  final String title, path;

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: DataView(
          auth: auth,
          path: path,
          builder: (data, reload) =>
              ListView(padding: const EdgeInsets.all(20), children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A))),
                    IconButton(
                        onPressed: reload,
                        icon: const Icon(Icons.refresh_rounded)),
                  ],
                ),
                const SizedBox(height: 12),
                if ((data as List).isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text('No records.',
                        style: TextStyle(color: Color(0xFF64748B))),
                  ),
                for (final r in data)
                  Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          title: Text(
                            money(r['amount_paise']),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          subtitle: Text(r['reason'] ?? '',
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF64748B))),
                          trailing: StatusPill(status: '${r['status']}'))),
              ])));
}

class IdentityPage extends StatelessWidget {
  const IdentityPage({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('DigiLocker verification')),
      body: DataView(
          auth: auth,
          path: '/kyc/identity/status',
          builder: (data, reload) =>
              ListView(padding: const EdgeInsets.all(20), children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Verification Status',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600)),
                            StatusPill(status: '${data['status']}'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Authorize the provider to retrieve your PAN from DigiLocker and match it to your verified PAN. This app does not retain the downloaded document.',
                          style: TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF334155),
                              height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                    onPressed: () async {
                      try {
                        final result = await auth.request('/kyc/identity/start',
                            method: 'POST', body: {'consent': true});
                        final uri = Uri.parse(result['url']);
                        if (!await launchUrl(uri,
                            mode: LaunchMode.externalApplication,
                            webOnlyWindowName: '_self')) {
                          throw Exception(
                              'Unable to open identity verification');
                        }
                      } catch (e) {
                        if (context.mounted) showMessage(context, message(e));
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Consent and open DigiLocker')),
                const SizedBox(height: 12),
                OutlinedButton(
                    onPressed: reload,
                    child: const Text('Check verification result'))
              ])));
}
