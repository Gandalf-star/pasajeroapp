import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:clickexpress/utils/constantes_interoperabilidad.dart';

class VerificadorEstructuraFirebase {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<void> verificarEstructuraConductores() async {
    try {
      debugPrint('\n=== VERIFICANDO ESTRUCTURA DE CONDUCTORES EN FIREBASE ===');

      final snapshot =
          await _db.child(ConstantesInteroperabilidad.nodoConductores).get();

      if (!snapshot.exists) {
        debugPrint('No se encontró el nodo de conductores en la base de datos');
        return;
      }

      final conductores = snapshot.value as Map<dynamic, dynamic>?;

      if (conductores == null || conductores.isEmpty) {
        debugPrint('No hay conductores registrados en la base de datos');
        return;
      }

      debugPrint('\n=== CONDUCTORES ENCONTRADOS ===');
      debugPrint('Total de conductores: ${conductores.length}');

      int contador = 1;
      conductores.forEach((key, value) async {
        final conductor = Map<String, dynamic>.from(value as Map);
        debugPrint('\nConductor #$contador (ID: $key)');
        debugPrint('----------------------------');

        // Información básica
        debugPrint(
            'Nombre: ${conductor[ConstantesInteroperabilidad.campoNombre] ?? 'No especificado'}');
        debugPrint(
            'Teléfono: ${conductor[ConstantesInteroperabilidad.campoTelefono] ?? 'No especificado'}');

        // Estado
        debugPrint('\nESTADO:');
        debugPrint(
            '- En línea: ${conductor[ConstantesInteroperabilidad.campoEstaEnLinea] ?? 'No especificado'}');
        debugPrint(
            '- ID Viaje Activo: ${conductor[ConstantesInteroperabilidad.campoIdViajeActivo] ?? 'Ninguno'}');

        // Vehículo
        debugPrint('\nVEHÍCULO:');
        debugPrint(
            '- Tipo: ${conductor[ConstantesInteroperabilidad.campoTipoVehiculo] ?? 'No especificado'}');
        debugPrint(
            '- Categoría: ${conductor[ConstantesInteroperabilidad.campoCategoria] ?? 'No especificada'}');
        debugPrint(
            '- Placa: ${conductor[ConstantesInteroperabilidad.campoPlaca] ?? 'No especificada'}');

        // Ubicación
        debugPrint('\nUBICACIÓN:');
        final ubicacion =
            conductor[ConstantesInteroperabilidad.campoUbicacionActual];
        if (ubicacion != null && ubicacion is Map) {
          debugPrint(
              '- Latitud: ${ubicacion['lat'] ?? 'No especificada'}, Longitud: ${ubicacion['lng'] ?? 'No especificada'}');
        } else {
          debugPrint('- Sin ubicación registrada o formato incorrecto');
        }

        // Verificar disponibilidad
        debugPrint('\nDISPONIBILIDAD:');
        final estaEnLinea =
            conductor[ConstantesInteroperabilidad.campoEstaEnLinea] == true;
        final tieneViajeActivo =
            conductor[ConstantesInteroperabilidad.campoIdViajeActivo] != null &&
                conductor[ConstantesInteroperabilidad.campoIdViajeActivo]
                    .toString()
                    .trim()
                    .isNotEmpty;

        debugPrint('- Está en línea: $estaEnLinea');
        debugPrint('- Tiene viaje activo: $tieneViajeActivo');
        debugPrint(
            '- Disponible para viajes: ${estaEnLinea && !tieneViajeActivo}');

        contador++;
      });

      debugPrint('\n=== FIN DE LA VERIFICACIÓN ===\n');
    } catch (e) {
      debugPrint('Error al verificar la estructura de Firebase: $e');
    }
  }
}

// Función de utilidad para mostrar la estructura de un conductor de ejemplo
Map<String, dynamic> getEstructuraConductorEjemplo() {
  return {
    'nombre': 'Nombre del Conductor',
    'telefono': '1234567890',
    'email': 'conductor@ejemplo.com',
    'tipoVehiculo': ConstantesInteroperabilidad.tipoCarro,
    'categoriaServicio': ConstantesInteroperabilidad.categoriaConfort,
    'placa': 'ABC123',
    'calificacion': 4.8,
    'enLinea': true,
    'idViajeActivo': null,
    'ubicacion': {
      'lat': 4.710989, // Reemplaza con coordenadas reales
      'lng': -74.072092
    },
    'fechaRegistro': DateTime.now().toIso8601String(),
    'vehiculo': {
      'marca': 'Marca',
      'modelo': 'Modelo',
      'anio': 2023,
      'color': 'Color',
      'placa': 'ABC123'
    }
  };
}
