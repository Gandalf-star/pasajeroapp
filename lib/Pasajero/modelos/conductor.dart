import '../utils/interoperabilidad/safe_utils.dart';
import '../../utils/constantes_interoperabilidad.dart';

class Conductor {
  final String id;
  final String nombre;
  final String telefono;
  final String tipoVehiculo;
  final String categoria;
  final String placa;
  final double calificacion;
  final Map<String, dynamic> ubicacionActual;
  final bool estaEnLinea;
  final String? idViajeActivo;
  final String? fotoPerfil;
  final String? modeloVehiculo;
  final String? colorVehiculo;
  final String? estado;

  Conductor({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.tipoVehiculo,
    required this.categoria,
    required this.placa,
    required this.calificacion,
    required this.ubicacionActual,
    required this.estaEnLinea,
    this.idViajeActivo,
    this.fotoPerfil,
    this.modeloVehiculo,
    this.colorVehiculo,
    this.estado,
  });

  factory Conductor.fromMap(String id, Map<dynamic, dynamic> map) {
    final ubicacionRaw =
        map[ConstantesInteroperabilidad.campoUbicacionActual] ??
            map[ConstantesInteroperabilidad.campoUbicacionActual];
    final ubicacion = SafeUtils.safeMap(ubicacionRaw).normalizedLocation;

    final idViajeActivoRaw =
        map[ConstantesInteroperabilidad.campoIdViajeActivo] ??
            map[ConstantesInteroperabilidad.campoIdViajeActivo];
    final idViajeActivo = SafeUtils.safeString(idViajeActivoRaw);

    return Conductor(
      id: id,
      nombre: SafeUtils.safeString(
          map[ConstantesInteroperabilidad.campoNombre] ??
              map[ConstantesInteroperabilidad.campoNombre],
          'Sin nombre'),
      telefono: SafeUtils.safeString(
          map[ConstantesInteroperabilidad.campoTelefono] ??
              map[ConstantesInteroperabilidad.campoTelefono]),
      tipoVehiculo: SafeUtils.safeString(
          map[ConstantesInteroperabilidad.campoTipoVehiculo] ??
              map[ConstantesInteroperabilidad.campoTipoVehiculo]),
      categoria: SafeUtils.safeString(
          map[ConstantesInteroperabilidad.campoCategoria] ??
              map[ConstantesInteroperabilidad.campoCategoria]),
      placa: SafeUtils.safeString(map[ConstantesInteroperabilidad.campoPlaca] ??
          map[ConstantesInteroperabilidad.campoPlaca]),
      calificacion: SafeUtils.safeDouble(
          map[ConstantesInteroperabilidad.campoCalificacion] ??
              map[ConstantesInteroperabilidad.campoCalificacion]),
      ubicacionActual: ubicacion,
      estaEnLinea: (map[ConstantesInteroperabilidad.campoEstaEnLinea] ??
              map[ConstantesInteroperabilidad.campoEstaEnLinea]) ==
          true,
      idViajeActivo: idViajeActivo.isEmpty ? null : idViajeActivo,
      fotoPerfil: map['fotoPerfil']?.toString(),
      modeloVehiculo: map['modeloVehiculo']?.toString(),
      colorVehiculo: map['colorVehiculo']?.toString(),
      estado: map['estado']?.toString(),
    );
  }
}
