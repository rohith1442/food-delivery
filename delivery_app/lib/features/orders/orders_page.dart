import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'delivery_orders_api_service.dart';
import '../../core/config/app_branding.dart';

class DeliveryOrdersPage extends StatefulWidget {
  const DeliveryOrdersPage({super.key});

  @override
  State<DeliveryOrdersPage> createState() => _DeliveryOrdersPageState();
}

class _DeliveryOrdersPageState extends State<DeliveryOrdersPage> {
  final DeliveryOrdersApiService _ordersApiService = DeliveryOrdersApiService();

  List<Map<String, dynamic>> orders = [];

  bool _isLoading = true;
  String? _error;
  String? _updatingOrderId;

  List<Map<String, dynamic>> get _availableOrders =>
      orders.where((order) => order['status'] == 'READY').toList();
  List<Map<String, dynamic>> get _activeOrders =>
      orders.where((order) => order['status'] != 'READY').toList();

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await _ordersApiService.getOrders();

      if (!mounted) return;

      setState(() {
        orders = response;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptOrder(String orderId) async {
    await _executeOrderAction(
      orderId,
      () => _ordersApiService.acceptOrder(orderId),
      'Order accepted',
    );
  }

  Future<void> _updateStatus(String orderId, String status) async {
    await _executeOrderAction(
      orderId,
      () => _ordersApiService.updateStatus(orderId: orderId, status: status),
      _successMessage(status),
    );
  }

  Future<void> _executeOrderAction(
    String orderId,
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      setState(() {
        _updatingOrderId = orderId;
      });

      await action();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));

      await _loadOrders();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to update order: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _updatingOrderId = null;
        });
      }
    }
  }

  Future<void> _completeDelivery(String orderId) async {
    final otpController = TextEditingController();

    try {
      setState(() {
        _updatingOrderId = orderId;
      });

      final generatedOtp = await _ordersApiService.generateDeliveryOtp(orderId);

      if (!mounted) return;

      final shouldVerify = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Verify Delivery OTP'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ask the customer for their 4-digit OTP, then enter it here.',
                ),
                const SizedBox(height: 12),

                // DEVELOPMENT ONLY.
                // Remove after SMS integration.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    generatedOtp == null
                        ? 'OTP sent to customer'
                        : 'Development OTP: $generatedOtp',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Delivery OTP',
                    hintText: 'Enter 4-digit OTP',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final otp = otpController.text.trim();

                  if (otp.length != 4) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Enter a valid 4-digit OTP'),
                      ),
                    );

                    return;
                  }

                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Verify'),
              ),
            ],
          );
        },
      );

      if (shouldVerify != true) {
        return;
      }

      final otp = otpController.text.trim();

      await _ordersApiService.verifyDeliveryOtp(orderId: orderId, otp: otp);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery completed successfully')),
      );

      await _loadOrders();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to complete delivery: $error')),
      );
    } finally {
      otpController.dispose();

      if (mounted) {
        setState(() {
          _updatingOrderId = null;
        });
      }
    }
  }

  String _successMessage(String status) {
    switch (status) {
      case 'PICKED_UP':
        return 'Order marked as picked up';

      case 'ON_THE_WAY':
        return 'Delivery started';

      default:
        return 'Order updated';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deliveries')),
      body: RefreshIndicator(onRefresh: _loadOrders, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.error_outline, size: 52),
          const SizedBox(height: 16),
          const Text(
            'Unable to load deliveries',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Center(
            child: FilledButton(
              onPressed: _loadOrders,
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (orders.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 120),
          Icon(Icons.delivery_dining_outlined, size: 64),
          SizedBox(height: 16),
          Text(
            'No deliveries available',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Orders will appear here once the merchant marks them ready.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final visibleOrders = [..._activeOrders, ..._availableOrders];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visibleOrders.length,
      itemBuilder: (context, index) {
        final order = visibleOrders[index];

        final orderId = order['id']?.toString() ?? '';

        return _DeliveryCard(
          order: order,
          allowAccept: _activeOrders.isEmpty,
          isUpdating: _updatingOrderId == orderId,
          onAccept: () {
            _acceptOrder(orderId);
          },
          onUpdateStatus: (status) {
            _updateStatus(orderId, status);
          },
          onCompleteDelivery: () {
            _completeDelivery(orderId);
          },
        );
      },
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.order,
    required this.allowAccept,
    required this.onAccept,
    required this.onUpdateStatus,
    required this.onCompleteDelivery,
    required this.isUpdating,
  });

  final Map<String, dynamic> order;
  final bool allowAccept;

  final VoidCallback onAccept;

  final ValueChanged<String> onUpdateStatus;

  final VoidCallback onCompleteDelivery;

  final bool isUpdating;

  Future<void> _openNavigation(
    BuildContext context, {
    required dynamic latitude,
    required dynamic longitude,
  }) async {
    final lat = double.tryParse(latitude?.toString() ?? '');

    final lng = double.tryParse(longitude?.toString() ?? '');

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location coordinates are unavailable')),
      );

      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$lat,$lng'
      '&travelmode=driving',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open navigation')),
        );
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open navigation')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderId = order['id']?.toString() ?? '-';

    final status = order['status']?.toString() ?? '';

    final storeLocation = order['storeLocation'] as Map<dynamic, dynamic>?;

    final newDeliveryAddress =
        order['deliveryAddress'] as Map<dynamic, dynamic>?;

    final legacyAddress = order['address'] as Map<dynamic, dynamic>?;

    final addressLine =
        newDeliveryAddress?['address']?.toString().trim() ??
        legacyAddress?['address']?.toString().trim() ??
        '';

    final addressLabel =
        newDeliveryAddress?['label']?.toString().trim() ??
        legacyAddress?['type']?.toString().trim() ??
        '';

    final addressDetails = legacyAddress?['details']?.toString().trim() ?? '';

    final deliveryAddress = [
      if (addressLabel.isNotEmpty) addressLabel,
      addressLine,
      addressDetails,
    ].where((value) => value.trim().isNotEmpty).join('\n');

    final displayDeliveryAddress = deliveryAddress.isEmpty
        ? 'Address unavailable'
        : deliveryAddress;

    final storeLatitude = storeLocation?['latitude'];

    final storeLongitude = storeLocation?['longitude'];

    final customerLatitude = newDeliveryAddress?['latitude'];

    final customerLongitude = newDeliveryAddress?['longitude'];

    final items = order['items'] as List<dynamic>? ?? [];

    final total = order['total']?.toString() ?? '0';

    final storeName = order['storeName']?.toString() ?? 'Store';

    final storeAddress =
        order['storeAddress']?.toString() ?? 'Pickup address unavailable';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #${_shortOrderId(orderId)}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${AppBrandingController.instance.branding.currencySymbol}$total',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              '${items.length} item(s)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 12),

            _LocationRow(
              icon: Icons.storefront_outlined,
              label: 'Pickup',
              location: '$storeName\n$storeAddress',
            ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: storeLatitude != null && storeLongitude != null
                    ? () {
                        _openNavigation(
                          context,
                          latitude: storeLatitude,
                          longitude: storeLongitude,
                        );
                      }
                    : null,
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Navigate to Pickup'),
              ),
            ),

            const SizedBox(height: 12),

            _LocationRow(
              icon: Icons.location_on_outlined,
              label: 'Drop',
              location: displayDeliveryAddress,
            ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: customerLatitude != null && customerLongitude != null
                    ? () {
                        _openNavigation(
                          context,
                          latitude: customerLatitude,
                          longitude: customerLongitude,
                        );
                      }
                    : null,
                icon: const Icon(Icons.navigation),
                label: const Text('Navigate to Customer'),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              _statusLabel(status),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 16),

            _DeliveryProgress(status: status),

            const SizedBox(height: 16),

            if (isUpdating)
              const SizedBox(
                width: double.infinity,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              _buildActionButton(status),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String status) {
    if (status == 'READY') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: allowAccept ? onAccept : null,
          child: Text(
            allowAccept ? 'Accept Delivery' : 'Finish current delivery first',
          ),
        ),
      );
    }

    if (status == 'RIDER_ASSIGNED') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () {
            onUpdateStatus('PICKED_UP');
          },
          child: const Text('Mark Picked Up'),
        ),
      );
    }

    if (status == 'PICKED_UP') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () {
            onUpdateStatus('ON_THE_WAY');
          },
          child: const Text('Start Delivery'),
        ),
      );
    }

    if (status == 'ON_THE_WAY') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onCompleteDelivery,
          child: const Text('Complete Delivery'),
        ),
      );
    }

    if (status == 'DELIVERED') {
      return const SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: null,
          child: Text('Delivery Completed'),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'READY':
        return 'Ready for pickup';

      case 'RIDER_ASSIGNED':
        return 'Accepted';

      case 'PICKED_UP':
        return 'Picked Up';

      case 'ON_THE_WAY':
        return 'On The Way';

      case 'DELIVERED':
        return 'Delivered';

      default:
        return status;
    }
  }

  static String _shortOrderId(String orderId) {
    if (orderId.length <= 8) {
      return orderId;
    }

    return orderId.substring(0, 8);
  }
}

class _DeliveryProgress extends StatelessWidget {
  const _DeliveryProgress({required this.status});
  final String status;
  static const steps = [
    'RIDER_ASSIGNED',
    'PICKED_UP',
    'ON_THE_WAY',
    'DELIVERED',
  ];
  @override
  Widget build(BuildContext context) {
    if (status == 'READY') return const SizedBox.shrink();
    final current = steps.indexOf(status);
    const labels = ['Accepted', 'Picked up', 'On the way', 'Delivered'];
    return Column(
      children: List.generate(steps.length, (index) {
        final completed = index <= current;
        final color = completed
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline;
        return Row(
          children: [
            Column(
              children: [
                Icon(
                  completed ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 22,
                  color: color,
                ),
                if (index != steps.length - 1)
                  Container(
                    width: 2,
                    height: 22,
                    color: completed
                        ? color
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Text(
                labels[index],
                style: TextStyle(
                  fontWeight: completed ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.label,
    required this.location,
  });

  final IconData icon;
  final String label;
  final String location;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Text(location)),
      ],
    );
  }
}
