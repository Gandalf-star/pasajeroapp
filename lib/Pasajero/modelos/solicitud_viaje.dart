import '../utils/interoperabilidad/safe_utils.dart';
import '../../utils/constantes_interoperabilidad.dart';

class SolicitudViaje {
  final String id;
  final String idPasajero;
  final String nombrePasajero;
  final String telefonoPasajero;
  final String tipoVehiculoRequerido;
  final String categoria;
  final double precio;
  final Map<String, dynamic> origen;
  final Map<String, dynamic> destino;
  final String estado;
  final int timestamp;
  final String? idConductor;
  final String? nombreConductor;
  final String? placaVehiculo;
  final String? telefonoConductor;
  final int? timestampAceptacion;
  final int? timestampInicio;
  final int? timestampFinalizacion;
  final int timestampActualizacion;

  SolicitudViaje({
    required this.id,
    required this.idPasajero,
    required this.nombrePasajero,
    required this.telefonoPasajero,
    required this.tipoVehiculoRequerido,
    required this.categoria,
    required this.precio,
    required this.origen,
    required this.destino,
    required this.estado,
    required this.timestamp,
    this.idConductor,
    this.nombreConductor,
    this.placaVehiculo,
    this.telefonoConductor,
    this.timestampAceptacion,
    this.timestampInicio,
    this.timestampFinalizacion,
    int? timestampActualizacion,
  }) : timestampActualizacion = timestampActualizacion ?? timestamp;

