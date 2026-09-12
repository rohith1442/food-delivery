import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../orders/orders_page.dart';

class DeliveryDashboardPage extends StatefulWidget {
  const DeliveryDashboardPage({super.key});

  @override
  State<DeliveryDashboardPage> createState() =>
      _DeliveryDashboardPageState();
}

class _DeliveryDashboardPageState
    extends State<DeliveryDashboardPage> {
  final ApiClient _apiClient = ApiClient();

  bool _isLoadingProfile = true;
  bool _isUpdatingAvailability = false;

  bool _isOnline = false;
  bool _isAvailable = false;

  String? _zoneId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      setState(() {
        _isLoadingProfile = true;
      });

      final response = await _apiClient.get(
        '/delivery/profile',
      );

      final data = response.data;

      final profile =
          data is Map<String, dynamic>
              ? data['profile']
              : null;

      if (!mounted) return;

      setState(() {
        _zoneId =
            profile is Map<String, dynamic>
                ? profile['zoneId'] as String?
                : null;

        _isOnline =
            profile is Map<String, dynamic> &&
            profile['isOnline'] == true;

        _isAvailable =
            profile is Map<String, dynamic> &&
            profile['isAvailable'] == true;

        _isLoadingProfile = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoadingProfile = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to load delivery profile',
          ),
        ),
      );
    }
  }

  Future<void> _updateAvailability(
    bool value,
  ) async {
    if (_zoneId == null ||
        _zoneId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Delivery zone is not configured',
          ),
        ),
      );

      return;
    }

    try {
      setState(() {
        _isUpdatingAvailability = true;
      });

      final response = await _apiClient.patch(
        '/delivery/profile/availability',
        data: {
          'zoneId': _zoneId,
          'isOnline': value,
        },
      );

      final data = response.data;

      final profile =
          data is Map<String, dynamic>
              ? data['profile']
              : null;

      if (!mounted) return;

      setState(() {
        _isOnline =
            profile is Map<String, dynamic> &&
            profile['isOnline'] == true;

        _isAvailable =
            profile is Map<String, dynamic> &&
            profile['isAvailable'] == true;

        _isUpdatingAvailability = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isOnline
                ? 'You are now online'
                : 'You are now offline',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isUpdatingAvailability = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update availability',
          ),
        ),
      );
    }
  }

  Future<void> _logout(
    BuildContext context,
  ) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Delivery Dashboard',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _isLoadingProfile
                    ? null
                    : _loadProfile,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () => _logout(context),
            icon: const Icon(
              Icons.logout,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Good afternoon 👋',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              'Ready to deliver?',
              style: TextStyle(
                fontSize: 16,
                color:
                    Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 20),

            _buildAvailabilityCard(context),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons
                            .account_balance_wallet_outlined,
                        color:
                            Theme.of(context)
                                .colorScheme
                                .primary,
                      ),
                    ),

                    const SizedBox(width: 16),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Today's Earnings",
                            style: TextStyle(
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '₹850',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    TextButton(
                      onPressed: () {},
                      child:
                          const Text('Details'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon:
                        Icons
                            .local_shipping_outlined,
                    title: 'Deliveries',
                    value: '8',
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _StatCard(
                    icon: Icons.star_outline,
                    title: 'Rating',
                    value: '4.8',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            Text(
              'Quick Actions',
              style:
                  Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight:
                            FontWeight.bold,
                      ),
            ),

            const SizedBox(height: 12),

            Card(
              child: ListTile(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) =>
                              DeliveryOrdersPage(),
                    ),
                  );
                },
                leading: Icon(
                  Icons.local_shipping_outlined,
                  color:
                      Theme.of(context)
                          .colorScheme
                          .primary,
                ),
                title: const Text(
                  'Available Deliveries',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'View nearby delivery requests',
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
              ),
            ),

            Card(
              child: ListTile(
                onTap: () {},
                leading: Icon(
                  Icons
                      .account_balance_wallet_outlined,
                  color:
                      Theme.of(context)
                          .colorScheme
                          .primary,
                ),
                title: const Text(
                  'Earnings',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'View your earnings history',
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          NavigationBar(
        selectedIndex: 0,
        destinations: [
          NavigationDestination(
            icon: Icon(
              Icons.dashboard_outlined,
            ),
            selectedIcon: Icon(
              Icons.dashboard,
            ),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.local_shipping_outlined,
            ),
            label: 'Deliveries',
          ),
          NavigationDestination(
            icon: Icon(
              Icons
                  .account_balance_wallet_outlined,
            ),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person_outline,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard(
    BuildContext context,
  ) {
    if (_isLoadingProfile) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child:
                CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color:
                        _isOnline
                            ? Theme.of(context)
                                .colorScheme
                                .primaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isOnline
                        ? Icons
                            .radio_button_checked
                        : Icons
                            .radio_button_off,
                    color:
                        _isOnline
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                            : Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isOnline
                            ? 'You are Online'
                            : 'You are Offline',
                        style:
                            const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        _isOnline
                            ? _isAvailable
                                ? 'Ready to receive deliveries'
                                : 'Currently handling a delivery'
                            : 'Go online to receive deliveries',
                        style: TextStyle(
                          color:
                              Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_isUpdatingAvailability)
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                else
                  Switch(
                    value: _isOnline,
                    onChanged:
                        _updateAvailability,
                  ),
              ],
            ),

            const Divider(height: 28),

            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 20,
                ),

                const SizedBox(width: 8),

                const Text(
                  'Delivery Zone',
                ),

                const Spacer(),

                Flexible(
                  child: Text(
                    _zoneId ??
                        'Not configured',
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
            ),

            const SizedBox(height: 12),

            Text(
              value,
              style:
                  const TextStyle(
                fontSize: 24,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              title,
              style:
                  const TextStyle(
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
