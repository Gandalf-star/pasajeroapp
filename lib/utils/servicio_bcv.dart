import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class ServicioBCV {
  static final ServicioBCV _instancia = ServicioBCV._internal();
  factory ServicioBCV() => _instancia;
  ServicioBCV._internal() {
    _iniciarEscucha();
  }

  // Tasa BCV por defecto si no se puede obtener de Firebase
  // Valor temporal solicitado por el usuario
  double _tasaActual = 50.0;

  final _controller = StreamController<double>.broadcast();
  Stream<double> get tasaStream => _controller.stream;

  // Referencia a donde guardaremos la tasa en Firebase
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref('configuracion/tasa_bcv');
  StreamSubscription? _subscripcion;

  double get tasaActual => _tasaActual;

  void _iniciarEscucha() {
    _subscripcion = _dbRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        try {
          // Intentar parsear el valor (puede venir como int, double o string)
          final valorRaw = event.snapshot.value;
          double nuevaTasa = 50.0;

          if (valorRaw is num) {
            nuevaTasa = valorRaw.toDouble();
          } else if (valorRaw is String) {
            nuevaTasa = double.tryParse(valorRaw) ?? 50.0;
          }

          // Solo notificar si cambia y si es un valor razonable (>0)
          if (nuevaTasa > 0 && nuevaTasa != _tasaActual) {
            _tasaActual = nuevaTasa;
            _controller.add(_tasaActual);
            debugPrint('💵 Tasa BCV Actualizada: Bs $_tasaActual / USD');
          }
        } catch (e) {
          debugPrint('Error al parsear tasa BCV: $e');
        }
      }
    }, onError: (error) {
      debugPrint('Error al escuchar tasa BCV: $error');
    });
  }

  /// Convierte montos en USD a Bolivares usando la tasa actual
  double convertirABs(double dolares) {
    return dolares * _tasaActual;
  }

  /// Formatea un monto en dolares como "X.XX USD (Y.YY Bs)"
  String formatearPrecioMultiple(double dolares) {
    final bs = convertirABs(dolares);
    return '\$${dolares.toStringAsFixed(2)} (Bs ${bs.toStringAsFixed(2)})';
  }

  void dispose() {
    _subscripcion?.cancel();
    _controller.close();
  }
}
