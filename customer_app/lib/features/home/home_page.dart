import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_branding.dart';
import '../../core/config/home_config.dart';
import '../location/addresses_api_service.dart';
import '../location/saved_addresses_page.dart';
import '../orders/orders_page.dart';
import '../notifications/notifications_page.dart';
import '../profile/profile_page.dart';
import '../restaurants/menu_page.dart';
import '../restaurants/restaurants_page.dart';
import '../restaurants/stores_api_service.dart';
import '../search/search_page.dart';
import 'widgets/home_header.dart';
import 'widgets/home_category_item.dart';
import 'widgets/home_search_bar.dart';
import 'widgets/module_card.dart';
import 'widgets/promo_banner.dart';
import 'widgets/section_header.dart';
import 'widgets/store_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AddressesApiService _addressesApiService = AddressesApiService();

  final StoresApiService _storesApiService = StoresApiService();

  final TextEditingController _searchController = TextEditingController();

  int selectedIndex = 0;

  String _selectedAddress = 'Select location';
  String? _selectedZoneId;

  bool _isLoadingAddress = true;
  bool _isLoadingStores = false;

  String? _storesError;

  List<Map<String, dynamic>> _modules = [];
  List<Map<String, dynamic>> _foodStores = [];
  List<Map<String, dynamic>> _groceryStores = [];
  List<Map<String, dynamic>> _foodCategories = [];
  List<Map<String, dynamic>> _groceryCategories = [];

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSavedAddress();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

      await _loadStores();
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

  Future<void> _loadStores() async {
    final zoneId = _selectedZoneId;

    if (zoneId == null || zoneId.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _modules = [];
        _foodStores = [];
        _groceryStores = [];
        _foodCategories = [];
        _groceryCategories = [];
      });

      return;
    }

    setState(() {
      _isLoadingStores = true;
      _storesError = null;
    });

    try {
      final modulesFuture = _storesApiService.getModules();
      final homeConfig = HomeConfigController.instance.config;
      final foodEnabled = homeConfig.moduleEnabled('food');
      final groceryEnabled = homeConfig.moduleEnabled('grocery');

      final foodStoresFuture = foodEnabled
          ? _storesApiService.getStores(moduleId: 'food', zoneId: zoneId)
          : Future.value(<Map<String, dynamic>>[]);

      final groceryStoresFuture = groceryEnabled
          ? _storesApiService.getStores(moduleId: 'grocery', zoneId: zoneId)
          : Future.value(<Map<String, dynamic>>[]);

      final foodCategoriesFuture = foodEnabled
          ? _storesApiService.getHomeCategories(
              moduleId: 'food',
              zoneId: zoneId,
            )
          : Future.value(<Map<String, dynamic>>[]);

      final groceryCategoriesFuture = groceryEnabled
          ? _storesApiService.getHomeCategories(
              moduleId: 'grocery',
              zoneId: zoneId,
            )
          : Future.value(<Map<String, dynamic>>[]);

      final results = await Future.wait([
        modulesFuture,
        foodStoresFuture,
        groceryStoresFuture,
        foodCategoriesFuture,
        groceryCategoriesFuture,
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _modules = results[0];
        _foodStores = results[1];
        _groceryStores = results[2];
        _foodCategories = results[3];
        _groceryCategories = results[4];
        _isLoadingStores = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load home stores: $error');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _modules = [];
        _foodStores = [];
        _groceryStores = [];
        _foodCategories = [];
        _groceryCategories = [];
        _storesError = 'Unable to load nearby stores.';
        _isLoadingStores = false;
      });
    }
  }

  Future<void> _chooseLocation() async {
    final selectedAddress = await Navigator.of(context).push<CustomerAddress>(
      MaterialPageRoute(builder: (_) => const SavedAddressesPage()),
    );

    if (selectedAddress == null || !mounted) {
      return;
    }

    final zoneChanged = _selectedZoneId != selectedAddress.zoneId;

    setState(() {
      _selectedAddress = selectedAddress.address;

      _selectedZoneId = selectedAddress.zoneId;
    });

    if (zoneChanged) {
      await _loadStores();
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  void _openRestaurants({String moduleId = 'food', String? category}) {
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
        builder: (_) => RestaurantsPage(
          zoneId: zoneId,
          moduleId: moduleId,
          category: category,
        ),
      ),
    );
  }

  void _openStore(Map<String, dynamic> store) {
    final storeId = store['id']?.toString() ?? '';

    final storeName = store['name']?.toString() ?? 'Store';

    final storeAddress = store['address']?.toString() ?? '';

    final isOpen = store['isOpen'] == true;

    if (!isOpen || storeId.isEmpty) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MenuPage(
          storeId: storeId,
          storeName: storeName,
          storeAddress: storeAddress,
        ),
      ),
    );
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim().toLowerCase();
    });
  }

  void _onPromoTap(HomeConfig homeConfig) {
    final promo = homeConfig.promoBanner;

    switch (promo.actionType) {
      case 'MODULE':
        if (promo.actionValue.isNotEmpty) {
          _openRestaurants(moduleId: promo.actionValue);
        }
        break;

      case 'CATEGORY':
        final value = promo.actionValue.trim();

        if (value.isEmpty) {
          break;
        }

        final separatorIndex = value.indexOf(':');

        if (separatorIndex <= 0) {
          _openRestaurants(moduleId: 'food', category: value);

          break;
        }

        final moduleId = value
            .substring(0, separatorIndex)
            .trim()
            .toLowerCase();

        final category = value.substring(separatorIndex + 1).trim();

        if ((moduleId == 'food' || moduleId == 'grocery') &&
            category.isNotEmpty) {
          _openRestaurants(moduleId: moduleId, category: category);
        }
        break;

      case 'NONE':
      default:
        break;
    }
  }

  void _onNavigationTap(int index) {
    if (index == 0) {
      setState(() {
        selectedIndex = 0;
      });

      return;
    }

    if (index == 1) {
      final zoneId = _selectedZoneId;

      if (zoneId == null || zoneId.isEmpty) {
        _showMessage('Please select your delivery location first.');

        return;
      }

      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => SearchPage(zoneId: zoneId)));

      return;
    }

    if (index == 2) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const OrdersPage()));

      return;
    }

    if (index == 3) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ProfilePage()));
    }
  }

  List<Map<String, dynamic>> get _allStores {
    final stores = [..._foodStores, ..._groceryStores];

    final unique = <String, Map<String, dynamic>>{};

    for (final store in stores) {
      final id = store['id']?.toString();

      if (id == null || id.isEmpty) {
        continue;
      }

      unique[id] = store;
    }

    return unique.values.toList();
  }

  List<Map<String, dynamic>> get _homeCategories {
    return [..._foodCategories, ..._groceryCategories];
  }

  List<Map<String, dynamic>> get _filteredStores {
    final stores = _allStores;

    if (_searchQuery.isEmpty) {
      return stores;
    }

    return stores.where((store) {
      final name = store['name']?.toString().toLowerCase() ?? '';

      final address = store['address']?.toString().toLowerCase() ?? '';

      return name.contains(_searchQuery) || address.contains(_searchQuery);
    }).toList();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildHeaderSliver(AppBranding branding) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeHeader(
              address: _selectedAddress,
              loadingAddress: _isLoadingAddress,
              onLocationTap: _chooseLocation,
              onNotificationTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CustomerNotificationsPage(),
                ),
              ),
              onLogoutTap: _logout,
            ),
            const SizedBox(height: 22),
            Text(
              branding.appName,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(branding.tagline, style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 20),
            HomeSearchBar(
              controller: _searchController,
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSectionSlivers(String sectionId, HomeConfig config) {
    switch (sectionId) {
      case 'modules':
        return _buildModulesSlivers(config);
      case 'promo':
        return _buildPromoSlivers(config);
      case 'categories':
        return _buildCategorySlivers();
      case 'nearby':
        return _buildNearbySlivers(config);
      default:
        return [];
    }
  }

  List<Widget> _buildModulesSlivers(HomeConfig config) {
    final modules =
        _modules.where((module) {
          final id = module['id']?.toString() ?? '';

          return config.moduleEnabled(id);
        }).toList()..sort((a, b) {
          final aOrder = int.tryParse(a['sortOrder']?.toString() ?? '') ?? 999;
          final bOrder = int.tryParse(b['sortOrder']?.toString() ?? '') ?? 999;

          return aOrder.compareTo(bOrder);
        });

    if (modules.isEmpty) {
      return [];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              for (var index = 0; index < modules.length; index++) ...[
                if (index > 0) const SizedBox(width: 12),
                Expanded(
                  child: ModuleCard(
                    title: modules[index]['name']?.toString() ?? '',
                    subtitle: modules[index]['description']?.toString() ?? '',
                    imageUrl: modules[index]['imageUrl']?.toString() ?? '',
                    icon: modules[index]['id'] == 'food'
                        ? Icons.restaurant
                        : Icons.shopping_basket,
                    highlighted: index == 0,
                    onTap: () {
                      _openRestaurants(
                        moduleId: modules[index]['id'].toString(),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 22)),
    ];
  }

  List<Widget> _buildPromoSlivers(HomeConfig config) {
    if (!config.promoBanner.enabled) {
      return [];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: PromoBanner(
            title: config.promoBanner.title,
            subtitle: config.promoBanner.subtitle,
            imageUrl: config.promoBanner.imageUrl,
            onTap: () => _onPromoTap(config),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 28)),
    ];
  }

  List<Widget> _buildCategorySlivers() {
    if (_searchQuery.isNotEmpty || _homeCategories.isEmpty) {
      return [];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Categories'),
              const SizedBox(height: 14),
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _homeCategories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final category = _homeCategories[index];
                    final moduleId = category['moduleId']?.toString() ?? 'food';

                    return HomeCategoryItem(
                      category: category,
                      onTap: () {
                        final name = category['name']?.toString() ?? '';
                        _openRestaurants(moduleId: moduleId, category: name);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 28)),
    ];
  }

  List<Widget> _buildNearbySlivers(
    HomeConfig config, {
    bool isSearchResults = false,
  }) {
    final branding = AppBrandingController.instance.branding;
    final stores = _filteredStores;

    final heading = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: SectionHeader(
          title: isSearchResults ? 'Search Results' : 'Nearby Stores',
          actionText: isSearchResults ? null : 'See all',
          onAction: isSearchResults ? null : _openRestaurants,
        ),
      ),
    );

    if (_isLoadingStores) {
      return [
        heading,
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }

    if (_storesError != null) {
      return [
        heading,
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.cloud_off_outlined, size: 48),
                const SizedBox(height: 12),
                Text(_storesError!, textAlign: TextAlign.center),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _loadStores,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (_selectedZoneId == null || _selectedZoneId!.isEmpty) {
      return [
        heading,
        SliverToBoxAdapter(
          child: _EmptyState(
            icon: Icons.location_on_outlined,
            title: 'Choose your delivery location',
            message: 'Select an address to see stores available near you.',
            buttonText: 'Select location',
            onPressed: _chooseLocation,
          ),
        ),
      ];
    }

    if (stores.isEmpty) {
      return [
        heading,
        SliverToBoxAdapter(
          child: _EmptyState(
            icon: _searchQuery.isEmpty
                ? Icons.storefront_outlined
                : Icons.search_off,
            title: _searchQuery.isEmpty
                ? 'No stores available'
                : 'No results found',
            message: _searchQuery.isEmpty
                ? 'There are currently no stores available in your area.'
                : 'Try searching with a different store name.',
          ),
        ),
      ];
    }

    return [
      heading,
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final store = stores[index];
            return StoreCard(
              store: store,
              currencySymbol: branding.currencySymbol,
              onTap: () => _openStore(store),
            );
          }, childCount: stores.length),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final branding = AppBrandingController.instance.branding;
    final homeConfig = HomeConfigController.instance.config;
    final isSearching = _searchQuery.trim().isNotEmpty;
    final orderedSections =
        homeConfig.sections.where((section) => section.enabled).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final slivers = <Widget>[
      _buildHeaderSliver(branding),
      if (isSearching)
        ..._buildNearbySlivers(homeConfig, isSearchResults: true)
      else
        for (final section in orderedSections)
          ..._buildSectionSlivers(section.id, homeConfig),
      const SliverToBoxAdapter(child: SizedBox(height: 110)),
    ];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSavedAddress,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: slivers,
          ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.buttonText,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 45, 32, 30),
      child: Column(
        children: [
          Icon(icon, size: 56, color: Colors.grey[500]),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[700]),
          ),
          if (buttonText != null && onPressed != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onPressed, child: Text(buttonText!)),
          ],
        ],
      ),
    );
  }
}
