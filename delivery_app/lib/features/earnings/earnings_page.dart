import 'package:flutter/material.dart';

import '../../core/config/app_branding.dart';
import 'earnings_api_service.dart';

class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key});

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  final _service = EarningsApiService();
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _transactions = [];
  int _selectedDays = 7;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getEarnings(days: _selectedDays);
      final summary = data['summary'];
      final transactions = data['transactions'];
      if (!mounted) return;
      setState(() {
        _summary = summary is Map
            ? Map<String, dynamic>.from(summary)
            : <String, dynamic>{};
        _transactions = (transactions as List<dynamic>? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
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
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 7, label: Text('7 Days')),
                      ButtonSegment(value: 30, label: Text('30 Days')),
                    ],
                    selected: {_selectedDays},
                    onSelectionChanged: (selection) {
                      setState(() => _selectedDays = selection.first);
                      _load();
                    },
                  ),
                  const SizedBox(height: 12),
                  _metric(
                    '$_selectedDays-day earnings',
                    _summary['net'],
                    currency,
                  ),
                  _metric(
                    'Completed deliveries',
                    _summary['totalTransactions'],
                    '',
                  ),
                  _metric('Gross earnings', _summary['gross'], currency),
                  _metric('Paid earnings', _summary['paid'], currency),
                  _metric(
                    'Pending payout',
                    _summary['pendingSettlement'],
                    currency,
                  ),
                  _metric('Processing', _summary['processing'], currency),
                  _metric('On hold', _summary['onHold'], currency),
                  const SizedBox(height: 24),
                  Text(
                    'Settlement history',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (_transactions.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(child: Text('No settlements yet')),
                      ),
                    ),
                  ..._transactions.map(
                    (item) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.two_wheeler_outlined),
                        title: Text('Order #${item['orderId'] ?? '-'}'),
                        subtitle: Text(item['status']?.toString() ?? 'PENDING'),
                        trailing: Text(_money(item['netAmount'], currency)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
