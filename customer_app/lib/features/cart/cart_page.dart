import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_branding.dart';
import '../checkout/checkout_page.dart';
import '../location/addresses_api_service.dart';
import '../location/saved_addresses_page.dart';
import 'cart_provider.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  Future<void> _proceedToCheckout(BuildContext context) async {
    final selectedAddress = await Navigator.of(context).push<CustomerAddress>(
      MaterialPageRoute(builder: (_) => const SavedAddressesPage()),
    );

    if (selectedAddress == null || !context.mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CheckoutPage(address: selectedAddress)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    final items = cart.items;

    final cartNotifier = ref.read(cartProvider.notifier);
    final currency = AppBrandingController.instance.branding.currencySymbol;

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 72),
                  const SizedBox(height: 16),
                  const Text(
                    'Your cart is empty',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add something delicious to get started.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];

                      final maxReached = item.quantity >= item.availableStock;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.fastfood,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  Text('$currency${item.price}'),

                                  const SizedBox(height: 4),

                                  Text(
                                    item.availableStock <= 5
                                        ? 'Only ${item.availableStock} left'
                                        : 'In stock',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: item.availableStock > 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),

                                  if (maxReached)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Maximum available quantity reached',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      cartNotifier.decreaseQuantity(item.id);
                                    },
                                    icon: const Icon(Icons.remove_rounded),
                                  ),
                                  Text(
                                    '${item.quantity}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: maxReached
                                        ? null
                                        : () {
                                            final result = cartNotifier
                                                .increaseQuantity(item.id);

                                            if (result ==
                                                IncreaseQuantityResult
                                                    .maxStockReached) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Only ${item.availableStock} available',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    icon: const Icon(Icons.add_rounded),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 18,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _SummaryRow(
                          label: 'Subtotal',
                          value: '$currency${cartNotifier.subtotal}',
                        ),

                        const SizedBox(height: 8),

                        _SummaryRow(
                          label: 'Delivery fee',
                          value: '$currency${cartNotifier.deliveryFee}',
                        ),

                        const Divider(height: 24),

                        _SummaryRow(
                          label: 'Total',
                          value: '$currency${cartNotifier.total}',
                          bold: true,
                        ),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: () {
                              _proceedToCheckout(context);
                            },
                            child: const Text('Proceed to Checkout'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 18 : 15,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}
