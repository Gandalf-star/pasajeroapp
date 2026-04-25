import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:clickexpress/Pasajero/modelos/viaje_modelo.dart';
import 'package:clickexpress/utils/constantes_interoperabilidad.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import '../../utils/click_logger.dart';

class ServicioSeguimientoViaje {
  static final ServicioSeguimientoViaje _instance =
      ServicioSeguimientoViaje._internal();
  factory ServicioSeguimientoViaje() => _instance;
  ServicioSeguimientoViaje._internal();

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  StreamSubscription<DatabaseEvent>? _viajeSubscription;
  StreamSubscription<DatabaseEvent>? _conductorSubscription;
  StreamSubscription<DatabaseEvent>? _viajeActivoSubscription;
  StreamSubscription<DatabaseEvent>? _conductorDataSubscription;

  final StreamController<ViajeModelo?> _viajeController =
      StreamController<ViajeModelo?>.broadcast();
  final StreamController<UbicacionModelo?> _ubicacionConductorController =
      StreamController<UbicacionModelo?>.broadcast();

  Stream<ViajeModelo?> get viajeStream => _viajeController.stream;
  Stream<UbicacionModelo?> get ubicacionConductorStream =>
      _ubicacionConductorController.stream;

  ViajeModelo? _viajeActual;
  ViajeModelo? get viajeActual => _viajeActual;

  final Map<String, Map<String, dynamic>> _cacheConductores = {};

  void _cancelarTodasLasSubscriptions() {
    _viajeSubscription?.cancel();
    _viajeSubscription = null;
    _conductorSubscription?.cancel();
    _conductorSubscription = null;
    _viajeActivoSubscription?.cancel();
    _viajeActivoSubscription = null;
    _conductorDataSubscription?.cancel();
    _conductorDataSubscription = null;
    _cacheConductores.clear();
  }

  /// Inicia el seguimiento de un viaje específico
  /// Inicia el seguimiento de un viaje específico
  Future<void> iniciarSeguimientoViaje(String idViaje) async {
    debugPrint('Iniciando seguimiento del viaje: $idViaje');
    try {
      detenerSeguimiento();

      _viajeSubscription = _dbRef
          .child(ConstantesInteroperabilidad.nodoSolicitudesViaje)
          .child(idViaje)
          .onValue
          .listen((event) {
        // 1. Si la solicitud ya no existe en este nodo, buscamos en viajes_activos
        if (!event.snapshot.exists) {
          debugPrint(
              'Solicitud no encontrada en nodo pendiente, buscando en activos...');
          _escucharViajeActivo(idViaje);
          // IMPORTANTE: Cancelamos esta suscripción para no quedar escuchando un nodo vacío
          _viajeSubscription?.cancel();
          return;
        }

        try {
          if (event.snapshot.value is Map) {
            final data = Map<String, dynamic>.from(event.snapshot.value as Map);

            String? idConductor = data['idConductor']?.toString();
            Map<String, dynamic>? datosConductor;
            if (idConductor != null && idConductor.isNotEmpty) {
              datosConductor = _cacheConductores[idConductor];
              if (datosConductor == null) {
                _obtenerYEnriquecerDatosConductor(idConductor);
                _escucharDatosConductor(idConductor);
              }
            }

            _viajeActual = ViajeModelo.fromMap(data, idViaje,
                datosConductor: datosConductor);
            _viajeController.add(_viajeActual);

            // 2. Si ya tiene un ID de viaje activo diferente o se confirma el paso a activo
            final idViajeActivo =
                (data[ConstantesInteroperabilidad.campoIdViajeActivo] ??
                        data['idViajeActivo'] ??
                        '')
                    .toString();

            if (idViajeActivo.isNotEmpty) {
              _escucharViajeActivo(idViajeActivo);
              _viajeSubscription
                  ?.cancel(); // Dejamos de escuchar la solicitud, ahora mandan los "activos"
            }

            // 3. Escuchar ubicación solo si hay conductor
            if (_viajeActual?.idConductor != null) {
              _escucharUbicacionConductor(_viajeActual!.idConductor!);
            }
          }
        } catch (e) {
          debugPrint('Error procesando data: $e');
        }
      }, onError: (error) {
        debugPrint('ERROR Firebase: $error');
        _viajeController.addError(error);
      });
    } catch (e) {
      _viajeController.addError(e);
    }
  }

