import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000/api');

void main() => runApp(const SchemeApp());

class AuthService {
  AuthService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(), _storage = storage ?? const FlutterSecureStorage();
  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<String> login(String email, String password) async {
    final response = await _client.post(Uri.parse('$_apiBaseUrl/auth/login'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': email, 'password': password}));
    if (response.statusCode != 200) throw Exception('Invalid email or password');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    await _storage.write(key: 'access_token', value: body['access_token'] as String);
    await _storage.write(key: 'refresh_token', value: body['refresh_token'] as String);
    return _currentEmail();
  }

  Future<String?> restoreEmail() async {
    if (await _storage.read(key: 'access_token') == null) return null;
    try {
      return await _currentEmail();
    } catch (_) {
      if (await _refresh()) {
        try { return await _currentEmail(); } catch (_) { /* session will be cleared below */ }
      }
      await logout();
      return null;
    }
  }

  Future<String> _currentEmail() async {
    final access = await _storage.read(key: 'access_token');
    if (access == null) throw Exception('No active session');
    final response = await _client.get(Uri.parse('$_apiBaseUrl/auth/me'), headers: {'Authorization': 'Bearer $access'});
    if (response.statusCode != 200) throw Exception('Session expired');
    return (jsonDecode(response.body) as Map<String, dynamic>)['email'] as String;
  }

  Future<bool> _refresh() async {
    final refresh = await _storage.read(key: 'refresh_token');
    if (refresh == null) return false;
    final response = await _client.post(Uri.parse('$_apiBaseUrl/auth/refresh'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'refresh_token': refresh}));
    if (response.statusCode != 200) return false;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    await _storage.write(key: 'access_token', value: body['access_token'] as String);
    await _storage.write(key: 'refresh_token', value: body['refresh_token'] as String);
    return true;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }
}

class SchemeApp extends StatelessWidget {
  const SchemeApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(title: 'Mobile Shop Scheme', theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true), home: const SessionGate());
}

class SessionGate extends StatefulWidget { const SessionGate({super.key}); @override State<SessionGate> createState() => _SessionGateState(); }
class _SessionGateState extends State<SessionGate> {
  final _auth = AuthService();
  Future<String?>? _session;
  @override void initState() { super.initState(); _session = _auth.restoreEmail(); }
  @override Widget build(BuildContext context) => FutureBuilder<String?>(future: _session, builder: (context, snapshot) {
    if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return snapshot.data == null ? LoginPage(auth: _auth, onSignedIn: () => setState(() => _session = _auth.restoreEmail())) : HomePage(email: snapshot.data!, auth: _auth, onSignedOut: () => setState(() => _session = _auth.restoreEmail()));
  });
}

class LoginPage extends StatefulWidget { const LoginPage({super.key, required this.auth, required this.onSignedIn}); final AuthService auth; final VoidCallback onSignedIn; @override State<LoginPage> createState() => _LoginPageState(); }
class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>(); final _email = TextEditingController(); final _password = TextEditingController(); bool _busy = false;
  @override void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }
  Future<void> _submit() async { if (!_form.currentState!.validate()) return; setState(() => _busy = true); try { await widget.auth.login(_email.text.trim(), _password.text); widget.onSignedIn(); } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to sign in. Check your credentials and connection.'))); } finally { if (mounted) setState(() => _busy = false); } }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Mobile Shop Scheme')), body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Padding(padding: const EdgeInsets.all(24), child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Sign in', style: TextStyle(fontSize: 28)), const SizedBox(height: 20), TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email'), validator: (value) => value != null && value.contains('@') ? null : 'Enter a valid email'), TextFormField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password'), validator: (value) => value != null && value.length >= 8 ? null : 'Password must be at least 8 characters'), const SizedBox(height: 20), FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Signing in…' : 'Sign in'))])))));
}

class HomePage extends StatelessWidget { const HomePage({super.key, required this.email, required this.auth, required this.onSignedOut}); final String email; final AuthService auth; final VoidCallback onSignedOut; @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Mobile Shop Scheme'), actions: [IconButton(onPressed: () async { await auth.logout(); onSignedOut(); }, icon: const Icon(Icons.logout), tooltip: 'Sign out')]), body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Signed in as $email\n\nYour scheme dashboard will become available after enrollment features are introduced.', textAlign: TextAlign.center)))); }
