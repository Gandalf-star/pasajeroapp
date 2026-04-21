import 'package:firebase_database/firebase_database.dart';
import '../modelos/viaje_programado.dart';

class ServicioViajesProgramados {
  static final ServicioViajesProgramados _instancia =
      ServicioViajesProgramados._internal();
  factory ServicioViajesProgramados() => _instancia;
  ServicioViajesProgramados._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final String _nodoViajesProgramados = 'viajes_programados';

  /// Obtener todos los viajes programados PENDIENTES del pasajero
  Future<List<ViajeProgramado>> obtenerViajesPendientesPasajero(
      String idPasajero) async {
    try {
      final snapshot = await _db
          .ref()
          .child(_nodoViajesProgramados)
          .orderByChild('idPasajero')
          .equalTo(idPasajero)
          .get();

      if (snapshot.value == null) return [];

      final data = snapshot.value as Map<dynamic, dynamic>;
      final viajes = data.entries.map((e) {
        return ViajeProgramado.desdeMapa(e.key.toString(), e.value as Map);
      }).toList();

      // Filtrar solo los que están pendientes o confirmados (no completados ni cancelados) y a futuro
      final ahora = DateTime.now();
      return viajes.where((v) {
        final estadoActivo =
            (v.estado == 'pendiente' || v.estado == 'confirmado');
        final esFuturo = v.fechaHoraProgramada
            .isAfter(ahora.subtract(const Duration(minutes: 30))); // Dar margen
        return estadoActivo && esFuturo;
      }).toList();
    } catch (e) {
      throw Exception('Error al obtener viajes programados: $e');
    }
  }

  /// Valida si se puede programar un viaje a cierta fecha y hora,
  /// asegurando que haya al menos 1.5 horas de diferencia con el más cercano
  /// del MISMO DÍA. Retorna un String de error, o null si es válido.
  Future<String?> validarDisponibilidad(
      String idPasajero, DateTime nuevaFecha) async {
    try {
      final viajesPendientes =
          await obtenerViajesPendientesPasajero(idPasajero);

      final mismaFechaDia =
          DateTime(nuevaFecha.year, nuevaFecha.month, nuevaFecha.day);

      for (var viaje in viajesPendientes) {
        final vFecha = viaje.fechaHoraProgramada;
        final vFechaDia = DateTime(vFecha.year, vFecha.month, vFecha.day);

        // Si es el mismo día, calcular la diferencia de horas.
        if (mismaFechaDia == vFechaDia) {
          final diferenciaMinutos =
              vFecha.difference(nuevaFecha).inMinutes.abs();

          // Se requieren 90 minutos (1.5 horas)
          if (diferenciaMinutos < 90) {
            return 'Ya tienes un viaje programado muy cerca de esta hora. Debe de haber al menos 1 hora y media de diferencia.';
          }
        }
      }
      return null; // Todo limpio, no hay colisión
    } catch (e) {
      return 'Error de conexión al validar fechas.';
    }
  }

  /// Programa un nuevo viaje y lo envía a Firebase
  Future<String> programarViaje(ViajeProgramado viaje) async {
    try {
      final ref = _db.ref().child(_nodoViajesProgramados).push();

      final viajeConId = ViajeProgramado(
        id: ref.key!,
        idPasajero: viaje.idPasajero,
        nombrePasajero: viaje.nombrePasajero,
        telefonoPasajero: viaje.telefonoPasajero,
        origenNombre: viaje.origenNombre,
        origenLatLng: viaje.origenLatLng,
        destinoNombre: viaje.destinoNombre,
        destinoLatLng: viaje.destinoLatLng,
        fechaHoraProgramada: viaje.fechaHoraProgramada,
        tipoVehiculo: viaje.tipoVehiculo,
        categoria: viaje.categoria,
        precioEstimado: viaje.precioEstimado,
        preferencias: viaje.preferencias,
        estado: 'pendiente',
        timestampCreacion: DateTime.now().millisecondsSinceEpoch,
        timestampActualizacion: null,
      );

      await ref.set(viajeConId.toMapa());
      return viajeConId.id;
    } catch (e) {
      throw Exception('Error al programar el viaje: $e');
    }
  }
}
