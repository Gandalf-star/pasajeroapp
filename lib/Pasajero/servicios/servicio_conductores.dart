import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../../utils/constantes_interoperabilidad.dart';
import '../../utils/click_logger.dart';
import '../../utils/servicio_sincronizacion.dart';
import '../../utils/geohash_utils.dart';
import '../modelos/conductor.dart';

class ServicioConductores {
  final DatabaseReference _baseDeDatos;
  final ServicioSincronizacion _servicioSincronizacion;

  ServicioConductores(this._baseDeDatos, this._servicioSincronizacion);

  Stream<List<Conductor>> obtenerConductoresDisponiblesStream(
      String tipoVehiculo, String categoria,
      {double? lat, double? lng}) {
    try {
      ClickLogger.d(
          'Buscando conductores Geo: $tipoVehiculo - $categoria en ($lat, $lng)');

      Query query =
          _baseDeDatos.child(ConstantesInteroperabilidad.nodoConductores);

      if (lat != null && lng != null) {
        final geohashCentro = GeoHashUtils.encode(
          lat,
          lng,
          precision: ConstantesInteroperabilidad.geohashPrecision,
        );
        ClickLogger.d('Query Geohash: $geohashCentro');

        query = query
            .orderByChild('geohash')
            .startAt(geohashCentro)
            .endAt(GeoHashUtils.nextHash(geohashCentro));
      } else {
        ClickLogger.d('Búsqueda global de conductores (sin lat/lng).');
        query = query
            .orderByChild(ConstantesInteroperabilidad.campoEstaEnLinea)
            .equalTo(true);
      }

      return query.onValue.map((event) {
        if (event.snapshot.value == null) return <Conductor>[];

        final conductoresMap = event.snapshot.value != null
            ? Map<dynamic, dynamic>.from(event.snapshot.value as Map)
            : <dynamic, dynamic>{};
        final conductores = <Conductor>[];

        conductoresMap.forEach((key, value) {
          if (value is! Map) return;

          try {
            final conductorData = Map<String, dynamic>.from(value)
              ..['id'] = key;

            final estaEnLinea =
                conductorData[ConstantesInteroperabilidad.campoEstaEnLinea] ??
                    false;
            final idViajeActivo =
                conductorData[ConstantesInteroperabilidad.campoIdViajeActivo];

            if (!estaEnLinea || idViajeActivo != null) {
              return;
            }

            if (!ConstantesInteroperabilidad.coincideCriterios(
                conductorData, tipoVehiculo, categoria)) {
              return;
            }

            final ubicacion =
                conductorData[ConstantesInteroperabilidad.campoUbicacionActual];
            if (ubicacion is! Map) {
              return;
            }

            final u = Map<String, dynamic>.from(ubicacion);
            final lat = u[ConstantesInteroperabilidad.campoLat] ?? u['lat'];
            final lng = u[ConstantesInteroperabilidad.campoLng] ?? u['lng'];

            if (lat == null || lng == null) {
              return;
            }

            final timestamp = u['timestamp'];
            if (timestamp != null) {
              final ahora = DateTime.now().millisecondsSinceEpoch;
              final diferencia = ahora - timestamp;
              if (diferencia > 300000) {
                return;
              }
            }

            conductores.add(Conductor.fromMap(key.toString(), value));
          } catch (e) {
            ClickLogger.d('Error procesando conductor $key: $e');
          }
        });

        return conductores;
      });
    } catch (e) {
      ClickLogger.d('Error en obtenerConductoresDisponiblesStream: $e');
      return const Stream.empty();
    }
  }

  Future<List<Conductor>> obtenerConductoresDisponibles(
      String tipoVehiculo, String categoria) async {
    try {
      final tipoVehiculoNormalizado =
          _servicioSincronizacion.normalizarTipoVehiculo(tipoVehiculo);
      final categoriaNormalizada =
          _servicioSincronizacion.normalizarCategoria(categoria);

      ClickLogger.d(
          'Buscando conductores para tipo: $tipoVehiculoNormalizado, categoría: $categoriaNormalizada');

      final snapshot = await _baseDeDatos
          .child(ConstantesInteroperabilidad.nodoConductores)
          .orderByChild(ConstantesInteroperabilidad.campoEstaEnLinea)
          .equalTo(true)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        ClickLogger.d('No se encontraron conductores en línea');
        return [];
      }

      final conductoresMap = snapshot.value as Map<dynamic, dynamic>;
      final conductores = <Conductor>[];

      conductoresMap.forEach((key, value) {
        if (value is! Map) return;

        try {
          final conductorData = Map<String, dynamic>.from(value);

          // Usamos la lógica unificada de ConstantesInteroperabilidad
          final esValido =
              ConstantesInteroperabilidad.esConductorDisponible(conductorData);
          final coincide = ConstantesInteroperabilidad.coincideCriterios(
              conductorData, tipoVehiculoNormalizado, categoriaNormalizada);

          if (esValido && coincide) {
            conductores.add(Conductor.fromMap(key.toString(), value));
          } else if (esValido) {
            // Log para debug si el conductor es válido pero no coincide con los criterios
            final tipoC =
                (conductorData[ConstantesInteroperabilidad.campoTipoVehiculo] ??
                        '')
                    .toString();
            final catC =
                (conductorData[ConstantesInteroperabilidad.campoCategoria] ??
                        '')
                    .toString();
            ClickLogger.d(
                'Conductor $key no coincide: ($tipoC, $catC) vs ($tipoVehiculoNormalizado, $categoriaNormalizada)');
          }
        } catch (e) {
          ClickLogger.d('Error procesando conductor $key: $e');
        }
      });

      ClickLogger.d('Total conductores disponibles: ${conductores.length}');
      return conductores;
    } catch (e) {
      ClickLogger.d('Error en obtenerConductoresDisponibles: $e');
      return [];
    }
  }

  Stream<Conductor?> obtenerConductorEnTiempoReal(String idConductor) {
    try {
      return _baseDeDatos
          .child(ConstantesInteroperabilidad.nodoConductores)
          .child(idConductor)
          .onValue
          .map((event) {
        if (event.snapshot.value == null) return null;
        if (event.snapshot.value is! Map) return null;
        final data = Map<String, dynamic>.from(
            event.snapshot.value as Map<dynamic, dynamic>);
        try {
          return Conductor.fromMap(idConductor, data);
        } catch (e) {
          ClickLogger.d('Conductor inválido ($idConductor): $e');
          return null;
        }
      });
    } catch (e) {
      ClickLogger.d('Error en obtenerConductorEnTiempoReal: $e');
      return const Stream.empty();
    }
  }

  Stream<Conductor?> obtenerConductorStream(String idConductor) {
    return _baseDeDatos
        .child(ConstantesInteroperabilidad.nodoConductores)
        .child(idConductor)
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return null;
      try {
        final map = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        return Conductor.fromMap(idConductor, map);
      } catch (e) {
        ClickLogger.d('Error parsing conductor $idConductor: $e');
        return null;
      }
    });
  }
}
