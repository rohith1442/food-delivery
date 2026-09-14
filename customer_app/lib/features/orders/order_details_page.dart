import 'package:flutter/material.dart';

import '../reviews/review_dialog.dart';
import '../reviews/reviews_api_service.dart';
import '../../core/config/app_branding.dart';
import '../restaurants/menu_page.dart';
import 'order_tracking_page.dart';
import 'orders_api_service.dart';
import 'widgets/order_lifecycle.dart';

class OrderDetailsPage extends StatefulWidget {
  const OrderDetailsPage({super.key, required this.order});

  final Map<String, dynamic> order;

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  final ReviewsApiService _reviewsApiService = ReviewsApiService();
  final OrdersApiService _ordersApiService = OrdersApiService();

  bool _submittingReview = false;
  bool _checkingReview = false;
  Map<String, dynamic>? _review;
  late Map<String, dynamic> _order;
  bool _refreshingOrder = false;

  Map<String, dynamic> get order => _order;

  @override
  void initState() {
    super.initState();
    _order = Map<String, dynamic>.from(widget.order);

    if (order['status']?.toString() == 'DELIVERED') {
      _loadReview();
    }
  }

  Future<void> _refreshOrder() async {
    final orderId = order['id']?.toString() ?? '';
    if (orderId.isEmpty || _refreshingOrder) return;
    setState(() => _refreshingOrder = true);
    try {
      final response = await _ordersApiService.getOrder(orderId);
      final raw = response['order'];
      if (!mounted) return;
      setState(() {
        _order = raw is Map ? Map<String, dynamic>.from(raw) : response;
        _refreshingOrder = false;
      });
      if (_order['status']?.toString() == 'DELIVERED' && _review == null) {
        await _loadReview();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _refreshingOrder = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to refresh order')));
    }
  }

  Future<void> _loadReview() async {
    final orderId = order['id']?.toString() ?? '';

    if (orderId.isEmpty) return;

    setState(() {
      _checkingReview = true;
    });

    try {
      final review = await _reviewsApiService.getOrderReview(orderId);

      if (!mounted) return;

      setState(() {
        _review = review;
        _checkingReview = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _checkingReview = false;
      });
    }
  }

  Future<void> _rateOrder() async {
    final storeName = order['storeName']?.toString() ?? 'Store';

    final result = await showDialog<ReviewResult>(
      context: context,
      builder: (_) => ReviewDialog(storeName: storeName),
    );

    if (result == null) return;

    final orderId = order['id']?.toString() ?? '';

    if (orderId.isEmpty) return;

    setState(() {
      _submittingReview = true;
    });

    try {
      final response = await _reviewsApiService.createReview(
        orderId: orderId,
        rating: result.rating,
        comment: result.comment,
      );

      if (!mounted) return;

      final review = response['review'];

      setState(() {
        _review = review is Map ? Map<String, dynamic>.from(review) : null;
        _submittingReview = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Thanks for your review!')));
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _submittingReview = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to submit review: $error')),
      );
    }
  }

  String _formatStatus(dynamic value) {
    final status = value?.toString() ?? '';

    switch (status) {
      case 'VENDOR_PENDING':
        return 'Waiting for restaurant';
      case 'ACCEPTED':
        return 'Accepted';
      case 'PREPARING':
        return 'Preparing';
      case 'READY':
        return 'Ready';
      case 'RIDER_ASSIGNED':
        return 'Rider assigned';
      case 'PICKED_UP':
        return 'Picked up';
      case 'ON_THE_WAY':
        return 'On the way';
      case 'DELIVERED':
        return 'Delivered';
      case 'REJECTED':
        return 'Rejected';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) {
      return '';
    }

    final date = DateTime.tryParse(value.toString());

    if (date == null) {
      return value.toString();
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _getItems() {
    final rawItems = order['items'];

    if (rawItems is! List) {
      return [];
    }

    return rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, dynamic>? _getDeliveryAddress() {
    final newAddress = order['deliveryAddress'];

    if (newAddress is Map) {
      return Map<String, dynamic>.from(newAddress);
    }

    final legacyAddress = order['address'];

    if (legacyAddress is Map) {
      return Map<String, dynamic>.from(legacyAddress);
    }

    return null;
  }

  String _getAddressLabel(Map<String, dynamic>? address) {
    if (address == null) {
      return 'Delivery Address';
    }

    return address['label']?.toString().trim().isNotEmpty == true
        ? address['label'].toString()
        : address['type']?.toString().trim().isNotEmpty == true
        ? address['type'].toString()
        : 'Delivery Address';
  }

  String _getAddressText(Map<String, dynamic>? address) {
    if (address == null) {
      return 'Address unavailable';
    }

    final addressLine = address['address']?.toString().trim() ?? '';

    final details = address['details']?.toString().trim() ?? '';

    final value = [
      addressLine,
      details,
    ].where((item) => item.isNotEmpty).join('\n');

    return value.isEmpty ? 'Address unavailable' : value;
  }

  @override
  Widget build(BuildContext context) {
    final rawStatus = order['status']?.toString() ?? '';

    final status = _formatStatus(rawStatus);

    final isCancelled = rawStatus == 'CANCELLED' || rawStatus == 'REJECTED';

    final isDelivered = rawStatus == 'DELIVERED';

    final items = _getItems();

    final deliveryAddress = _getDeliveryAddress();

    final orderId = order['id']?.toString() ?? '-';

    final storeName = order['storeName']?.toString() ?? 'Store';

    final storeAddress = order['storeAddress']?.toString() ?? '';

    final createdAt = _formatDate(order['createdAt']);

    final subtotal = order['subtotal']?.toString() ?? '0';

    final deliveryFee = order['deliveryFee']?.toString() ?? '0';

    final total = order['total']?.toString() ?? '0';

    final paymentMethod = order['paymentMethod']?.toString() ?? '-';
    final currency = AppBrandingController.instance.branding.currencySymbol;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        actions: [
          IconButton(
            onPressed: _refreshingOrder ? null : _refreshOrder,
            icon: _refreshingOrder
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    isCancelled
                        ? Icons.cancel_outlined
                        : isDelivered
                        ? Icons.check_circle_outline
                        : Icons.delivery_dining,
                    size: 52,
                    color: isCancelled
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    orderId,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (createdAt.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      createdAt,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Order Progress',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: OrderLifecycle(status: rawStatus),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Store',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Card(
            child: ListTile(
              leading: Icon(
                Icons.restaurant,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                storeName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: storeAddress.isEmpty ? null : Text(storeAddress),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Delivery Address',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Card(
            child: ListTile(
              leading: Icon(
                Icons.location_on_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                _getAddressLabel(deliveryAddress),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_getAddressText(deliveryAddress)),
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Items',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: items.isEmpty
                  ? const Text('No items available')
                  : Column(
                      children: [
                        for (var index = 0; index < items.length; index++) ...[
                          _OrderItemRow(item: items[index]),
                          if (index != items.length - 1)
                            const Divider(height: 24),
                        ],
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Payment Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SummaryRow(label: 'Subtotal', value: '$currency$subtotal'),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: 'Delivery fee',
                    value: '$currency$deliveryFee',
                  ),
                  const Divider(height: 24),
                  _SummaryRow(
                    label: 'Total',
                    value: '$currency$total',
                    bold: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.payment_outlined, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(paymentMethod)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          if (!isCancelled && !isDelivered)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OrderTrackingPage(orderId: orderId),
                    ),
                  );
                },
                icon: const Icon(Icons.location_searching),
                label: const Text('Track Order'),
              ),
            ),

          if (isDelivered) ...[
            if (_checkingReview)
              const Center(child: CircularProgressIndicator())
            else if (_review == null)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _submittingReview ? null : _rateOrder,
                  icon: const Icon(Icons.star_outline),
                  label: Text(
                    _submittingReview ? 'Submitting...' : 'Rate your order',
                  ),
                ),
              )
            else
              _ExistingReviewCard(review: _review!),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () {
                  final storeId = order['storeId']?.toString() ?? '';
                  if (storeId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Store is unavailable for reorder'),
                      ),
                    );
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
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reorder'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExistingReviewCard extends StatelessWidget {
  const _ExistingReviewCard({required this.review});

  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final rating = review['rating'] is num
        ? (review['rating'] as num).toInt()
        : 0;
    final comment = review['comment']?.toString().trim() ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Review',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 22,
                ),
              ),
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(comment),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ?? 'Item';

    final quantity = item['quantity']?.toString() ?? '1';

    final price = item['price']?.toString() ?? '0';
    final currency = AppBrandingController.instance.branding.currencySymbol;

    return Row(
      children: [
        Expanded(child: Text('$name × $quantity')),
        Text(
          '$currency$price',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
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
      fontSize: bold ? 18 : 15,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
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
