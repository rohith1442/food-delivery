import 'package:flutter/material.dart';

import 'earnings_api_service.dart';
import '../../core/config/app_branding.dart';

class MerchantEarningsPage extends StatefulWidget {
  const MerchantEarningsPage({super.key});
  @override
  State<MerchantEarningsPage> createState() => _MerchantEarningsPageState();
}

class _MerchantEarningsPageState extends State<MerchantEarningsPage> {
  final _api = EarningsApiService();
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _items = [];
  int _selectedDays = 7;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await Future.wait([
        _api.getSummary(days: _selectedDays),
        _api.getTransactions(days: _selectedDays),
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

  String _money(dynamic value, String currency) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return '$currency${amount.toStringAsFixed(0)}';
  }

  Widget _metric(String label, dynamic value, String currency) => Card(
    child: ListTile(
      title: Text(label),
      trailing: Text(_money(value, currency)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final currency = AppBrandingController.instance.branding.currencySymbol;
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
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 7, label: Text('7 Days')),
                      ButtonSegment(value: 30, label: Text('30 Days')),
                    ],
                    selected: {_selectedDays},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _selectedDays = selection.first;
                        _loading = true;
                      });
                      _load();
                    },
                  ),
                  const SizedBox(height: 12),
                  _metric('Net earnings', summary['net'], currency),
                  _metric('Gross earnings', summary['gross'], currency),
                  _metric('Commission', summary['commission'], currency),
                  _metric('Paid', summary['paid'], currency),
                  _metric(
                    'Pending settlement',
                    summary['pendingSettlement'],
                    currency,
                  ),
                  _metric('On hold', summary['onHold'], currency),
                  const SizedBox(height: 20),
                  ..._items.map(
                    (item) => Card(
                      child: ListTile(
                        title: Text(
                          'Order #${item['orderId'] ?? item['id'] ?? '-'}',
                        ),
                        subtitle: Text(item['status']?.toString() ?? 'PENDING'),
                        trailing: Text('$currency${item['netAmount'] ?? 0}'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
