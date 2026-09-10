import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../location/addresses_api_service.dart';
import '../orders/orders_page.dart';
import '../restaurants/restaurants_page.dart';
import '../location/saved_addresses_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  String _selectedAddress = 'Home';
  String? _selectedZoneId;

  bool _isLoadingAddress = true;
  final bool _isSavingAddress = false;
  final AddressesApiService _addressesApiService = AddressesApiService();

  @override
  void initState() {
    super.initState();
    _loadSavedAddress();
  }

  Future<void> _loadSavedAddress() async {
    try {
      final addresses = await _addressesApiService.getAddresses();

      if (!mounted) {
        return;
      }

      if (addresses.isEmpty) {
        setState(() {
          _isLoadingAddress = false;
        });

        return;
      }

      CustomerAddress selectedAddress;

      try {
        selectedAddress = addresses.firstWhere((address) => address.isDefault);
      } catch (_) {
        selectedAddress = addresses.first;
      }

      setState(() {
        _selectedAddress = selectedAddress.address;
        _selectedZoneId = selectedAddress.zoneId;
        _isLoadingAddress = false;
      });

      debugPrint(
        'Loaded saved address: '
        '${selectedAddress.address}, '
        'zone=${selectedAddress.zoneId}',
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to load saved address: $error');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingAddress = false;
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _chooseLocation() async {
    if (_isSavingAddress) {
      return;
    }

    final selectedAddress = await Navigator.of(context).push<CustomerAddress>(
      MaterialPageRoute(builder: (_) => const SavedAddressesPage()),
    );

    if (selectedAddress == null || !mounted) {
      return;
    }

    setState(() {
      _selectedAddress = selectedAddress.address;
      _selectedZoneId = selectedAddress.zoneId;
    });

    debugPrint(
      'Selected saved address: '
      '${selectedAddress.address}, '
      'zone=${selectedAddress.zoneId}',
    );
  }

  void _openRestaurants({String moduleId = 'food'}) {
    final zoneId = _selectedZoneId;

    if (_isLoadingAddress) {
      _showMessage('Loading your delivery location...');

      return;
    }

    if (zoneId == null || zoneId.isEmpty) {
      _showMessage('Please select your delivery location first.');

      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RestaurantsPage(zoneId: zoneId, moduleId: moduleId),
      ),
    );
  }

  void _onNavigationTap(int index) {
    if (index == 2) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const OrdersPage()));

      return;
    }

    setState(() {
      selectedIndex = index;
    });
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _chooseLocation,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Deliver to',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _isLoadingAddress
                                                    ? 'Loading location...'
                                                    : _selectedAddress,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.keyboard_arrow_down,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Notifications
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.notifications_outlined),
                        ),

                        // Logout
                        IconButton(
                          tooltip: 'Logout',
                          onPressed: _logout,
                          icon: const Icon(Icons.logout),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search food, groceries and more',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.tune),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _openRestaurants(moduleId: 'food');
                            },
                            child: const _ServiceCard(
                              icon: Icons.restaurant,
                              title: 'Food',
                              subtitle: 'Restaurants & meals',
                              selected: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _openRestaurants(moduleId: 'grocery');
                            },
                            child: const _ServiceCard(
                              icon: Icons.shopping_basket,
                              title: 'Grocery',
                              subtitle: 'Daily essentials',
                              selected: false,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    const _SectionHeader(
                      title: 'Categories',
                      actionText: 'See all',
                    ),

                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(
                height: 105,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  children: const [
                    _CategoryItem(icon: Icons.local_pizza, name: 'Pizza'),
                    _CategoryItem(icon: Icons.lunch_dining, name: 'Burgers'),
                    _CategoryItem(icon: Icons.ramen_dining, name: 'Asian'),
                    _CategoryItem(icon: Icons.local_cafe, name: 'Cafe'),
                    _CategoryItem(icon: Icons.icecream, name: 'Desserts'),
                    _CategoryItem(icon: Icons.eco, name: 'Healthy'),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nearby Restaurants',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {
                        _openRestaurants();
                      },
                      child: const Text('See all'),
                    ),
                  ],
                ),
              ),
            ),

            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                return _RestaurantCard(
                  onTap: () {
                    _openRestaurants();
                  },
                );
              }, childCount: 3),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: _onNavigationTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? color : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: selected ? Colors.white : color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.85)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({required this.icon, required this.name});

  final IconData icon;
  final String name;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: 72,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.actionText});

  final String title;
  final String actionText;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        TextButton(onPressed: () {}, child: Text(actionText)),
      ],
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    final containerColor = Theme.of(context).colorScheme.primaryContainer;

    return Card(
      margin: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 110,
          child: Row(
            children: [
              Container(
                width: 110,
                height: double.infinity,
                color: containerColor,
                child: Icon(Icons.restaurant, size: 42, color: primaryColor),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Restaurant Name',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Indian • Biryani • North Indian',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: primaryColor),
                          const SizedBox(width: 4),
                          const Text('4.5'),
                          const SizedBox(width: 12),
                          const Text('25-35 min'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
