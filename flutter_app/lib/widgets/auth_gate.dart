import 'package:flutter/material.dart';

import '../data/inventory_store.dart';
import '../services/api_device_identification_service.dart';
import '../services/jakstore_api_client.dart';
import 'app_shell.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.apiClient,
    required this.store,
    super.key,
  });

  final JakStoreApiClient apiClient;
  final InventoryStore store;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool loading = true;
  String? startupError;

  @override
  void initState() {
    super.initState();
    widget.apiClient.onUnauthorized = _handleUnauthorized;
    _restoreSession();
  }

  void _handleUnauthorized() {
    if (mounted) {
      setState(() {
        startupError = 'Sesi berakhir. Silakan masuk kembali.';
        loading = false;
      });
    }
  }

  Future<void> _restoreSession() async {
    try {
      final user = await widget.apiClient.restoreSession();
      if (user != null) await widget.store.refreshFromApi();
    } on ApiException catch (error) {
      startupError = error.message;
      await widget.apiClient.clearSession();
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _login(String email, String password) async {
    await widget.apiClient.login(email: email, password: password);
    try {
      await widget.store.refreshFromApi();
      if (mounted) setState(() => startupError = null);
    } on ApiException {
      await widget.apiClient.clearSession();
      rethrow;
    }
  }

  Future<void> _logout() async {
    try {
      await widget.apiClient.logout();
    } on ApiException catch (error) {
      startupError =
          'Token lokal dihapus, tetapi server belum mengonfirmasi logout: '
          '${error.message}';
    } finally {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!widget.apiClient.hasToken) {
      return _LoginScreen(onLogin: _login, initialError: startupError);
    }
    return AppShell(
      store: widget.store,
      deviceIdentificationService:
          ApiDeviceIdentificationService(widget.apiClient),
      onLogout: _logout,
    );
  }
}

class _LoginScreen extends StatefulWidget {
  const _LoginScreen({required this.onLogin, this.initialError});

  final Future<void> Function(String email, String password) onLogin;
  final String? initialError;

  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onLogin(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error ?? widget.initialError;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CircleAvatar(
                    radius: 32,
                    backgroundColor: Color(0xFFFF6A2A),
                    child: Text(
                      'J',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Masuk admin JakStore',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF10172A),
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Email admin'),
                    validator: (value) => value == null ||
                            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(value.trim())
                        ? 'Masukkan email yang valid.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Password wajib diisi.'
                        : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Masuk'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
