import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../../utils/constantes_interoperabilidad.dart';
import '../../utils/click_logger.dart';

class ServicioPerfilPasajero {
  final DatabaseReference _baseDeDatos;

  ServicioPerfilPasajero(this._baseDeDatos);

  Stream<Map<String, dynamic>?> obtenerPerfilPasajeroStream(String uid) {
    return _baseDeDatos
        .child(ConstantesInteroperabilidad.nodoPasajeros)
        .child(uid)
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return null;
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }

  Future<void> actualizarPerfilPasajero({
    required String uid,
    required String nombre,
    required String telefono,
    String? fotoUrl,
  }) async {
    try {
      final perfilData = {
        ConstantesInteroperabilidad.campoNombre: nombre,
        ConstantesInteroperabilidad.campoTelefono: telefono,
        'fotoUrl': fotoUrl ?? '',
        'fechaActualizacion': ServerValue.timestamp,
        'fechaCreacion': ServerValue.timestamp,
        'ultimaConexion': ServerValue.timestamp,
      };

      await _baseDeDatos
          .child(ConstantesInteroperabilidad.nodoPasajeros)
          .child(uid)
          .update(perfilData);

      ClickLogger.d(
          'Perfil del pasajero actualizado: ${ConstantesInteroperabilidad.nodoPasajeros}/$uid');
    } catch (e) {
      ClickLogger.d('Error al actualizar perfil del pasajero: $e');
    }
  }

  Stream<String?> obtenerIdSolicitudActivaStream(String uidPasajero) {
    try {
      return _baseDeDatos
          .child(ConstantesInteroperabilidad.nodoPasajeros)
          .child(uidPasajero)
          .child('solicitudActiva')
          .onValue
          .map((event) {
        final v = event.snapshot.value;
        if (v == null) return null;
        if (v is Map) {
          return v['id']?.toString() ?? '';
        }
        return v.toString();
      });
    } catch (e) {
      ClickLogger.d('Error en obtenerIdSolicitudActivaStream: $e');
      return const Stream.empty();
    }
  }

  Future<void> limpiarSolicitudesAntiguas(String uidPasajero) async {
    try {
      final snapshot = await _baseDeDatos
          .child(ConstantesInteroperabilidad.nodoPasajeros)
          .child(uidPasajero)
          .child('solicitudActiva')
          .get();

      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final timestamp =
            data[ConstantesInteroperabilidad.campoTimestamp] as int? ?? 0;
        final ahora = DateTime.now().millisecondsSinceEpoch;
        const tiempoLimite = 24 * 60 * 60 * 1000;

        if (timestamp > 0 && (ahora - timestamp) > tiempoLimite) {
          await _baseDeDatos
              .child(ConstantesInteroperabilidad.nodoPasajeros)
              .child(uidPasajero)
              .child('solicitudActiva')
              .remove();
          ClickLogger.d('Limpiando solicitudActiva antigua para $uidPasajero');
        }
      }
    } catch (e) {
      ClickLogger.d('Error al limpiar solicitudes antiguas: $e');
    }
  }
}
