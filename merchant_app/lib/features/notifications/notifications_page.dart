import 'package:flutter/material.dart';

import '../orders/orders_page.dart';
import 'notifications_api_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _service = NotificationsApiService();
  List<Map<String, dynamic>> _notifications = [];
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
      final notifications = await _service.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    await _service.markAllRead();
    if (!mounted) return;
    setState(() {
      _notifications = _notifications
          .map((notification) => {...notification, 'isRead': true})
          .toList();
    });
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    final id = notification['id']?.toString();
    if (id != null && id.isNotEmpty && notification['isRead'] != true) {
      await _service.markRead(id);
      if (mounted) {
        setState(() {
          notification['isRead'] = true;
        });
      }
    }

    final data = notification['data'];
    if (data is Map && data['type']?.toString() == 'NEW_ORDER' && mounted) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const MerchantOrdersPage()));
    }
  }

  String _timeAgo(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes} min ago';
    if (difference.inDays < 1) return '${difference.inHours} hr ago';
    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _notifications.any((item) => item['isRead'] != true)
                ? _markAllRead
                : null,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, textAlign: TextAlign.center))
          : _notifications.isEmpty
          ? const Center(child: Text('No notifications yet'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  final unread = notification['isRead'] != true;
                  return Card(
                    child: ListTile(
                      onTap: () => _openNotification(notification),
                      leading: Icon(
                        unread
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_none_outlined,
                      ),
                      title: Text(
                        notification['title']?.toString() ?? 'Notification',
                        style: TextStyle(
                          fontWeight: unread
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notification['body']?.toString() ?? ''),
                          const SizedBox(height: 4),
                          Text(_timeAgo(notification['createdAt'])),
                        ],
                      ),
                      trailing: unread
                          ? const Icon(Icons.circle, size: 10)
                          : null,
                    ),
                  );
                },
              ),
            ),
    );
  }
}