  factory SolicitudViaje.fromMap(String id, Map<dynamic, dynamic> map) {
    final origen =
        SafeUtils.safeMap(map[ConstantesInteroperabilidad.campoOrigen])
            .normalizedLocation;

    final destinoRaw = map[ConstantesInteroperabilidad.campoDestino];
    final Map<String, dynamic> destinoMap;
    if (destinoRaw is Map) {
      destinoMap = {
        'nombre': destinoRaw[ConstantesInteroperabilidad.campoNombre] ??
            destinoRaw['direccion'] ??
            'Destino',
        'lat': destinoRaw['lat'] ??
            destinoRaw[ConstantesInteroperabilidad.campoLat] ??
            0.0,
        'lng': destinoRaw['lng'] ??
            destinoRaw[ConstantesInteroperabilidad.campoLng] ??
            0.0,
      };
    } else {
      destinoMap = {
        'nombre': SafeUtils.safeString(destinoRaw, 'Destino'),
        'lat': 0.0,
        'lng': 0.0,
      };
    }

    final idConductor =
        SafeUtils.safeString(map[ConstantesInteroperabilidad.campoIdConductor]);

    return SolicitudViaje(
      id: id,
      idPasajero: SafeUtils.safeString(
          map[ConstantesInteroperabilidad.campoIdPasajero] ??
              map[ConstantesInteroperabilidad.campoIdPasajero]),
      nombrePasajero: SafeUtils.safeString(
          map[ConstantesInteroperabilidad.campoNombrePasajero] ??
              map[ConstantesInteroperabilidad.campoNombrePasajero],
          'Pasajero'),
      telefonoPasajero: SafeUtils.safeString(
          map[ConstantesInteroperabilidad.campoTelefonoPasajero] ??
              map[ConstantesInteroperabilidad.campoTelefonoPasajero]),
      tipoVehiculoRequerido: SafeUtils.safeString(
          map[ConstantesInteroperabilidad.campoTipoVehiculoRequerido] ??
              map[ConstantesInteroperabilidad.campoTipoVehiculo],
          ConstantesInteroperabilidad.tipoCarro),
      categoria: SafeUtils.safeString(
          map[ConstantesInteroperabilidad.campoCategoriaRequerida] ??
              map[ConstantesInteroperabilidad.campoCategoria],
          ConstantesInteroperabilidad.categoriaConfort),
      precio: SafeUtils.safeDouble(
          map[ConstantesInteroperabilidad.campoPrecio] ??
              map[ConstantesInteroperabilidad.campoPrecio]),
      origen: origen,
      destino: destinoMap,
      estado: SafeUtils.safeString(
          map[ConstantesInteroperabilidad.campoEstado] ??
              map[ConstantesInteroperabilidad.campoEstado],
          ConstantesInteroperabilidad.estadoSolicitado),
      timestamp: SafeUtils.safeInt(
          map[ConstantesInteroperabilidad.campoTimestamp] ??
              map[ConstantesInteroperabilidad.campoTimestamp],
          DateTime.now().millisecondsSinceEpoch),
      idConductor: idConductor.isEmpty ? null : idConductor,
      nombreConductor: SafeUtils.safeString(
          map[ConstantesInteroperabilidad.campoNombreConductor] ??
              map[ConstantesInteroperabilidad.campoNombreConductor]),
      placaVehiculo: SafeUtils.safeString(
          map[ConstantesInteroperabilidad.campoPlaca] ??
              map[ConstantesInteroperabilidad.campoPlaca]),
      telefonoConductor: SafeUtils.safeString(
          map[ConstantesInteroperabilidad.campoTelefonoConductor] ??
              map[ConstantesInteroperabilidad.campoTelefonoConductor]),
      timestampAceptacion: SafeUtils.safeInt(
          map[ConstantesInteroperabilidad.campoTimestampAceptacion] ??
              map[ConstantesInteroperabilidad.campoTimestampAceptacion]),
      timestampInicio: SafeUtils.safeInt(
          map[ConstantesInteroperabilidad.campoTimestampInicio] ??
              map[ConstantesInteroperabilidad.campoTimestampInicio]),
      timestampFinalizacion: SafeUtils.safeInt(
          map[ConstantesInteroperabilidad.campoTimestampFinalizacion] ??
              map[ConstantesInteroperabilidad.campoTimestampFinalizacion]),
      timestampActualizacion: SafeUtils.safeInt(
          map['timestampActualizacion'] ?? map['timestampActualizacion'],
          DateTime.now().millisecondsSinceEpoch),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ConstantesInteroperabilidad.campoIdPasajero: idPasajero,
      ConstantesInteroperabilidad.campoNombrePasajero: nombrePasajero,
      ConstantesInteroperabilidad.campoTelefonoPasajero: telefonoPasajero,
      ConstantesInteroperabilidad.campoTipoVehiculoRequerido:
          tipoVehiculoRequerido,
      ConstantesInteroperabilidad.campoCategoriaRequerida: categoria,
      ConstantesInteroperabilidad.campoPrecio: precio,
      ConstantesInteroperabilidad.campoIdSolicitud: id,
      ConstantesInteroperabilidad.campoOrigen: {
        'lat': origen['lat'] ??
            origen[ConstantesInteroperabilidad.campoLat] ??
            0.0,
        'lng': origen['lng'] ??
            origen[ConstantesInteroperabilidad.campoLng] ??
            0.0,
        'nombre': origen[ConstantesInteroperabilidad.campoNombre] ?? 'Origen',
        'direccion': origen['direccion'] ?? 'Origen',
      },
      ConstantesInteroperabilidad.campoDestino: {
        'nombre': destino[ConstantesInteroperabilidad.campoNombre] ?? 'Destino',
        'lat': destino['lat'] ??
            destino[ConstantesInteroperabilidad.campoLat] ??
            0.0,
        'lng': destino['lng'] ??
            destino[ConstantesInteroperabilidad.campoLng] ??
            0.0,
      },
      ConstantesInteroperabilidad.campoEstado: estado,
      ConstantesInteroperabilidad.campoTimestamp: timestamp,
      if (idConductor != null)
        ConstantesInteroperabilidad.campoIdConductor: idConductor,
      if (nombreConductor != null)
        ConstantesInteroperabilidad.campoNombreConductor: nombreConductor,
      if (placaVehiculo != null)
        ConstantesInteroperabilidad.campoPlaca: placaVehiculo,
      if (telefonoConductor != null)
        ConstantesInteroperabilidad.campoTelefonoConductor: telefonoConductor,
      if (timestampAceptacion != null)
        ConstantesInteroperabilidad.campoTimestampAceptacion:
            timestampAceptacion,
      if (timestampInicio != null)
        ConstantesInteroperabilidad.campoTimestampInicio: timestampInicio,
      if (timestampFinalizacion != null)
        ConstantesInteroperabilidad.campoTimestampFinalizacion:
            timestampFinalizacion,
      'timestampActualizacion': timestampActualizacion,
    };
  }
}
