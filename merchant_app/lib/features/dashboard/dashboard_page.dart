import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/app_branding.dart';
import '../../core/widgets/merchant_state_view.dart';
import '../notifications/notifications_page.dart';
import '../orders/orders_page.dart';
import '../orders/merchant_orders_api_service.dart';
import '../profile/profile_page.dart';
import '../products/products_page.dart';
import '../store/create_store_page.dart';
import '../store/store_api_service.dart';
import '../store/store_settings_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final StoreApiService _storeApiService = StoreApiService();
  final MerchantOrdersApiService _ordersApiService = MerchantOrdersApiService();
  final ImagePicker _imagePicker = ImagePicker();

  Map<String, dynamic>? _store;
  List<Map<String, dynamic>> _dashboardOrders = [];

  bool _isLoading = true;
  bool _isUpdatingStatus = false;
  bool _isUpdatingImage = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  Future<void> _loadStore() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final results = await Future.wait<Object?>([
        _storeApiService.getStore(),
        _ordersApiService.getOrders(),
      ]);
      final store = results[0] as Map<String, dynamic>?;
      final orders = results[1] as List<Map<String, dynamic>>;

      if (!mounted) return;

      setState(() {
        _store = store;
        _dashboardOrders = orders;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    context.go('/login');
  }

  Future<void> _updateStoreStatus(bool isOpen) async {
    final store = _store;

    if (store == null) {
      return;
    }

    final storeId = store['id']?.toString();

    if (storeId == null || storeId.isEmpty) {
      return;
    }

    try {
      setState(() {
        _isUpdatingStatus = true;
      });

      await _storeApiService.updateStoreStatus(
        storeId: storeId,
        isOpen: isOpen,
      );

      if (!mounted) return;

      setState(() {
        _store = {...store, 'isOpen': isOpen};
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isOpen ? 'Store is now open' : 'Store is now closed'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to update store: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  Future<void> _changeStoreImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) {
        return;
      }

      setState(() {
        _isUpdatingImage = true;
      });

      final imageUrl = await _storeApiService.uploadStoreImage(
        filePath: image.path,
      );

      await _storeApiService.updateStoreImage(imageUrl: imageUrl);

      if (!mounted) return;

      setState(() {
        _store = {...?_store, 'imageUrl': imageUrl};
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Store image updated')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update store image: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingImage = false;
        });
      }
    }
  }

  Future<void> _openCreateStore() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateStorePage(
          onStoreCreated: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );

    if (!mounted) return;

    await _loadStore();
  }

  void _openOrders() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MerchantOrdersPage()));
  }

  void _openProducts() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ProductsPage()));
  }

  Future<void> _openStoreSettings() async {
    final store = _store;
    if (store == null) return;

    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => StoreSettingsPage(store: store)),
    );

    if (mounted && updated != null) {
      setState(() => _store = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadStore,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
            },
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _store == null
          ? null
          : NavigationBar(
              selectedIndex: 0,
              onDestinationSelected: (index) {
                switch (index) {
                  case 0:
                    break;

                  case 1:
                    _openOrders();
                    break;

                  case 2:
                    _openProducts();
                    break;

                  case 3:
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MerchantProfilePage(),
                      ),
                    );
                    break;
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  label: 'Orders',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  label: 'Products',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Profile',
                ),
              ],
            ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const MerchantLoadingView(message: 'Loading your store...');
    }

    if (_error != null) {
      return MerchantStateView(
        icon: Icons.error_outline,
        title: 'Unable to load store',
        message: _error,
        actionLabel: 'Retry',
        onAction: _loadStore,
      );
    }

    if (_store == null) {
      return _buildNoStore();
    }

    return _buildDashboard();
  }

  Widget _buildNoStore() {
    return RefreshIndicator(
      onRefresh: _loadStore,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.storefront_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          const Text(
            'Create your store',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Set up your store before you start receiving orders.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _openCreateStore,
            icon: const Icon(Icons.add_business),
            label: const Text('Create Store'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final store = _store!;

    final storeName = store['name']?.toString() ?? 'My Store';

    final address = store['address']?.toString() ?? 'Address not available';

    final imageUrl = store['imageUrl']?.toString();

    final moduleId = store['moduleId']?.toString() ?? '';

    final isOpen = store['isOpen'] == true;
    final currency = AppBrandingController.instance.branding.currencySymbol;

    return RefreshIndicator(
      onRefresh: _loadStore,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Good afternoon 👋',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 4),

          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'New Orders',
                  value: '$_newOrders',
                  icon: Icons.receipt_long,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Preparing',
                  value: '$_preparingOrders',
                  icon: Icons.restaurant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Ready',
                  value: '$_readyOrders',
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: "Today's Sales",
                  value: '$currency${_todaySales.toStringAsFixed(0)}',
                  icon: Icons.payments_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            storeName,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            address,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: _isUpdatingImage ? null : _changeStoreImage,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 180,
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: _isUpdatingImage
                    ? const Center(child: CircularProgressIndicator())
                    : imageUrl != null && imageUrl.isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.storefront_outlined,
                                  size: 56,
                                ),
                              );
                            },
                          ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Change image',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add store image',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          _StoreStatusCard(
            moduleId: moduleId,
            isOpen: isOpen,
            isUpdating: _isUpdatingStatus,
            onChanged: _updateStoreStatus,
          ),

          const SizedBox(height: 24),

          Text(
            'Manage your store',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _DashboardActionCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'Orders',
                  subtitle: 'Manage incoming orders',
                  onTap: _openOrders,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DashboardActionCard(
                  icon: Icons.inventory_2_outlined,
                  title: 'Products',
                  subtitle: 'Menu & availability',
                  onTap: _openProducts,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _DashboardActionCard(
            icon: Icons.storefront_outlined,
            title: 'Store settings',
            subtitle: isOpen
                ? 'Store is accepting orders'
                : 'Store is currently closed',
            onTap: _openStoreSettings,
          ),
        ],
      ),
    );
  }

  int get _newOrders => _dashboardOrders
      .where((order) => order['status'] == 'VENDOR_PENDING')
      .length;

  int get _preparingOrders =>
      _dashboardOrders.where((order) => order['status'] == 'PREPARING').length;

  int get _readyOrders =>
      _dashboardOrders.where((order) => order['status'] == 'READY').length;

  double get _todaySales {
    final now = DateTime.now();

    return _dashboardOrders.fold(0.0, (sum, order) {
      final createdAt = DateTime.tryParse(order['createdAt']?.toString() ?? '')
          ?.toLocal();
      if (createdAt == null ||
          createdAt.year != now.year ||
          createdAt.month != now.month ||
          createdAt.day != now.day ||
          order['status']?.toString() == 'REJECTED') {
        return sum;
      }

      final total = order['total'];
      return sum + (total is num ? total.toDouble() : 0);
    });
  }
}

class _StoreStatusCard extends StatelessWidget {
  const _StoreStatusCard({
    required this.moduleId,
    required this.isOpen,
    required this.isUpdating,
    required this.onChanged,
  });

  final String moduleId;
  final bool isOpen;
  final bool isUpdating;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final moduleName = moduleId == 'grocery' ? 'Grocery' : 'Food';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                moduleId == 'grocery'
                    ? Icons.shopping_basket_outlined
                    : Icons.restaurant_outlined,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    moduleName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOpen ? 'Open for orders' : 'Closed',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            if (isUpdating)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Switch(value: isOpen, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _DashboardActionCard extends StatelessWidget {
  const _DashboardActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colors.primary),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
