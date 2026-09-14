import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_branding.dart';
import '../../core/network/api_client.dart';

class DeliveryProfilePage extends StatefulWidget {
  const DeliveryProfilePage({super.key});
  @override
  State<DeliveryProfilePage> createState() => _DeliveryProfilePageState();
}

class _DeliveryProfilePageState extends State<DeliveryProfilePage> {
  final _api = ApiClient();
  Map<String, dynamic>? _user, _profile;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final responses = await Future.wait([
        _api.get('/auth/me'),
        _api.get('/delivery/profile'),
      ]);
      if (!mounted) return;
      final auth = Map<String, dynamic>.from(responses[0].data as Map);
      final profile = Map<String, dynamic>.from(responses[1].data as Map);
      setState(() {
        _user = auth['user'] is Map
            ? Map<String, dynamic>.from(auth['user'] as Map)
            : null;
        _profile = profile['profile'] is Map
            ? Map<String, dynamic>.from(profile['profile'] as Map)
            : null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branding = AppBrandingController.instance.branding;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                const CircleAvatar(
                  radius: 42,
                  child: Icon(Icons.delivery_dining, size: 44),
                ),
                const SizedBox(height: 16),
                Text(
                  _user?['name']?.toString() ?? 'Delivery Partner',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  FirebaseAuth.instance.currentUser?.email ?? '',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Account status'),
                        trailing: Text(_user?['status']?.toString() ?? '-'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Delivery zone'),
                        trailing: Text(
                          _profile?['zoneId']?.toString() ?? 'Not configured',
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Availability'),
                        trailing: Text(
                          _profile?['isOnline'] == true ? 'Online' : 'Offline',
                        ),
                      ),
                    ],
                  ),
                ),
                if (branding.supportPhone.isNotEmpty)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.support_agent),
                      title: const Text('Support'),
                      subtitle: Text(branding.supportPhone),
                    ),
                  ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ],
            ),
    );
  }
}
