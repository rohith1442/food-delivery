import 'package:flutter/material.dart';

import 'earnings_api_service.dart';

class MerchantEarningsPage extends StatefulWidget {
  const MerchantEarningsPage({super.key});
  @override
  State<MerchantEarningsPage> createState() => _MerchantEarningsPageState();
}

class _MerchantEarningsPageState extends State<MerchantEarningsPage> {
  final _api = EarningsApiService();
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await Future.wait([
        _api.getSummary(),
        _api.getTransactions(),
      ]);
      if (mounted) {
        setState(() {
          _summary = result[0] as Map<String, dynamic>;
          _items = result[1] as List<Map<String, dynamic>>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary?['summary'] is Map
        ? Map<String, dynamic>.from(_summary!['summary'] as Map)
        : {};
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings & Settlements')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: ListTile(
                      title: const Text('Lifetime net earnings'),
                      trailing: Text('₹${summary['lifetimeNet'] ?? 0}'),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: const Text('Pending settlement'),
                      trailing: Text('₹${summary['pendingSettlement'] ?? 0}'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ..._items.map(
                    (item) => Card(
                      child: ListTile(
                        title: Text(
                          'Order #${item['orderId'] ?? item['id'] ?? '-'}',
                        ),
                        subtitle: Text(item['status']?.toString() ?? 'PENDING'),
                        trailing: Text('₹${item['netAmount'] ?? 0}'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
