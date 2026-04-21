import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

// Clase ServicioUbicacion para la gestión de la ubicación del dispositivo
class ServicioUbicacion {
  // Método para obtener la ubicación actual del usuario
  Future<Position?> obtenerUbicacionActual(BuildContext context) async {
    // Verifica si los servicios de ubicación están habilitados
    bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicioHabilitado) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Por favor, activa los servicios de ubicación.')),
        );
      }
      return null;
    }

    // Verifica los permisos de ubicación
    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.deniedForever ||
          permiso == LocationPermission.denied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Permisos de ubicación denegados. No se puede obtener la ubicación.')),
          );
        }
        return null;
      }
    }

    // Obtiene la posición actual con alta precisión
    try {
      return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener la ubicación: $e')),
        );
      }
      debugPrint('Error al obtener la ubicación: $e'); // Para depuración
      return null;
    }
  }
}
