import 'package:flutter/material.dart';

import '../../core/config/app_branding.dart';
import 'menu_page.dart';
import 'stores_api_service.dart';

class RestaurantsPage extends StatefulWidget {
  const RestaurantsPage({
    super.key,
    required this.zoneId,
    this.moduleId = 'food',
    this.category,
  });

  final String zoneId;
  final String moduleId;
  final String? category;

  @override
  State<RestaurantsPage> createState() => _RestaurantsPageState();
}

class _RestaurantsPageState extends State<RestaurantsPage> {
  final StoresApiService _apiService = StoresApiService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _stores = [];

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final stores = await _apiService.getStores(
        moduleId: widget.moduleId,
        zoneId: widget.zoneId,
        category: widget.category,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _stores = stores;
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load stores: $error');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _stores = [];
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.category?.isNotEmpty == true
              ? '${widget.category} near you'
              : widget.moduleId == 'grocery'
              ? 'Grocery Stores'
              : 'Restaurants',
        ),
      ),
      body: RefreshIndicator(onRefresh: _loadStores, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.error_outline, size: 56),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Unable to load stores',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text(_error!, textAlign: TextAlign.center)),
          const SizedBox(height: 20),
          FilledButton(onPressed: _loadStores, child: const Text('Retry')),
        ],
      );
    }

    if (_stores.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Icon(Icons.storefront_outlined, size: 64),
          SizedBox(height: 16),
          Center(
            child: Text(
              'No stores available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _stores.length,
      itemBuilder: (context, index) {
        final store = _stores[index];

        final storeId = store['id']?.toString() ?? '';

        final name = store['name']?.toString() ?? 'Store';

        final address = store['address']?.toString() ?? '';

        final imageUrl = store['imageUrl']?.toString();

        final ratingAverage = store['ratingAverage'] is num
            ? (store['ratingAverage'] as num).toDouble()
            : 0.0;

        final ratingCount = store['ratingCount'] is num
            ? (store['ratingCount'] as num).toInt()
            : 0;

        final minimumOrder = _toNumber(store['minimumOrder']);

        final isOpen = store['isOpen'] == true;

        final currencySymbol =
            AppBrandingController.instance.branding.currencySymbol;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: !isOpen || storeId.isEmpty
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MenuPage(
                          storeId: storeId,
                          storeName: name,
                          storeAddress: address,
                          storeImageUrl: imageUrl ?? '',
                          storeRating: ratingAverage,
                          ratingCount: ratingCount,
                        ),
                      ),
                    );
                  },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  child: const Icon(Icons.storefront_outlined),
                                );
                              },
                            )
                          : Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: const Icon(Icons.storefront_outlined),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (address.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 9,
                              color: isOpen ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isOpen ? 'Open' : 'Currently closed',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isOpen ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        if (minimumOrder > 0) ...[
                          const SizedBox(height: 5),
                          Text(
                            'Minimum order $currencySymbol${_formatAmount(minimumOrder)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: isOpen ? null : Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  num _toNumber(dynamic value) {
    if (value is num) {
      return value;
    }

    if (value is String) {
      return num.tryParse(value) ?? 0;
    }

    return 0;
  }

  String _formatAmount(num value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}
