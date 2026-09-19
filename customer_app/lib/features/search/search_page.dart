import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/config/app_branding.dart';
import '../home/widgets/store_card.dart';
import '../cart/widgets/cart_floating_bar.dart';
import '../restaurants/menu_page.dart';
import '../restaurants/restaurants_page.dart';
import '../restaurants/stores_api_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.zoneId});

  final String zoneId;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final StoresApiService _storesApiService = StoresApiService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _loading = false;
        _error = null;
        _stores = [];
        _categories = [];
        _products = [];
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _storesApiService.search(
        zoneId: widget.zoneId,
        query: query,
      );

      if (!mounted ||
          _searchController.text.trim().toLowerCase() !=
              query.trim().toLowerCase()) {
        return;
      }

      setState(() {
        _stores = _extractList(response['stores']);
        _categories = _extractList(response['categories']);
        _products = _extractList(response['products']);
        _loading = false;
      });
    } catch (_) {
      if (!mounted ||
          _searchController.text.trim().toLowerCase() !=
              query.trim().toLowerCase()) {
        return;
      }

      setState(() {
        _error = 'Unable to search right now.';
        _stores = [];
        _categories = [];
        _products = [];
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _extractList(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  void _openStore(Map<String, dynamic> store) {
    final storeId = store['id']?.toString() ?? '';
    final storeName = store['name']?.toString() ?? 'Store';
    final storeAddress = store['address']?.toString() ?? '';
    final storeImageUrl = store['imageUrl']?.toString() ?? '';
    final storeRating = store['ratingAverage'] is num
        ? (store['ratingAverage'] as num).toDouble()
        : 0.0;
    final ratingCount = store['ratingCount'] is num
        ? (store['ratingCount'] as num).toInt()
        : 0;

    if (storeId.isEmpty) return;

    if (store['isOpen'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This store is currently closed.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MenuPage(
          storeId: storeId,
          storeName: storeName,
          storeAddress: storeAddress,
          storeImageUrl: storeImageUrl,
          storeRating: storeRating,
          ratingCount: ratingCount,
        ),
      ),
    );
  }

  void _openCategory(Map<String, dynamic> category) {
    final name = category['name']?.toString() ?? '';
    final moduleId = category['moduleId']?.toString() ?? '';

    if (name.isEmpty || moduleId.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RestaurantsPage(
          zoneId: widget.zoneId,
          moduleId: moduleId,
          category: name,
        ),
      ),
    );
  }

  void _openProduct(Map<String, dynamic> product) {
    final storeId = product['storeId']?.toString() ?? '';
    final storeName = product['storeName']?.toString() ?? 'Store';
    final storeAddress = product['storeAddress']?.toString() ?? '';
    final storeImageUrl = product['storeImageUrl']?.toString() ?? '';
    final storeRating = product['storeRating'] is num
        ? (product['storeRating'] as num).toDouble()
        : 0.0;
    final ratingCount = product['ratingCount'] is num
        ? (product['ratingCount'] as num).toInt()
        : 0;

    if (storeId.isEmpty) return;

    if (product['storeIsOpen'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This store is currently closed.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MenuPage(
          storeId: storeId,
          storeName: storeName,
          storeAddress: storeAddress,
          storeImageUrl: storeImageUrl,
          storeRating: storeRating,
          ratingCount: ratingCount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      bottomNavigationBar: const CartFloatingBar(),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search food, stores or groceries',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _debounce?.cancel();
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          Expanded(child: _buildBody(query)),
        ],
      ),
    );
  }

  Widget _buildBody(String query) {
    if (query.isEmpty) {
      return const _SearchEmptyState(
        icon: Icons.search,
        title: 'What are you looking for?',
        message: 'Search stores, categories or products.',
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _SearchEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Search unavailable',
        message: _error!,
        buttonText: 'Retry',
        onPressed: () => _search(_searchController.text.trim()),
      );
    }

    if (_stores.isEmpty && _categories.isEmpty && _products.isEmpty) {
      return const _SearchEmptyState(
        icon: Icons.search_off,
        title: 'No results found',
        message: 'Try a different search term.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
      children: [
        if (_categories.isNotEmpty) ...[
          _sectionTitle('Categories'),
          const SizedBox(height: 8),
          ..._categories.map(
            (category) => _CategoryResult(
              category: category,
              onTap: () => _openCategory(category),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (_stores.isNotEmpty) ...[
          _sectionTitle('Stores'),
          const SizedBox(height: 8),
          ..._stores.map(
            (store) => StoreCard(
              store: store,
              currencySymbol:
                  AppBrandingController.instance.branding.currencySymbol,
              onTap: () => _openStore(store),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (_products.isNotEmpty) ...[
          _sectionTitle('Products'),
          const SizedBox(height: 8),
          ..._products.map(
            (product) => _ProductResult(
              product: product,
              currencySymbol:
                  AppBrandingController.instance.branding.currencySymbol,
              onTap: () => _openProduct(product),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _CategoryResult extends StatelessWidget {
  const _CategoryResult({required this.category, required this.onTap});

  final Map<String, dynamic> category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = category['imageUrl']?.toString() ?? '';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 52,
          height: 52,
          child: imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.category_outlined),
                )
              : const Icon(Icons.category_outlined),
        ),
      ),
      title: Text(category['name']?.toString() ?? 'Category'),
      subtitle: Text(category['moduleId']?.toString().toUpperCase() ?? ''),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _ProductResult extends StatelessWidget {
  const _ProductResult({
    required this.product,
    required this.currencySymbol,
    required this.onTap,
  });

  final Map<String, dynamic> product;
  final String currencySymbol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product['imageUrl']?.toString() ?? '';
    final name = product['name']?.toString() ?? 'Product';
    final storeName = product['storeName']?.toString() ?? '';
    final price = product['price'];
    final isOpen = product['storeIsOpen'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.fastfood_outlined),
                      )
                    : const Icon(Icons.fastfood_outlined),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (storeName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                  if (!isOpen)
                    Text(
                      'Closed',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$currencySymbol${price ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: Colors.grey[500]),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            if (buttonText != null && onPressed != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onPressed, child: Text(buttonText!)),
            ],
          ],
        ),
      ),
    );
  }
}
