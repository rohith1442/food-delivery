import 'package:flutter/material.dart';

import '../../core/config/app_branding.dart';
import '../orders/delivery_orders_api_service.dart';

class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key});
  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  final _service = DeliveryOrdersApiService();
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final orders = await _service.getHistory();
      if (mounted) {
        setState(() {
          _orders = orders;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  double _fee(Map<String, dynamic> order) {
    final value = order['deliveryFee'];
    return value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _today(Map<String, dynamic> order) {
    final date = DateTime.tryParse(order['updatedAt']?.toString() ?? '')
        ?.toLocal();
    final now = DateTime.now();
    return date != null &&
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final currency = AppBrandingController.instance.branding.currencySymbol;
    final total = _orders.fold(0.0, (sum, order) => sum + _fee(order));
    final today = _orders
        .where(_today)
        .fold(0.0, (sum, order) => sum + _fee(order));
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: FilledButton(onPressed: _load, child: const Text('Retry')),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Today's earnings"),
                          Text(
                            '$currency${today.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      title: const Text('Completed deliveries'),
                      trailing: Text('${_orders.length}'),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: const Text('Total delivery earnings'),
                      trailing: Text('$currency${total.toStringAsFixed(0)}'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Delivery history',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  if (_orders.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(
                          child: Text('No completed deliveries yet'),
                        ),
                      ),
                    ),
                  ..._orders.map(
                    (order) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text(
                          'Order #${order['id']?.toString().substring(0, (order['id']?.toString().length ?? 0) > 8 ? 8 : order['id']?.toString().length ?? 0)}',
                        ),
                        trailing: Text(
                          '$currency${_fee(order).toStringAsFixed(0)}',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
