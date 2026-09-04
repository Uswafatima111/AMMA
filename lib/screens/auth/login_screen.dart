import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_enums.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    // TODO: BACKEND INTEGRATION REQUIRED FROM USWA
    // Service: AuthService.login()
    // Input: identifier (email/phone), password
    // Output: { success: bool, role: UserRole, userId: String, error: String? }
    // Mocked for now so the frontend flow is testable today.
    await Future.delayed(const Duration(milliseconds: 800));

    setState(() => _isLoading = false);

    // MOCK: change to UserRole.patient to test the other flow.
    const mockRole = UserRole.asha;

    if (!mounted) return;
    if (mockRole == UserRole.asha) {
      Navigator.pushReplacementNamed(context, '/asha-dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/patient-dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
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
              Text(
                'Maternal Care',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.phone_android),
                  hintText: 'Email / Mobile',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.lock_outline),
                  hintText: 'Password',
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
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
            ],
          ),
        ),
      ),
    );
  }
}
