import 'package:flutter/material.dart';

import 'content_api_service.dart';

class ContentPage extends StatefulWidget {
  const ContentPage({
    super.key,
    required this.type,
    required this.fallbackTitle,
  });
  final String type, fallbackTitle;
  @override
  State<ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends State<ContentPage> {
  final _service = ContentApiService();
  Map<String, dynamic>? _content;
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final content = await _service.getContent(widget.type);
      if (mounted) {
        setState(() {
          _content = content;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load this page.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _content?['title']?.toString() ?? widget.fallbackTitle;
    final enabled = _content?['isEnabled'] != false;
    final version = _content?['version']?.toString() ?? '';
    final text = _content?['content']?.toString() ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: FilledButton(onPressed: _load, child: const Text('Retry')),
            )
          : !enabled
          ? const Center(
              child: Text('This information is currently unavailable.'),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (version.isNotEmpty) Text('Version $version'),
                const SizedBox(height: 24),
                SelectableText(
                  text.isEmpty ? 'Content has not been configured yet.' : text,
                  style: const TextStyle(fontSize: 15, height: 1.6),
                ),
              ],
            ),
    );
  }
}
