import '../modelos/viaje_frecuente.dart';

class ServicioViajesFrecuentes {
  static final ServicioViajesFrecuentes _instancia =
      ServicioViajesFrecuentes._internal();
  factory ServicioViajesFrecuentes() => _instancia;
  ServicioViajesFrecuentes._internal();

  Stream<List<ViajeFrecuente>> get viajesStream => Stream.value([]);
  List<ViajeFrecuente> get viajes => [];
  Future<void> inicializar(String userId) async {}
  void dispose() {}

  Stream<List<ViajeFrecuente>> escucharViajesFrecuentes(String userId) {
    return Stream.value([]);
  }

  Future<void> incrementarUso(String userId, String viajeId) async {}
}
