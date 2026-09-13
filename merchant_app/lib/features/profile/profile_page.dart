import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/merchant_state_view.dart';
import '../../core/config/app_branding.dart';
import '../../core/network/api_client.dart';
import '../store/store_api_service.dart';

class MerchantProfilePage extends StatefulWidget {
  const MerchantProfilePage({super.key});

  @override
  State<MerchantProfilePage> createState() => _MerchantProfilePageState();
}

class _MerchantProfilePageState extends State<MerchantProfilePage> {
  final _apiClient = ApiClient();
  final _storeApiService = StoreApiService();
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _store;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userResponse = await _apiClient.get('/auth/me');
      final store = await _storeApiService.getStore();
      final data = Map<String, dynamic>.from(userResponse.data as Map);
      if (!mounted) return;
      setState(() {
        _user = data['user'] is Map
            ? Map<String, dynamic>.from(data['user'] as Map)
            : {};
        _store = store;
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

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: MerchantLoadingView());
    if (_error != null) {
      return Scaffold(
        body: Center(child: Text(_error!, textAlign: TextAlign.center)),
      );
    }

    final email = FirebaseAuth.instance.currentUser?.email ?? 'Not available';
    final storeName = _store?['name']?.toString() ?? 'Not configured';
    final zone = _store?['zoneId']?.toString() ?? 'Not assigned';
    final isOpen = _store?['isOpen'] == true;
    final supportPhone = AppBrandingController.instance.branding.supportPhone;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Merchant Account',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          _InfoCard(
            label: 'Name',
            value: _user?['name']?.toString() ?? 'Not available',
          ),
          _InfoCard(label: 'Email', value: email),
          _InfoCard(
            label: 'Role',
            value: _user?['role']?.toString() ?? 'MERCHANT',
          ),
          _InfoCard(
            label: 'Account status',
            value: _user?['status']?.toString() ?? 'ACTIVE',
          ),
          const SizedBox(height: 20),
          Text(
            'Store',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _InfoCard(label: 'Store name', value: storeName),
          _InfoCard(label: 'Zone', value: zone),
          _InfoCard(label: 'Status', value: isOpen ? 'Open' : 'Closed'),
          if (supportPhone.isNotEmpty)
            _InfoCard(label: 'Support', value: supportPhone),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(title: Text(label), subtitle: Text(value)),
    );
  }
}
