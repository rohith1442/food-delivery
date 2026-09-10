import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cart/cart_page.dart';
import '../cart/cart_provider.dart';

class ProductDetailsPage extends ConsumerWidget {
  const ProductDetailsPage({
    super.key,
    required this.storeId,
    required this.storeName,
    required this.storeAddress,
    required this.productId,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
  });

  final String storeId;
  final String storeName;
  final String storeAddress;

  final String productId;
  final String name;
  final String description;
  final int price;
  final int stock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    CartItem? existingItem;

    for (final item in cart.items) {
      if (item.id == productId) {
        existingItem = item;
        break;
      }
    }

    final cartQuantity = existingItem?.quantity ?? 0;

    final bool outOfStock = stock <= 0;

    final bool maxStockReached = stock > 0 && cartQuantity >= stock;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            onPressed: cart.isEmpty
                ? null
                : () {
                    Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (_) => const CartPage()));
                  },
            icon: Badge(
              isLabelVisible: cart.isNotEmpty,
              label: Text('${cartNotifier.itemCount}'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 260,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.fastfood,
                      size: 100,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),

                        const SizedBox(height: 8),

                        Text(
                          name,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          '₹$price',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 12),

                        _StockStatus(stock: stock),

                        if (cartQuantity > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            '$cartQuantity already in cart',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],

                        const SizedBox(height: 20),

                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: outOfStock || maxStockReached
                      ? null
                      : () async {
                          final result = cartNotifier.addItem(
                            storeId: storeId,
                            storeName: storeName,
                            storeAddress: storeAddress,
                            id: productId,
                            name: name,
                            price: price,
                            availableStock: stock,
                          );

                          if (!context.mounted) {
                            return;
                          }

                          if (result == AddToCartResult.added) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Added to cart')),
                            );

                            return;
                          }

                          if (result == AddToCartResult.outOfStock) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('This item is out of stock'),
                              ),
                            );

                            return;
                          }

                          if (result == AddToCartResult.maxStockReached) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Only $stock available')),
                            );

                            return;
                          }

                          if (result == AddToCartResult.differentStore) {
                            final replace = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) {
                                return AlertDialog(
                                  title: const Text('Replace cart?'),
                                  content: const Text(
                                    'Your cart contains items from another store. '
                                    'Clear the cart and add this item?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(dialogContext, false);
                                      },
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () {
                                        Navigator.pop(dialogContext, true);
                                      },
                                      child: const Text('Replace'),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (replace != true) {
                              return;
                            }

                            cartNotifier.clearCart();

                            final replaceResult = cartNotifier.addItem(
                              storeId: storeId,
                              storeName: storeName,
                              storeAddress: storeAddress,
                              id: productId,
                              name: name,
                              price: price,
                              availableStock: stock,
                            );

                            if (!context.mounted) {
                              return;
                            }

                            if (replaceResult == AddToCartResult.added) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cart replaced and item added'),
                                ),
                              );
                            }
                          }
                        },
                  child: Text(
                    outOfStock
                        ? 'Out of Stock'
                        : maxStockReached
                        ? 'Maximum Quantity Added'
                        : 'Add to Cart',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockStatus extends StatelessWidget {
  const _StockStatus({required this.stock});

  final int stock;

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final Color color;
    late final IconData icon;

    if (stock <= 0) {
      text = 'Out of stock';
      color = Colors.red;
      icon = Icons.cancel_outlined;
    } else if (stock <= 5) {
      text = 'Only $stock left';
      color = Colors.orange;
      icon = Icons.inventory_2_outlined;
    } else {
      text = 'In stock';
      color = Colors.green;
      icon = Icons.check_circle_outline;
    }

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
