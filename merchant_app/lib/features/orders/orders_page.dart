import 'package:flutter/material.dart';

import 'merchant_orders_api_service.dart';

class MerchantOrdersPage extends StatefulWidget {
  const MerchantOrdersPage({super.key});

  @override
  State<MerchantOrdersPage> createState() =>
      _MerchantOrdersPageState();
}

class _MerchantOrdersPageState
    extends State<MerchantOrdersPage> {
  final MerchantOrdersApiService _apiService =
  MerchantOrdersApiService();

  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;

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
      final orders = await _apiService.getOrders();

      if (!mounted) return;

      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (error) {
      debugPrint('LOAD MERCHANT ORDERS ERROR: $error');

      if (!mounted) return;

      setState(() {
        _error = 'Failed to load orders: $error';
        _loading = false;
      });
    }
  }

  Future<void> _updateStatus(
      String orderId,
      String status,
      ) async {
    try {
      await _apiService.updateStatus(
        orderId: orderId,
        status: status,
      );

      if (!mounted) return;

      await _loadOrders();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order marked as ${_displayStatus(status)}',
          ),
        ),
      );
    } catch (error) {
      debugPrint(
        'UPDATE MERCHANT ORDER STATUS ERROR: $error',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update order: $error',
          ),
        ),
      );
    }
  }

  String _displayStatus(String status) {
    switch (status) {
      case 'VENDOR_PENDING':
        return 'New';
      case 'ACCEPTED':
        return 'Accepted';
      case 'PREPARING':
        return 'Preparing';
      case 'READY':
        return 'Ready';
      case 'REJECTED':
        return 'Rejected';
      default:
        return status;
    }
  }

  String _formatItems(dynamic value) {
    if (value is! List) {
      return '';
    }

    return value.map((item) {
      if (item is Map) {
        final name = item['name'] ?? 'Item';
        final quantity = item['quantity'] ?? 1;
        return '$name × $quantity';
      }

      return item.toString();
    }).join(', ');
  }

  String _formatTime(dynamic value) {
    if (value is! String) {
      return '';
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      return '';
    }

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadOrders,
                child: const Text('Retry'),
              ),
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
            Center(
              child: Text('No active orders'),
            ),
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

          final orderId =
              order['id']?.toString() ?? '';

          final status =
              order['status']?.toString() ?? '';

          final total =
              order['total'] ?? 0;

          final items =
          _formatItems(order['items']);

          final time =
          _formatTime(order['createdAt']);

          return _OrderCard(
            orderId: orderId,
            status: _displayStatus(status),
            items: items,
            total: total,
            time: time,
            onAccept: () {
              _updateStatus(
                orderId,
                'ACCEPTED',
              );
            },
            onReject: () {
              _updateStatus(
                orderId,
                'REJECTED',
              );
            },
            onPrepare: () {
              _updateStatus(
                orderId,
                'PREPARING',
              );
            },
            onReady: () {
              _updateStatus(
                orderId,
                'READY',
              );
            },
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.orderId,
    required this.status,
    required this.items,
    required this.total,
    required this.time,
    required this.onAccept,
    required this.onReject,
    required this.onPrepare,
    required this.onReady,
  });

  final String orderId;
  final String status;
  final String items;
  final dynamic total;
  final String time;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onPrepare;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    orderId,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusBadge(
                  status: status,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              time,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              items,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Order Total',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '₹$total',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ActionButtons(
              status: status,
              onAccept: onAccept,
              onReject: onReject,
              onPrepare: onPrepare,
              onReady: onReady,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.status,
    required this.onAccept,
    required this.onReject,
    required this.onPrepare,
    required this.onReady,
  });

  final String status;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onPrepare;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'New':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onReject,
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: onAccept,
                child: const Text('Accept'),
              ),
            ),
          ],
        );

      case 'Accepted':
        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onPrepare,
            child: const Text('Start Preparing'),
          ),
        );

      case 'Preparing':
        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onReady,
            child: const Text('Mark Ready'),
          ),
        );

      case 'Ready':
        return const SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: null,
            child: Text(
              'Waiting for Delivery Partner',
            ),
          ),
        );

      case 'Rejected':
        return const SizedBox.shrink();

      default:
        return const SizedBox.shrink();
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final isRejected = status == 'Rejected';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: isRejected
            ? Theme.of(context)
            .colorScheme
            .errorContainer
            : Theme.of(context)
            .colorScheme
            .primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isRejected
              ? Theme.of(context)
              .colorScheme
              .error
              : Theme.of(context)
              .colorScheme
              .primary,
        ),
      ),
    );
  }
}