import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  String _friendly(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return 'Wrong email or password';
      case 'network-request-failed':
        return 'No internet. Please connect once to log in.';
      case 'too-many-requests':
        return 'Too many tries. Please wait and try again.';
      default:
        return 'Could not log in. Please try again.';
    }
  }
  
  void _devSkip(String route) {
  Navigator.pushReplacementNamed(context, route);
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      _fail('Enter your email and password');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await AuthService()
          .signInWithRole(email: email, password: password);
      if (!mounted) return;
      final route =
          result['role'] == 'asha' ? '/asha-dashboard' : '/patient-dashboard';
      Navigator.pushReplacementNamed(context, route);
    } on FirebaseAuthException catch (e) {
      _fail(_friendly(e));
    } on StateError catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🌸', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                Text(
                  'AMMA',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 40,
                        color: AppColors.primary,
                      ),
                ),
                const SizedBox(height: 4),
                Text('Maternal Care',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 48),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.email_outlined),
                    hintText: 'Email',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _password,
                  obscureText: true,
                  onSubmitted: (_) => _login(),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.lock_outline),
                    hintText: 'Password',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.riskHigh,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('LOGIN'),
                ),

                if (kDebugMode) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'DEV ONLY: skips login',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _devSkip('/asha-dashboard'),
                          child: const Text('ASHA'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _devSkip('/patient-dashboard'),
                          child: const Text('Patient'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}