  /// Escucha el viaje activo (viajes_activos/{id}) cuando existe
  void _escucharViajeActivo(String idViajeActivo,
      {int reintentos = 0, int maxReintentos = 5}) {
    // 1. Cancelamos cualquier suscripción previa para este nodo
    _viajeActivoSubscription?.cancel();

    _viajeActivoSubscription = _dbRef
        .child(ConstantesInteroperabilidad.nodoViajesActivos)
        .child(idViajeActivo)
        .onValue
        .listen((event) {
      // Reiniciamos contador de reintentos tras un evento exitoso
      reintentos = 0;

      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);

        final String? idConductorAnterior = _viajeActual?.idConductor;
        final String? idConductorNuevo = data['idConductor']?.toString();

        Map<String, dynamic>? datosConductor;
        if (idConductorNuevo != null && idConductorNuevo.isNotEmpty) {
          datosConductor = _cacheConductores[idConductorNuevo];
          if (datosConductor == null) {
            _obtenerYEnriquecerDatosConductor(idConductorNuevo);
            _escucharDatosConductor(idConductorNuevo);
          }
        }

        _viajeActual = ViajeModelo.fromMap(data, idViajeActivo,
            datosConductor: datosConductor);
        _viajeController.add(_viajeActual);

        // 2. Gestión de estados finales — incluir TODAS las variantes de cancelación
        final estadoStr =
            data[ConstantesInteroperabilidad.campoEstado]?.toString() ?? '';
        final esEstadoFinal = _viajeActual?.estado == EstadoViaje.cancelado ||
            _viajeActual?.estado == EstadoViaje.completado ||
            _viajeActual?.estado == EstadoViaje.canceladoPorConductor ||
            _viajeActual?.estado == EstadoViaje.canceladoPorPasajero ||
            estadoStr == 'cancelado_por_conductor' ||
            estadoStr == 'cancelado_por_pasajero' ||
            estadoStr == 'cancelado' ||
            estadoStr == 'completado';

        if (esEstadoFinal) {
          debugPrint(
              '[FlashDrive] Viaje finalizado ($estadoStr). Deteniendo flujos.');
          detenerSeguimiento();
          return; // Salimos para no re-activar la ubicación
        }

        // 3. OPTIMIZACIÓN: Solo escuchar ubicación si el conductor es nuevo o cambió
        if (_viajeActual?.idConductor != null &&
            _viajeActual?.idConductor != idConductorAnterior) {
          debugPrint(
              '[FlashDrive] Nuevo conductor asignado: ${_viajeActual!.idConductor}');
          _escucharUbicacionConductor(_viajeActual!.idConductor!);
        }
      } else {
        // Si el snapshot no existe, emitimos el último estado conocido
        _viajeController.add(_viajeActual);
      }
    }, onError: (error) async {
      _cancelarTodasLasSubscriptions();

      if (reintentos < maxReintentos) {
        final nuevosReintentos = reintentos + 1;
        int segundosEspera = (math.pow(2, nuevosReintentos)).toInt();

        ClickLogger.d(
            'Error en Stream Viaje Activo. Reintentando en $segundosEspera s');

        await Future.delayed(Duration(seconds: segundosEspera));

        _escucharViajeActivo(idViajeActivo, reintentos: nuevosReintentos);
      } else {
        ClickLogger.d('Máximo de reintentos alcanzado.');
        _viajeController.addError('Error de conexión persistente en el viaje.');
      }
    });
  }

  /// Escucha la ubicación del conductor en tiempo real
  void _escucharUbicacionConductor(String idConductor) {
    _conductorSubscription?.cancel();

    debugPrint(
        '[SEGUIMIENTO] Iniciando escucha de ubicación del conductor: $idConductor');

    _conductorSubscription = _dbRef
        .child(ConstantesInteroperabilidad.nodoConductores)
        .child(idConductor)
        .child(ConstantesInteroperabilidad.campoUbicacionActual)
        .onValue
        .listen((event) {
      if (event.snapshot.exists && event.snapshot.value is Map) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        debugPrint('[SEGUIMIENTO] Ubicación del conductor recibida: $data');
        final ubicacion = UbicacionModelo.fromMap(data);
        _ubicacionConductorController.add(ubicacion);
      } else {
        debugPrint('[SEGUIMIENTO] Datos de ubicación vacíos o inválidos');
      }
    }, onError: (error) {
      debugPrint(
          '[SEGUIMIENTO] Error al escuchar ubicación del conductor: $error');
    });
  }

  Future<void> _obtenerYEnriquecerDatosConductor(String idConductor) async {
    if (_cacheConductores.containsKey(idConductor)) return;

    try {
      final snapshot = await _dbRef
          .child(ConstantesInteroperabilidad.nodoConductores)
          .child(idConductor)
          .get();

      if (snapshot.exists && snapshot.value is Map) {
        final conductorData = Map<String, dynamic>.from(snapshot.value as Map);
        _cacheConductores[idConductor] = conductorData;

        debugPrint(
            '[SEGUIMIENTO] Datos del conductor obtenidos: ${conductorData['nombre']}');

        if (_viajeActual != null && _viajeActual!.idConductor == idConductor) {
          if (_viajeActual!.nombreConductor == null ||
              _viajeActual!.nombreConductor!.isEmpty ||
              _viajeActual!.telefonoConductor == null ||
              _viajeActual!.placaVehiculo == null) {
            final viajeEnriquecido = ViajeModelo.fromMap(
              {
                ..._viajeActual!.toMap(),
                'nombreConductor':
                    conductorData[ConstantesInteroperabilidad.campoNombre],
                'telefonoConductor':
                    conductorData[ConstantesInteroperabilidad.campoTelefono],
                'placaVehiculo':
                    conductorData[ConstantesInteroperabilidad.campoPlaca],
              },
              _viajeActual!.id,
              datosConductor: conductorData,
            );

            _viajeActual = viajeEnriquecido;
            _viajeController.add(_viajeActual);
            debugPrint(
                '[SEGUIMIENTO] Viaje enriquecido con datos del conductor');
          }
        }
      }
    } catch (e) {
      debugPrint('[SEGUIMIENTO] Error obteniendo datos del conductor: $e');
    }
  }

  void _escucharDatosConductor(String idConductor) {
    if (_cacheConductores.containsKey(idConductor)) {
      if (_viajeActual != null &&
          (_viajeActual!.nombreConductor == null ||
              _viajeActual!.nombreConductor!.isEmpty)) {
        final conductorData = _cacheConductores[idConductor]!;
        final viajeEnriquecido = ViajeModelo.fromMap(
          {..._viajeActual!.toMap()},
          _viajeActual!.id,
          datosConductor: conductorData,
        );
        _viajeActual = viajeEnriquecido;
        _viajeController.add(_viajeActual);
      }
      return;
    }

    _conductorDataSubscription?.cancel();

    _conductorDataSubscription = _dbRef
        .child(ConstantesInteroperabilidad.nodoConductores)
        .child(idConductor)
        .onValue
        .listen((event) async {
      if (event.snapshot.exists && event.snapshot.value is Map) {
        final conductorData =
            Map<String, dynamic>.from(event.snapshot.value as Map);
        _cacheConductores[idConductor] = conductorData;

        if (_viajeActual != null && _viajeActual!.idConductor == idConductor) {
          if (_viajeActual!.nombreConductor == null ||
              _viajeActual!.nombreConductor!.isEmpty) {
            final viajeEnriquecido = ViajeModelo.fromMap(
              {..._viajeActual!.toMap()},
              _viajeActual!.id,
              datosConductor: conductorData,
            );
            _viajeActual = viajeEnriquecido;
            _viajeController.add(_viajeActual);
            debugPrint('[SEGUIMIENTO] Viaje enriquecido en tiempo real');
          }
        }
      }
    });
  }

  /// Busca el viaje activo del pasajero
  Future<ViajeModelo?> buscarViajeActivoPasajero(String idPasajero) async {
    try {
      final snapshot = await _dbRef
          .child(ConstantesInteroperabilidad.nodoSolicitudesViaje)
          .orderByChild(ConstantesInteroperabilidad.campoIdPasajero)
          .equalTo(idPasajero)
          .once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<String, dynamic>;

        for (final entry in data.entries) {
          final viajeData = entry.value as Map<String, dynamic>;
          final estado = EstadoViajeExtension.fromString(
              viajeData[ConstantesInteroperabilidad.campoEstado] ??
                  'pendiente');

          if (estado != EstadoViaje.completado &&
              estado != EstadoViaje.cancelado &&
              estado != EstadoViaje.canceladoPorConductor &&
              estado != EstadoViaje.canceladoPorPasajero) {
            String? idConductor = viajeData['idConductor']?.toString();
            Map<String, dynamic>? datosConductor;

            if (idConductor != null && idConductor.isNotEmpty) {
              datosConductor = _cacheConductores[idConductor];
              if (datosConductor == null) {
                try {
                  final snapConductor = await _dbRef
                      .child(ConstantesInteroperabilidad.nodoConductores)
                      .child(idConductor)
                      .get();
                  if (snapConductor.exists && snapConductor.value is Map) {
                    datosConductor =
                        Map<String, dynamic>.from(snapConductor.value as Map);
                    _cacheConductores[idConductor] = datosConductor;
                  }
                } catch (_) {}
              }
            }

            return ViajeModelo.fromMap(viajeData, entry.key,
                datosConductor: datosConductor);
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error al buscar viaje activo: $e');
      return null;
    }
  }

  /// Cancela un viaje por parte del pasajero
  Future<bool> cancelarViaje(String idViaje, String razon) async {
    try {
      final ahora = DateTime.now().millisecondsSinceEpoch;

      // Obtener datos del viaje para poder limpiar al conductor
      String? idConductor;
      String? idPasajero;
      try {
        final snap = await _dbRef
            .child(ConstantesInteroperabilidad.nodoViajesActivos)
            .child(idViaje)
            .get();
        if (snap.exists && snap.value is Map) {
          final d = Map<String, dynamic>.from(snap.value as Map);
          idConductor = d['idConductor']?.toString();
          idPasajero = d['idPasajero']?.toString();
        }
        // Fallback desde solicitudes_viaje
        if (idConductor == null || idPasajero == null) {
          final snapSol = await _dbRef
              .child(ConstantesInteroperabilidad.nodoSolicitudesViaje)
              .child(idViaje)
              .get();
          if (snapSol.exists && snapSol.value is Map) {
            final d = Map<String, dynamic>.from(snapSol.value as Map);
            idConductor ??= d['idConductor']?.toString();
            idPasajero ??= d['idPasajero']?.toString();
          }
        }
      } catch (e) {
        debugPrint('Error obteniendo datos para cancelación: $e');
      }

      // Actualización atómica de todos los nodos
      final Map<String, dynamic> atomicUpdates = {
        // Cancelar la solicitud
        '${ConstantesInteroperabilidad.nodoSolicitudesViaje}/$idViaje/${ConstantesInteroperabilidad.campoEstado}':
            'cancelado_por_pasajero',
        '${ConstantesInteroperabilidad.nodoSolicitudesViaje}/$idViaje/razonCancelacion':
            razon,
        '${ConstantesInteroperabilidad.nodoSolicitudesViaje}/$idViaje/timestampCancelacion':
            ahora,
        // Cancelar el viaje activo
        '${ConstantesInteroperabilidad.nodoViajesActivos}/$idViaje/${ConstantesInteroperabilidad.campoEstado}':
            'cancelado_por_pasajero',
        '${ConstantesInteroperabilidad.nodoViajesActivos}/$idViaje/timestampCancelacion':
            ahora,
      };

      // Limpiar solicitudActiva del pasajero
      idPasajero ??= _viajeActual?.idPasajero;
      if (idPasajero != null && idPasajero.isNotEmpty) {
        atomicUpdates[
                '${ConstantesInteroperabilidad.nodoPasajeros}/$idPasajero/solicitudActiva'] =
            null;
      }

      // CRÍTICO: Liberar al conductor para que pueda aceptar nuevos viajes
      if (idConductor != null && idConductor.isNotEmpty) {
        atomicUpdates[
                '${ConstantesInteroperabilidad.nodoConductores}/$idConductor/idViajeActivo'] =
            null;
        atomicUpdates[
                '${ConstantesInteroperabilidad.nodoConductores}/$idConductor/disponible'] =
            true;
        atomicUpdates['usuarios/$idConductor/idViajeActivo'] = null;
        atomicUpdates['usuarios/$idConductor/disponible'] = true;
      }

      await _dbRef.update(atomicUpdates);
      debugPrint('[CANCELAR_PASAJERO] Viaje $idViaje cancelado atómicamente.');
      return true;
    } catch (e) {
      debugPrint('Error al cancelar viaje: $e');

      // Verificar si el estado cambió a pesar del error
      try {
        final snapshot = await _dbRef
            .child(ConstantesInteroperabilidad.nodoSolicitudesViaje)
            .child(idViaje)
            .child('estado')
            .get();
        if (snapshot.value == 'cancelado_por_pasajero') {
          debugPrint('Estado cambió correctamente a pesar del error');
          return true;
        }
      } catch (_) {}

      return false;
    }
  }

  /// Califica al conductor al finalizar el viaje
  Future<bool> calificarConductor(String idViaje, String idConductor,
      double calificacion, String? comentario) async {
    try {
      // Actualizar calificación en el viaje
      await _dbRef
          .child(ConstantesInteroperabilidad.nodoSolicitudesViaje)
          .child(idViaje)
          .update({
        'calificacionPasajero': calificacion,
        'comentarioPasajero': comentario,
        'timestampCalificacion': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    } catch (e) {
      debugPrint('Error al calificar conductor: $e');
      return false;
    }
  }

  /// Obtiene el historial de viajes del pasajero
  Future<List<ViajeModelo>> obtenerHistorialViajes(String idPasajero) async {
    try {
      final snapshot = await _dbRef
          .child('solicitudes_viaje')
          .orderByChild('idPasajero')
          .equalTo(idPasajero)
          .once();

      final List<ViajeModelo> viajes = [];

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<String, dynamic>;

        for (final entry in data.entries) {
          final viajeData = entry.value as Map<String, dynamic>;

          String? idConductor = viajeData['idConductor']?.toString();
          Map<String, dynamic>? datosConductor;

          if (idConductor != null && idConductor.isNotEmpty) {
            datosConductor = _cacheConductores[idConductor];
            if (datosConductor == null) {
              try {
                final snapConductor = await _dbRef
                    .child(ConstantesInteroperabilidad.nodoConductores)
                    .child(idConductor)
                    .get();
                if (snapConductor.exists && snapConductor.value is Map) {
                  datosConductor =
                      Map<String, dynamic>.from(snapConductor.value as Map);
                  _cacheConductores[idConductor] = datosConductor;
                }
              } catch (_) {}
            }
          }

          final viaje = ViajeModelo.fromMap(viajeData, entry.key,
              datosConductor: datosConductor);
          viajes.add(viaje);
        }

        viajes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }

      return viajes;
    } catch (e) {
      debugPrint('Error al obtener historial de viajes: $e');
      return [];
    }
  }

  /// Envía un mensaje al conductor (chat básico)
  Future<bool> enviarMensajeConductor(String idViaje, String mensaje) async {
    try {
      debugPrint(
          '[CHAT CLICKEXPRESS] Intentando enviar mensaje al viaje: $idViaje');
      debugPrint('   Mensaje: "$mensaje"');

      // Obtener UID del pasajero actual
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint(
            '[CHAT CLICKEXPRESS] No se puede enviar: usuario no autenticado');
        return false;
      }

      debugPrint('   UID del pasajero: $uid');

      final mensajeData = {
        'mensaje': mensaje,
        'timestamp': ServerValue.timestamp,
        'remitente': 'pasajero',
        'idRemitente': uid,
      };

      debugPrint('   Ruta Firebase: chats/$idViaje');
      debugPrint('   Datos del mensaje: $mensajeData');

      await _dbRef.child('chats').child(idViaje).push().set(mensajeData);

      debugPrint('[CHAT CLICKEXPRESS] Mensaje enviado exitosamente');
      return true;
    } catch (e) {
      debugPrint('[CHAT CLICKEXPRESS] ERROR al enviar mensaje: $e');
      debugPrint('   Tipo de error: ${e.runtimeType}');
      debugPrint('   idViaje: $idViaje');
      debugPrint('   Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Escucha mensajes del chat utilizando `onChildAdded`.
  Stream<List<Map<String, dynamic>>> escucharChat(String idViaje) {
    debugPrint(
        '[CHAT CLICKEXPRESS] Iniciando escucha de chat(optimizado) para viaje: $idViaje');

    final controller = StreamController<List<Map<String, dynamic>>>();
    final List<Map<String, dynamic>> mensajesCache = [];

    final subscription =
        _dbRef.child('chats').child(idViaje).onChildAdded.listen((event) {
      if (event.snapshot.exists &&
          event.snapshot.value != null &&
          event.snapshot.value is Map) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        mensajesCache.add({'id': event.snapshot.key, ...data});

        // Ordenar in-place por timestamp
        mensajesCache.sort((a, b) {
          final t1 = a['timestamp'] ?? 0;
          final t2 = b['timestamp'] ?? 0;
          final ts1 = t1 is int
              ? t1
              : (t1 is double ? t1.toInt() : int.tryParse(t1.toString()) ?? 0);
          final ts2 = t2 is int
              ? t2
              : (t2 is double ? t2.toInt() : int.tryParse(t2.toString()) ?? 0);
          return ts1.compareTo(ts2);
        });

        // Emitir copia del cache
        controller.add(List.from(mensajesCache));
      }
    });

    controller.onCancel = () {
      subscription.cancel();
    };

    return controller.stream;
  }

  /// Detiene todo el seguimiento activo
  void detenerSeguimiento() {
    _cancelarTodasLasSubscriptions();
  }

  /// Limpia recursos al cerrar la aplicación
  void dispose() {
    detenerSeguimiento();
    _viajeController.close();
    _ubicacionConductorController.close();
  }
}
