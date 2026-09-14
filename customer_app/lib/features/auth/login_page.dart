import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_api_service.dart';
import '../../services/notification_service.dart';
import '../content/content_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthApiService _authApiService = AuthApiService();

  String? _verificationId;
  bool _otpSent = false;
  bool _loading = false;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds--);
    });
  }

  String _firebasePhoneError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-phone-number':
        return 'Enter a valid mobile number';
      case 'too-many-requests':
        return 'Too many OTP requests. Please try again later.';
      case 'invalid-verification-code':
        return 'Incorrect OTP. Please try again.';
      case 'session-expired':
        return 'OTP expired. Request a new OTP.';
      case 'quota-exceeded':
        return 'OTP service is temporarily unavailable.';
      case 'network-request-failed':
        return 'Check your internet connection and try again.';
      default:
        return error.message ?? 'Something went wrong. Please try again.';
    }
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();

    if (phone.length != 10) {
      _showError('Enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);

          await _authApiService.ensureCustomerProfile();

          NotificationService().initialize();

          if (!mounted) return;

          context.go('/home');
        },
        verificationFailed: (FirebaseAuthException error) {
          if (!mounted) return;

          _showError(_firebasePhoneError(error));
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;

          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            _loading = false;
          });
          _startResendTimer();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (error) {
      if (!mounted) return;

      _showError('Unable to send OTP');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      _showError('Enter the 6-digit OTP');
      return;
    }

    if (_verificationId == null) {
      _showError('Please request OTP again');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      await _auth.signInWithCredential(credential);

      await _authApiService.ensureCustomerProfile();

      NotificationService().initialize();

      if (!mounted) return;

      context.go('/home');
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      _showError(_firebasePhoneError(error));
    } catch (_) {
      if (!mounted) return;

      _showError('Failed to verify OTP');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text(
              'Welcome back 👋',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Login to continue ordering food and groceries.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            if (!_otpSent) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  prefixText: '+91 ',
                  hintText: 'Enter your mobile number',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _sendOtp,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send OTP'),
                ),
              ),
            ] else ...[
              Text(
                'Enter the OTP sent to +91 ${_phoneController.text.trim()}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'OTP',
                  hintText: 'Enter 6-digit OTP',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _verifyOtp,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify OTP'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _loading || _resendSeconds > 0 ? null : _sendOtp,
                  child: Text(
                    _resendSeconds > 0
                        ? 'Resend OTP in $_resendSeconds s'
                        : 'Resend OTP',
                  ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() {
                            _otpSent = false;
                            _verificationId = null;
                            _otpController.clear();
                          });
                        },
                  child: const Text('Change mobile number'),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  const Text('By continuing, you agree to our '),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ContentPage(
                          type: 'terms',
                          fallbackTitle: 'Terms & Conditions',
                        ),
                      ),
                    ),
                    child: Text(
                      'Terms & Conditions',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Text(' and '),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ContentPage(
                          type: 'privacy',
                          fallbackTitle: 'Privacy Policy',
                        ),
                      ),
                    ),
                    child: Text(
                      'Privacy Policy',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
