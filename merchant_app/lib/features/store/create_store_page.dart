import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/config/app_branding.dart';
import 'store_api_service.dart';
import 'zone_api_service.dart';

class CreateStorePage extends StatefulWidget {
  const CreateStorePage({super.key, required this.onStoreCreated});

  final VoidCallback onStoreCreated;

  @override
  State<CreateStorePage> createState() => _CreateStorePageState();
}

class _CreateStorePageState extends State<CreateStorePage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();

  final _addressController = TextEditingController();

  final _minimumOrderController = TextEditingController(text: '199');

  final StoreApiService _storeApiService = StoreApiService();
  final ZoneApiService _zoneApiService = ZoneApiService();

  String _moduleId = 'food';
  LatLng? _selectedLocation;
  Map<String, dynamic>? _resolvedZone;

  bool _isSaving = false;
  bool _isGettingLocation = false;
  bool _resolvingLocation = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _minimumOrderController.dispose();
    super.dispose();
  }

  Future<void> _createStore() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the store location')),
      );
      return;
    }

    if (_resolvedZone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected location is not serviceable')),
      );
      return;
    }

    try {
      setState(() {
        _isSaving = true;
      });

      await _storeApiService.createStore(
        name: _nameController.text.trim(),
        moduleId: _moduleId,
        zoneId: _resolvedZone!['id'].toString(),
        address: _addressController.text.trim(),
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        minimumOrder: double.tryParse(_minimumOrderController.text) ?? 0,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store created successfully')),
      );

      widget.onStoreCreated();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to create store: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      setState(() {
        _isGettingLocation = true;
      });

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required');
      }

      final position = await Geolocator.getCurrentPosition();
      await _setLocation(LatLng(position.latitude, position.longitude));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to get location: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  Future<void> _setLocation(LatLng location) async {
    setState(() {
      _selectedLocation = location;
      _resolvedZone = null;
      _resolvingLocation = true;
    });

    try {
      final zone = await _zoneApiService.resolveZone(
        latitude: location.latitude,
        longitude: location.longitude,
      );

      if (!mounted) return;

      if (zone == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This location is outside the service area'),
          ),
        );
        return;
      }

      setState(() {
        _resolvedZone = zone;
      });

      final placemarks = await Geocoding().placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isEmpty) return;

      final place = placemarks.first;
      final parts =
          <String?>[
                place.name,
                place.street,
                place.subLocality,
                place.locality,
                place.administrativeArea,
                place.postalCode,
              ]
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList();

      if (parts.isNotEmpty && mounted) {
        _addressController.text = parts.join(', ');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to resolve this location: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _resolvingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Store')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Store details',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Add the information customers will see.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Store location',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Container(
              height: 220,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E8E8)),
              ),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selectedLocation ?? const LatLng(17.3850, 78.4867),
                  zoom: _selectedLocation == null ? 11 : 16,
                ),
                markers: _selectedLocation == null
                    ? {}
                    : {
                        Marker(
                          markerId: const MarkerId('store'),
                          position: _selectedLocation!,
                        ),
                      },
                onTap: _setLocation,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isGettingLocation ? null : _useCurrentLocation,
              icon: _isGettingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: const Text('Use Current Location'),
            ),
            if (_resolvingLocation)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_resolvedZone != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_resolvedZone!['name']} • '
                        '${_resolvedZone!['city']}',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Store Name'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Store name is required';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _moduleId,
              decoration: const InputDecoration(labelText: 'Module'),
              items: const [
                DropdownMenuItem(value: 'food', child: Text('Food')),
                DropdownMenuItem(value: 'grocery', child: Text('Grocery')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _moduleId = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Store Address'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Store address is required';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _minimumOrderController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Minimum Order Amount',
                prefixText:
                    '${AppBrandingController.instance.branding.currencySymbol} ',
              ),
            ),

            const SizedBox(height: 24),

            FilledButton(
              onPressed: _isSaving ? null : _createStore,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Store'),
            ),
          ],
        ),
      ),
    );
  }
}
