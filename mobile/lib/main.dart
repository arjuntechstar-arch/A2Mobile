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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
Future<void> openPage(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

class SchemeApp extends StatelessWidget {
  const SchemeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'Mobile Shop Scheme',
      theme: ThemeData(
          colorSchemeSeed: const Color(0xff274b9f),
          useMaterial3: true,
          inputDecorationTheme:
              const InputDecorationTheme(border: OutlineInputBorder())),
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
      appBar: AppBar(title: const Text('Mobile Shop Scheme')),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                      key: _form,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(Icons.storefront, size: 64),
                            const SizedBox(height: 18),
                            const Text('Plan your next purchase',
                                style: TextStyle(fontSize: 28)),
                            const SizedBox(height: 8),
                            const Text(
                                'Choose a monthly scheme, track your contributions, and redeem your eligible store benefit.'),
                            const SizedBox(height: 28),
                            const Text('Sign in',
                                style: TextStyle(fontSize: 24)),
                            const SizedBox(height: 20),
                            if (widget.linkError != null)
                              Text(widget.linkError!,
                                  style: const TextStyle(color: Colors.red)),
                            TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                decoration:
                                    const InputDecoration(labelText: 'Email'),
                                validator: (v) => v != null && v.contains('@')
                                    ? null
                                    : 'Enter a valid email'),
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: _password,
                                obscureText: true,
                                decoration: const InputDecoration(
                                    labelText: 'Password'),
                                validator: (v) => v != null && v.length >= 8
                                    ? null
                                    : 'Enter at least 8 characters'),
                            const SizedBox(height: 20),
                            FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: Text(_busy ? 'Signing in…' : 'Sign in')),
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
              child: ListView(padding: const EdgeInsets.all(24), children: [
                if (widget.description != null) Text(widget.description!),
                Form(
                    key: _form,
                    child: Column(children: [
                      for (final f in widget.fields)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: TextFormField(
                                controller: _inputs[f.key],
                                decoration: InputDecoration(labelText: f.label),
                                obscureText: f.secret,
                                maxLines: f.multiline ? 5 : 1,
                                keyboardType: f.email
                                    ? TextInputType.emailAddress
                                    : TextInputType.text,
                                validator: (v) =>
                                    !f.optional && (v == null || v.isEmpty)
                                        ? 'This field is required'
                                        : null)),
                      if (_error != null)
                        Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      if (_result != null)
                        Text(_result!,
                            style: const TextStyle(color: Colors.green)),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: _busy ? null : submit,
                          child:
                              Text(_busy ? 'Please wait…' : widget.buttonLabel))
                    ]))
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
      appBar: AppBar(title: const Text('Mobile Shop Scheme'), actions: [
        IconButton(
            onPressed: () async {
              try {
                await widget.auth.logout();
              } finally {
                if (mounted) widget.onSignedOut();
              }
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out')
      ]),
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
                icon: Icon(Icons.home_outlined), label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.storefront), label: 'Schemes'),
            NavigationDestination(
                icon: Icon(Icons.payments_outlined), label: 'Payments'),
            NavigationDestination(
                icon: Icon(Icons.notifications_outlined),
                label: 'Notifications'),
            NavigationDestination(
                icon: Icon(Icons.person_outline), label: 'Profile')
          ]));
}

