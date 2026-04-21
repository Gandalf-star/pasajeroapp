import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/constantes_interoperabilidad.dart';
import '../../utils/click_logger.dart';
import '../utils/interoperabilidad/safe_utils.dart';

class ServicioBilletera {
  final DatabaseReference _baseDeDatos;
  final FirebaseAuth? _auth;

  ServicioBilletera(this._baseDeDatos, [this._auth]);

  Future<Map<String, dynamic>> verificarSaldo(String uid, double monto) async {
    try {
      final snapshot = await _baseDeDatos
          .child(ConstantesInteroperabilidad.nodoPasajeros)
          .child(uid)
          .child('billetera/saldo')
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return {
          'success': false,
          'error': 'No se encontró información de saldo'
        };
      }

      double saldoActual = SafeUtils.safeDouble(snapshot.value);
      if (saldoActual < monto) {
        return {
          'success': false,
          'error': 'Saldo insuficiente: \$${saldoActual.toStringAsFixed(2)}'
        };
      }

      return {'success': true, 'saldo': saldoActual};
    } catch (e) {
      ClickLogger.d('Error en verificarSaldo: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> verificarYDescontarSaldo(
      String uid, double monto) async {
    try {
      final saldoRef = _baseDeDatos
          .child(ConstantesInteroperabilidad.nodoPasajeros)
          .child(uid)
          .child('billetera/saldo');

      final TransactionResult result =
          await saldoRef.runTransaction((Object? currentSaldo) {
        if (currentSaldo == null) {
          return Transaction.abort();
        }

        double saldoActual = SafeUtils.safeDouble(currentSaldo);
        if (saldoActual < monto) {
          return Transaction.abort();
        }

        return Transaction.success(saldoActual - monto);
      });

      if (result.committed) {
        final actividadRef = _baseDeDatos
            .child(ConstantesInteroperabilidad.nodoPasajeros)
            .child(uid)
            .child('billetera/actividad')
            .push();

        actividadRef.set({
          'monto': monto,
          'tipo': 'gasto_viaje',
          'fecha': ServerValue.timestamp,
          'referencia': 'Pago de Viaje',
        }).catchError((e) => ClickLogger.d('Error al registrar actividad: $e'));

        return {'success': true, 'nuevoSaldo': result.snapshot.value};
      } else {
        return {
          'success': false,
          'error': 'Saldo insuficiente o error en la cuenta de origen'
        };
      }
    } catch (e) {
      ClickLogger.d('Error en verificarYDescontarSaldo: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> aplicarPenalizacion({
    required String idSolicitud,
    required double precioCorrida,
    String? estadoActual,
    String? idConductorAceptante,
  }) async {
    final db = _baseDeDatos;
    bool penalizado = false;
    double montoPenalizacion = 0.0;
    double montoAcreditadoConductor = 0.0;

    try {
      final bool aplicaPenalizacion = idConductorAceptante != null &&
          idConductorAceptante.isNotEmpty &&
          precioCorrida > 0 &&
          estadoActual == ConstantesInteroperabilidad.estadoAceptado;

      if (!aplicaPenalizacion) {
        return {'exito': true, 'penalizado': false};
      }

      final user = _auth?.currentUser;
      montoPenalizacion = precioCorrida * 0.50;
      montoAcreditadoConductor = precioCorrida * 0.25;

      ClickLogger.d(
          'Penalización: Monto=\$${montoPenalizacion.toStringAsFixed(2)}');

      if (user != null) {
        final saldoPasajeroRef = db.child(
            '${ConstantesInteroperabilidad.nodoPasajeros}/${user.uid}/billetera/saldo');
        final txPasajero =
            await saldoPasajeroRef.runTransaction((Object? curr) {
          double saldo = SafeUtils.safeDouble(curr);
          final nuevoSaldo = saldo - montoPenalizacion;
          return Transaction.success(nuevoSaldo < 0 ? 0.0 : nuevoSaldo);
        });

        if (txPasajero.committed) {
          await db
              .child(
                  '${ConstantesInteroperabilidad.nodoPasajeros}/${user.uid}/billetera/actividad')
              .push()
              .set({
            'tipo': 'penalizacion_cancelacion',
            'monto': montoPenalizacion,
            'idViaje': idSolicitud,
            'fecha': ServerValue.timestamp,
            'status': 'aplicado',
            'referencia': 'Cancelación tras aceptación del conductor',
          });
        }

        final saldoConductorRef =
            db.child('usuarios/$idConductorAceptante/billetera/saldo');
        final txConductor =
            await saldoConductorRef.runTransaction((Object? curr) {
          double saldo = SafeUtils.safeDouble(curr);
          return Transaction.success(saldo + montoAcreditadoConductor);
        });

        if (txConductor.committed) {
          await db
              .child('usuarios/$idConductorAceptante/billetera/actividad')
              .push()
              .set({
            'tipo': 'compensacion_cancelacion_pasajero',
            'monto': montoAcreditadoConductor,
            'idViaje': idSolicitud,
            'fecha': ServerValue.timestamp,
            'status': 'acreditado',
            'referencia': 'Compensación por cancelación del pasajero',
          });

          await db
              .child('conductores/$idConductorAceptante/billetera/saldo')
              .runTransaction((Object? curr) {
            double saldo = SafeUtils.safeDouble(curr);
            return Transaction.success(saldo + montoAcreditadoConductor);
          });
        }

        await db.update({
          'conductores/$idConductorAceptante/idViajeActivo': null,
          'conductores/$idConductorAceptante/disponible': true,
          'usuarios/$idConductorAceptante/idViajeActivo': null,
          'usuarios/$idConductorAceptante/disponible': true,
        });

        penalizado = true;
      }

      return {
        'exito': true,
        'penalizado': penalizado,
        'montoPenalizacion': montoPenalizacion,
        'montoAcreditadoConductor': montoAcreditadoConductor,
      };
    } catch (e) {
      ClickLogger.d('Error en aplicarPenalizacion: $e');
      return {'exito': false, 'error': e.toString()};
    }
  }
}
