import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
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
              colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
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
    if (['ACTIVE', 'COMPLETED', 'CAPTURED', 'VERIFIED', 'RESOLVED', 'SUCCESS'].contains(s)) {
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF059669);
    } else if (['DUE', 'PENDING', 'OPEN', 'IN_PROGRESS', 'REQUIRES_REVIEW', 'PENDING_APPROVAL'].contains(s)) {
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          primary: const Color(0xFF2563EB),
          secondary: const Color(0xFF06B6D4),
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
          elevation: 0,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 3,
          indicatorColor: const Color(0xFFEEF2FF),
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
              return const IconThemeData(color: Color(0xFF2563EB));
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
      return FormPage(
          title: 'Reset password',
          fields: const [
            InputField('password', 'New password (12+ characters)',
                secret: true)
          ],
          submit: (values) async {
            await _auth.request('/auth/reset-password',
                method: 'POST', body: {'token': reset, ...values});
          },
          success:
              'Password updated. Open the app without the reset link and sign in.');
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
  bool _busy = false;

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
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const A2BrandHeader()),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Form(
                      key: _form,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Row(
                              children: [
                                A2BrandHeader(),
                                Spacer(),
                                Icon(Icons.storefront_rounded, size: 28, color: Color(0xFF2563EB)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text('Plan your next purchase',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                            const SizedBox(height: 4),
                            const Text(
                                'Choose a monthly scheme, track your contributions, and redeem your eligible store benefit.',
                                style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.35)),
                            const SizedBox(height: 16),
                            const Text('Sign in',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                            const SizedBox(height: 12),
                            if (widget.linkError != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(widget.linkError!,
                                    style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                              ),
                            TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                decoration:
                                    const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded, size: 18)),
                                validator: (v) => v != null && v.contains('@')
                                    ? null
                                    : 'Enter a valid email'),
                            const SizedBox(height: 12),
                            TextFormField(
                                controller: _password,
                                obscureText: true,
                                decoration: const InputDecoration(
                                    labelText: 'Password', prefixIcon: Icon(Icons.lock_outline_rounded, size: 18)),
                                validator: (v) => v != null && v.length >= 8
                                    ? null
                                    : 'Enter at least 8 characters'),
                            const SizedBox(height: 16),
                            FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: Text(_busy ? 'Signing in…' : 'Sign in')),
                            const SizedBox(height: 4),
                            TextButton(
                                onPressed: () => openPage(
                                    context,
                                    FormPage(
                                        title: 'Create account',
                                        fields: const [
                                          InputField('name', 'Full name'),
                                          InputField('email', 'Email',
                                              email: true),
                                          InputField('phone',
                                              'Phone with country code'),
                                          InputField('password',
                                              'Password (12+ characters)',
                                              secret: true)
                                        ],
                                        submit: (values) => widget.auth.request(
                                            '/auth/register',
                                            method: 'POST',
                                            body: values),
                                        success:
                                            'Account created. Sign in, then verify your phone and email from Profile.')),
                                child: const Text('Create an account')),
                            TextButton(
                                onPressed: () => openPage(
                                    context,
                                    FormPage(
                                        title: 'Forgot password',
                                        fields: const [
                                          InputField('email', 'Email',
                                              email: true)
                                        ],
                                        submit: (values) => widget.auth.request(
                                            '/auth/forgot-password',
                                            method: 'POST',
                                            body: values),
                                        success:
                                            'If this account exists, a reset email has been sent.')),
                                child: const Text('Forgot password?')),
                            Wrap(
                                alignment: WrapAlignment.center,
                                children: ['terms', 'privacy']
                                    .map((key) => TextButton(
                                        onPressed: () => openPage(
                                            context,
                                            ContentPage(
                                                auth: widget.auth,
                                                contentKey: key)),
                                        child: Text(key == 'terms'
                                            ? 'Terms'
                                            : 'Privacy')))
                                    .toList()),
                          ]))))));
}

class InputField {
  const InputField(this.key, this.label,
      {this.secret = false,
      this.email = false,
      this.multiline = false,
      this.initial = '',
      this.optional = false});
  final String key, label, initial;
  final bool secret, email, multiline, optional;
}

