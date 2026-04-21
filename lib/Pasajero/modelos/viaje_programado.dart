import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'preferencias_viaje.dart';

/// Modelo para viajes programados por pasajeros
class ViajeProgramado {
  final String id;
  final String idPasajero;
  final String nombrePasajero;
  final String telefonoPasajero;

  // Origen
  final String origenNombre;
  final LatLng origenLatLng;

  // Destino
  final String destinoNombre;
  final LatLng destinoLatLng;

  // Programación
  final DateTime fechaHoraProgramada;

  // Detalles del viaje
  final String tipoVehiculo; // 'Carro' o 'Moto'
  final String categoria; // 'economico', 'confort', 'viajes_largos'
  final double precioEstimado;

  // Preferencias
  final PreferenciasViaje preferencias;

  // Estado
  String
      estado; // 'pendiente', 'confirmado', 'en_curso', 'completado', 'cancelado'
  String? idConductorAsignado;
  DateTime? fechaHoraConfirmacion;

  // Timestamps
  final int timestampCreacion;
  int? timestampActualizacion;

  ViajeProgramado({
    required this.id,
    required this.idPasajero,
    required this.nombrePasajero,
    required this.telefonoPasajero,
    required this.origenNombre,
    required this.origenLatLng,
    required this.destinoNombre,
    required this.destinoLatLng,
    required this.fechaHoraProgramada,
    required this.tipoVehiculo,
    required this.categoria,
    required this.precioEstimado,
    this.preferencias = PreferenciasViaje.porDefecto,
    this.estado = 'pendiente',
    this.idConductorAsignado,
    this.fechaHoraConfirmacion,
    required this.timestampCreacion,
    this.timestampActualizacion,
  });

  /// Crear desde mapa de Firebase
  factory ViajeProgramado.desdeMapa(String id, Map<dynamic, dynamic> data) {
    String toStr(dynamic v, [String def = '']) =>
        v == null ? def : v.toString();
    double toDouble(dynamic v, [double def = 0.0]) {
      if (v == null) return def;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? def;
    }

    int toInt(dynamic v, [int def = 0]) {
      if (v == null) return def;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? def;
    }

    // Parsear ubicación
    LatLng parseLatLng(Map<dynamic, dynamic>? map) {
      if (map != null) {
        final lat = toDouble(map['lat'] ?? map['latitud']);
        final lng = toDouble(map['lng'] ?? map['longitud']);
        return LatLng(lat, lng);
      }
      return const LatLng(0.0, 0.0);
    }

    DateTime parseFecha(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    final origenMap = (data['origen'] as Map?)?.cast<dynamic, dynamic>() ?? {};
    final destinoMap =
        (data['destino'] as Map?)?.cast<dynamic, dynamic>() ?? {};

    return ViajeProgramado(
      id: id,
      idPasajero: toStr(data['idPasajero']),
      nombrePasajero: toStr(data['nombrePasajero'], 'Pasajero'),
      telefonoPasajero: toStr(data['telefonoPasajero']),
      origenNombre: toStr(origenMap['nombre'], 'Origen'),
      origenLatLng: parseLatLng(origenMap),
      destinoNombre: toStr(destinoMap['nombre'], 'Destino'),
      destinoLatLng: parseLatLng(destinoMap),
      fechaHoraProgramada: parseFecha(data['fechaHoraProgramada']),
      tipoVehiculo: toStr(data['tipoVehiculo'], 'Carro'),
      categoria: toStr(data['categoria'], 'economico'),
      precioEstimado: toDouble(data['precioEstimado']),
      preferencias: data['preferencias'] != null
          ? PreferenciasViaje.desdeMapa(data['preferencias'] as Map?)
          : PreferenciasViaje.porDefecto,
      estado: toStr(data['estado'], 'pendiente'),
      idConductorAsignado: toStr(data['idConductorAsignado']).isEmpty
          ? null
          : toStr(data['idConductorAsignado']),
      fechaHoraConfirmacion: data['fechaHoraConfirmacion'] != null
          ? parseFecha(data['fechaHoraConfirmacion'])
          : null,
      timestampCreacion: toInt(
        data['timestampCreacion'],
        DateTime.now().millisecondsSinceEpoch,
      ),
      timestampActualizacion: data['timestampActualizacion'] != null
          ? toInt(data['timestampActualizacion'])
          : null,
    );
  }

  /// Convertir a mapa para enviar a Firebase
  Map<String, dynamic> toMapa() {
    return {
      'idPasajero': idPasajero,
      'nombrePasajero': nombrePasajero,
      'telefonoPasajero': telefonoPasajero,
      'origen': {
        'nombre': origenNombre,
        'lat': origenLatLng.latitude,
        'lng': origenLatLng.longitude,
      },
      'destino': {
        'nombre': destinoNombre,
        'lat': destinoLatLng.latitude,
        'lng': destinoLatLng.longitude,
      },
      'fechaHoraProgramada': fechaHoraProgramada.millisecondsSinceEpoch,
      'tipoVehiculo': tipoVehiculo,
      'categoria': categoria,
      'precioEstimado': precioEstimado,
      'preferencias': preferencias.toMapa(),
      'estado': estado,
      'idConductorAsignado': idConductorAsignado,
      'fechaHoraConfirmacion': fechaHoraConfirmacion?.millisecondsSinceEpoch,
      'timestampCreacion': timestampCreacion,
      'timestampActualizacion':
          timestampActualizacion ?? DateTime.now().millisecondsSinceEpoch,
    };
  }
}
