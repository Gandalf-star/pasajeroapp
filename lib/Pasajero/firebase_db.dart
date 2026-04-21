import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/servicio_sincronizacion.dart';

import 'modelos/conductor.dart';
import 'modelos/solicitud_viaje.dart';

import 'servicios/servicio_perfil_pasajero.dart';
import 'servicios/servicio_conductores.dart';
import 'servicios/servicio_solicitudes.dart';
import 'servicios/servicio_billetera.dart';
import 'servicios/servicio_favoritos.dart';

export 'modelos/conductor.dart';
export 'modelos/solicitud_viaje.dart';
export 'utils/interoperabilidad/safe_utils.dart';

export 'servicios/firebase_base.dart';
export 'servicios/servicio_perfil_pasajero.dart';
export 'servicios/servicio_conductores.dart';
export 'servicios/servicio_solicitudes.dart';
export 'servicios/servicio_billetera.dart';
export 'servicios/servicio_favoritos.dart';

class ServicioFirebase {
  static final ServicioFirebase _instance = ServicioFirebase._internal();
  factory ServicioFirebase() => _instance;
  ServicioFirebase._internal();

  late final DatabaseReference _baseDeDatos = FirebaseDatabase.instance.ref();
  late final ServicioSincronizacion _servicioSincronizacion =
      ServicioSincronizacion();

  late final ServicioPerfilPasajero _servicioPerfil;
  late final ServicioConductores _servicioConductores;
  late final ServicioBilletera _servicioBilletera;
  late final ServicioFavoritos _servicioFavoritos;
  late final ServicioSolicitudes _servicioSolicitudes;

  void _inicializarServicios() {
    _servicioPerfil = ServicioPerfilPasajero(_baseDeDatos);
    _servicioConductores =
        ServicioConductores(_baseDeDatos, _servicioSincronizacion);
    _servicioBilletera = ServicioBilletera(_baseDeDatos, FirebaseAuth.instance);
    _servicioFavoritos = ServicioFavoritos(_baseDeDatos);
    _servicioSolicitudes = ServicioSolicitudes(
      _baseDeDatos,
      _servicioSincronizacion,
      _servicioConductores,
      _servicioBilletera,
      _servicioPerfil,
    );
  }

  bool _inicializado = false;
  void ensureInitialized() {
    if (!_inicializado) {
      _inicializarServicios();
      _inicializado = true;
    }
  }

  Stream<Map<String, dynamic>?> obtenerPerfilPasajeroStream(String uid) {
    ensureInitialized();
    return _servicioPerfil.obtenerPerfilPasajeroStream(uid);
  }

  Stream<List<SolicitudViaje>> obtenerHistorialViajes(String uidPasajero) {
    ensureInitialized();
    return _servicioSolicitudes.obtenerHistorialViajes(uidPasajero);
  }

  Stream<List<Conductor>> obtenerConductoresDisponiblesStream(
      String tipoVehiculo, String categoria,
      {double? lat, double? lng}) {
    ensureInitialized();
    return _servicioConductores.obtenerConductoresDisponiblesStream(
        tipoVehiculo, categoria,
        lat: lat, lng: lng);
  }

  Future<List<Conductor>> obtenerConductoresDisponibles(
      String tipoVehiculo, String categoria) {
    ensureInitialized();
    return _servicioConductores.obtenerConductoresDisponibles(
        tipoVehiculo, categoria);
  }

  Future<Map<String, dynamic>> verificarYDescontarSaldo(
      String uid, double monto) {
    ensureInitialized();
    return _servicioBilletera.verificarYDescontarSaldo(uid, monto);
  }

  Future<Map<String, dynamic>> verificarSaldo(String uid, double monto) {
    ensureInitialized();
    return _servicioBilletera.verificarSaldo(uid, monto);
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
  }) {
    ensureInitialized();
    return _servicioSolicitudes.enviarSolicitudViaje(
      uidPasajero: uidPasajero,
      tipoVehiculo: tipoVehiculo,
      categoria: categoria,
      precio: precio,
      origenNombre: origenNombre,
      destinoNombre: destinoNombre,
      destinoLat: destinoLat,
      destinoLng: destinoLng,
      preferencias: preferencias,
      posicionActual: posicionActual,
      nombrePasajero: nombrePasajero,
      telefonoPasajero: telefonoPasajero,
      idConductor: idConductor,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Stream<SolicitudViaje?> obtenerSolicitudEnTiempoReal(String idSolicitud) {
    ensureInitialized();
    return _servicioSolicitudes.obtenerSolicitudEnTiempoReal(idSolicitud);
  }

  Stream<List<SolicitudViaje>> escucharSolicitudesPorPasajero(
      String uidPasajero) {
    ensureInitialized();
    return _servicioSolicitudes.escucharSolicitudesPorPasajero(uidPasajero);
  }

  Future<void> limpiarSolicitudesAntiguas(String uidPasajero) {
    ensureInitialized();
    return _servicioPerfil.limpiarSolicitudesAntiguas(uidPasajero);
  }

  Stream<String?> obtenerIdSolicitudActivaStream(String uidPasajero) {
    ensureInitialized();
    return _servicioPerfil.obtenerIdSolicitudActivaStream(uidPasajero);
  }

  Stream<Conductor?> obtenerConductorEnTiempoReal(String idConductor) {
    ensureInitialized();
    return _servicioConductores.obtenerConductorEnTiempoReal(idConductor);
  }

  Future<bool> cancelarSolicitudViaje(String idSolicitud, String uidPasajero) {
    ensureInitialized();
    return _servicioSolicitudes.cancelarSolicitudViaje(
        idSolicitud, uidPasajero);
  }

  Future<SolicitudViaje?> verificarViajeActivo(String uidPasajero) {
    ensureInitialized();
    return _servicioSolicitudes.verificarViajeActivo(uidPasajero);
  }

  Future<Map<String, dynamic>> cancelarSolicitud(String idSolicitud) {
    ensureInitialized();
    return _servicioSolicitudes.cancelarSolicitud(idSolicitud);
  }

  Future<void> toggleFavorito(String uidPasajero, String idConductor) {
    ensureInitialized();
    return _servicioFavoritos.toggleFavorito(uidPasajero, idConductor);
  }

  Future<bool> esFavorito(String uidPasajero, String idConductor) {
    ensureInitialized();
    return _servicioFavoritos.esFavorito(uidPasajero, idConductor);
  }

  Stream<Conductor?> obtenerConductorStream(String idConductor) {
    ensureInitialized();
    return _servicioConductores.obtenerConductorStream(idConductor);
  }

  Stream<List<String>> obtenerIdsFavoritosStream(String uidPasajero) {
    ensureInitialized();
    return _servicioFavoritos.obtenerIdsFavoritosStream(uidPasajero);
  }
}

final firebaseDb = ServicioFirebase();
