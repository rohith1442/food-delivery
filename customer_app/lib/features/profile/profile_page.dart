import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/auth_api_service.dart';
import '../addresses/addresses_page.dart';
import '../orders/orders_page.dart';
import '../notifications/notifications_page.dart';
import '../content/content_page.dart';
import '../content/support_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authApiService = AuthApiService();

  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final response = await _authApiService.getCurrentUser();

      if (!mounted) {
        return;
      }

      final rawUser = response['user'];

      setState(() {
        _user = rawUser is Map<String, dynamic>
            ? rawUser
            : rawUser is Map
            ? Map<String, dynamic>.from(rawUser)
            : null;
      });
    } catch (error, stackTrace) {
      debugPrint('Profile load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Unable to load profile.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadProfile, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final user = _user ?? <String, dynamic>{};
    final name = user['name']?.toString().trim() ?? '';
    final email = user['email']?.toString().trim() ?? '';
    final phone = user['phoneNumber']?.toString().trim() ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Profile'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      _initials(name),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isNotEmpty ? name : 'Customer',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                        ),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            phone,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.white),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit profile',
                    color: Colors.white,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _showEditProfile(name),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionLabel('Account'),
            _ProfileTile(
              icon: Icons.location_on_outlined,
              title: 'Saved Addresses',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddressesPage()),
                );
              },
            ),
            _ProfileTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CustomerNotificationsPage(),
                ),
              ),
            ),
            _ProfileTile(
              icon: Icons.receipt_long_outlined,
              title: 'My Orders',
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const OrdersPage()));
              },
            ),
            _sectionLabel('Support'),
            _ProfileTile(
              icon: Icons.support_agent_outlined,
              title: 'Help & Support',
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SupportPage())),
            ),
            _ProfileTile(
              icon: Icons.description_outlined,
              title: 'Terms & Conditions',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ContentPage(
                    type: 'terms',
                    fallbackTitle: 'Terms & Conditions',
                  ),
                ),
              ),
            ),
            _ProfileTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ContentPage(
                    type: 'privacy',
                    fallbackTitle: 'Privacy Policy',
                  ),
                ),
              ),
            ),
            _ProfileTile(
              icon: Icons.currency_exchange_outlined,
              title: 'Refund & Cancellation Policy',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ContentPage(
                    type: 'refund-policy',
                    fallbackTitle: 'Refund & Cancellation Policy',
                  ),
                ),
              ),
            ),
            _ProfileTile(
              icon: Icons.local_shipping_outlined,
              title: 'Delivery Policy',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ContentPage(
                    type: 'delivery-policy',
                    fallbackTitle: 'Delivery Policy',
                  ),
                ),
              ),
            ),
            _sectionLabel('App'),
            _ProfileTile(
              icon: Icons.info_outline,
              title: 'About Us',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ContentPage(
                    type: 'about',
                    fallbackTitle: 'About Us',
                  ),
                ),
              ),
            ),
            _ProfileTile(
              icon: Icons.admin_panel_settings_outlined,
              title: 'App Permissions',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ContentPage(
                    type: 'permissions',
                    fallbackTitle: 'App Permissions',
                  ),
                ),
              ),
            ),
            if (email.isNotEmpty)
              _ProfileTile(
                icon: Icons.email_outlined,
                title: 'Email',
                subtitle: email,
              ),
            const SizedBox(height: 12),
            _ProfileTile(
              icon: Icons.logout,
              title: 'Logout',
              danger: true,
              onTap: _logout,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Future<void> _showEditProfile(String currentName) async {
    var nameValue = currentName;

    final updatedName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: TextFormField(
            initialValue: currentName,
            autofocus: true,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              nameValue = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameValue.trim();

                if (name.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext).pop(name);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted || updatedName == null || updatedName == currentName) {
      return;
    }

    try {
      await _authApiService.updateProfile(name: updatedName);

      if (!mounted) {
        return;
      }

      await _loadProfile();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to update profile')));
    }
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((value) => value.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'C';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: onTap != null && !danger
            ? const Icon(Icons.chevron_right)
            : null,
        onTap: onTap,
      ),
    );
  }
}
