import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ServicioTasaBCV {
  // Singleton
  static final ServicioTasaBCV _instancia = ServicioTasaBCV._internal();
  factory ServicioTasaBCV() => _instancia;

  ServicioTasaBCV._internal() {
    _inicializar();
  }

  // Estado interno
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StreamController<double> _controlador =
      StreamController<double>.broadcast();

  double _tasaActual = 0.0;
  bool _inicializado = false;

  /// Timer para polling periodico de la API (cada 15 minutos)
  Timer? _timerPeriodico;
  static const Duration _intervaloActualizacion = Duration(minutes: 15);

  // Cache en memoria
  static double _tasaEnMemoria = 0.0;

  // ── Fuentes de datos (en orden de prioridad) ──────────────────────────────
  // Fuente 1: ExchangeRate-API (datos BCV en tiempo real, actualiza muy frecuente)
  static const String _urlFuente1 =
      'https://api.exchangerate-api.com/v4/latest/USD';

  // Fuente 2: DolarAPI (scraping del BCV, puede tener lag de horas)
  static const String _urlFuente2 =
      'https://ve.dolarapi.com/v1/dolares/oficial';

  /// Ruta en Firestore
  static const String _coleccion = 'configuracion';
  static const String _documento = 'tasa_cambio';

  // Getter publico
  double get tasaActual => _tasaActual;

  // Inicializacion
  void _inicializar() {
    if (_inicializado) return;
    _inicializado = true;

    // 1. Escuchar Firestore en tiempo real
    _firestore
        .collection(_coleccion)
        .doc(_documento)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final datos = snapshot.data()!;
        final tasa = (datos[_documento] as num?)?.toDouble() ?? 0.0;
        final bool usarManual = datos['usar_manual'] ?? false;

        if (tasa > 0) {
          _actualizarTasa(tasa);
        }

        if (usarManual) {
          debugPrint('[BCV] Modo manual activo. Timer de API pausado.');
          _timerPeriodico?.cancel();
          _timerPeriodico = null;
        } else {
          _iniciarTimerPeriodico();
        }
      } else {
        _refrescarDesdeApis();
        _iniciarTimerPeriodico();
      }
    }, onError: (e) {
      debugPrint('[BCV] Error en Firestore stream: $e');
      _usarFallback();
      _iniciarTimerPeriodico();
    });

    // 2. Fetch inmediato al arrancar
    _refrescarDesdeApis();

    // 3. Timer periodico
    _iniciarTimerPeriodico();
  }

  void _iniciarTimerPeriodico() {
    if (_timerPeriodico?.isActive ?? false) return;
    debugPrint(
        '[BCV] Timer periodico iniciado (cada ${_intervaloActualizacion.inMinutes} min).');
    _timerPeriodico = Timer.periodic(_intervaloActualizacion, (_) {
      debugPrint('[BCV] Timer: consultando APIs...');
      _refrescarDesdeApis();
    });
  }

  // ── Consulta dual de fuentes ──────────────────────────────────────────────
  /// Consulta ambas fuentes y usa el valor mas reciente/alto.
  Future<void> _refrescarDesdeApis() async {
    final tasas = await Future.wait([
      _consultarFuente1(),
      _consultarFuente2(),
    ]);

    // Filtrar invalidos y tomar el maximo (mas actualizado = generalmente el mayor)
    final validas = tasas.where((t) => t > 0).toList();

    if (validas.isEmpty) {
      debugPrint('[BCV] Todas las fuentes fallaron -> usando fallback');
      _usarFallback();
      return;
    }

    // Usar el valor maximo entre las fuentes validas
    final tasaFinal = validas.reduce((a, b) => a > b ? a : b);
    debugPrint('[BCV] Fuentes: $tasas -> usando: $tasaFinal');
    _actualizarTasa(tasaFinal);
    _escribirEnFirestore(tasaFinal);
  }

  /// Fuente 1: ExchangeRate-API (tasa VES, muy actualizada)
  Future<double> _consultarFuente1() async {
    try {
      final response = await http
          .get(Uri.parse(_urlFuente1))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>?;
        final tasa = (rates?['VES'] as num?)?.toDouble() ?? 0.0;
        debugPrint('[BCV] Fuente1 (ExchangeRate): $tasa Bs/\$');
        return tasa;
      }
    } catch (e) {
      debugPrint('[BCV] Fuente1 error: $e');
    }
    return 0.0;
  }

  /// Fuente 2: DolarAPI (puede tener lag intradiario)
  Future<double> _consultarFuente2() async {
    try {
      final response = await http
          .get(Uri.parse(_urlFuente2))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final tasa = (data['promedio'] as num?)?.toDouble() ?? 0.0;
        debugPrint('[BCV] Fuente2 (DolarAPI): $tasa Bs/\$');
        return tasa;
      }
    } catch (e) {
      debugPrint('[BCV] Fuente2 error: $e');
    }
    return 0.0;
  }

  void _usarFallback() {
    if (_tasaEnMemoria > 0) {
      debugPrint('[BCV] Usando cache en memoria: $_tasaEnMemoria');
      _actualizarTasa(_tasaEnMemoria);
    }
  }

  void _actualizarTasa(double nuevaTasa) {
    _tasaActual = nuevaTasa;
    _tasaEnMemoria = nuevaTasa;
    if (!_controlador.isClosed) {
      _controlador.add(nuevaTasa);
    }
    debugPrint('[BCV] Tasa actualizada: $nuevaTasa Bs/\$');
  }

  Future<void> _escribirEnFirestore(double tasa) async {
    try {
      await _firestore.collection(_coleccion).doc(_documento).set({
        _documento: tasa,
        'fuente': 'dual: exchangerate-api + dolarapi.com',
        'usar_manual': false,
        'ultima_actualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[BCV] Tasa guardada en Firestore: $tasa');
    } catch (e) {
      debugPrint('[BCV] Error guardando en Firestore: $e');
    }
  }

  // ── API publica ────────────────────────────────────────────────────────────

  /// Stream en tiempo real. Usalo en StreamBuilder.
  Stream<double> obtenerTasaStream() => _controlador.stream;

  /// Fuerza un refresco inmediato desde las APIs.
  Future<void> refrescarTasa() => _refrescarDesdeApis();

  /// Obtiene la tasa una sola vez.
  Future<double> obtenerTasaUnaVez() async {
    if (_tasaActual > 0) return _tasaActual;
    try {
      final snapshot =
          await _firestore.collection(_coleccion).doc(_documento).get();
      if (snapshot.exists && snapshot.data() != null) {
        final tasa =
            (snapshot.data()![_documento] as num?)?.toDouble() ?? 0.0;
        if (tasa > 0) {
          _actualizarTasa(tasa);
          return tasa;
        }
      }
    } catch (_) {}
    await _refrescarDesdeApis();
    return _tasaActual;
  }

  // ── Formateo ───────────────────────────────────────────────────────────────

  /// "\$ 1.00 (Bs 473.87)" o "\$ 1.00" si la tasa no esta disponible.
  String formatearPrecio(double usd) {
    if (_tasaActual <= 0) return '\$${usd.toStringAsFixed(2)}';
    final bs = usd * _tasaActual;
    return '\$${usd.toStringAsFixed(2)} (Bs ${bs.toStringAsFixed(2)})';
  }

  /// "Bs 473.87" o cadena vacia si la tasa no esta disponible.
  String formatearSoloBs(double usd) {
    if (_tasaActual <= 0) return '';
    final bs = usd * _tasaActual;
    return 'Bs ${bs.toStringAsFixed(2)}';
  }
}
