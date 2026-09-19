import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'addresses_api_service.dart';

class SavedAddressesPage extends StatefulWidget {
  const SavedAddressesPage({super.key});

  @override
  State<SavedAddressesPage> createState() => _SavedAddressesPageState();
}

class _SavedAddressesPageState extends State<SavedAddressesPage> {
  final AddressesApiService _addressesApiService = AddressesApiService();

  List<CustomerAddress> _addresses = [];

  bool _loading = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final addresses = await _addressesApiService.getAddresses();

      if (!mounted) {
        return;
      }

      setState(() {
        _addresses = addresses;
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load addresses: $error');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      _showMessage('Unable to load saved addresses.');
    }
  }

  Future<void> _selectAddress(CustomerAddress address) async {
    if (_processing) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      if (!address.isDefault) {
        await _addressesApiService.setDefaultAddress(address.id);
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(address);
    } catch (error, stackTrace) {
      debugPrint('Failed to select address: $error');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      _showMessage('Unable to select this address.');
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _addAddress() async {
    if (_processing) {
      return;
    }

    final result = await context.push<Map<String, dynamic>>('/location');

    if (result == null || !mounted) {
      return;
    }

    final address = result['address']?.toString().trim();

    final latitude = _toDouble(result['latitude']);

    final longitude = _toDouble(result['longitude']);

    if (address == null ||
        address.isEmpty ||
        latitude == null ||
        longitude == null) {
      _showMessage('Unable to read the selected location.');

      return;
    }

    final details = await _showAddressDetails();

    if (details == null || !mounted) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      final savedAddress = await _addressesApiService.createAddress(
        label: details['label']!,
        contactName: details['name']!,
        contactPhone: details['phone']!,
        address: address,
        latitude: latitude,
        longitude: longitude,
      );

      if (!savedAddress.isDefault) {
        await _addressesApiService.setDefaultAddress(savedAddress.id);
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(savedAddress);
    } catch (error, stackTrace) {
      debugPrint('Failed to add address: $error');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to save this address. '
        'Please check that we deliver to this location.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<Map<String, String>?> _showAddressDetails() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    var label = 'Home';

    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Save delivery address',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Contact name'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    prefixText: '+91 ',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 18),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'Home',
                      label: Text('Home'),
                      icon: Icon(Icons.home_outlined),
                    ),
                    ButtonSegment(
                      value: 'Work',
                      label: Text('Work'),
                      icon: Icon(Icons.work_outline),
                    ),
                    ButtonSegment(
                      value: 'Other',
                      label: Text('Other'),
                      icon: Icon(Icons.location_on_outlined),
                    ),
                  ],
                  selected: {label},
                  onSelectionChanged: (values) {
                    setModalState(() => label = values.first);
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () {
                      final name = nameController.text.trim();
                      final phone = phoneController.text.trim();
                      if (name.isEmpty || phone.length != 10) return;
                      Navigator.of(context)
                          .pop({'name': name, 'phone': phone, 'label': label});
                    },
                    child: const Text('Save Address'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteAddress(CustomerAddress address) async {
    if (_processing) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete address?'),
          content: Text('Remove "${address.label}" from your saved addresses?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      await _addressesApiService.deleteAddress(address.id);

      if (!mounted) {
        return;
      }

      await _loadAddresses();
    } catch (error, stackTrace) {
      debugPrint('Failed to delete address: $error');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      _showMessage('Unable to delete address.');
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  IconData _getAddressIcon(String label) {
    switch (label.toLowerCase()) {
      case 'home':
        return Icons.home_outlined;

      case 'work':
        return Icons.work_outline;

      default:
        return Icons.location_on_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Addresses')),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadAddresses,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_addresses.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Column(
                            children: [
                              Icon(Icons.location_off_outlined, size: 56),
                              SizedBox(height: 16),
                              Text(
                                'No saved addresses',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Add a delivery address to get started.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                      for (final address in _addresses)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: address.isDefault
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              _selectAddress(address);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    foregroundColor: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    child: Icon(_getAddressIcon(address.label)),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              address.label,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            if (address.isDefault) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: const Text(
                                                  'Default',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          address.address,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: _processing
                                        ? null
                                        : () {
                                            _deleteAddress(address);
                                          },
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 8),

                      OutlinedButton.icon(
                        onPressed: _processing ? null : _addAddress,
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Add new address'),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
          ),

          if (_processing)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
