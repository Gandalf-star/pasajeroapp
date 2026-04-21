import '../../utils/constantes_interoperabilidad.dart';
import '../utils/interoperabilidad/safe_utils.dart';

class ViajeModelo {
  final String id;
  final String idPasajero;
  final String? idConductor;
  final String tipoVehiculo;
  final double precio;
  final UbicacionModelo origen;
  final String destino;
  final UbicacionModelo? destinoUbicacion; // Nuevo campo
  final EstadoViaje estado;
  final int timestamp;
  final String? nombreConductor;
  final String? telefonoConductor;
  final String? placaVehiculo;
  final UbicacionModelo? ubicacionConductor;
  final int? tiempoEstimadoLlegada;
  final String? categoria;

  // Helpers
  double get destinoLat => destinoUbicacion?.lat ?? 0.0;
  double get destinoLng => destinoUbicacion?.lng ?? 0.0;

  ViajeModelo({
    required this.id,
    required this.idPasajero,
    this.idConductor,
    required this.tipoVehiculo,
    required this.precio,
    required this.origen,
    required this.destino,
    this.destinoUbicacion,
    required this.estado,
    required this.timestamp,
    this.nombreConductor,
    this.telefonoConductor,
    this.placaVehiculo,
    this.ubicacionConductor,
    this.tiempoEstimadoLlegada,
    this.categoria,
  });

  factory ViajeModelo.fromMap(Map<String, dynamic> map, String id) {
    String destinoNombre = '';
    final destinoData = map['destino'];
    if (destinoData is Map) {
      final destinoMap = Map<String, dynamic>.from(destinoData);
      destinoNombre = destinoMap['nombre'] ?? destinoMap['direccion'] ?? '';
    } else if (destinoData is String) {
      destinoNombre = destinoData;
    }

    // Parse Destino Coords
    UbicacionModelo? destUbicacion;
    double dLat = 0.0;
    double dLng = 0.0;

    if (map['destino'] is Map) {
      final dMap = Map<String, dynamic>.from(map['destino'] as Map);
      dLat = double.tryParse(
              dMap['lat']?.toString() ?? dMap['latitud']?.toString() ?? '') ??
          0.0;
      dLng = double.tryParse(
              dMap['lng']?.toString() ?? dMap['longitud']?.toString() ?? '') ??
          0.0;
    }

    if (dLat == 0 && map['destinoLat'] != null) {
      dLat = double.tryParse(map['destinoLat'].toString()) ?? 0.0;
    }
    if (dLng == 0 && map['destinoLng'] != null) {
      dLng = double.tryParse(map['destinoLng'].toString()) ?? 0.0;
    }

    if (dLat != 0 && dLng != 0) {
      destUbicacion =
          UbicacionModelo(lat: dLat, lng: dLng, nombre: destinoNombre);
    }

    return ViajeModelo(
      id: id,
      idPasajero: SafeUtils.safeString(map['idPasajero'] ??
          map[ConstantesInteroperabilidad.campoIdPasajero]),
      idConductor: SafeUtils.safeString(map['idConductor'] ??
          map[ConstantesInteroperabilidad.campoIdConductor]),
      tipoVehiculo: SafeUtils.safeString(map['tipoVehiculoRequerido'] ??
          map['tipoVehiculo'] ??
          map[ConstantesInteroperabilidad.campoTipoVehiculo]),
      precio: SafeUtils.safeDouble(
          map['precio'] ?? map[ConstantesInteroperabilidad.campoPrecio]),
      origen: UbicacionModelo.fromMap(SafeUtils.safeMap(map['origen'])),
      destino: destinoNombre,
      destinoUbicacion: destUbicacion,
      estado: EstadoViajeExtension.fromString(SafeUtils.safeString(
          map['estado'] ?? map[ConstantesInteroperabilidad.campoEstado],
          'pendiente')),
      timestamp: SafeUtils.safeInt(
          map['timestamp'] ?? map[ConstantesInteroperabilidad.campoTimestamp]),
      nombreConductor: SafeUtils.safeString(map['nombreConductor'] ??
          map[ConstantesInteroperabilidad.campoNombreConductor]),
      telefonoConductor: SafeUtils.safeString(map['telefonoConductor'] ??
          map[ConstantesInteroperabilidad.campoTelefonoConductor]),
      placaVehiculo: SafeUtils.safeString(
          map['placaVehiculo'] ?? map[ConstantesInteroperabilidad.campoPlaca]),
      ubicacionConductor: map['ubicacionConductor'] != null
          ? UbicacionModelo.fromMap(
              SafeUtils.safeMap(map['ubicacionConductor']))
          : null,
      tiempoEstimadoLlegada: SafeUtils.safeInt(map['tiempoEstimadoLlegada']),
      categoria: SafeUtils.safeString(map['categoria'] ??
          map['categoriaServicio'] ??
          map[ConstantesInteroperabilidad.campoCategoriaRequerida]),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idPasajero': idPasajero,
      'idConductor': idConductor,
      'tipoVehiculoRequerido': tipoVehiculo,
      'precio': precio,
      'origen': origen.toMap(),
      'destino': destino,
      'destinoUbicacion': destinoUbicacion?.toMap(),
      'destinoLat': destinoUbicacion?.lat,
      'destinoLng': destinoUbicacion?.lng,
      'estado': estado.toString().split('.').last,
      'timestamp': timestamp,
      'nombreConductor': nombreConductor,
      'telefonoConductor': telefonoConductor,
      'placaVehiculo': placaVehiculo,
      'ubicacionConductor': ubicacionConductor?.toMap(),
      'tiempoEstimadoLlegada': tiempoEstimadoLlegada,
      'categoria': categoria,
    };
  }

