import 'package:flutter/material.dart';

import '../orders/orders_page.dart';
import 'notifications_api_service.dart';

class DeliveryNotificationsPage extends StatefulWidget {
  const DeliveryNotificationsPage({super.key});
  @override
  State<DeliveryNotificationsPage> createState() =>
      _DeliveryNotificationsPageState();
}

class _DeliveryNotificationsPageState extends State<DeliveryNotificationsPage> {
  final _service = NotificationsApiService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final items = await _service.getNotifications();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _markAll() async {
    await _service.markAllRead();
    if (mounted) {
      setState(() {
        for (final item in _items) {
          item['isRead'] = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        if (_items.any((item) => item['isRead'] != true))
          TextButton(onPressed: _markAll, child: const Text('Mark all read')),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: FilledButton(onPressed: _load, child: const Text('Retry')),
          )
        : _items.isEmpty
        ? const Center(child: Text('No notifications yet'))
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final data = item['data'] is Map
                    ? Map<String, dynamic>.from(item['data'] as Map)
                    : <String, dynamic>{};
                final type = data['type']?.toString();
                return Card(
                  color: item['isRead'] == true
                      ? null
                      : Theme.of(context).colorScheme.primaryContainer,
                  child: ListTile(
                    isThreeLine: true,
                    onTap: () async {
                      final id = item['id']?.toString();
                      if (id != null) await _service.markRead(id);
                      if (type == 'NEW_DELIVERY' ||
                          type == 'DELIVERY_STATUS_CHANGED') {
                        if (context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DeliveryOrdersPage(),
                            ),
                          );
                        }
                      } else if (mounted) {
                        setState(() => item['isRead'] = true);
                      }
                    },
                    title: Text(item['title']?.toString() ?? 'Notification'),
                    subtitle: Text(item['body']?.toString() ?? ''),
                    trailing: item['isRead'] == true
                        ? null
                        : const Icon(Icons.circle, size: 10),
                  ),
                );
              },
            ),
          ),
  );
}
