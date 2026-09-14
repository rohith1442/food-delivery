import 'package:flutter/material.dart';

import 'order_details_page.dart';
import 'orders_api_service.dart';
import '../../core/config/app_branding.dart';
import 'widgets/order_lifecycle.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final OrdersApiService _ordersApiService = OrdersApiService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final orders = await _ordersApiService.getOrders();

      if (!mounted) return;

      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (error) {
      debugPrint('LOAD ORDERS ERROR: $error');

      if (!mounted) return;

      setState(() {
        _error = 'Failed to load orders';
        _loading = false;
      });
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
        '${date.year}';
  }

  String _formatItems(dynamic value) {
    if (value is! List) {
      return '';
    }

    return value
        .map((item) {
          if (item is! Map) {
            return '';
          }

          final name = item['name'] ?? 'Item';
          final quantity = item['quantity'] ?? 1;

          return '$name × $quantity';
        })
        .where((item) => item.isNotEmpty)
        .join(', ');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadOrders, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadOrders,
        child: ListView(
          children: const [
            SizedBox(height: 180),
            Center(child: Text('No orders yet')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];

          final orderId = order['id']?.toString() ?? '';

          final total = order['total']?.toString() ?? '0';
          final currency =
              AppBrandingController.instance.branding.currencySymbol;

          final status = _formatStatus(order['status']);

          final items = _formatItems(order['items']);

          final date = _formatDate(order['createdAt']);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OrderDetailsPage(order: order),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.restaurant,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Food Order',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                orderId,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusBadge(status: status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(items, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    OrderLifecycle(
                      status: order['status']?.toString() ?? '',
                      compact: true,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '$currency$total',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