class Dashboard extends StatelessWidget {
  const Dashboard({super.key, required this.auth, required this.email});
  final AuthService auth;
  final String email;
  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Signed in as $email')),
        Expanded(
            child: DataView(
                auth: auth,
                path: '/dashboard',
                builder: (data, reload) =>
                    ListView(padding: const EdgeInsets.all(20), children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Your schemes',
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            IconButton(
                                onPressed: reload,
                                icon: const Icon(Icons.refresh))
                          ]),
                      if ((data['enrollments'] as List).isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                                'No enrollments yet. Verify your profile, then choose a published scheme.')),
                      for (final e in data['enrollments'])
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(e['terms']['name'],
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge),
                                      Text(e['status']),
                                      const SizedBox(height: 12),
                                      LinearProgressIndicator(
                                          value: e['paid_installments'] /
                                              e['terms']['installment_count']),
                                      const SizedBox(height: 10),
                                      Text(
                                          '${e['paid_installments']} / ${e['terms']['installment_count']} installments • Paid ${money(e['paid_paise'])}'),
                                      Text(
                                          'Shop benefit: ${money(e['terms']['benefit_paise'])}'),
                                      if (e['next_due'] != null)
                                        Text(
                                            'Next due: ${money(e['next_due']['amount_paise'])} on ${dueDate(e['next_due']['due_date'], Map<String, dynamic>.from(e['terms']))}'),
                                      FilledButton.tonal(
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
                                              const Text('View installments'))
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
              Text('Available schemes',
                  style: Theme.of(context).textTheme.headlineSmall),
              IconButton(onPressed: reload, icon: const Icon(Icons.refresh))
            ]),
            if ((data as List).isEmpty)
              const Text('The store has not published any schemes yet.'),
            for (final scheme in data)
              Card(
                  child: ListTile(
                      contentPadding: const EdgeInsets.all(20),
                      title: Text(scheme['name']),
                      subtitle: Text(
                          '${money(scheme['monthly_amount_paise'])} monthly × ${scheme['installment_count']}\nShop benefit ${money(scheme['benefit_paise'])}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => openPage(
                          context,
                          SchemeDetails(
                              auth: auth,
                              scheme: Map<String, dynamic>.from(scheme)))))
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
    return Scaffold(
        appBar: AppBar(title: Text(s['name'])),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          Text('${money(s['monthly_amount_paise'])} per month',
              style: Theme.of(context).textTheme.headlineMedium),
          Text(
              '${s['installment_count']} installments • benefit ${money(s['benefit_paise'])}'),
          Text(
              'Eligible purchase value: ${money(s['monthly_amount_paise'] * s['installment_count'] + s['benefit_paise'])}'),
          const SizedBox(height: 24),
          Text('Terms · version ${s['version']}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(p['terms_text']),
          const SizedBox(height: 16),
          Text(
              'Due rule: ${p['due_rule'] == 'ANNIVERSARY' ? 'Joining-day anniversary' : 'Day ${p['due_day']} of each month'}\nGrace period: ${p['grace_days']} days\nLate payments: ${p['late_payments_allowed'] ? 'allowed' : 'not allowed'}\nCancellation: ${p['cancellation_allowed'] ? 'allowed with approval' : 'not allowed'}\nRefund deduction: ${money(p['refund_deduction_paise'])}\nRedemption validity: ${p['redemption_valid_days']} days'),
          const SizedBox(height: 20),
          const Text(
              'A verified phone, email and provider-verified KYC are required. Complete these in Profile before joining.'),
          CheckboxListTile(
              value: _accepted,
              onChanged: (v) => setState(() => _accepted = v ?? false),
              title: const Text(
                  'I accept these terms and the installment schedule.')),
          FilledButton(
              onPressed: _accepted && !_busy ? join : null,
              child: Text(_busy ? 'Enrolling…' : 'Join scheme'))
        ]));
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
                for (final i in data)
                  Card(
                      child: ListTile(
                          title: Text(
                              'Installment ${i['number']} · ${money(i['amount_paise'])}'),
                          subtitle: Text(
                              '${dueDate(i['due_date'], Map<String, dynamic>.from(widget.enrollment['terms']))} · ${i['status']}'),
                          trailing: ['DUE', 'OVERDUE'].contains(i['status'])
                              ? FilledButton(
                                  onPressed:
                                      _busy ? null : () => pay(i, reload),
                                  child: const Text('Pay'))
                              : const Icon(Icons.check_circle,
                                  color: Colors.green))),
                const SizedBox(height: 16),
                OutlinedButton(
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
                    child: const Text('Request redemption')),
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
              Text('Payment history',
                  style: Theme.of(context).textTheme.headlineSmall),
              IconButton(onPressed: reload, icon: const Icon(Icons.refresh))
            ]),
            if ((data as List).isEmpty)
              const Text('No reconciled payments yet.'),
            for (final p in data)
              Card(
                  child: ListTile(
                      title: Text(money(p['amount_paise'])),
                      subtitle: Text(
                          'Installment ${p['installment_number']} · ${p['status']}'),
                      trailing: const Icon(Icons.receipt_long),
                      onTap: () => openPage(context,
                          ReceiptPage(auth: auth, paymentId: p['id'])))),
            TextButton(
                onPressed: () => openPage(
                    context,
                    RecordsPage(
                        auth: auth, title: 'Refunds', path: '/refunds')),
                child: const Text('View refunds'))
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
                'Mobile Shop Scheme\nContribution receipt ${data['id']}\nPayment: ${data['payment_id']}\nEnrollment: ${data['enrollment_id']}\nInstallment: ${data['installment_number']}\nAmount: ${money(data['amount_paise'])}\nIssued: ${data['issued_at']}\nThis contribution receipt is not a product tax invoice.';
            return ListView(padding: const EdgeInsets.all(24), children: [
              SelectableText(text,
                  style: const TextStyle(fontSize: 18, height: 1.8)),
              const SizedBox(height: 24),
              OutlinedButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      showMessage(context, 'Receipt copied.');
                    }
                  },
                  child: const Text('Copy receipt'))
            ]);
          }));
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
              Text('Notifications',
                  style: Theme.of(context).textTheme.headlineSmall),
              IconButton(onPressed: reload, icon: const Icon(Icons.refresh))
            ]),
            if ((data as List).isEmpty)
              const Text('You have no notifications.'),
            for (final n in data)
              Card(
                  child: ListTile(
                      leading: Icon(n['read'] == true
                          ? Icons.notifications_none
                          : Icons.notifications_active),
                      title: Text(n['title']),
                      subtitle: Text(n['body']),
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
      builder: (data, reload) =>
          ListView(padding: const EdgeInsets.all(20), children: [
            Text(data['name'] == '' ? data['email'] : data['name'],
                style: Theme.of(context).textTheme.headlineSmall),
            Text(data['email']),
            Text(data['phone'] ?? 'No phone saved'),
            const SizedBox(height: 20),
            ListTile(
                title: const Text('Phone verification'),
                subtitle: Text(data['phone_verified'] == true
                    ? 'Verified'
                    : 'Verification required'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openPage(context,
                    VerificationPage(auth: auth, phone: data['phone'] ?? ''))),
            ListTile(
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
                    child: const Text('Send link'))),
            ListTile(
                title: const Text('Edit profile'),
                trailing: const Icon(Icons.edit),
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
                          submit: (values) => auth.request('/me',
                              method: 'PATCH', body: values)));
                  reload();
                }),
            ListTile(
                title: const Text('KYC verification'),
                trailing: const Icon(Icons.verified_user_outlined),
                onTap: () => openPage(context, KycPage(auth: auth))),
            ListTile(
                title: const Text('DigiLocker identity verification'),
                trailing: const Icon(Icons.badge_outlined),
                onTap: () => openPage(context, IdentityPage(auth: auth))),
            ListTile(
                title: const Text('Enable push notifications'),
                trailing: const Icon(Icons.notifications_active),
                onTap: () async {
                  try {
                    await enablePush(auth);
                    if (context.mounted) {
                      showMessage(context, 'Notifications enabled.');
                    }
                  } catch (e) {
                    if (context.mounted) showMessage(context, message(e));
                  }
                }),
            ListTile(
                title: const Text('Redemptions'),
                trailing: const Icon(Icons.redeem),
                onTap: () => openPage(context, RedemptionsPage(auth: auth))),
            ListTile(
                title: const Text('Support'),
                trailing: const Icon(Icons.support_agent),
                onTap: () => openPage(context, SupportPage(auth: auth))),
            for (final key in ['faq', 'contact', 'terms', 'privacy'])
              ListTile(
                  title: Text({
                    'faq': 'FAQ',
                    'contact': 'Store contact',
                    'terms': 'Terms',
                    'privacy': 'Privacy policy'
                  }[key]!),
                  onTap: () => openPage(
                      context, ContentPage(auth: auth, contentKey: key))),
            OutlinedButton(
                onPressed: reload,
                child: const Text('Refresh verification status')),
          ]));
}