  ViajeModelo copyWith({
    String? id,
    String? idPasajero,
    String? idConductor,
    String? tipoVehiculo,
    double? precio,
    UbicacionModelo? origen,
    String? destino,
    UbicacionModelo? destinoUbicacion,
    EstadoViaje? estado,
    int? timestamp,
    String? nombreConductor,
    String? telefonoConductor,
    String? placaVehiculo,
    UbicacionModelo? ubicacionConductor,
    int? tiempoEstimadoLlegada,
    String? categoria,
  }) {
    return ViajeModelo(
      id: id ?? this.id,
      idPasajero: idPasajero ?? this.idPasajero,
      idConductor: idConductor ?? this.idConductor,
      tipoVehiculo: tipoVehiculo ?? this.tipoVehiculo,
      precio: precio ?? this.precio,
      origen: origen ?? this.origen,
      destino: destino ?? this.destino,
      destinoUbicacion: destinoUbicacion ?? this.destinoUbicacion,
      estado: estado ?? this.estado,
      timestamp: timestamp ?? this.timestamp,
      nombreConductor: nombreConductor ?? this.nombreConductor,
      telefonoConductor: telefonoConductor ?? this.telefonoConductor,
      placaVehiculo: placaVehiculo ?? this.placaVehiculo,
      ubicacionConductor: ubicacionConductor ?? this.ubicacionConductor,
      tiempoEstimadoLlegada:
          tiempoEstimadoLlegada ?? this.tiempoEstimadoLlegada,
      categoria: categoria ?? this.categoria,
    );
  }
}

class UbicacionModelo {
  final double lat;
  final double lng;
  final String nombre;

  UbicacionModelo({
    required this.lat,
    required this.lng,
    required this.nombre,
  });

  factory UbicacionModelo.fromMap(Map<String, dynamic> map) {
    return UbicacionModelo(
      lat: SafeUtils.safeDouble(
          map['lat'] ?? map[ConstantesInteroperabilidad.campoLat]),
      lng: SafeUtils.safeDouble(
          map['lng'] ?? map[ConstantesInteroperabilidad.campoLng]),
      nombre: SafeUtils.safeString(map['nombre'] ??
          map[ConstantesInteroperabilidad.campoUbicacionActual]),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lat': lat,
      'lng': lng,
      'nombre': nombre,
    };
  }
}

enum EstadoViaje {
  pendiente,
  aceptado,
  enCamino,
  llegado,
  enCurso,
  completado,
  cancelado,
  canceladoPorConductor,
  canceladoPorPasajero
}

extension EstadoViajeExtension on EstadoViaje {
  static EstadoViaje fromString(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return EstadoViaje.pendiente;
      case ConstantesInteroperabilidad.estadoAceptado:
        return EstadoViaje.aceptado;
      case ConstantesInteroperabilidad.estadoEnCamino:
        return EstadoViaje.enCamino;
      case ConstantesInteroperabilidad.estadoLlegado:
        return EstadoViaje.llegado;
      case 'en_curso':
      case 'en_viaje':
        return EstadoViaje.enCurso;
      case ConstantesInteroperabilidad.estadoCompletado:
        return EstadoViaje.completado;
      case ConstantesInteroperabilidad.estadoCancelado:
        return EstadoViaje.cancelado;
      case 'cancelado_por_conductor':
      case 'canceladoporconductor':
        return EstadoViaje.canceladoPorConductor;
      case 'cancelado_por_pasajero':
      case 'canceladoporpasajero':
      case 'canceladoporpajero':
        return EstadoViaje.canceladoPorPasajero;
      default:
        return EstadoViaje.pendiente; // Fallback para producción
    }
  }

  String get displayName {
    switch (this) {
      case EstadoViaje.pendiente:
        return 'Buscando conductor...';
      case EstadoViaje.aceptado:
        return 'Viaje aceptado';
      case EstadoViaje.enCamino:
        return 'Conductor en camino';
      case EstadoViaje.llegado:
        return 'Conductor ha llegado';
      case EstadoViaje.enCurso:
        return 'Viaje en curso';
      case EstadoViaje.completado:
        return 'Viaje completado';
      case EstadoViaje.cancelado:
        return 'Viaje cancelado';
      case EstadoViaje.canceladoPorConductor:
        return 'Cancelado por conductor';
      case EstadoViaje.canceladoPorPasajero:
        return 'Cancelado por pasajero';
    }
  }

  String get descripcion {
    switch (this) {
      case EstadoViaje.pendiente:
        return 'Estamos buscando un conductor cercano para ti';
      case EstadoViaje.aceptado:
        return 'Un conductor ha aceptado tu viaje';
      case EstadoViaje.enCamino:
        return 'El conductor se dirige a tu ubicación';
      case EstadoViaje.llegado:
        return 'Tu conductor ha llegado al punto de encuentro';
      case EstadoViaje.enCurso:
        return 'Estás en camino a tu destino';
      case EstadoViaje.completado:
        return '¡Has llegado a tu destino!';
      case EstadoViaje.cancelado:
        return 'El viaje ha sido cancelado';
      case EstadoViaje.canceladoPorConductor:
        return 'El conductor canceló el viaje';
      case EstadoViaje.canceladoPorPasajero:
        return 'Has cancelado el viaje';
    }
  }
}
