import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class PantallaSeleccionDestino extends StatefulWidget {
  final LatLng ubicacionInicial;

  const PantallaSeleccionDestino({
    super.key,
    required this.ubicacionInicial,
  });

  @override
  State<PantallaSeleccionDestino> createState() =>
      _PantallaSeleccionDestinoState();
}

class _PantallaSeleccionDestinoState extends State<PantallaSeleccionDestino> {
  GoogleMapController? _mapController;
  LatLng? _destinoSeleccionado;

  // Nombres de ubicaciones comunes para demo (en producción usaríamos geocoding)
  final String _nombreUbicacionDefecto = "Ubicación seleccionada en mapa";

  @override
  void initState() {
    super.initState();
  }

  void _seleccionarPunto(LatLng point) {
    setState(() {
      _destinoSeleccionado = point;
    });
  }

  void _confirmarSeleccion() {
    if (_destinoSeleccionado != null) {
      Navigator.pop(context, {
        'lat': _destinoSeleccionado!.latitude,
        'lng': _destinoSeleccionado!.longitude,
        'nombre':
            _nombreUbicacionDefecto, // Podríamos permitir editar esto después
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Selecciona el Destino',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: CameraPosition(
              target: widget.ubicacionInicial,
              zoom: 15.0,
            ),
            onTap: _seleccionarPunto,
            markers: {
              Marker(
                markerId: const MarkerId('posicion_inicial'),
                position: widget.ubicacionInicial,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue),
              ),
              if (_destinoSeleccionado != null)
                Marker(
                  markerId: const MarkerId('destino_seleccionado'),
                  position: _destinoSeleccionado!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed),
                ),
            },
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
          ),

          // Instrucciones o Info
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app, color: Colors.teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _destinoSeleccionado == null
                          ? 'Toca en el mapa para seleccionar el destino'
                          : 'Ubicación seleccionada. Confirma para continuar.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Botón de confirmación flotante
          if (_destinoSeleccionado != null)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: ElevatedButton(
                onPressed: _confirmarSeleccion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  'Confirmar Destino',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Botón para volver a mi ubicación
          Positioned(
            bottom: _destinoSeleccionado != null ? 100 : 24,
            right: 24,
            child: FloatingActionButton(
              onPressed: () {
                _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(widget.ubicacionInicial, 15.0));
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.teal),
            ),
          ),
        ],
      ),
    );
  }
}