class VerificationPage extends StatelessWidget {
  const VerificationPage({super.key, required this.auth, required this.phone});
  final AuthService auth;
  final String phone;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Verify phone')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Verification for $phone')),
        OutlinedButton(
            onPressed: () async {
              try {
                await auth.request('/auth/send-phone-otp',
                    method: 'POST', body: {'phone': phone});
                if (context.mounted) showMessage(context, 'Code sent.');
              } catch (e) {
                if (context.mounted) showMessage(context, message(e));
              }
            },
            child: const Text('Send verification code')),
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
              ListView(padding: const EdgeInsets.all(24), children: [
                Text('Status: ${data['status']}',
                    style: Theme.of(context).textTheme.titleLarge),
                if (data['pan_last4'] != null)
                  Text('PAN ending ${data['pan_last4']}'),
                const SizedBox(height: 20),
                const Text(
                    'With your consent, your PAN and legal name are sent securely to our verification provider. The full PAN is not stored by this application.'),
                const SizedBox(height: 16),
                FilledButton(
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
                    child: const Text('Submit PAN for verification')),
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
                  const Text(
                      'No redemptions yet. Request one from a completed enrollment.'),
                for (final r in data)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${money(r['eligible_value_paise'])} · ${r['status']}'),
                                SelectableText('Reference: ${r['id']}'),
                                if (r['status'] == 'PENDING')
                                  OutlinedButton(
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
                                      child: const Text('Send collection OTP'))
                              ]))),
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
          icon: const Icon(Icons.add),
          label: const Text('New ticket')),
      body: DataView(
          auth: auth,
          path: '/support/tickets',
          builder: (data, reload) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  children: [
                    OutlinedButton(
                        onPressed: reload, child: const Text('Refresh')),
                    if ((data as List).isEmpty)
                      const Text('No support tickets.'),
                    for (final t in data)
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t['subject'],
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    Text(t['status']),
                                    Text(t['message']),
                                    for (final reply in t['replies'] ?? [])
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(top: 12),
                                          child: Text(
                                              'Store reply: ${reply['message']}'))
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
              ListView(padding: const EdgeInsets.all(24), children: [
                Text(data['title'],
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 20),
                SelectableText(data['body'])
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
                OutlinedButton(onPressed: reload, child: const Text('Refresh')),
                if ((data as List).isEmpty) const Text('No records.'),
                for (final r in data)
                  Card(
                      child: ListTile(
                          title: Text(
                              '${money(r['amount_paise'])} · ${r['status']}'),
                          subtitle: Text(r['reason'] ?? '')))
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
              ListView(padding: const EdgeInsets.all(24), children: [
                Text('Status: ${data['status']}'),
                const SizedBox(height: 20),
                const Text(
                    'Authorize the provider to retrieve your PAN from DigiLocker and match it to your verified PAN. This app does not retain the downloaded document.'),
                const SizedBox(height: 20),
                FilledButton(
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
                    child: const Text('Consent and open DigiLocker')),
                OutlinedButton(
                    onPressed: reload,
                    child: const Text('Check verification result'))
              ])));
}
