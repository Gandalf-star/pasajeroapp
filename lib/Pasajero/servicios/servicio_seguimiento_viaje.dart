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

  // Stream controllers para notificar cambios
  final StreamController<ViajeModelo?> _viajeController =
      StreamController<ViajeModelo?>.broadcast();
  final StreamController<UbicacionModelo?> _ubicacionConductorController =
      StreamController<UbicacionModelo?>.broadcast();

  // Getters para los streams
  Stream<ViajeModelo?> get viajeStream => _viajeController.stream;
  Stream<UbicacionModelo?> get ubicacionConductorStream =>
      _ubicacionConductorController.stream;

  ViajeModelo? _viajeActual;
  ViajeModelo? get viajeActual => _viajeActual;

  /// Inicia el seguimiento de un viaje específico
  Future<void> iniciarSeguimientoViaje(String idViaje) async {
    debugPrint('Iniciando seguimiento del viaje: $idViaje');
    try {
      // Detener seguimiento anterior si existe
      detenerSeguimiento();

      // Escuchar cambios en el viaje
      _viajeSubscription = _dbRef
          .child(ConstantesInteroperabilidad.nodoSolicitudesViaje)
          .child(idViaje)
          .onValue
          .listen((event) {
        debugPrint('Evento recibido para solicitud $idViaje');
        try {
          if (event.snapshot.exists) {
            debugPrint('Snapshot existe');
            if (event.snapshot.value is Map) {
              final data =
                  Map<String, dynamic>.from(event.snapshot.value as Map);
              debugPrint('Datos recibidos: ${data.keys.join(', ')}');
              debugPrint('   Estado: ${data['estado']}');
              debugPrint('   idConductor: ${data['idConductor']}');
              debugPrint('   idViajeActivo: ${data['idViajeActivo']}');

              _viajeActual = ViajeModelo.fromMap(data, idViaje);
              debugPrint('ViajeModelo creado exitosamente');
              _viajeController.add(_viajeActual);

              // Si la solicitud ya tiene idViajeActivo, escuchar el viaje activo
              final idViajeActivo =
                  (data[ConstantesInteroperabilidad.campoIdViajeActivo] ??
                          data['idViajeActivo'] ??
                          '')
                      .toString();
              if (idViajeActivo.isNotEmpty) {
                debugPrint('Escuchando viaje activo: $idViajeActivo');
                _escucharViajeActivo(idViajeActivo);
              }

              // También escuchar ubicación del conductor si está asignado
              if (_viajeActual?.idConductor != null) {
                debugPrint(
                    'Escuchando ubicación del conductor: ${_viajeActual!.idConductor}');
                _escucharUbicacionConductor(_viajeActual!.idConductor!);
              }
            } else {
              debugPrint(
                  'ERROR: Snapshot value no es Map: ${event.snapshot.value.runtimeType}');
            }
          } else {
            debugPrint('Snapshot no existe para $idViaje');
            _viajeActual = null;
            _viajeController.add(null);
          }
        } catch (e, stackTrace) {
          debugPrint('ERROR al procesar evento de viaje: $e');
          debugPrint('Stack trace: $stackTrace');
          _viajeController.addError(e);
        }
      }, onError: (error) {
        debugPrint('ERROR en listener de viaje: $error');
        _viajeController.addError(error);
      });
    } catch (e, stackTrace) {
      debugPrint('ERROR al iniciar seguimiento del viaje: $e');
      debugPrint('Stack trace: $stackTrace');
      _viajeController.addError(e);
    }
  }

  /// Escucha el viaje activo (viajes_activos/{id}) cuando existe
  void _escucharViajeActivo(String idViajeActivo,
      {int reintentosViajeActivo = 0, int maxReintentos = 5}) {
    _viajeActivoSubscription?.cancel();

    _viajeActivoSubscription = _dbRef
        .child(ConstantesInteroperabilidad.nodoViajesActivos)
        .child(idViajeActivo)
        .onValue
        .listen((event) {
      // RESET de reintentos si recibimos datos exitosos
      reintentosViajeActivo = 0;

      if (event.snapshot.exists && event.snapshot.value is Map) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        _viajeActual = ViajeModelo.fromMap(data, idViajeActivo);
        _viajeController.add(_viajeActual);

        if (_viajeActual?.idConductor != null) {
          _escucharUbicacionConductor(_viajeActual!.idConductor!);
        }
      } else {
        _viajeController.add(_viajeActual);
      }
    }, onError: (error) async {
      if (reintentosViajeActivo < maxReintentos) {
        reintentosViajeActivo++;

        int segundosEspera = (math.pow(2, reintentosViajeActivo)).toInt();

        ClickLogger.d(
            '📡 Error en Stream Viaje Activo. Reintentando en $segundosEspera s (Intento $reintentosViajeActivo)');

        await Future.delayed(Duration(seconds: segundosEspera));

        // Re-llamada para intentar abrir el Stream de nuevo
        _escucharViajeActivo(idViajeActivo);
      } else {
        ClickLogger.d(
            'Se alcanzó el máximo de reintentos para el Stream del viaje.');
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

  /// Busca el viaje activo del pasajero
  Future<ViajeModelo?> buscarViajeActivoPasajero(String idPasajero) async {
    try {
      // Buscar en solicitudes_viaje
      final snapshot = await _dbRef
          .child(ConstantesInteroperabilidad.nodoSolicitudesViaje)
          .orderByChild(ConstantesInteroperabilidad.campoIdPasajero)
          .equalTo(idPasajero)
          .once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<String, dynamic>;

        // Buscar viajes que no estén completados o cancelados
        for (final entry in data.entries) {
          final viajeData = entry.value as Map<String, dynamic>;
          final estado = EstadoViajeExtension.fromString(
              viajeData[ConstantesInteroperabilidad.campoEstado] ??
                  'pendiente');

          if (estado != EstadoViaje.completado &&
              estado != EstadoViaje.cancelado &&
              estado != EstadoViaje.canceladoPorConductor &&
              estado != EstadoViaje.canceladoPorPasajero) {
            return ViajeModelo.fromMap(viajeData, entry.key);
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
      // 1. CRÍTICO: Actualizar estado del viaje
      await _dbRef
          .child(ConstantesInteroperabilidad.nodoSolicitudesViaje)
          .child(idViaje)
          .update({
        ConstantesInteroperabilidad.campoEstado: 'cancelado_por_pasajero',
        'razonCancelacion': razon,
        'timestampCancelacion': DateTime.now().millisecondsSinceEpoch,
      });

      // Actualizar estado en viajes_activos para evitar viajes colgados
      try {
        await _dbRef
            .child(ConstantesInteroperabilidad.nodoViajesActivos)
            .child(idViaje)
            .update({
          ConstantesInteroperabilidad.campoEstado: 'cancelado_por_pasajero',
          'timestampCancelacion': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (e) {
        debugPrint('Error no crítico cancelando en viajes_activos: $e');
      }

      // Intentar limpiar solicitudActiva
      // Si falla por permisos, no afecta el resultado
      if (_viajeActual != null) {
        try {
          await _dbRef
              .child(ConstantesInteroperabilidad.nodoPasajeros)
              .child(_viajeActual!.idPasajero)
              .update({
            'solicitudActiva': null,
          });
        } catch (e) {
          debugPrint('Error no crítico limpiando solicitudActiva: $e');
          // Ignorar error de limpieza
        }
      }

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

      // Actualizar promedio de calificación del conductor
      final conductorRef = _dbRef
          .child(ConstantesInteroperabilidad.nodoConductores)
          .child(idConductor);
      final snapshot = await conductorRef.once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<String, dynamic>;
        final calificacionActual =
            (data[ConstantesInteroperabilidad.campoCalificacion] ?? 5.0)
                .toDouble();
        final totalViajes = (data['totalViajes'] ?? 0) + 1;

        final nuevaCalificacion =
            ((calificacionActual * (totalViajes - 1)) + calificacion) /
                totalViajes;

        await conductorRef.update({
          'calificacionPromedio': nuevaCalificacion,
          'totalViajes': totalViajes,
        });
      }

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
          final viaje = ViajeModelo.fromMap(viajeData, entry.key);
          viajes.add(viaje);
        }

        // Ordenar por timestamp descendente (más recientes primero)
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
    _viajeSubscription?.cancel();
    _conductorSubscription?.cancel();
    _viajeActivoSubscription?.cancel();
    _viajeSubscription = null;
    _conductorSubscription = null;
    _viajeActivoSubscription = null;
  }

  /// Limpia recursos al cerrar la aplicación
  void dispose() {
    detenerSeguimiento();
    _viajeController.close();
    _ubicacionConductorController.close();
  }
}
