import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../services/notification_service.dart';

class MerchantLoginPage extends StatefulWidget {
  const MerchantLoginPage({super.key});

  @override
  State<MerchantLoginPage> createState() =>
      _MerchantLoginPageState();
}

class _MerchantLoginPageState
    extends State<MerchantLoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final ApiClient apiClient = ApiClient();

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
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage(
        'Please enter email and password',
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final response =
      await apiClient.get('/auth/me');

      final responseData =
      Map<String, dynamic>.from(
        response.data as Map,
      );

      final userData =
      Map<String, dynamic>.from(
        responseData['user'] as Map,
      );

      final role = userData['role']
          ?.toString()
          .trim()
          .toUpperCase();

      final rawStatus = userData['status']
          ?.toString()
          .trim()
          .toUpperCase();

      final isActive =
          userData['isActive'] == true;

      // Temporary backward compatibility
      // for existing users created before
      // the status field was introduced.
      final status =
          rawStatus ??
              (isActive ? 'ACTIVE' : 'PENDING');

      if (role != 'MERCHANT') {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        _showMessage(
          'This account is not registered as a merchant',
        );

        return;
      }

      switch (status) {
        case 'ACTIVE':
          await NotificationService().initialize();

          if (!mounted) return;

          context.go('/dashboard');
          return;

        case 'PENDING':
          if (!mounted) return;

          context.go('/approval-pending');
          return;

        case 'REJECTED':
          await FirebaseAuth.instance.signOut();

          if (!mounted) return;

          _showMessage(
            'Your merchant registration was rejected',
          );
          return;

        case 'SUSPENDED':
          await FirebaseAuth.instance.signOut();

          if (!mounted) return;

          _showMessage(
            'Your merchant account is suspended',
          );
          return;

        default:
          await FirebaseAuth.instance.signOut();

          if (!mounted) return;

          _showMessage(
            'Merchant account is not active',
          );
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      String message;

      switch (error.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          message =
          'Invalid email or password';
          break;

        case 'user-disabled':
          message =
          'This merchant account is disabled';
          break;

        case 'too-many-requests':
          message =
          'Too many attempts. Please try again later';
          break;

        default:
          message =
              error.message ?? 'Login failed';
      }

      _showMessage(message);
    } on DioException catch (error) {
      if (!mounted) return;

      _showMessage(
        _getApiErrorMessage(
          error,
          'Unable to verify merchant account',
        ),
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Unable to login. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  String _getApiErrorMessage(
      DioException error,
      String fallback,
      ) {
    final data = error.response?.data;

    if (data is Map &&
        data['message'] != null) {
      return data['message'].toString();
    }

    return fallback;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
            const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
              const BoxConstraints(
                maxWidth: 420,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration:
                      BoxDecoration(
                        color: Theme.of(
                          context,
                        )
                            .colorScheme
                            .primaryContainer,
                        shape:
                        BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.storefront,
                        size: 46,
                        color: Theme.of(
                          context,
                        )
                            .colorScheme
                            .primary,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                  Text(
                    'Merchant Login',
                    style:
                    Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    'Manage your restaurant and orders',
                    style:
                    Theme.of(context)
                        .textTheme
                        .bodyLarge,
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                  TextField(
                    controller:
                    emailController,
                    keyboardType:
                    TextInputType
                        .emailAddress,
                    decoration:
                    const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  TextField(
                    controller:
                    passwordController,
                    obscureText:
                    obscurePassword,
                    decoration:
                    InputDecoration(
                      labelText: 'Password',
                      prefixIcon:
                      const Icon(
                        Icons.lock_outline,
                      ),
                      suffixIcon:
                      IconButton(
                        onPressed: () {
                          setState(() {
                            obscurePassword =
                            !obscurePassword;
                          });
                        },
                        icon: Icon(
                          obscurePassword
                              ? Icons
                              .visibility_outlined
                              : Icons
                              .visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 24,
                  ),
                  SizedBox(
                    width:
                    double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed:
                      loading
                          ? null
                          : _login,
                      child: loading
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                        CircularProgressIndicator(
                          strokeWidth:
                          2,
                        ),
                      )
                          : const Text(
                        'Login',
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  SizedBox(
                    width:
                    double.infinity,
                    child:
                    OutlinedButton(
                      onPressed:
                      loading
                          ? null
                          : () {
                        context.go(
                          '/register',
                        );
                      },
                      child: const Text(
                        'Create Merchant Account',
                      ),
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
