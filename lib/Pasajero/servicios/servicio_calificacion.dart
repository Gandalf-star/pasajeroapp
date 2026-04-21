import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

class ServicioCalificacion {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  Future<void> enviarCalificacionYComentario({
    required String idViaje,
    required String idConductor,
    required int calificacion,
    required String comentario,
  }) async {
    try {
      final dbRef = _db.ref();

      // Guardamos la calificación en el viaje
      await dbRef.child('solicitudes_viaje/$idViaje').update({
        'calificacionPasajero': calificacion,
        'comentarioPasajero': comentario.trim(),
        'timestampCalificacionPasajero': ServerValue.timestamp,
      });

      // Actualizar el rating promedio del conductor
      final conductorRef = dbRef.child('conductores/$idConductor');
      final conductorSnapshot = await conductorRef.get();

      if (conductorSnapshot.exists && conductorSnapshot.value is Map) {
        final data = Map<String, dynamic>.from(conductorSnapshot.value as Map);

        final double calificacionActual = (data['calificacionPromedio'] ?? 5.0).toDouble();
        final int viajes = (data['totalCalificaciones'] ?? data['totalViajes'] ?? 0) as int;

        // Calcular nuevo promedio
        final nuevoTotalViajes = viajes + 1;
        final nuevaCalificacion = ((calificacionActual * viajes) + calificacion) / nuevoTotalViajes;

        await conductorRef.update({
          'calificacionPromedio': double.parse(nuevaCalificacion.toStringAsFixed(1)),
          'totalCalificaciones': nuevoTotalViajes,
        });
      }
    } catch (e) {
      debugPrint('Error enviando calificación: $e');
      rethrow; 
    }
  }
}
