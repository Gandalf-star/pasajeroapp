import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class VistaMapa extends StatelessWidget {
  final void Function(GoogleMapController)? onMapCreated;
  final Position posicionActual;
  final Set<Marker> marcadoresConductores;
  final VoidCallback? onMyLocationTap;

  const VistaMapa({
    super.key,
    this.onMapCreated,
    required this.posicionActual,
    required this.marcadoresConductores,
    this.onMyLocationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(posicionActual.latitude, posicionActual.longitude),
            zoom: 15.0,
          ),
          onMapCreated: onMapCreated,
          markers: {
            ...marcadoresConductores,
            Marker(
              markerId: const MarkerId('posicion_actual'),
              position:
                  LatLng(posicionActual.latitude, posicionActual.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue),
            ),
          },
          myLocationEnabled:
              false, // Lo dibujamos manual o con el marker arriba
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapType: MapType.normal,
        ),
        Positioned(
          bottom: 220,
          right: 20,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.teal.shade600,
                  Colors.blue.shade500,
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onMyLocationTap,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
