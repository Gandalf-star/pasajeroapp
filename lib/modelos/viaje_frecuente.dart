import 'package:latlong2/latlong.dart';

class ViajeFrecuente {
  final String id;
  final String idPasajero;
  final String nombre;
  final String? icono;
  final String? horarioHabitual;
  final int contadorUsos;
  final String origenNombre;
  final String destinoNombre;
  final String? tipoVehiculoPreferido;
  final LatLng? origen;
  final LatLng? destino;

  ViajeFrecuente({
    required this.id,
    required this.idPasajero,
    required this.nombre,
    this.icono,
    this.horarioHabitual,
    this.contadorUsos = 0,
    required this.origenNombre,
    required this.destinoNombre,
    this.tipoVehiculoPreferido,
    this.origen,
    this.destino,
  });
}
