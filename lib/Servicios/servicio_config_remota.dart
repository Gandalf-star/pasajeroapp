import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Servicio de configuración remota para producción.
/// Externaliza datos que deben ser actualizables sin redeploy de la app:
///   - Datos bancarios de recarga C2P
///   - Configuración de tarifas
///   - Mensajes de UI
///   - Flags de feature toggle
class ServicioConfigRemota {
  static final ServicioConfigRemota _instancia =
      ServicioConfigRemota._internal();
  factory ServicioConfigRemota() => _instancia;
  ServicioConfigRemota._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  static const String _nodoConfig = 'config_app';

  // Cache en memoria para evitar lecturas repetitivas
  Map<String, dynamic>? _configCache;
  DateTime? _ultimaLectura;
  static const Duration _duracionCache = Duration(minutes: 30);

  // =========== VALORES POR DEFECTO (fallback si Firebase no responde) ===========
  static const Map<String, dynamic> _defaults = {
    'datosRecarga': {
      'banco': 'Mercantil',
      'codigoBanco': '0105',
      'telefono': '0412-4443322',
      'rifCi': 'J-12345678-9',
      'titular': 'Click Express C.A.',
    },
    'tarifas': {
      'economico': 2.30,
      'confort': 3.50,
      'viajes_largos': 6.00,
      'mototaxi_economico': 1.50,
      'mototaxi_confort': 2.00,
    },
    'limites': {
      'montoMaximoRecarga': 500.0,
      'montoMinimoRecarga': 1.0,
      'saldoMaximoBilletera': 1000.0,
      'rateLimitSegundos': 30,
    },
    'osrm': {
      'url': 'http://router.project-osrm.org',
      'timeoutSegundos': 10,
      'intentosMaximos': 3,
    },
    'fcm': {
      'habilitado': true,
    },
    'mantenimiento': {
      'enMantenimiento': false,
      'mensaje': '',
    },
  };

  /// Carga la configuración desde Firebase (con cache)
  Future<Map<String, dynamic>> cargarConfig() async {
    // Retornar cache si aún es válido
    if (_configCache != null && _ultimaLectura != null) {
      final diferencia = DateTime.now().difference(_ultimaLectura!);
      if (diferencia < _duracionCache) {
        return _configCache!;
      }
    }

    try {
      final snapshot = await _db.child(_nodoConfig).get();

      if (!snapshot.exists || snapshot.value == null) {
        debugPrint('⚠️ ServicioConfigRemota: Sin config en Firebase, usando defaults');
        _configCache = Map<String, dynamic>.from(_defaults);
        _ultimaLectura = DateTime.now();
        return _configCache!;
      }

      final remoto = Map<String, dynamic>.from(snapshot.value as Map);

      // Hacer deep merge de defaults + remoto (remoto gana)
      _configCache = _deepMerge(_defaults, remoto);
      _ultimaLectura = DateTime.now();

      debugPrint('✅ ServicioConfigRemota: Config cargada correctamente');
      return _configCache!;
    } catch (e) {
      debugPrint('❌ ServicioConfigRemota: Error cargando config: $e');
      _configCache = Map<String, dynamic>.from(_defaults);
      _ultimaLectura = DateTime.now();
      return _configCache!;
    }
  }

  /// Obtiene los datos bancarios para recarga C2P
  Future<Map<String, dynamic>> obtenerDatosBancarios() async {
    final config = await cargarConfig();
    final datos = config['datosRecarga'];
    if (datos is Map) {
      return Map<String, dynamic>.from(datos);
    }
    return Map<String, dynamic>.from(_defaults['datosRecarga'] as Map);
  }

  /// Obtiene la tarifa para una categoría específica
  Future<double> obtenerTarifa(String categoria) async {
    final config = await cargarConfig();
    final tarifas = config['tarifas'];
    if (tarifas is Map) {
      final tarifa = tarifas[categoria];
      if (tarifa is num) return tarifa.toDouble();
    }
    final defaultTarifas = _defaults['tarifas'] as Map;
    return (defaultTarifas[categoria] as num?)?.toDouble() ?? 3.50;
  }

  /// Verifica si la app está en mantenimiento
  Future<bool> estaEnMantenimiento() async {
    final config = await cargarConfig();
    final mantenimiento = config['mantenimiento'];
    if (mantenimiento is Map) {
      return mantenimiento['enMantenimiento'] == true;
    }
    return false;
  }

  /// Obtiene mensaje de mantenimiento
  Future<String> obtenerMensajeMantenimiento() async {
    final config = await cargarConfig();
    final mantenimiento = config['mantenimiento'];
    if (mantenimiento is Map) {
      return mantenimiento['mensaje']?.toString() ?? '';
    }
    return '';
  }

  /// Obtiene la URL del servidor OSRM
  Future<String> obtenerUrlOsrm() async {
    final config = await cargarConfig();
    final osrm = config['osrm'];
    if (osrm is Map) {
      return osrm['url']?.toString() ?? _defaults['osrm']['url'] as String;
    }
    return _defaults['osrm']['url'] as String;
  }

  /// Obtiene el rate limit en segundos
  Future<int> obtenerRateLimitSegundos() async {
    final config = await cargarConfig();
    final limites = config['limites'];
    if (limites is Map && limites['rateLimitSegundos'] is num) {
      return (limites['rateLimitSegundos'] as num).toInt();
    }
    return 30;
  }

  /// Obtiene el monto máximo de recarga
  Future<double> obtenerMontoMaximoRecarga() async {
    final config = await cargarConfig();
    final limites = config['limites'];
    if (limites is Map && limites['montoMaximoRecarga'] is num) {
      return (limites['montoMaximoRecarga'] as num).toDouble();
    }
    return 500.0;
  }

  /// Invalida el cache para forzar recarga
  void invalidarCache() {
    _configCache = null;
    _ultimaLectura = null;
    debugPrint('🔄 ServicioConfigRemota: Cache invalidado');
  }

  /// Escucha cambios en la config en tiempo real (para actualizaciones instantáneas)
  Stream<Map<String, dynamic>> escucharConfig() {
    return _db.child(_nodoConfig).onValue.map((event) {
      if (event.snapshot.value == null) {
        return Map<String, dynamic>.from(_defaults);
      }
      final remoto = Map<String, dynamic>.from(event.snapshot.value as Map);
      final merged = _deepMerge(_defaults, remoto);
      _configCache = merged;
      _ultimaLectura = DateTime.now();
      return merged;
    });
  }

  // ============ Utilidad de merge profundo ============
  Map<String, dynamic> _deepMerge(
    Map<String, dynamic> base,
    Map<String, dynamic> override,
  ) {
    final resultado = Map<String, dynamic>.from(base);
    for (final key in override.keys) {
      final baseVal = resultado[key];
      final overrideVal = override[key];
      if (baseVal is Map && overrideVal is Map) {
        resultado[key] = _deepMerge(
          Map<String, dynamic>.from(baseVal),
          Map<String, dynamic>.from(overrideVal),
        );
      } else {
        resultado[key] = overrideVal;
      }
    }
    return resultado;
  }
}
