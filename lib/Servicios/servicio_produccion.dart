import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';
import '../utils/constantes_interoperabilidad.dart';

/// Servicio optimizado para producción con:
/// - Rate limiting
/// - Reintentos automáticos
/// - Validaciones de seguridad
/// - Sistema de cola/broadcast
class ServicioProduccion {
  static final ServicioProduccion _instance = ServicioProduccion._internal();
  factory ServicioProduccion() => _instance;
  ServicioProduccion._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Rate limiting para solicitudes de viaje
  final Map<String, DateTime> _ultimaSolicitudPorUsuario = {};
  static const Duration _rateLimitDuration = Duration(seconds: 30);

  // Cache para reducir lecturas de Firebase
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(seconds: 10);

  /// ============ RATE LIMITING ============

  /// Verifica si el usuario puede hacer una nueva solicitud
  bool puedeSolicitarViaje(String idPasajero) {
    final ahora = DateTime.now();
    final ultimaSolicitud = _ultimaSolicitudPorUsuario[idPasajero];

    if (ultimaSolicitud == null) return true;

    final diferencia = ahora.difference(ultimaSolicitud);
    if (diferencia >= _rateLimitDuration) return true;

    final segundosRestantes =
        _rateLimitDuration.inSeconds - diferencia.inSeconds;
    debugPrint('⏱️ Rate limiting: Debes esperar $segundosRestantes segundos');
    return false;
  }

  /// Registra una nueva solicitud de viaje
  void registrarSolicitud(String idPasajero) {
    _ultimaSolicitudPorUsuario[idPasajero] = DateTime.now();
  }

  /// Obtiene el tiempo restante para poder solicitar
  int obtenerSegundosRestantes(String idPasajero) {
    final ultimaSolicitud = _ultimaSolicitudPorUsuario[idPasajero];
    if (ultimaSolicitud == null) return 0;

    final diferencia = DateTime.now().difference(ultimaSolicitud);
    final restante = _rateLimitDuration.inSeconds - diferencia.inSeconds;
    return restante > 0 ? restante : 0;
  }

  /// ============ REINTENTOS AUTOMÁTICOS ============

