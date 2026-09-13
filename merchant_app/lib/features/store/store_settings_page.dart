import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/config/app_branding.dart';
import 'store_api_service.dart';
import 'zone_api_service.dart';

class StoreSettingsPage extends StatefulWidget {
  const StoreSettingsPage({super.key, required this.store});

  final Map<String, dynamic> store;

  @override
  State<StoreSettingsPage> createState() => _StoreSettingsPageState();
}

class _StoreSettingsPageState extends State<StoreSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _minimumOrderController = TextEditingController();
  final _storeApiService = StoreApiService();
  final _zoneApiService = ZoneApiService();

  late String _moduleId;
  late bool _isOpen;
  LatLng? _selectedLocation;
  Map<String, dynamic>? _resolvedZone;
  bool _resolvingLocation = false;
  bool _isGettingLocation = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.store['name']?.toString() ?? '';
    _addressController.text = widget.store['address']?.toString() ?? '';
    _minimumOrderController.text =
        widget.store['minimumOrder']?.toString() ?? '0';
    _moduleId = widget.store['moduleId']?.toString() ?? 'food';
    _isOpen = widget.store['isOpen'] == true;

    final latitude = (widget.store['latitude'] as num?)?.toDouble();
    final longitude = (widget.store['longitude'] as num?)?.toDouble();
    if (latitude != null && longitude != null) {
      _selectedLocation = LatLng(latitude, longitude);
      _resolveLocation(_selectedLocation!, updateAddress: false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _minimumOrderController.dispose();
    super.dispose();
  }

  Future<void> _resolveLocation(
    LatLng location, {
    bool updateAddress = true,
  }) async {
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

      setState(() => _resolvedZone = zone);
      if (!updateAddress) return;

      final placemarks = await Geocoding().placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (!mounted || placemarks.isEmpty) return;

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
      if (parts.isNotEmpty) _addressController.text = parts.join(', ');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to resolve this location: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _resolvingLocation = false);
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
      debugPrint(
        'Current location: ${position.latitude}, ${position.longitude}',
      );
      await _resolveLocation(LatLng(position.latitude, position.longitude));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to get current location: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null || _resolvedZone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a serviceable store location'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final storeId = widget.store['id'].toString();
      final updated = await _storeApiService.updateStore(
        storeId: storeId,
        data: {
          'name': _nameController.text.trim(),
          'moduleId': _moduleId,
          'zoneId': _resolvedZone!['id'],
          'address': _addressController.text.trim(),
          'latitude': _selectedLocation!.latitude,
          'longitude': _selectedLocation!.longitude,
          'minimumOrder': double.tryParse(_minimumOrderController.text) ?? 0,
        },
      );
      if (_isOpen != (widget.store['isOpen'] == true)) {
        await _storeApiService.updateStoreStatus(
          storeId: storeId,
          isOpen: _isOpen,
        );
        updated['isOpen'] = _isOpen;
      }
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save store settings: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = AppBrandingController.instance.branding.currencySymbol;
    final imageUrl = widget.store['imageUrl']?.toString() ?? '';
    final target = _selectedLocation ?? const LatLng(17.3850, 78.4867);

    return Scaffold(
      appBar: AppBar(title: const Text('Store settings')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  height: 170,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            if (imageUrl.isNotEmpty) const SizedBox(height: 18),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Store name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Store name is required'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _moduleId,
              decoration: const InputDecoration(labelText: 'Module'),
              items: const [
                DropdownMenuItem(value: 'food', child: Text('Food')),
                DropdownMenuItem(value: 'grocery', child: Text('Grocery')),
              ],
              onChanged: (value) =>
                  setState(() => _moduleId = value ?? _moduleId),
            ),
            const SizedBox(height: 18),
            Text(
              'Store location',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: target,
                    zoom: 15,
                  ),
                  markers: _selectedLocation == null
                      ? {}
                      : {
                          Marker(
                            markerId: const MarkerId('store'),
                            position: _selectedLocation!,
                          ),
                        },
                  onTap: _resolveLocation,
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                ),
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
            if (_resolvingLocation) const LinearProgressIndicator(minHeight: 2),
            if (_resolvedZone != null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${_resolvedZone!['name']} • ${_resolvedZone!['city']}',
                ),
              ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Address'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Store address is required'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _minimumOrderController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Minimum order',
                prefixText: '$currency ',
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Accept orders'),
              value: _isOpen,
              onChanged: (value) => setState(() => _isOpen = value),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