class FormPage extends StatefulWidget {
  const FormPage(
      {super.key,
      required this.title,
      required this.fields,
      required this.submit,
      this.success = 'Saved successfully.',
      this.description,
      this.buttonLabel = 'Submit'});
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
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(padding: const EdgeInsets.all(20), children: [
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
                      style: const TextStyle(fontSize: 13, color: Color(0xFF3730A3), height: 1.4),
                    ),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
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
                                        validator: (v) =>
                                            !f.optional && (v == null || v.isEmpty)
                                                ? 'This field is required'
                                                : null)),
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
                                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
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
                                      style: const TextStyle(color: Color(0xFF065F46), fontSize: 13)),
                                ),
                              const SizedBox(height: 6),
                              FilledButton(
                                  onPressed: _busy ? null : submit,
                                  child: Text(_busy ? 'Please wait…' : widget.buttonLabel))
                            ])),
                  ),
                ),
              ]))));
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
  int _tab = Uri.base.queryParameters.containsKey('notifications') ? 3 : 0;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: const A2BrandHeader(),
        actions: [
          IconButton(
              onPressed: () async {
                try {
                  await widget.auth.logout();
                } finally {
                  if (mounted) widget.onSignedOut();
                }
              },
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Sign out'),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _tab, children: [
        Dashboard(auth: widget.auth, email: widget.email),
        SchemesPage(auth: widget.auth),
        PaymentsPage(auth: widget.auth),
        NotificationsPage(auth: widget.auth),
        ProfilePage(auth: widget.auth),
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
                icon: Icon(Icons.notifications_outlined),
                selectedIcon: Icon(Icons.notifications_rounded),
                label: 'Notifications'),
            NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile')
          ]));
}

