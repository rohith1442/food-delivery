import 'package:flutter/material.dart';

import '../orders/order_details_page.dart';
import '../orders/orders_api_service.dart';
import 'notifications_api_service.dart';

class CustomerNotificationsPage extends StatefulWidget {
  const CustomerNotificationsPage({super.key});
  @override
  State<CustomerNotificationsPage> createState() =>
      _CustomerNotificationsPageState();
}

class _CustomerNotificationsPageState extends State<CustomerNotificationsPage> {
  final _service = NotificationsApiService();
  final _orders = OrdersApiService();
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
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load notifications';
          _loading = false;
        });
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _service.markAllRead();
      if (mounted) {
        setState(() {
          for (final item in _items) {
            item['isRead'] = true;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to mark notifications as read')),
        );
      }
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    if (id?.isNotEmpty == true) {
      try {
        await _service.markRead(id!);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => item['isRead'] = true);
    final raw = item['data'];
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final type = data['type']?.toString() ?? '';
    final orderId = data['orderId']?.toString() ?? '';
    if (!{
          'ORDER_STATUS_CHANGED',
          'DELIVERY_STATUS_CHANGED',
          'DELIVERY_OTP',
        }.contains(type) ||
        orderId.isEmpty) {
      return;
    }
    try {
      final response = await _orders.getOrder(orderId);
      final rawOrder = response['order'];
      final order = rawOrder is Map
          ? Map<String, dynamic>.from(rawOrder)
          : response;
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OrderDetailsPage(order: order)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unable to open order')));
      }
    }
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  IconData _icon(Map<String, dynamic> item) {
    final data = item['data'];
    final type = data is Map ? data['type']?.toString() : null;
    switch (type) {
      case 'DELIVERY_OTP':
        return Icons.password_outlined;
      case 'DELIVERY_STATUS_CHANGED':
        return Icons.delivery_dining_outlined;
      case 'ORDER_STATUS_CHANGED':
        return Icons.receipt_long_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.any((item) => item['isRead'] != true);
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: FilledButton(onPressed: _load, child: const Text('Retry')),
      );
    } else if (_items.isEmpty) {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 180),
            Center(child: Text('No notifications yet')),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final item = _items[index];
            final isUnread = item['isRead'] != true;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isUnread
                    ? Theme.of(context).colorScheme.primary
                          .withValues(alpha: 0.06)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isUnread
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade200,
                ),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () => _open(item),
                leading: CircleAvatar(child: Icon(_icon(item))),
                title: Text(
                  item['title']?.toString() ?? 'Notification',
                  style: TextStyle(
                    fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${item['body']?.toString() ?? ''}\n${_date(item['createdAt'])}',
                ),
                trailing: isUnread
                    ? Icon(
                        Icons.circle,
                        size: 9,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
            );
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: body,
    );
  }
}
