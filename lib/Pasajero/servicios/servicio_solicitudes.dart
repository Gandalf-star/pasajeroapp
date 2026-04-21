import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/constantes_interoperabilidad.dart';
import '../../utils/click_logger.dart';
import '../../utils/servicio_sincronizacion.dart';
import '../../utils/geohash_utils.dart';
import '../modelos/solicitud_viaje.dart';
import '../utils/interoperabilidad/safe_utils.dart';
import 'servicio_conductores.dart';
import 'servicio_billetera.dart';
import 'servicio_perfil_pasajero.dart';

class ServicioSolicitudes {
  final DatabaseReference _baseDeDatos;
  final ServicioSincronizacion _servicioSincronizacion;
  final ServicioConductores _servicioConductores;
  final ServicioBilletera _servicioBilletera;
  final ServicioPerfilPasajero _servicioPerfil;

  ServicioSolicitudes(
    this._baseDeDatos,
    this._servicioSincronizacion,
    this._servicioConductores,
    this._servicioBilletera,
    this._servicioPerfil,
  );

  Stream<List<SolicitudViaje>> obtenerHistorialViajes(String uidPasajero) {
    return _baseDeDatos
        .child(ConstantesInteroperabilidad.nodoSolicitudesViaje)
        .orderByChild(ConstantesInteroperabilidad.campoIdPasajero)
        .equalTo(uidPasajero)
        .limitToLast(20)
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return [];
      final map = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final viajes = <SolicitudViaje>[];
      map.forEach((key, value) {
        try {
          viajes.add(SolicitudViaje.fromMap(key.toString(), value));
        } catch (e) {
          ClickLogger.d('Error parsing viaje $key: $e');
        }
      });
      viajes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return viajes;
    });
  }

  Stream<SolicitudViaje?> obtenerSolicitudEnTiempoReal(String idSolicitud) {
    try {
      return _baseDeDatos
          .child(ConstantesInteroperabilidad.nodoSolicitudesViaje)
          .child(idSolicitud)
          .onValue
          .map((event) {
        if (event.snapshot.value == null) return null;
        if (event.snapshot.value is! Map) return null;
        final data = Map<String, dynamic>.from(
            event.snapshot.value as Map<dynamic, dynamic>);
        try {
          return SolicitudViaje.fromMap(idSolicitud, data);
        } catch (e) {
          ClickLogger.d('Solicitud inválida ($idSolicitud): $e');
          return null;
        }
      });
    } catch (e) {
      ClickLogger.d('Error en obtenerSolicitudEnTiempoReal: $e');
      return const Stream.empty();
    }
  }

  Stream<List<SolicitudViaje>> escucharSolicitudesPorPasajero(
      String uidPasajero) {
    try {
      return _baseDeDatos
          .child(ConstantesInteroperabilidad.nodoSolicitudesViaje)
          .orderByChild(ConstantesInteroperabilidad.campoIdPasajero)
          .equalTo(uidPasajero)
          .onValue
          .map((event) {
        if (event.snapshot.value == null) return <SolicitudViaje>[];

        final map = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        final solicitudes = <SolicitudViaje>[];

        map.forEach((key, value) {
          if (value is! Map) return;
          try {
            final solicitud = SolicitudViaje.fromMap(key.toString(), value);
            final estado = solicitud.estado;
            if (estado == ConstantesInteroperabilidad.estadoCompletado ||
                estado == ConstantesInteroperabilidad.estadoCancelado ||
                estado == 'cancelado' ||
                estado == 'cancelado_por_pasajero' ||
                estado == 'cancelado_por_conductor' ||
                estado == 'rechazado' ||
                estado == 'error' ||
                estado == 'error_busqueda') {
              return;
            }
            if (estado == ConstantesInteroperabilidad.estadoSolicitado ||
                estado == 'solicitado' ||
                estado == 'buscando_conductor' ||
                estado == 'pendiente' ||
                estado == ConstantesInteroperabilidad.estadoAceptado ||
                estado == ConstantesInteroperabilidad.estadoEnCamino ||
                estado == ConstantesInteroperabilidad.estadoLlegado ||
                estado == ConstantesInteroperabilidad.estadoEnViaje ||
                estado == 'en_viaje') {
              solicitudes.add(solicitud);
            }
          } catch (e) {
            ClickLogger.d('Error parsing solicitud $key: $e');
          }
        });

        return solicitudes;
      });
    } catch (e) {
      ClickLogger.d('Error en escucharSolicitudesPorPasajero: $e');
      return const Stream.empty();
    }
  }

  Future<SolicitudViaje?> verificarViajeActivo(String uidPasajero) async {
    try {
      final snapshot = await _baseDeDatos
          .child(ConstantesInteroperabilidad.nodoSolicitudesViaje)
          .orderByChild(ConstantesInteroperabilidad.campoIdPasajero)
          .equalTo(uidPasajero)
          .get()
          .timeout(const Duration(seconds: 8));

      if (snapshot.exists && snapshot.value is Map) {
        final map = Map<dynamic, dynamic>.from(snapshot.value as Map);

        SolicitudViaje? solicitudActiva;
        int timestampMasReciente = 0;

        final estadosFinalizados = <String>{
          'completado',
          'cancelado',
          'cancelado_por_pasajero',
          'cancelado_por_conductor',
          'rechazado',
          'error',
          'error_busqueda',
          'rechazado_por_pasajero',
          'rechazado_por_conductor',
        };

        for (final entry in map.entries) {
          if (entry.value is! Map) continue;
          try {
            final data = Map<String, dynamic>.from(entry.value as Map);
            final estado =
                data[ConstantesInteroperabilidad.campoEstado]?.toString();

            if (estado != null && estadosFinalizados.contains(estado)) continue;

            final timestamp =
                data[ConstantesInteroperabilidad.campoTimestamp] as int? ?? 0;
            final ahora = DateTime.now().millisecondsSinceEpoch;
            const tiempoLimite = 24 * 60 * 60 * 1000;
            if (timestamp > 0 && (ahora - timestamp) > tiempoLimite) continue;

            final estadosActivos = <String>{
              'solicitado',
              'buscando_conductor',
              'pendiente',
              'aceptado',
              'en_camino',
              'llegado',
              'en_viaje'
            };

            if (estado != null && estadosActivos.contains(estado)) {
              if (timestamp >= timestampMasReciente) {
                solicitudActiva =
                    SolicitudViaje.fromMap(entry.key.toString(), data);
                timestampMasReciente = timestamp;
              }
            }
          } catch (e) {
            ClickLogger.d('Error verificando viaje activo: $e');
          }
        }

        return solicitudActiva;
      }

      return null;
    } catch (e) {
      ClickLogger.d('Error al verificar viaje activo: $e');
      return null;
    }
  }

  Future<String?> enviarSolicitudViaje({
    required String uidPasajero,
    required String tipoVehiculo,
    required String categoria,
    required double precio,
    required String origenNombre,
    required String destinoNombre,
    double? destinoLat,
    double? destinoLng,
    Map<String, dynamic>? preferencias,
    required Position posicionActual,
    required String nombrePasajero,
    required String telefonoPasajero,
    String? idConductor,
    required Function(String mensaje, String idViaje) onSuccess,
    required Function(String error) onError,
  }) async {
    bool exitoNotificado = false;
    final tipoVehiculoNormalizado =
        _servicioSincronizacion.normalizarTipoVehiculo(tipoVehiculo);
    final categoriaNormalizada =
        _servicioSincronizacion.normalizarCategoria(categoria);

    ClickLogger.d(
        'Preparando solicitud de viaje: $tipoVehiculoNormalizado - $categoriaNormalizada');

    if (uidPasajero.isEmpty ||
        nombrePasajero.isEmpty ||
        telefonoPasajero.isEmpty) {
      ClickLogger.d('Error de validación: Datos del pasajero incompletos');
      onError('Datos del pasajero incompletos. Por favor, complete su perfil.');
      return null;
    }

    try {
      final pasajeroSnapshot = await _baseDeDatos
          .child(ConstantesInteroperabilidad.nodoPasajeros)
          .child(uidPasajero)
          .get();

      if (!pasajeroSnapshot.exists) {
        ClickLogger.d('Error: Pasajero no registrado en el nodo correcto');
        onError(
            'Usuario no registrado correctamente. Por favor, reinicie la aplicación.');
        return null;
      }
    } catch (e) {
      ClickLogger.d('Error al validar registro del pasajero: $e');
      onError('Error al validar el registro del usuario.');
      return null;
    }

    try {
      final solicitudRef = _baseDeDatos
          .child(ConstantesInteroperabilidad.nodoSolicitudesViaje)
          .push();
      final String idSolicitud = solicitudRef.key!;
      final int timestamp = DateTime.now().millisecondsSinceEpoch;

      await _servicioPerfil.actualizarPerfilPasajero(
        uid: uidPasajero,
        nombre: nombrePasajero,
        telefono: telefonoPasajero,
      );

      final datosSolicitud = <String, dynamic>{
        'pasajero': {
          ConstantesInteroperabilidad.campoIdPasajero: uidPasajero,
          ConstantesInteroperabilidad.campoNombrePasajero: nombrePasajero,
          ConstantesInteroperabilidad.campoTelefonoPasajero: telefonoPasajero,
        },
        ConstantesInteroperabilidad.campoIdPasajero: uidPasajero,
        ConstantesInteroperabilidad.campoNombrePasajero: nombrePasajero,
        ConstantesInteroperabilidad.campoTelefonoPasajero: telefonoPasajero,
        if (idConductor != null)
          ConstantesInteroperabilidad.campoIdConductor: idConductor,
        ConstantesInteroperabilidad.campoTipoVehiculo: tipoVehiculoNormalizado,
        ConstantesInteroperabilidad.campoCategoria: categoriaNormalizada,
        ConstantesInteroperabilidad.campoPrecio: precio,
        'idSolicitud': idSolicitud,
        'geohash': GeoHashUtils.encode(
            posicionActual.latitude, posicionActual.longitude,
            precision: 5),
        ConstantesInteroperabilidad.campoOrigen: {
          ConstantesInteroperabilidad.campoLat: posicionActual.latitude,
          ConstantesInteroperabilidad.campoLng: posicionActual.longitude,
          ConstantesInteroperabilidad.campoNombre: origenNombre,
          'direccion': origenNombre,
        },
        ConstantesInteroperabilidad.campoDestino: {
          ConstantesInteroperabilidad.campoLat: destinoLat ?? 0.0,
          ConstantesInteroperabilidad.campoLng: destinoLng ?? 0.0,
          ConstantesInteroperabilidad.campoNombre: destinoNombre,
          'direccion': destinoNombre,
        },
        'destinoLat': destinoLat ?? 0.0,
        'destinoLng': destinoLng ?? 0.0,
        ConstantesInteroperabilidad.campoEstado:
            ConstantesInteroperabilidad.estadoSolicitado,
        ConstantesInteroperabilidad.campoTimestamp: timestamp,
        if (preferencias != null) 'preferencias': preferencias,
        'fechaCreacion': ServerValue.timestamp,
        'fechaActualizacion': ServerValue.timestamp,
        'busquedaExpansiva': false,
      };

      if (!_validarDatosSolicitud(datosSolicitud)) {
        onError('Error en la estructura de datos de la solicitud');
        return null;
      }

      final updates = <String, dynamic>{};
      final solicitudPath =
          '${ConstantesInteroperabilidad.nodoSolicitudesViaje}/$idSolicitud';
      updates[solicitudPath] = datosSolicitud;

      final pasajeroPath =
          '${ConstantesInteroperabilidad.nodoPasajeros}/$uidPasajero/solicitudActiva';
      updates[pasajeroPath] = {
        'id': idSolicitud,
        ConstantesInteroperabilidad.campoEstado:
            ConstantesInteroperabilidad.estadoSolicitado,
        ConstantesInteroperabilidad.campoTipoVehiculo: tipoVehiculoNormalizado,
        ConstantesInteroperabilidad.campoCategoria: categoriaNormalizada,
        ConstantesInteroperabilidad.campoPrecio: precio,
        ConstantesInteroperabilidad.campoOrigen: {
          ConstantesInteroperabilidad.campoLat: posicionActual.latitude,
          ConstantesInteroperabilidad.campoLng: posicionActual.longitude,
          ConstantesInteroperabilidad.campoNombre: origenNombre,
          'direccion': origenNombre,
        },
        ConstantesInteroperabilidad.campoDestino: {
          ConstantesInteroperabilidad.campoLat: destinoLat ?? 0.0,
          ConstantesInteroperabilidad.campoLng: destinoLng ?? 0.0,
          ConstantesInteroperabilidad.campoNombre: destinoNombre,
          'direccion': destinoNombre,
        },
        ConstantesInteroperabilidad.campoTimestamp: timestamp,
        'fechaActualizacion': ServerValue.timestamp,
      };

      await _baseDeDatos.update(updates);

      ClickLogger.d('Solicitud de viaje guardada correctamente: $idSolicitud');

      try {
        Future.microtask(() {
          onSuccess("Solicitud de viaje registrada. Buscando conductors...",
              idSolicitud);
        });
        exitoNotificado = true;
      } catch (callbackError) {
        ClickLogger.d('Error al ejecutar callback onSuccess: $callbackError');
      }

      Future.delayed(const Duration(milliseconds: 500), () {
        _buscarYNotificarConductoresDisponibles(
            tipoVehiculoNormalizado, idSolicitud);
      });

      Future.delayed(const Duration(seconds: 30), () async {
        try {
          final snap = await _baseDeDatos
              .child(ConstantesInteroperabilidad.nodoSolicitudesViaje)
              .child(idSolicitud)
              .child('estado')
              .get();

          if (snap.exists &&
              (snap.value == ConstantesInteroperabilidad.estadoSolicitado ||
                  snap.value == 'buscando_conductor' ||
                  snap.value == 'pendiente')) {
            ClickLogger.d('Búsqueda expansiva: Expandiendo radio...');

            await _baseDeDatos
                .child(ConstantesInteroperabilidad.nodoSolicitudesViaje)
                .child(idSolicitud)
                .update({
              'geohash': GeoHashUtils.encode(
                  posicionActual.latitude, posicionActual.longitude,
                  precision: 4),
              'busquedaExpansiva': true,
              'fechaActualizacion': ServerValue.timestamp,
            });

            _buscarYNotificarConductoresDisponibles(
                tipoVehiculoNormalizado, idSolicitud);
          }
        } catch (e) {
          ClickLogger.d('Error en búsqueda expansiva: $e');
        }
      });

      return idSolicitud;
    } catch (e) {
      ClickLogger.d('Error general al enviar solicitud de viaje: $e');
      if (!exitoNotificado) {
        onError(
            'Error al registrar la solicitud. Verifica tu conexión a internet e inténtalo de nuevo.');
      }
      return null;
    }
  }

  Future<void> _buscarYNotificarConductoresDisponibles(
      String tipoVehiculo, String idSolicitud) async {
    ClickLogger.d(
        'Iniciando búsqueda de conductores para solicitud: $idSolicitud');
    try {
      final solicitudSnapshot = await _baseDeDatos
          .child(ConstantesInteroperabilidad.nodoSolicitudesViaje)
          .child(idSolicitud)
          .get();

      if (!solicitudSnapshot.exists) {
        ClickLogger.d('Solicitud no encontrada: $idSolicitud');
        await _actualizarEstadoSolicitud(
            idSolicitud, ConstantesInteroperabilidad.estadoError);
        return;
      }

      final solicitudData =
          Map<String, dynamic>.from(solicitudSnapshot.value as Map);
      final categoriaRequerida =
          solicitudData[ConstantesInteroperabilidad.campoCategoriaRequerida] ??
              solicitudData[ConstantesInteroperabilidad.campoCategoria] ??
              ConstantesInteroperabilidad.categoriaEconomico;

      final conductoresDisponibles = await _servicioConductores
          .obtenerConductoresDisponibles(tipoVehiculo, categoriaRequerida);

      if (conductoresDisponibles.isEmpty) {
        ClickLogger.d('No se encontraron conductores disponibles');
        final currentSnap = await _baseDeDatos
            .child(ConstantesInteroperabilidad.nodoSolicitudesViaje)
            .child(idSolicitud)
            .child('estado')
            .get();

        if (currentSnap.exists &&
            currentSnap.value == ConstantesInteroperabilidad.estadoSolicitado) {
          await _actualizarEstadoSolicitud(
              idSolicitud, ConstantesInteroperabilidad.estadoBuscandoConductor);
        }
      } else {
        ClickLogger.d(
            'Encontrados ${conductoresDisponibles.length} conductores disponibles');
        await _notificarConductores(conductoresDisponibles, idSolicitud);
      }
    } catch (e) {
      ClickLogger.d('Error en búsqueda de conductors: $e');
    }
  }

  Future<void> _actualizarEstadoSolicitud(
      String idSolicitud, String estado) async {
    try {
      await _baseDeDatos
          .child(
              '${ConstantesInteroperabilidad.nodoSolicitudesViaje}/$idSolicitud/${ConstantesInteroperabilidad.campoEstado}')
          .set(estado);

      final snapshot = await _baseDeDatos
          .child(ConstantesInteroperabilidad.nodoSolicitudesViaje)
          .child(idSolicitud)
          .child(ConstantesInteroperabilidad.campoIdPasajero)
          .get();

      if (snapshot.exists) {
        final idPasajero = snapshot.value as String;
        await _baseDeDatos
            .child(
                '${ConstantesInteroperabilidad.nodoPasajeros}/$idPasajero/solicitudActiva/estado')
            .set(estado);
      }
    } catch (e) {
      ClickLogger.d('Error al actualizar estado: $e');
    }
  }

  Future<void> _notificarConductores(List drivers, String idSolicitud) async {
    ClickLogger.d(
        'Notificando ${drivers.length} conductores sobre solicitud $idSolicitud');
  }

  Future<bool> cancelarSolicitudViaje(
      String idSolicitud, String uidPasajero) async {
    try {
      final updates = <String, dynamic>{};

      updates['${ConstantesInteroperabilidad.nodoSolicitudesViaje}/$idSolicitud/${ConstantesInteroperabilidad.campoEstado}'] =
          ConstantesInteroperabilidad.estadoCancelado;
      updates['${ConstantesInteroperabilidad.nodoSolicitudesViaje}/$idSolicitud/timestampActualizacion'] =
          ServerValue.timestamp;
      updates['${ConstantesInteroperabilidad.nodoPasajeros}/$uidPasajero/solicitudActiva'] =
          null;

      await _baseDeDatos.update(updates);

      ClickLogger.d('Solicitud $idSolicitud cancelada exitosamente');
      return true;
    } catch (e) {
      ClickLogger.d('Error al cancelar solicitud: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> cancelarSolicitud(String idSolicitud) async {
    final db = _baseDeDatos;

    try {
      final snapSolicitud = await db
          .child(ConstantesInteroperabilidad.nodoSolicitudesViaje)
          .child(idSolicitud)
          .get();

      String? idConductorAceptante;
      double precioCorrida = 0.0;
      String estadoActual = '';

      if (snapSolicitud.exists && snapSolicitud.value is Map) {
        final data = Map<String, dynamic>.from(snapSolicitud.value as Map);
        estadoActual = data['estado']?.toString() ?? '';
        precioCorrida = SafeUtils.safeDouble(data['precio']);
        if (estadoActual == ConstantesInteroperabilidad.estadoAceptado) {
          idConductorAceptante = data['idConductor']?.toString();
        }
      }

      final resultadoPenalizacion =
          await _servicioBilletera.aplicarPenalizacion(
        idSolicitud: idSolicitud,
        precioCorrida: precioCorrida,
        estadoActual: estadoActual,
        idConductorAceptante: idConductorAceptante,
      );

      final Map<String, dynamic> updateSolicitud = {
        'estado': 'cancelado_por_pasajero',
        'timestampCancelacion': ServerValue.timestamp,
      };

      if (resultadoPenalizacion['penalizado'] == true) {
        updateSolicitud['penalizacion'] = {
          'aplicada': true,
          'monto': resultadoPenalizacion['montoPenalizacion'],
          'montoAcreditadoConductor':
              resultadoPenalizacion['montoAcreditadoConductor'],
          'timestamp': ServerValue.timestamp,
        };
      }

      await db
          .child(ConstantesInteroperabilidad.nodoSolicitudesViaje)
          .child(idSolicitud)
          .update(updateSolicitud);

      try {
        final snapViaje = await db
            .child(
                '${ConstantesInteroperabilidad.nodoViajesActivos}/$idSolicitud')
            .get();
        if (snapViaje.exists) {
          await db
              .child(
                  '${ConstantesInteroperabilidad.nodoViajesActivos}/$idSolicitud')
              .update({'estado': 'cancelado_por_pasajero'});
        }
      } catch (_) {}

      return {'exito': true, ...resultadoPenalizacion};
    } catch (e) {
      ClickLogger.d('Error al cancelar solicitud: $e');
      rethrow;
    }
  }

  bool _validarDatosSolicitud(Map<String, dynamic> datosSolicitud) {
    final tieneTipoVehiculo = datosSolicitud
            .containsKey(ConstantesInteroperabilidad.campoTipoVehiculo) ||
        datosSolicitud.containsKey(
            ConstantesInteroperabilidad.campoTipoVehiculoRequerido);
    if (!tieneTipoVehiculo) {
      ClickLogger.d('Campo requerido faltante: tipoVehiculo');
    }

    final tieneCategoria = datosSolicitud
            .containsKey(ConstantesInteroperabilidad.campoCategoria) ||
        datosSolicitud
            .containsKey(ConstantesInteroperabilidad.campoCategoriaRequerida);
    if (!tieneCategoria) {
      ClickLogger.d('Campo requerido faltante: categoria');
    }

    final validaciones = <bool>[
      tieneTipoVehiculo,
      tieneCategoria,
      _validarCampo(datosSolicitud, ConstantesInteroperabilidad.campoPrecio),
      _validarCampo(
          datosSolicitud, ConstantesInteroperabilidad.campoIdPasajero),
      _validarCampo(
          datosSolicitud, ConstantesInteroperabilidad.campoNombrePasajero),
      _validarCampo(
          datosSolicitud, ConstantesInteroperabilidad.campoTelefonoPasajero),
    ];

    final tipoVehiculo = datosSolicitud[
            ConstantesInteroperabilidad.campoTipoVehiculo] ??
        datosSolicitud[ConstantesInteroperabilidad.campoTipoVehiculoRequerido];
    if (tipoVehiculo != null &&
        ![
          ConstantesInteroperabilidad.tipoCarro,
          ConstantesInteroperabilidad.tipoMoto
        ].contains(tipoVehiculo.toString())) {
      ClickLogger.d('Tipo de vehículo inválido: $tipoVehiculo');
      return false;
    }

    final categoria =
        datosSolicitud[ConstantesInteroperabilidad.campoCategoria] ??
            datosSolicitud[ConstantesInteroperabilidad.campoCategoriaRequerida];
    if (categoria != null &&
        ![
          ConstantesInteroperabilidad.categoriaEconomico,
          ConstantesInteroperabilidad.categoriaConfort,
          ConstantesInteroperabilidad.categoriaViajesL,
          'premium'
        ].contains(categoria.toString())) {
      ClickLogger.d('Categoría inválida: $categoria');
      return false;
    }

    final precio = datosSolicitud[ConstantesInteroperabilidad.campoPrecio];
    if (precio == null || precio is! num || precio <= 0) {
      ClickLogger.d('Precio inválido: $precio');
      return false;
    }

    return !validaciones.contains(false);
  }

  bool _validarCampo(Map<String, dynamic> datos, String campo) {
    if (datos[campo] == null || datos[campo].toString().trim().isEmpty) {
      ClickLogger.d('Campo requerido faltante: $campo');
      return false;
    }
    return true;
  }
}
