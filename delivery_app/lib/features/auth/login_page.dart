import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../services/notification_service.dart';

class DeliveryLoginPage extends StatefulWidget {
  const DeliveryLoginPage({super.key});

  @override
  State<DeliveryLoginPage> createState() => _DeliveryLoginPageState();
}

class _DeliveryLoginPageState extends State<DeliveryLoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final ApiClient _apiClient = ApiClient();

  bool obscurePassword = true;
  bool loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter email and password');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final response = await _apiClient.get('/auth/me');

      final data = response.data as Map<String, dynamic>;

      final user = data['user'] as Map<String, dynamic>?;

      if (user == null) {
        await FirebaseAuth.instance.signOut();

        _showError('Delivery profile not found');

        return;
      }

      final role = user['role']?.toString().trim().toUpperCase();

      final rawStatus = user['status']?.toString().trim().toUpperCase();

      final isActive = user['isActive'] == true;

      final status = rawStatus ?? (isActive ? 'ACTIVE' : 'PENDING');

      if (role != 'DELIVERY') {
        await FirebaseAuth.instance.signOut();

        _showError('This account is not a delivery partner account');

        return;
      }

      if (status == 'ACTIVE' && isActive) {
        try {
          await NotificationService().initialize();
        } catch (error) {
          debugPrint('Notification initialization failed: $error');
        }

        if (!mounted) return;

        context.go('/dashboard');
        return;
      }

      if (status == 'PENDING') {
        if (!mounted) return;

        context.go('/approval-pending');
        return;
      }

      await FirebaseAuth.instance.signOut();

      if (status == 'REJECTED') {
        _showError('Your delivery partner application was rejected');
      } else if (status == 'SUSPENDED') {
        _showError('Your delivery account is suspended');
      } else {
        _showError('Your delivery account is not active');
      }
    } on FirebaseAuthException catch (error) {
      String message;

      switch (error.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          message = 'Invalid email or password';
          break;

        case 'user-disabled':
          message = 'This delivery account is disabled';
          break;

        case 'too-many-requests':
          message = 'Too many attempts. Please try again later';
          break;

        default:
          message = error.message ?? 'Login failed';
      }

      _showError(message);
    } on DioException catch (error) {
      await FirebaseAuth.instance.signOut();

      final response = error.response?.data;

      String message = 'Unable to verify delivery account';

      if (response is Map && response['message'] != null) {
        message = response['message'].toString();
      }

      _showError(message);
    } catch (error) {
      await FirebaseAuth.instance.signOut();

      _showError('Login failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delivery_dining,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Delivery Partner Login',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage deliveries and earn with every order',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: loading ? null : _login,
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Login'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: loading ? null : () => context.go('/register'),
                      child: const Text('Become a Delivery Partner'),
                    ),
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
