import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const LatLng _fallbackLocation = LatLng(17.3850, 78.4867);

  final geocoding.Geocoding _geocoder = geocoding.Geocoding();

  GoogleMapController? _mapController;

  LatLng _selectedLocation = _fallbackLocation;

  String _address = 'Move the map to select your location';

  bool _loadingLocation = true;
  bool _resolvingAddress = false;
  bool _locationPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    if (mounted) {
      setState(() {
        _loadingLocation = true;
      });
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }

        setState(() {
          _loadingLocation = false;
        });

        _showMessage('Please enable location services.');

        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) {
          return;
        }

        setState(() {
          _loadingLocation = false;
          _locationPermissionGranted = false;
        });

        _showMessage('Location permission is required.');

        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }

        setState(() {
          _loadingLocation = false;
          _locationPermissionGranted = false;
        });

        _showMessage(
          'Location permission is permanently denied. '
          'Please enable it from Settings.',
        );

        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _locationPermissionGranted = true;
      });

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final location = LatLng(position.latitude, position.longitude);

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedLocation = location;
        _loadingLocation = false;
      });

      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: location, zoom: 17),
          ),
        );
      }

      await _resolveAddress(location);
    } catch (error) {
      debugPrint('Unable to get current location: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingLocation = false;
      });

      _showMessage('Unable to get your current location.');
    }
  }

  Future<void> _resolveAddress(LatLng location) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _resolvingAddress = true;
    });

    try {
      final placemarks = await _geocoder.placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (!mounted) {
        return;
      }

      if (placemarks.isEmpty) {
        setState(() {
          _address = 'Selected location';
          _resolvingAddress = false;
        });

        return;
      }

      final place = placemarks.first;

      final parts = <String?>[
        place.name,
        place.street,
        place.subLocality,
        place.locality,
        place.administrativeArea,
        place.postalCode,
      ];

      final address = parts
          .where((part) => part != null && part.trim().isNotEmpty)
          .map((part) => part!.trim())
          .toSet()
          .join(', ');

      setState(() {
        _address = address.isEmpty ? 'Selected location' : address;

        _resolvingAddress = false;
      });
    } catch (error) {
      debugPrint('Reverse geocoding failed: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _address = 'Selected location';
        _resolvingAddress = false;
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _confirmLocation() {
    if (_resolvingAddress) {
      return;
    }

    Navigator.of(context).pop({
      'latitude': _selectedLocation.latitude,
      'longitude': _selectedLocation.longitude,
      'address': _address,
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Location')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _fallbackLocation,
              zoom: 14,
            ),
            myLocationEnabled: _locationPermissionGranted,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) async {
              _mapController = controller;

              if (_selectedLocation != _fallbackLocation) {
                await controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _selectedLocation, zoom: 17),
                  ),
                );
              }
            },
            onCameraMove: (position) {
              _selectedLocation = position.target;
            },
            onCameraIdle: () {
              _resolveAddress(_selectedLocation);
            },
          ),

          // Fixed center pin.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(Icons.location_pin, size: 48, color: Colors.red),
              ),
            ),
          ),

          // Current location button.
          Positioned(
            right: 16,
            bottom: 200,
            child: FloatingActionButton.small(
              heroTag: 'currentLocation',
              onPressed: _loadingLocation ? null : _loadCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Selected address.
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Delivery Location',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 8),

                      if (_resolvingAddress) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: 8),
                        const Text('Finding address...'),
                      ] else
                        Text(
                          _address,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _resolvingAddress
                              ? null
                              : _confirmLocation,
                          icon: const Icon(Icons.check),
                          label: const Text('Confirm Location'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_loadingLocation)
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
