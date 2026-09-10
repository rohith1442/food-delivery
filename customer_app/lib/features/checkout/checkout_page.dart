import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cart/cart_provider.dart';
import '../location/addresses_api_service.dart';
import '../location/saved_addresses_page.dart';
import '../orders/order_success_page.dart';
import '../orders/orders_api_service.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key, required this.address});

  final CustomerAddress address;

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  late CustomerAddress selectedAddress;

  String paymentMethod = 'Cash on Delivery';

  bool _placingOrder = false;

  final OrdersApiService _ordersApiService = OrdersApiService();

  @override
  void initState() {
    super.initState();

    selectedAddress = widget.address;
  }

  Future<void> _changeAddress() async {
    if (_placingOrder) {
      return;
    }

    final address = await Navigator.of(context).push<CustomerAddress>(
      MaterialPageRoute(builder: (_) => const SavedAddressesPage()),
    );

    if (address == null || !mounted) {
      return;
    }

    setState(() {
      selectedAddress = address;
    });
  }

  Future<void> _placeOrder() async {
    if (_placingOrder) {
      return;
    }

    final cartState = ref.read(cartProvider);

    final cart = ref.read(cartProvider.notifier);

    if (cartState.items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Your cart is empty')));

      return;
    }

    final storeId = cartState.storeId;

    if (storeId == null || storeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Store information is missing. Please add the product again.',
          ),
        ),
      );

      return;
    }

    if (selectedAddress.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery address.')),
      );

      return;
    }

    setState(() {
      _placingOrder = true;
    });

    try {
      // Used only for displaying success UI.
      // Backend calculates the authoritative total.
      final orderTotal = cart.total;

      final items = cartState.items
          .map(
            (item) => {
              'id': item.id,
              'name': item.name,
              'price': item.price,
              'quantity': item.quantity,
            },
          )
          .toList();

      final response = await _ordersApiService.createOrder(
        storeId: storeId,
        items: items,
        addressId: selectedAddress.id,
        paymentMethod: paymentMethod,
      );

      if (!mounted) {
        return;
      }

      debugPrint('Order created successfully: $response');

      cart.clearCart();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              OrderSuccessPage(total: orderTotal, paymentMethod: paymentMethod),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to place order: $error');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to place order: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _placingOrder = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);

    final items = cartState.items;

    final cart = ref.read(cartProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle(
            title: 'Delivery Address',
            action: TextButton(
              onPressed: _placingOrder ? null : _changeAddress,
              child: const Text('Change'),
            ),
          ),

          const SizedBox(height: 8),

          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Icon(
                _getAddressIcon(selectedAddress.label),
                color: Theme.of(context).colorScheme.primary,
                size: 30,
              ),
              title: Text(
                selectedAddress.label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(selectedAddress.address),
              ),
            ),
          ),

          const SizedBox(height: 24),

          const _SectionTitle(title: 'Order Summary'),

          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('${item.name} × ${item.quantity}'),
                          ),
                          Text(
                            '₹${item.price * item.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Divider(height: 20),

                  _SummaryRow(label: 'Subtotal', value: '₹${cart.subtotal}'),

                  const SizedBox(height: 8),

                  _SummaryRow(
                    label: 'Delivery fee',
                    value: '₹${cart.deliveryFee}',
                  ),

                  const Divider(height: 24),

                  _SummaryRow(
                    label: 'Total',
                    value: '₹${cart.total}',
                    bold: true,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          const _SectionTitle(title: 'Payment Method'),

          const SizedBox(height: 8),

          Card(
            child: RadioGroup<String>(
              groupValue: paymentMethod,
              onChanged: (value) {
                if (value == null || _placingOrder) {
                  return;
                }

                setState(() {
                  paymentMethod = value;
                });
              },
              child: const Column(
                children: [
                  RadioListTile<String>(
                    value: 'Cash on Delivery',
                    title: Text('Cash on Delivery'),
                    subtitle: Text('Pay when your order arrives'),
                    secondary: Icon(Icons.money_outlined),
                  ),
                  RadioListTile<String>(
                    value: 'Online Payment',
                    title: Text('Online Payment'),
                    subtitle: Text('UPI, Card, Net Banking'),
                    secondary: Icon(Icons.payment_outlined),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: items.isEmpty || _placingOrder ? null : _placeOrder,
              child: _placingOrder
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Place Order • ₹${cart.total}'),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getAddressIcon(String label) {
    switch (label.toLowerCase()) {
      case 'home':
        return Icons.home_outlined;

      case 'work':
        return Icons.work_outline;

      default:
        return Icons.location_on_outlined;
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action});

  final String title;
  final Widget? action;

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
        ?action,
      ],
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
