import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';

class ApprovalPendingPage
    extends StatefulWidget {
  const ApprovalPendingPage({
    super.key,
  });

  @override
  State<ApprovalPendingPage>
  createState() =>
      _ApprovalPendingPageState();
}

class _ApprovalPendingPageState
    extends State<ApprovalPendingPage> {
  final ApiClient apiClient =
  ApiClient();

  bool checking = false;

  Future<void> _checkStatus() async {
    setState(() {
      checking = true;
    });

    try {
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

      final status =
          rawStatus ??
              (isActive ? 'ACTIVE' : 'PENDING');

      if (role != 'MERCHANT') {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        context.go('/login');
        return;
      }

      if (status == 'ACTIVE') {
        if (!mounted) return;

        context.go('/dashboard');
        return;
      }

      if (status == 'REJECTED') {
        _showMessage(
          'Your merchant registration was rejected',
        );
        return;
      }

      if (status == 'SUSPENDED') {
        _showMessage(
          'Your merchant account is suspended',
        );
        return;
      }

      _showMessage(
        'Your account is still waiting for approval',
      );
    } on DioException catch (error) {
      if (!mounted) return;

      final data = error.response?.data;

      var message =
          'Unable to check account status';

      if (data is Map &&
          data['message'] != null) {
        message =
            data['message'].toString();
      }

      _showMessage(message);
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Unable to check account status',
      );
    } finally {
      if (mounted) {
        setState(() {
          checking = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance
        .signOut();

    if (!mounted) return;

    context.go('/login');
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
          child: Padding(
            padding:
            const EdgeInsets.all(24),
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
                    Icons
                        .hourglass_top_outlined,
                    size: 90,
                    color: Theme.of(
                      context,
                    )
                        .colorScheme
                        .primary,
                  ),
                  const SizedBox(
                    height: 24,
                  ),
                  Text(
                    'Approval Pending',
                    style:
                    Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  const Text(
                    'Your merchant registration has been submitted successfully.',
                    textAlign:
                    TextAlign.center,
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  const Text(
                    'You can access the merchant dashboard once your account is approved.',
                    textAlign:
                    TextAlign.center,
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                  SizedBox(
                    width:
                    double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed:
                      checking
                          ? null
                          : _checkStatus,
                      child: checking
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                        CircularProgressIndicator(
                          strokeWidth:
                          2,
                        ),
                      )
                          : const Text(
                        'Check Approval Status',
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
                      checking
                          ? null
                          : _logout,
                      child: const Text(
                        'Logout',
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