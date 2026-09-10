import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';

class DeliveryApprovalPendingPage extends StatefulWidget {
  const DeliveryApprovalPendingPage({super.key});

  @override
  State<DeliveryApprovalPendingPage> createState() =>
      _DeliveryApprovalPendingPageState();
}

class _DeliveryApprovalPendingPageState
    extends State<DeliveryApprovalPendingPage> {
  final ApiClient _apiClient = ApiClient();

  bool _loading = false;

  Future<void> _checkStatus() async {
    setState(() {
      _loading = true;
    });

    try {
      final response =
      await _apiClient.get('/auth/me');

      final data =
      response.data as Map<String, dynamic>;

      final user =
      data['user'] as Map<String, dynamic>?;

      if (user == null) {
        _showMessage(
          'Delivery profile not found',
        );
        return;
      }

      final role = user['role']
          ?.toString()
          .trim()
          .toUpperCase();

      final rawStatus = user['status']
          ?.toString()
          .trim()
          .toUpperCase();

      final isActive =
          user['isActive'] == true;

      final status =
          rawStatus ??
              (isActive ? 'ACTIVE' : 'PENDING');

      if (role != 'DELIVERY') {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        context.go('/login');

        _showMessage(
          'This account is not a delivery partner account',
        );

        return;
      }

      if (status == 'ACTIVE' && isActive) {
        if (!mounted) return;

        context.go('/dashboard');
        return;
      }

      if (status == 'PENDING') {
        _showMessage(
          'Your application is still pending approval',
        );

        return;
      }

      if (status == 'REJECTED') {
        _showMessage(
          'Your delivery partner application was rejected',
        );

        return;
      }

      if (status == 'SUSPENDED') {
        _showMessage(
          'Your delivery account is suspended',
        );

        return;
      }

      _showMessage(
        'Your delivery account is not active',
      );
    } on DioException catch (error) {
      final response = error.response?.data;

      String message =
          'Unable to check approval status';

      if (response is Map &&
          response['message'] != null) {
        message =
            response['message'].toString();
      }

      _showMessage(message);
    } catch (_) {
      _showMessage(
        'Unable to check approval status',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    context.go('/login');
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
              const BoxConstraints(
                maxWidth: 420,
              ),
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.hourglass_top,
                    size: 72,
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Approval Pending',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your delivery partner account is waiting for admin approval.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed:
                      _loading
                          ? null
                          : _checkStatus,
                      child: _loading
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Text(
                        'Check Approval Status',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed:
                    _loading
                        ? null
                        : _logout,
                    child: const Text(
                      'Logout',
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