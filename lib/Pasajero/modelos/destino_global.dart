import 'package:firebase_database/firebase_database.dart';

/// Modelo para representar un destino global compartido entre todos los usuarios
class DestinoGlobal {
  final String id;
  final String nombre;
  final double? lat;
  final double? lng;
  final String? direccion;
  final int vecesUsado;
  final int? ultimaActualizacion;
  final String? creadoPor;
  final int? fechaCreacion;
  final bool tieneCoordenadasExactas;

  DestinoGlobal({
    required this.id,
    required this.nombre,
    this.lat,
    this.lng,
    this.direccion,
    this.vecesUsado = 0,
    this.ultimaActualizacion,
    this.creadoPor,
    this.fechaCreacion,
    this.tieneCoordenadasExactas = false,
  });

  /// Crea un DestinoGlobal desde un Map de Firebase
  factory DestinoGlobal.fromMap(String id, Map<dynamic, dynamic> map) {
    final lat = map['lat'];
    final lng = map['lng'];

    return DestinoGlobal(
      id: id,
      nombre: map['nombre']?.toString() ?? '',
      lat: lat != null ? double.tryParse(lat.toString()) : null,
      lng: lng != null ? double.tryParse(lng.toString()) : null,
      direccion: map['direccion']?.toString(),
      vecesUsado: int.tryParse(map['vecesUsado']?.toString() ?? '0') ?? 0,
      ultimaActualizacion:
          int.tryParse(map['ultimaActualizacion']?.toString() ?? '0'),
      creadoPor: map['creadoPor']?.toString(),
      fechaCreacion: int.tryParse(map['fechaCreacion']?.toString() ?? '0'),
      tieneCoordenadasExactas: map['tieneCoordenadasExactas'] == true,
    );
  }

  /// Convierte el DestinoGlobal a un Map para guardar en Firebase
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'lat': lat,
      'lng': lng,
      'direccion': direccion ?? nombre,
      'vecesUsado': vecesUsado,
      'ultimaActualizacion': ServerValue.timestamp,
      'creadoPor': creadoPor,
      'fechaCreacion': fechaCreacion ?? ServerValue.timestamp,
      'tieneCoordenadasExactas': tieneCoordenadasExactas,
    };
  }

  /// Crea una copia del destino con campos actualizados
  DestinoGlobal copyWith({
    String? id,
    String? nombre,
    double? lat,
    double? lng,
    String? direccion,
    int? vecesUsado,
    int? ultimaActualizacion,
    String? creadoPor,
    int? fechaCreacion,
    bool? tieneCoordenadasExactas,
  }) {
    return DestinoGlobal(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      direccion: direccion ?? this.direccion,
      vecesUsado: vecesUsado ?? this.vecesUsado,
      ultimaActualizacion: ultimaActualizacion ?? this.ultimaActualizacion,
      creadoPor: creadoPor ?? this.creadoPor,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      tieneCoordenadasExactas:
          tieneCoordenadasExactas ?? this.tieneCoordenadasExactas,
    );
  }

  @override
  String toString() {
    return 'DestinoGlobal(id: $id, nombre: $nombre, lat: $lat, lng: $lng, vecesUsado: $vecesUsado, tieneCoordenadasExactas: $tieneCoordenadasExactas)';
  }
}
