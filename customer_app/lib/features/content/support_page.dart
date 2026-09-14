import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'content_api_service.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});
  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final _service = ContentApiService();
  Map<String, dynamic>? _support;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _service.getContent('support');
      if (mounted) {
        setState(() {
          _support = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this option')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final support = _support ?? {};
    final phone = support['phone']?.toString() ?? '';
    final email = support['email']?.toString() ?? '';
    final whatsapp = support['whatsapp']?.toString() ?? '';
    final hours = support['workingHours']?.toString() ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Support')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if ((support['content']?.toString() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(support['content'].toString()),
            ),
          if (phone.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Call us'),
                subtitle: Text(phone),
                onTap: () => _open(Uri(scheme: 'tel', path: phone)),
              ),
            ),
          if (email.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Email us'),
                subtitle: Text(email),
                onTap: () => _open(Uri(scheme: 'mailto', path: email)),
              ),
            ),
          if (whatsapp.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.chat),
                title: const Text('WhatsApp'),
                subtitle: Text(whatsapp),
                onTap: () => _open(
                  Uri.parse(
                    'https://wa.me/${whatsapp.replaceAll(RegExp(r'[^0-9]'), '')}',
                  ),
                ),
              ),
            ),
          if (hours.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Support hours'),
                subtitle: Text(hours),
              ),
            ),
        ],
      ),
    );
  }
}
