import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseBase {
  static final FirebaseBase _instance = FirebaseBase._internal();
  factory FirebaseBase() => _instance;
  FirebaseBase._internal();

  DatabaseReference get baseDeDatos => FirebaseDatabase.instance.ref();
  FirebaseAuth get auth => FirebaseAuth.instance;

  DatabaseReference get refConductores => baseDeDatos.child('conductores');
  DatabaseReference get refPasajeros => baseDeDatos.child('pasajeros');
  DatabaseReference get refSolicitudesViaje =>
      baseDeDatos.child('solicitudes_viaje');
  DatabaseReference get refViajesActivos => baseDeDatos.child('viajes_activos');
}

final firebaseBase = FirebaseBase();
