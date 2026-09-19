import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/config/app_branding.dart';
import '../cart/cart_provider.dart';
import '../location/addresses_api_service.dart';
import '../location/saved_addresses_page.dart';
import '../orders/order_success_page.dart';
import '../orders/orders_api_service.dart';
import 'payments_api_service.dart';

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

  final PaymentsApiService _paymentsApiService = PaymentsApiService();

  late final Razorpay _razorpay;

  String? _pendingPaymentId;
  String? _pendingRazorpayOrderId;
  double? _pendingOrderTotal;

  @override
  void initState() {
    super.initState();

    selectedAddress = widget.address;

    _razorpay = Razorpay();

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);

    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);

    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();

    super.dispose();
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

    if (paymentMethod == 'Cash on Delivery') {
      await _placeCodOrder(storeId: storeId, cartState: cartState, cart: cart);

      return;
    }

    await _startOnlinePayment(
      storeId: storeId,
      cartState: cartState,
      cart: cart,
    );
  }

  Future<void> _placeCodOrder({
    required String storeId,
    required dynamic cartState,
    required dynamic cart,
  }) async {
    setState(() {
      _placingOrder = true;
    });

    try {
      final orderTotal = cart.total;

      final items = cartState.items
          .map<Map<String, dynamic>>(
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
        paymentMethod: 'COD',
      );

      if (!mounted) {
        return;
      }

      debugPrint('COD order created successfully: $response');

      cart.clearCart();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderSuccessPage(
            total: orderTotal,
            paymentMethod: 'Cash on Delivery',
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to place COD order: $error');

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

  Future<void> _startOnlinePayment({
    required String storeId,
    required dynamic cartState,
    required dynamic cart,
  }) async {
    setState(() {
      _placingOrder = true;
    });

    try {
      final paymentItems = cartState.items
          .map<Map<String, dynamic>>(
            (item) => {'id': item.id, 'quantity': item.quantity},
          )
          .toList();

      final response = await _paymentsApiService.createRazorpayOrder(
        storeId: storeId,
        addressId: selectedAddress.id,
        items: paymentItems,
      );

      final paymentId = response['paymentId'] as String?;

      final razorpayOrderId = response['razorpayOrderId'] as String?;

      final keyId = response['keyId'] as String?;

      final amount = response['amount'];

      final currency = response['currency'] as String?;

      final total = response['total'];
      final branding = AppBrandingController.instance.branding;
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final contact = firebaseUser?.phoneNumber ?? '';
      final email = firebaseUser?.email ?? '';

      if (paymentId == null ||
          paymentId.isEmpty ||
          razorpayOrderId == null ||
          razorpayOrderId.isEmpty ||
          keyId == null ||
          keyId.isEmpty ||
          amount is! num) {
        throw Exception('Invalid payment order response');
      }

      _pendingPaymentId = paymentId;
      _pendingRazorpayOrderId = razorpayOrderId;
      _pendingOrderTotal = total is num
          ? total.toDouble()
          : cart.total.toDouble();

      final options = <String, dynamic>{
        'key': keyId,

        /*
         * Backend already returns amount in paise.
         * Do NOT multiply by 100 again here.
         */
        'amount': amount.toInt(),

        'currency': currency ?? 'INR',

        'order_id': razorpayOrderId,

        'name': branding.appName,

        'description': 'Order Payment',
        'prefill': {
          if (contact.isNotEmpty) 'contact': contact,
          if (email.isNotEmpty) 'email': email,
        },

        'retry': {'enabled': true, 'max_count': 1},

        'theme': {'color': branding.primaryColor},
      };

      debugPrint(
        'Opening Razorpay paymentId=$paymentId '
        'razorpayOrderId=$razorpayOrderId',
      );

      _razorpay.open(options);
    } catch (error, stackTrace) {
      debugPrint('Failed to start Razorpay payment: $error');

      debugPrintStack(stackTrace: stackTrace);

      _clearPendingPayment();

      if (!mounted) {
        return;
      }

      setState(() {
        _placingOrder = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start payment: $error')),
      );
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final paymentId = _pendingPaymentId;

    final expectedRazorpayOrderId = _pendingRazorpayOrderId;

    final razorpayPaymentId = response.paymentId;

    final razorpayOrderId = response.orderId;

    final signature = response.signature;

    if (paymentId == null ||
        expectedRazorpayOrderId == null ||
        razorpayPaymentId == null ||
        razorpayPaymentId.isEmpty ||
        razorpayOrderId == null ||
        razorpayOrderId.isEmpty ||
        signature == null ||
        signature.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _placingOrder = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment completed but payment verification data is missing.',
          ),
        ),
      );

      return;
    }

    if (razorpayOrderId != expectedRazorpayOrderId) {
      if (!mounted) {
        return;
      }

      setState(() {
        _placingOrder = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment order mismatch. Please contact support.'),
        ),
      );

      return;
    }

    try {
      final result = await _paymentsApiService.verifyRazorpayPayment(
        paymentId: paymentId,
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: razorpayPaymentId,
        razorpaySignature: signature,
      );

      debugPrint('Payment verified successfully: $result');

      if (!mounted) {
        return;
      }

      final total = _pendingOrderTotal ?? 0;

      ref.read(cartProvider.notifier).clearCart();

      _clearPendingPayment();

      setState(() {
        _placingOrder = false;
      });

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              OrderSuccessPage(total: total, paymentMethod: 'Online Payment'),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Payment verification failed: $error');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _placingOrder = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment verification failed: $error')),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint(
      'Razorpay payment failed '
      'code=${response.code} '
      'message=${response.message}',
    );

    _clearPendingPayment();

    if (!mounted) {
      return;
    }

    setState(() {
      _placingOrder = false;
    });

    final message = response.code == Razorpay.PAYMENT_CANCELLED
        ? 'Payment cancelled'
        : response.message ?? 'Payment failed';

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External wallet selected: ${response.walletName}');
  }

  void _clearPendingPayment() {
    _pendingPaymentId = null;
    _pendingRazorpayOrderId = null;
    _pendingOrderTotal = null;
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);

    final items = cartState.items;

    final cart = ref.read(cartProvider.notifier);
    final branding = AppBrandingController.instance.branding;
    final currency = branding.currencySymbol;

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

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
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

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
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
                          '$currency${item.price * item.quantity}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 20),

                _SummaryRow(
                  label: 'Subtotal',
                  value: '$currency${cart.subtotal}',
                ),

                const SizedBox(height: 8),

                _SummaryRow(
                  label: 'Delivery fee',
                  value: '$currency${cart.deliveryFee}',
                ),

                const Divider(height: 24),

                _SummaryRow(
                  label: 'Total',
                  value: '$currency${cart.total}',
                  bold: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const _SectionTitle(title: 'Payment Method'),

          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
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
              child: Column(
                children: [
                  const RadioListTile<String>(
                    value: 'Cash on Delivery',
                    title: Text(
                      'Cash on Delivery',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('Pay when your order arrives'),
                    secondary: Icon(Icons.payments_outlined),
                  ),
                  const RadioListTile<String>(
                    value: 'Online Payment',
                    title: Text(
                      'Online Payment',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('UPI, Card, Net Banking'),
                    secondary: Icon(Icons.account_balance_wallet_outlined),
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
                  : Text(
                      paymentMethod == 'Online Payment'
                          ? 'Pay • $currency${cart.total}'
                          : 'Place Order • $currency${cart.total}',
                    ),
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