  /// Ejecuta una operación con reintentos automáticos
  Future<T?> ejecutarConReintentos<T>({
    required Future<T?> Function() operacion,
    required String nombreOperacion,
    int maxReintentos = 3,
    Duration delayEntreReintentos = const Duration(seconds: 2),
  }) async {
    for (int intento = 1; intento <= maxReintentos; intento++) {
      try {
        debugPrint('🔄 $nombreOperacion - Intento $intento/$maxReintentos');
        final resultado = await operacion().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException('Operación timeout');
          },
        );

        if (intento > 1) {
          debugPrint('✅ $nombreOperacion exitoso después de $intento intentos');
        }
        return resultado;
      } catch (e) {
        debugPrint('❌ $nombreOperacion falló (intento $intento): $e');

        if (intento == maxReintentos) {
          debugPrint(
              '🚫 $nombreOperacion falló después de $maxReintentos intentos');
          return null;
        }

        // Esperar antes del siguiente intento con backoff exponencial
        final delay = delayEntreReintentos.multiply(intento);
        await Future.delayed(delay);
      }
    }
    return null;
  }

  /// ============ VALIDACIÓN DE CALIFICACIONES ============

  /// Verifica que un viaje esté completado antes de permitir calificación
  Future<bool> validarCalificacionPermitida({
    required String idViaje,
    required String idPasajero,
  }) async {
    try {
      // Verificar en viajes_completados
      final snapshotCompletado = await _db
          .child(
              '${ConstantesInteroperabilidad.nodoViajesCompletados}/$idViaje')
          .get();

      if (!snapshotCompletado.exists) {
        debugPrint('❌ Viaje $idViaje no encontrado en completados');
        return false;
      }

      final data = Map<String, dynamic>.from(snapshotCompletado.value as Map);
      final estado = data[ConstantesInteroperabilidad.campoEstado] ?? '';

      if (estado != ConstantesInteroperabilidad.estadoCompletado &&
          estado != 'completado') {
        debugPrint('❌ Viaje $idViaje no está completado. Estado: $estado');
        return false;
      }

      // Verificar que no haya sido calificado ya
      if (data.containsKey('calificacionPasajero')) {
        debugPrint('❌ Viaje $idViaje ya fue calificado');
        return false;
      }

      // Verificar que el usuario sea el pasajero del viaje
      final idPasajeroViaje = data[ConstantesInteroperabilidad.campoIdPasajero];
      if (idPasajero != idPasajeroViaje) {
        debugPrint('❌ Usuario $idPasajero no es el pasajero del viaje');
        return false;
      }

      debugPrint('✅ Validación de calificación permitida para viaje $idViaje');
      return true;
    } catch (e) {
      debugPrint('❌ Error validando calificación: $e');
      return false;
    }
  }

  /// ============ SISTEMA DE COLA/BROADCAST ============

  /// Crea una solicitud con sistema de broadcast a conductores cercanos
  Future<String?> crearSolicitudConBroadcast({
    required String idPasajero,
    required Map<String, dynamic> datosSolicitud,
    required List<String> idsConductoresCercanos,
    int tiempoExpiracionSegundos = 60,
  }) async {
    try {
      // 1. Rate limiting check
      if (!puedeSolicitarViaje(idPasajero)) {
        final segundosRestantes = obtenerSegundosRestantes(idPasajero);
        throw Exception(
            'Debes esperar $segundosRestantes segundos antes de solicitar otro viaje');
      }

      // 2. Crear la solicitud principal
      final solicitudRef =
          _db.child(ConstantesInteroperabilidad.nodoSolicitudesViaje).push();
      final idSolicitud = solicitudRef.key;

      if (idSolicitud == null) {
        throw Exception('No se pudo generar ID de solicitud');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final expiracion = timestamp + (tiempoExpiracionSegundos * 1000);

      final solicitudData = {
        ...datosSolicitud,
        'id': idSolicitud,
        ConstantesInteroperabilidad.campoIdPasajero: idPasajero,
        ConstantesInteroperabilidad.campoEstado:
            ConstantesInteroperabilidad.estadoSolicitado,
        'timestamp': timestamp,
        'timestampExpiracion': expiracion,
        'broadcast': true,
        'conductoresNotificados': idsConductoresCercanos.length,
      };

      // 3. Preparar updates atómicos
      final updates = <String, dynamic>{
        '${ConstantesInteroperabilidad.nodoSolicitudesViaje}/$idSolicitud':
            solicitudData,
        '${ConstantesInteroperabilidad.nodoPasajeros}/$idPasajero/solicitudActiva':
            {
          'id': idSolicitud,
          'estado': ConstantesInteroperabilidad.estadoSolicitado,
          'timestamp': timestamp,
        },
      };

      // 4. Agregar a cola de cada conductor (broadcast)
      final batchSize = 10;
      for (var i = 0; i < idsConductoresCercanos.length; i += batchSize) {
        final batch = idsConductoresCercanos.skip(i).take(batchSize).toList();

        for (final idConductor in batch) {
          updates[
              '${ConstantesInteroperabilidad.nodoConductores}/$idConductor/solicitudesPendientes/$idSolicitud'] = {
            'timestamp': timestamp,
            'expiraEn': expiracion,
            'tipoVehiculo': datosSolicitud['tipoVehiculoRequerido'],
            'categoria': datosSolicitud['categoria'],
          };
        }
      }

      // 5. Ejecutar todas las actualizaciones
      await _db.update(updates);

      // 6. Registrar en rate limiting
      registrarSolicitud(idPasajero);

      debugPrint(
          '✅ Solicitud $idSolicitud creada con broadcast a ${idsConductoresCercanos.length} conductores');
      return idSolicitud;
    } catch (e) {
      debugPrint('❌ Error creando solicitud con broadcast: $e');
      return null;
    }
  }

  /// Limpia solicitudes expiradas de un conductor
  Future<void> limpiarSolicitudesExpiradas(String idConductor) async {
    try {
      final snapshot = await _db
          .child(
              '${ConstantesInteroperabilidad.nodoConductores}/$idConductor/solicitudesPendientes')
          .get();

      if (!snapshot.exists) return;

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final ahora = DateTime.now().millisecondsSinceEpoch;
      final updates = <String, dynamic>{};

      data.forEach((idSolicitud, info) {
        final infoMap = Map<String, dynamic>.from(info as Map);
        final expiraEn = infoMap['expiraEn'] ?? 0;

        if (expiraEn < ahora) {
          updates['${ConstantesInteroperabilidad.nodoConductores}/$idConductor/solicitudesPendientes/$idSolicitud'] =
              null;
        }
      });

      if (updates.isNotEmpty) {
        await _db.update(updates);
        debugPrint('🧹 ${updates.length} solicitudes expiradas limpiadas');
      }
    } catch (e) {
      debugPrint('❌ Error limpiando solicitudes: $e');
    }
  }

  /// ============ OPTIMIZACIÓN DE LISTENERS ============

  /// Crea un listener optimizado con límite de resultados
  Stream<DatabaseEvent> crearListenerOptimizado({
    required String nodo,
    required String orderByChild,
    required dynamic equalTo,
    int limit = 50,
  }) {
    return _db
        .child(nodo)
        .orderByChild(orderByChild)
        .equalTo(equalTo)
        .limitToFirst(limit)
        .onValue;
  }

  /// Cache seguro para reducir lecturas
  T? obtenerDeCache<T>(String clave) {
    final timestamp = _cacheTimestamps[clave];
    if (timestamp == null) return null;

    final diferencia = DateTime.now().difference(timestamp);
    if (diferencia > _cacheDuration) {
      _cache.remove(clave);
      _cacheTimestamps.remove(clave);
      return null;
    }

    return _cache[clave] as T?;
  }

  void guardarEnCache<T>(String clave, T valor) {
    _cache[clave] = valor;
    _cacheTimestamps[clave] = DateTime.now();
  }

  void limpiarCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  /// ============ MONITOREO DE CONEXIÓN ============

  /// Verifica si hay conexión a Firebase
  Future<bool> verificarConexion() async {
    try {
      final testRef = _db.child('.info/connected');
      final snapshot = await testRef.get();
      return snapshot.value == true;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene el estado de la conexión como Stream
  Stream<bool> get estadoConexionStream {
    return _db
        .child('.info/connected')
        .onValue
        .map((event) => event.snapshot.value == true);
  }

  /// ============ UTILIDADES ============

  /// Calcula la distancia entre dos puntos
  double calcularDistancia(LatLng punto1, LatLng punto2) {
    const distance = Distance();
    return distance(punto1, punto2);
  }

  /// Dispose limpio
  void dispose() {
    limpiarCache();
  }
}

// Extensiones útiles
extension DurationExtension on Duration {
  Duration multiply(int factor) {
    return Duration(
      milliseconds: (inMilliseconds * factor).round(),
    );
  }
}
