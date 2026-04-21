import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../../utils/constantes_interoperabilidad.dart';
import '../../utils/click_logger.dart';

class ServicioFavoritos {
  final DatabaseReference _baseDeDatos;

  ServicioFavoritos(this._baseDeDatos);

  Future<void> toggleFavorito(String uidPasajero, String idConductor) async {
    try {
      final ref = _baseDeDatos
          .child(ConstantesInteroperabilidad.nodoPasajeros)
          .child(uidPasajero)
          .child('favoritos')
          .child(idConductor);

      final snapshot = await ref.get();

      if (snapshot.exists) {
        await ref.remove();
        ClickLogger.d('Conductor $idConductor eliminado de favoritos');
      } else {
        await ref.set(ServerValue.timestamp);
        ClickLogger.d('Conductor $idConductor agregado a favoritos');
      }
    } catch (e) {
      ClickLogger.d('Error al alternar favorito: $e');
      rethrow;
    }
  }

  Future<bool> esFavorito(String uidPasajero, String idConductor) async {
    try {
      final snapshot = await _baseDeDatos
          .child(ConstantesInteroperabilidad.nodoPasajeros)
          .child(uidPasajero)
          .child('favoritos')
          .child(idConductor)
          .get();
      return snapshot.exists;
    } catch (e) {
      return false;
    }
  }

  Stream<List<String>> obtenerIdsFavoritosStream(String uidPasajero) {
    return _baseDeDatos
        .child(ConstantesInteroperabilidad.nodoPasajeros)
        .child(uidPasajero)
        .child('favoritos')
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return [];
      final map = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      return map.keys.cast<String>().toList();
    });
  }
}
