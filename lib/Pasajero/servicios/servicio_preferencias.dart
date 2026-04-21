import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../modelos/preferencias_viaje.dart';

class ServicioPreferencias {
  static const String _kPrefsKey = 'preferencias_viaje_pasajero';

  /// Guarda las preferencias en el almacenamiento local del dispositivo.
  static Future<void> guardarPreferencias(
      PreferenciasViaje preferencias) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(preferencias.toMapa());
    await prefs.setString(_kPrefsKey, jsonString);
  }

  /// Lee las preferencias del almacenamiento local. Si no existen, retorna los valores por defecto.
  static Future<PreferenciasViaje> obtenerPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_kPrefsKey);

    if (jsonString == null) {
      return PreferenciasViaje.porDefecto;
    }

    try {
      final mapa = json.decode(jsonString) as Map<String, dynamic>;
      return PreferenciasViaje.desdeMapa(mapa);
    } catch (e) {
      // Si el formato cambia o está corrupto, devolver por defecto
      return PreferenciasViaje.porDefecto;
    }
  }

  /// Limpia las preferencias almacenadas, regresando a los valores por defecto.
  static Future<void> limpiarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefsKey);
  }
}
