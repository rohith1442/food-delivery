import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapTestPage extends StatelessWidget {
  const MapTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    const initialPosition = CameraPosition(
      target: LatLng(17.3850, 78.4867),
      zoom: 14,
    );

    return const Scaffold(
      body: GoogleMap(
        initialCameraPosition: initialPosition,
        zoomControlsEnabled: true,
        myLocationButtonEnabled: false,
      ),
    );
  }
}