class Dashboard extends StatelessWidget {
  const Dashboard({super.key, required this.auth, required this.email});
  final AuthService auth;
  final String email;

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Signed in as', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                    Text(
                      'Signed in as $email',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
            child: DataView(
                auth: auth,
                path: '/dashboard',
                builder: (data, reload) =>
                    ListView(padding: const EdgeInsets.all(16), children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Your schemes',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                Text('Active savings and installment status',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ),
                            IconButton(
                                onPressed: reload,
                                icon: const Icon(Icons.refresh_rounded))
                          ]),
                      const SizedBox(height: 12),
                      if ((data['enrollments'] as List).isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          margin: const EdgeInsets.only(top: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.savings_outlined, size: 48, color: Color(0xFF94A3B8)),
                              SizedBox(height: 12),
                              Text(
                                'No enrollments yet. Verify your profile, then choose a published scheme.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      for (final e in data['enrollments'])
                        Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              e['terms']['name'],
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                            ),
                                          ),
                                          StatusPill(status: e['status']),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: (e['paid_installments'] as num) /
                                              (e['terms']['installment_count'] as num),
                                          minHeight: 8,
                                          backgroundColor: const Color(0xFFF1F5F9),
                                          color: const Color(0xFF2563EB),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Installments', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${e['paid_installments']} / ${e['terms']['installment_count']}',
                                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                                ),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Total Paid', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                                const SizedBox(height: 2),
                                                Text(
                                                  money(e['paid_paise']),
                                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF2563EB)),
                                                ),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Shop Benefit', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                                const SizedBox(height: 2),
                                                Text(
                                                  money(e['terms']['benefit_paise']),
                                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF059669)),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (e['next_due'] != null) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFFBEB),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFFDE68A)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFFD97706)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Next due: ${money(e['next_due']['amount_paise'])} on ${dueDate(e['next_due']['due_date'], Map<String, dynamic>.from(e['terms']))}',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 14),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.tonal(
                                            onPressed: () async {
                                              await openPage(
                                                  context,
                                                  EnrollmentPage(
                                                      auth: auth,
                                                      enrollment: Map<String,
                                                          dynamic>.from(e)));
                                              reload();
                                            },
                                            child:
                                                const Text('View installments')),
                                      )
                                    ])))
                    ])))
      ]);
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available schemes',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  Text('Choose an A2Mobile scheme to start saving',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              IconButton(onPressed: reload, icon: const Icon(Icons.refresh_rounded))
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
                    Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF94A3B8)),
                    SizedBox(height: 12),
                    Text(
                      'The store has not published any schemes yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                    ),
                  ],
                ),
              ),
            for (final scheme in data)
              Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => openPage(
                        context,
                        SchemeDetails(
                            auth: auth,
                            scheme: Map<String, dynamic>.from(scheme))),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'A2Mobile Scheme',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            scheme['name'],
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                money(scheme['monthly_amount_paise']),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2563EB)),
                              ),
                              const Text(
                                ' / month',
                                style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                              const Spacer(),
                              Text(
                                '${scheme['installment_count']} installments',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.card_giftcard_rounded, size: 16, color: Color(0xFF059669)),
                                const SizedBox(width: 8),
                                Text(
                                  'Shop benefit: ${money(scheme['benefit_paise'])}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ))
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
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
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
    final eligibleTotal = s['monthly_amount_paise'] * s['installment_count'] + s['benefit_paise'];
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
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Text('${money(s['monthly_amount_paise'])} per month',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
                  const SizedBox(height: 4),
                  Text('${s['installment_count']} installments • bonus ${money(s['benefit_paise'])}',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
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
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF065F46))),
                        Text(money(eligibleTotal),
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
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
                  Text('Terms · version ${s['version']}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 12),
                  Text(p['terms_text'], style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.5)),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  _ruleRow('Due Rule', p['due_rule'] == 'ANNIVERSARY' ? 'Joining-day anniversary' : 'Day ${p['due_day']} of each month'),
                  _ruleRow('Grace Period', '${p['grace_days']} days'),
                  _ruleRow('Late Payments', p['late_payments_allowed'] ? 'Allowed' : 'Not allowed'),
                  _ruleRow('Cancellation', p['cancellation_allowed'] ? 'Allowed with approval' : 'Not allowed'),
                  _ruleRow('Refund Deduction', money(p['refund_deduction_paise'])),
                  _ruleRow('Redemption Validity', '${p['redemption_valid_days']} days'),
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
                Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'A verified phone, email and provider-verified KYC are required. Complete these in Profile before joining.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF1E40AF), height: 1.4),
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
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                const SizedBox(height: 12),
                for (final i in data)
                  Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          title: Text(
                            'Installment ${i['number']} · ${money(i['amount_paise'])}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          subtitle: Text(
                            '${dueDate(i['due_date'], Map<String, dynamic>.from(widget.enrollment['terms']))} · ${i['status']}',
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                          ),
                          trailing: ['DUE', 'OVERDUE'].contains(i['status'])
                              ? FilledButton(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  Text('All your scheme installment receipts',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              IconButton(onPressed: reload, icon: const Icon(Icons.refresh_rounded))
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
                    Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF94A3B8)),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.receipt_outlined, color: Color(0xFF2563EB)),
                      ),
                      title: Text(
                        money(p['amount_paise']),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0F172A)),
                      ),
                      subtitle: Text(
                        'Installment ${p['installment_number']}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StatusPill(status: p['status']),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
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
                      const Center(child: A2BrandHeader(subtitle: 'Official Contribution Receipt')),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                      _receiptRow('Receipt ID', '${data['id']}'),
                      _receiptRow('Payment ID', '${data['payment_id']}'),
                      _receiptRow('Enrollment ID', '${data['enrollment_id']}'),
                      _receiptRow('Installment', '#${data['installment_number']}'),
                      _receiptRow('Amount', money(data['amount_paise']), isHighlight: true),
                      _receiptRow('Issued At', '${data['issued_at']}'),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text(
                        'Note: This contribution receipt is not a product tax invoice. Store purchase invoice will be issued upon redemption.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
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
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: isHighlight ? 16 : 13,
                fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
                color: isHighlight ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
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
  Widget build(BuildContext context) => DataView(
      auth: auth,
      path: '/notifications',
      builder: (data, reload) =>
          ListView(padding: const EdgeInsets.all(20), children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notifications',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  Text('Updates on your installments and schemes',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              IconButton(onPressed: reload, icon: const Icon(Icons.refresh_rounded))
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
                    Icon(Icons.notifications_none_rounded, size: 48, color: Color(0xFF94A3B8)),
                    SizedBox(height: 12),
                    Text(
                      'You have no notifications.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                    ),
                  ],
                ),
              ),
            for (final n in data)
              Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: n['read'] == true ? const Color(0xFFF1F5F9) : const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          n['read'] == true
                              ? Icons.notifications_none_rounded
                              : Icons.notifications_active_rounded,
                          color: n['read'] == true ? const Color(0xFF94A3B8) : const Color(0xFF2563EB),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        n['title'],
                        style: TextStyle(
                          fontWeight: n['read'] == true ? FontWeight.w600 : FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        n['body'],
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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
                          if (context.mounted) showMessage(context, message(e));
                        }
                      }))
          ]));
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) => DataView(
      auth: auth,
      path: '/me',
      builder: (data, reload) {
        final displayName = (data['name'] == null || data['name'] == '') ? data['email'] : data['name'];
        final initial = (displayName.isNotEmpty ? displayName[0] : 'U').toUpperCase();
        return ListView(padding: const EdgeInsets.all(20), children: [
          Card(
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
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data['email'],
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data['phone'] ?? 'No phone saved',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
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
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.8)),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_iphone_rounded, color: Color(0xFF2563EB)),
                  title: const Text('Phone verification'),
                  subtitle: Text(data['phone_verified'] == true ? 'Verified' : 'Verification required'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openPage(context, VerificationPage(auth: auth, phone: data['phone'] ?? '')),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.mail_outline_rounded, color: Color(0xFF2563EB)),
                  title: const Text('Email verification'),
                  subtitle: Text(data['email_verified'] == true ? 'Verified' : 'Verification required'),
                  trailing: TextButton(
                    onPressed: () async {
                      try {
                        await auth.request('/auth/send-email-verification', method: 'POST');
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
                  leading: const Icon(Icons.verified_user_outlined, color: Color(0xFF2563EB)),
                  title: const Text('KYC verification'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openPage(context, KycPage(auth: auth)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.badge_outlined, color: Color(0xFF2563EB)),
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
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.8)),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB)),
                  title: const Text('Edit profile'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final profile = data['profile'] as Map;
                    await openPage(
                      context,
                      FormPage(
                        title: 'Profile',
                        fields: [
                          InputField('name', 'Full name', initial: data['name']),
                          InputField('phone', 'Phone with country code', initial: data['phone'] ?? ''),
                          InputField('address', 'Address', initial: profile['address'] ?? '', multiline: true, optional: true),
                          InputField('nominee_name', 'Nominee name', initial: profile['nominee_name'] ?? '', optional: true),
                          InputField('nominee_relationship', 'Nominee relationship', initial: profile['nominee_relationship'] ?? '', optional: true)
                        ],
                        submit: (values) => auth.request('/me', method: 'PATCH', body: values),
                      ),
                    );
                    reload();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined, color: Color(0xFF2563EB)),
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
                  leading: const Icon(Icons.redeem_rounded, color: Color(0xFF2563EB)),
                  title: const Text('Redemptions'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openPage(context, RedemptionsPage(auth: auth)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.support_agent_rounded, color: Color(0xFF2563EB)),
                  title: const Text('Support'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openPage(context, SupportPage(auth: auth)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('ABOUT & POLICIES',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.8)),
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
                    onTap: () => openPage(context, ContentPage(auth: auth, contentKey: key)),
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

class VerificationPage extends StatelessWidget {
  const VerificationPage({super.key, required this.auth, required this.phone});
  final AuthService auth;
  final String phone;

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
              const Icon(Icons.phone_android_rounded, size: 48, color: Color(0xFF2563EB)),
              const SizedBox(height: 12),
              Text(
                'Verification for $phone',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              const Text(
                'We will send a 6-digit one-time password to verify your mobile number.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                  onPressed: () async {
                    try {
                      await auth.request('/auth/send-phone-otp',
                          method: 'POST', body: {'phone': phone});
                      if (context.mounted) showMessage(context, 'Code sent.');
                    } catch (e) {
                      if (context.mounted) showMessage(context, message(e));
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
                submit: (values) => auth.request('/auth/verify-phone-otp',
                    method: 'POST', body: {'phone': phone, ...values}),
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
                            const Text('Current Status', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                            StatusPill(status: '${data['status']}'),
                          ],
                        ),
                        if (data['pan_last4'] != null) ...[
                          const SizedBox(height: 12),
                          Text('PAN ending with ${data['pan_last4']}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
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
                      Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'With your consent, your PAN and legal name are sent securely to our verification provider. The full PAN is not stored by this application.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF1E40AF), height: 1.4),
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
                        Icon(Icons.redeem_outlined, size: 48, color: Color(0xFF94A3B8)),
                        SizedBox(height: 12),
                        Text(
                          'No redemptions yet. Request one from a completed enrollment.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      money(r['eligible_value_paise']),
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                    ),
                                    StatusPill(status: r['status']),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  'Reference: ${r['id']}',
                                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontFamily: 'monospace'),
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
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        IconButton(onPressed: reload, icon: const Icon(Icons.refresh_rounded)),
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
                            Icon(Icons.support_agent_outlined, size: 48, color: Color(0xFF94A3B8)),
                            SizedBox(height: 12),
                            Text(
                              'No support tickets.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
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
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(t['subject'],
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                        ),
                                        StatusPill(status: t['status']),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(t['message'], style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4)),
                                    for (final reply in t['replies'] ?? [])
                                      Container(
                                          margin: const EdgeInsets.only(top: 12),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Icon(Icons.store_mall_directory_rounded, size: 18, color: Color(0xFF2563EB)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                    'Store reply: ${reply['message']}',
                                                    style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
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
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        SelectableText(
                          data['body'],
                          style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.6),
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
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    IconButton(onPressed: reload, icon: const Icon(Icons.refresh_rounded)),
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
                    child: const Text('No records.', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                for (final r in data)
                  Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            money(r['amount_paise']),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          subtitle: Text(r['reason'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
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
                                style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                            StatusPill(status: '${data['status']}'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Authorize the provider to retrieve your PAN from DigiLocker and match it to your verified PAN. This app does not retain the downloaded document.',
                          style: TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.5),
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
