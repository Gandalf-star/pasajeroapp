import 'package:cloud_functions/cloud_functions.dart';
import '../../utils/click_logger.dart';

class ServicioPagos {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// MODO DE PRUEBAS ACTIVADO
  static const bool modoMock = true;

  /// Procesa un pago C2P utilizando la Cloud Function 'procesarPagoC2P'
  /// Si [modoMock] es true, simula la respuesta localmente.
  Future<Map<String, dynamic>> procesarPagoC2P({
    required double monto,
    required String cedula,
    required String telefono,
    required String banco,
    required String claveC2P,
    String tipo = 'recarga_pasajero',
  }) async {
    // Lógica de Simulación (Mock)
    if (modoMock) {
      ClickLogger.d('MODO MOCK ACTIVO: Procesando pago C2P...');

      if (claveC2P == '123456') {
        ClickLogger.i('Pago Mock detectado: Delegando al servidor para actualizar saldo real...');
        
        try {
          final HttpsCallable callable =
              _functions.httpsCallable('procesarPagoC2P');

          final result = await callable.call({
            'monto': monto,
            'cedula': cedula,
            'telefono': telefono,
            'banco': banco,
            'claveC2P': claveC2P,
            'tipo': tipo,
          });

          return Map<String, dynamic>.from(result.data);
        } on FirebaseFunctionsException catch (e) {
          ClickLogger.w('Error Server Mock: ${e.message}');
          return {
            'success': false,
            'error': e.message ?? 'Error en la función de pago mock',
            'code': e.code,
          };
        } catch (e) {
          ClickLogger.w('Error Local Mock: $e');
          return {
            'success': false,
            'error': e.toString(),
          };
        }
      } else {
        ClickLogger.w('Pago Mock Rechazado (Motivo: Clave Dinámica Inválida)');
        return {
          'success': false,
          'error':
              'PAGO RECHAZADO: Clave dinámica C2P inválida o vencida (SOLO PRUEBAS: Usa 123456 para éxito)',
          'code': 'mock-invalid-key',
        };
      }
    }

    try {
      final HttpsCallable callable =
          _functions.httpsCallable('procesarPagoC2P');

      final result = await callable.call({
        'monto': monto,
        'cedula': cedula,
        'telefono': telefono,
        'banco': banco,
        'claveC2P': claveC2P,
        'tipo': tipo,
      });

      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      return {
        'success': false,
        'error': e.message ?? 'Error en la función de pago',
        'code': e.code,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
