import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ServicioGeocodificacion {
  static const String _apiKey = 'AIzaSyA7QmnEK36qat8Sam-Rpbu_mfOfAt1JtqQ';
  static const String _androidPackage = 'click_express.project';
  static const String _androidCert = '50EF7093A7572E7A53F70CC1B5EAD150AE5CC2CC';

  /// Obtiene las coordenadas geográficas a partir de una dirección en texto.
  /// Retorna un objeto LatLng, o null si falla.
  static Future<LatLng?> obtenerCoordenadasPorDireccion(String direccion) async {
    if (direccion.trim().isEmpty) return null;

    try {
      final geoUri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/geocode/json',
        {
          'address': direccion.trim(),
          'key': _apiKey,
        },
      );

      final resp = await http.get(geoUri, headers: {
        'X-Android-Package': _androidPackage,
        'X-Android-Cert': _androidCert,
      }).timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        final geoData = json.decode(resp.body) as Map<String, dynamic>;
        final results = geoData['results'] as List<dynamic>?;

        if (results != null && results.isNotEmpty) {
          final loc = results[0]['geometry']['location'] as Map<String, dynamic>;
          final lat = (loc['lat'] as num).toDouble();
          final lng = (loc['lng'] as num).toDouble();
          return LatLng(lat, lng);
        }
      }
    } catch (_) {
      // Retorna null si hay timeout o error de conexión
      return null;
    }
    return null;
  }
}
