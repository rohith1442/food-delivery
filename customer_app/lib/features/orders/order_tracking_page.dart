import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/config/app_branding.dart';
import 'orders_api_service.dart';
import 'widgets/order_lifecycle.dart';

class OrderTrackingPage extends StatefulWidget {
  const OrderTrackingPage({super.key, required this.orderId});
  final String orderId;
  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  final _api = OrdersApiService();
  Map<String, dynamic>? _order;
  Timer? _timer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _load(showLoading: false),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await _api.getOrder(widget.orderId);
      final raw = response['order'];
      final order = raw is Map ? Map<String, dynamic>.from(raw) : response;
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
        _error = null;
      });
      if ({'DELIVERED', 'REJECTED', 'CANCELLED'}.contains(order['status'])) {
        _timer?.cancel();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to refresh order';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final branding = AppBrandingController.instance.branding;
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _order == null) {
      body = Center(
        child: FilledButton(onPressed: _load, child: const Text('Retry')),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Order ${widget.orderId}',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text('Automatically refreshes every 10 seconds'),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: OrderLifecycle(
                  status: _order?['status']?.toString() ?? 'VENDOR_PENDING',
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Total'),
                trailing: Text(
                  '${branding.currencySymbol}${_order?['total'] ?? 0}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Order'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: body,
    );
  }
}
