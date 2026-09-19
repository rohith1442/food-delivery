import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cart/cart_provider.dart';
import '../products/product_details_page.dart';
import 'stores_api_service.dart';

class MenuPage extends ConsumerStatefulWidget {
  const MenuPage({
    super.key,
    required this.storeId,
    required this.storeName,
    required this.storeAddress,
    required this.storeImageUrl,
    required this.storeRating,
    required this.ratingCount,
  });

  final String storeId;
  final String storeName;
  final String storeAddress;
  final String storeImageUrl;
  final double storeRating;
  final int ratingCount;

  @override
  ConsumerState<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends ConsumerState<MenuPage> {
  final StoresApiService _apiService = StoresApiService();

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];

  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _apiService.getCategories(widget.storeId),
        _apiService.getProducts(widget.storeId),
      ]);

      if (!mounted) return;

      setState(() {
        _categories = results[0];
        _products = results[1];
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectCategory(String? categoryId) async {
    setState(() {
      _selectedCategoryId = categoryId;
      _loading = true;
      _error = null;
    });

    try {
      final products = await _apiService.getProducts(
        widget.storeId,
        categoryId: categoryId,
      );

      if (!mounted) return;

      setState(() {
        _products = products;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  int _getPrice(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.round();
    }

    if (value is num) {
      return value.round();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildStoreHeader(),
          if (_categories.isNotEmpty) _buildCategories(),
          Expanded(child: _buildProducts()),
        ],
      ),
    );
  }

  Widget _buildStoreHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 240,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.storeImageUrl.isNotEmpty
                  ? Image.network(
                      widget.storeImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _storePlaceholder(),
                    )
                  : _storePlaceholder(),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -18),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.storeName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      widget.ratingCount > 0
                          ? '${widget.storeRating.toStringAsFixed(1)} (${widget.ratingCount})'
                          : 'New',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text(widget.storeAddress)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _storePlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(child: Icon(Icons.storefront, size: 60)),
    );
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    final productId = product['id']?.toString() ?? '';
    final name = product['name']?.toString() ?? 'Product';
    final price = _getPrice(product['price']);
    final stock = _getPrice(product['stock']);
    final cartNotifier = ref.read(cartProvider.notifier);

    final result = cartNotifier.addItem(
      storeId: widget.storeId,
      storeName: widget.storeName,
      storeAddress: widget.storeAddress,
      id: productId,
      name: name,
      price: price,
      availableStock: stock,
    );

    if (!mounted) return;

    if (result == AddToCartResult.differentStore) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Replace cart?'),
          content: const Text(
            'Your cart contains items from another store. '
            'Clear the cart and add this item?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );

      if (replace == true) {
        cartNotifier.clearCart();
        cartNotifier.addItem(
          storeId: widget.storeId,
          storeName: widget.storeName,
          storeAddress: widget.storeAddress,
          id: productId,
          name: name,
          price: price,
          availableStock: stock,
        );
      }
      return;
    }

    final message = switch (result) {
      AddToCartResult.added => 'Added to cart',
      AddToCartResult.outOfStock => 'This item is out of stock',
      AddToCartResult.maxStockReached => 'Only $stock available',
      AddToCartResult.differentStore => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: const Text('All'),
              selected: _selectedCategoryId == null,
              onSelected: (_) {
                _selectCategory(null);
              },
            ),
          ),
          ..._categories.map((category) {
            final categoryId = category['id']?.toString() ?? '';

            final categoryName = category['name']?.toString() ?? 'Category';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(categoryName),
                selected: _selectedCategoryId == categoryId,
                onSelected: (_) {
                  _selectCategory(categoryId);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProducts() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 100),
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Unable to load menu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.fastfood_outlined, size: 64),
            SizedBox(height: 16),
            Center(
              child: Text(
                'No products available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];

          final productId = product['id']?.toString() ?? '';

          final name = product['name']?.toString() ?? 'Product';

          final description = product['description']?.toString() ?? '';

          final price = _getPrice(product['price']);

          final stock = _getPrice(product['stock']);

          final imageUrl = product['imageUrl']?.toString();

          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: productId.isEmpty
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProductDetailsPage(
                          storeId: widget.storeId,
                          storeName: widget.storeName,
                          storeAddress: widget.storeAddress,
                          productId: productId,
                          name: name,
                          description: description,
                          price: price,
                          stock: stock,
                        ),
                      ),
                    );
                  },
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          '₹$price',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          stock <= 0
                              ? 'Out of stock'
                              : stock <= 5
                              ? 'Only $stock left'
                              : 'In stock',
                          style: TextStyle(
                            fontSize: 12,
                            color: stock > 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    children: [
                      _ProductImage(imageUrl: imageUrl),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 84,
                        height: 36,
                        child: OutlinedButton(
                          onPressed: stock <= 0
                              ? null
                              : () => _addToCart(product),
                          child: const Text('ADD'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          imageUrl!,
          width: 105,
          height: 90,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _placeholder(context);
          },
        ),
      );
    }

    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: 105,
      height: 90,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.fastfood, color: Theme.of(context).colorScheme.primary),
    );
  }
}
