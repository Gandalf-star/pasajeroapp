// Constantes globales para ClickExpress
// Sincronizadas con Click_v2 para interoperabilidad perfecta

class ConstantesGlobales {
  // Colores de la app
  static const int colorTextoClaro = 0xFFFFFFFF;
  static const int colorTextoOscuro = 0xFF000000;
  static const int colorFondoGrisClaro = 0xFFF5F5F5;
  static const int colorVerdeOscuroUber = 0xFF2E7D32;
  static const int colorPrimarioUberVerde = 0xFF00D4AA;
  static const int colorAcentoUberNaranja = 0xFFFF6B35;
  
  // Precios de los vehículos (debe coincidir con Click_v2)
  static const Map<String, double> preciosVehiculos = {
    'economico': 3.5,
    'estandar': 5.0,
    'premium': 8.0,
  };
  
  // Precios para mototaxis (categoría económica por defecto)
  static const Map<String, double> preciosMototaxis = {
    'economico': 2.5,
    'estandar': 3.5,
    'premium': 5.0,
  };
  
  // Precios para taxis (carros)
  static const Map<String, double> preciosTaxis = {
    'economico': 5.0,
    'estandar': 7.5,
    'premium': 10.0,
  };
  
  // Configuración de la app
  static const int timeoutSolicitudSegundos = 300; // 5 minutos
  static const double radioBusquedaMetros = 10000.0; // 10km
  static const double calificacionMinima = 3.0;



}
