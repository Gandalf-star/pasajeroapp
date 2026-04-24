// Última corrección: Estandarización de estados y tipos de vehículo.

class ConstantesInteroperabilidad {
  // ========== NODOS DE FIREBASE (Colecciones) ==========
  static const String nodoUsuarios = 'usuarios';
  static const String nodoConductores = 'conductores';
  static const String nodoPasajeros = 'pasajeros';
  static const String nodoSolicitudesViaje = 'solicitudes_viaje';
  static const String nodoViajesActivos = 'viajes_activos';
  static const String nodoViajesCompletados = 'viajes_completados';
  static const String nodoHistorialViajes = 'historial_viajes';

  // ========== GEOHASH (Búsqueda Geoespacial) ==========
  static const int geohashPrecision = 6;

  // ========== ESTADOS DEL VIAJE (Flujo Lógico) ==========
  // 1. Pasajero crea la solicitud
  static const String estadoSolicitado = 'solicitado';
  static const String estadoBuscandoConductor =
      'buscando_conductor'; // Alias útil para UI
  // 2. Conductor acepta
  static const String estadoAceptado = 'aceptado';

  // 3. Conductor se dirige al origen
  static const String estadoEnCamino = 'en_camino';
  static const String estadoConductorEnCamino = 'en_camino';

  // 4. Conductor llega al origen
  static const String estadoLlegado = 'llegado';
  static const String estadoConductorLlego = 'llegado';

  // 5. Pasajero sube y comienza el traslado
  static const String estadoEnViaje = 'en_viaje';
  static const String estadoEnCurso = 'en_viaje';

  // 6. Finalización
  static const String estadoCompletado = 'completado';

  // Estados de interrupción
  static const String estadoCancelado = 'cancelado';
  static const String estadoRechazado = 'rechazado';
  static const String estadoError = 'error';
  static const String estadoErrorBusqueda = 'error_busqueda';

  // Lista completa de estados válidos para validaciones
  static const List<String> estadosValidos = [
    estadoSolicitado,
    estadoBuscandoConductor,
    estadoAceptado,
    estadoEnCamino,
    estadoLlegado,
    estadoEnViaje,
    estadoCompletado,
    estadoCancelado,
    estadoRechazado,
    estadoError,
    estadoErrorBusqueda
  ];

  // ========== TIPOS DE VEHÍCULO (Físicos) ==========
  static const String tipoCarro = 'carro';
  static const String tipoMoto = 'moto';

  // ========== CATEGORÍAS DE SERVICIO (Niveles) ==========
  static const String categoriaEconomico = 'economico';
  static const String categoriaConfort = 'confort';
  static const String categoriaViajesL = 'viajes_largos';

  // ========== CLAVES DE MAPA (Json Fields) ==========
  // Usar estas constantes evita errores de dedo ("typing errors")

  // Conductor / Usuario
  static const String campoNombre = 'nombre';
  static const String campoTelefono = 'telefono';
  static const String campoEmail = 'email';
  static const String campoPlaca = 'placa';
  static const String campoMarca = 'marca';
  static const String campoModelo = 'modelo';
  static const String campoColor = 'color';
  static const String campoAnio = 'anio';
  static const String campoCalificacion = 'calificacion';
  static const String campoEstaEnLinea = 'enLinea';
  static const String campoDisponible =
      'disponible'; // Booleano (falso si tiene viaje activo)
  static const String campoIdViajeActivo = 'idViajeActivo';
  static const String campoUbicacionActual =
      'ubicacionActual'; // Map o GeoPoint
  static const String campoTipoVehiculo = 'tipoVehiculo'; // carro, moto
  static const String campoCategoria = 'categoria'; // economico, confort...

  // Ubicación (Dentro de campoUbicacionActual)
  static const String campoLat = 'lat';
  static const String campoLng = 'lng';
  static const String campoHeading = 'heading'; // Dirección (grados)
  static const String campoTimestampUbicacion = 'timestamp';

  // Solicitud / Viaje
  static const String campoIdSolicitud = 'idSolicitud';
  static const String campoIdPasajero = 'idPasajero';
  static const String campoIdConductor = 'idConductor';
  static const String campoNombrePasajero = 'nombrePasajero';
  static const String campoTelefonoPasajero = 'telefonoPasajero';
  static const String campoNombreConductor = 'nombreConductor';
  static const String campoTelefonoConductor = 'telefonoConductor';

  static const String campoOrigen = 'origen'; // Map con direccion, lat, lng
  static const String campoDestino = 'destino'; // Map con direccion, lat, lng
  static const String campoDistancia = 'distancia';
  static const String campoDuracion = 'duracion';
  static const String campoPrecio = 'precio';
  static const String campoMetodoPago = 'metodoPago';

  static const String campoEstado = 'estado';
  static const String campoTimestamp = 'timestamp';
  static const String campoTimestampAceptacion = 'timestampAceptacion';
  static const String campoTimestampInicio = 'timestampInicio';
  static const String campoTimestampFinalizacion = 'timestampFinalizacion';

  // Campos de requerimiento (Lo que pide el pasajero)
  static const String campoTipoVehiculoRequerido =
      'tipoVehiculo'; // Puede coincidir con campoTipoVehiculo
  static const String campoCategoriaRequerida = 'categoria';

  // ========== VALIDACIONES Y UTILIDADES ==========

  static const double radioBusquedaMetros = 10000.0; // 10km
  static const int timeoutSolicitudSegundos = 300; // 5 min
  static const double calificacionMinima = 1.0;

  // Mapas de visualización (UI)
  static const Map<String, String> nombresCategoriaDisplay = {
    categoriaEconomico: 'Económico',
    categoriaConfort: 'Confort',
    categoriaViajesL: 'Viajes Largos',
  };

  static const Map<String, String> nombresTipoDisplay = {
    tipoCarro: 'Carro',
    tipoMoto: 'Moto',
  };

  /// Verifica si un conductor está disponible lógicamente
  static bool esConductorDisponible(Map<String, dynamic> data) {
    final bool enLinea = data[campoEstaEnLinea] == true;
    final dynamic idViaje = data[campoIdViajeActivo];
    final bool sinViaje = idViaje == null || idViaje.toString().isEmpty;
    // disponible puede ser null en conductores antiguos (retrocompatibles: se asume true)
    final dynamic disponibleRaw = data[campoDisponible];
    final bool disponible = disponibleRaw == null || disponibleRaw == true;
    // A veces la ubicación viene como Map, a veces como GeoPoint, validamos que exista
    final bool tieneUbicacion = data[campoUbicacionActual] != null;

    return enLinea && sinViaje && disponible && tieneUbicacion;
  }

  /// Lógica unificada de coincidencia de vehículo
  /// Maneja la conversión si la app de pasajeros envía "economico" como tipo en lugar de categoría
  static bool coincideCriterios(
    Map<String, dynamic> conductor,
    String tipoSolicitado,
    String categoriaSolicitada,
  ) {
    if (conductor.isEmpty) return false;

    String tipoConductor =
        (conductor[campoTipoVehiculo] ?? '').toString().toLowerCase();
    String catConductor =
        (conductor[campoCategoria] ?? '').toString().toLowerCase();

    // LÓGICA DE COMPATIBILIDAD:
    // Si la solicitud pide "economico" (que es una categoría) como tipo,
    // asumimos que es un Carro de categoría Económico.
    String tipoRealSolicitado = tipoSolicitado.toLowerCase();
    String catRealSolicitada = categoriaSolicitada.toLowerCase();

    // Parche para cuando la App Pasajero envía la categoría en el campo de tipo
    if ([categoriaEconomico, categoriaConfort, categoriaViajesL]
        .contains(tipoRealSolicitado)) {
      catRealSolicitada = tipoRealSolicitado;
      tipoRealSolicitado =
          tipoCarro; // Asumimos carro por defecto si piden categoría
    }

    // Verificación estricta
    bool tipoOk = tipoConductor == tipoRealSolicitado;

    // Lógica de categorías:
    // 1. Si no se especifica categoría, cualquiera del mismo tipo sirve.
    // 2. Si es Viajes Largos, los conductores Confort también aplican.
    // 3. De lo contrario, debe haber coincidencia exacta.
    bool catOk = catRealSolicitada.isEmpty ||
        catConductor == catRealSolicitada ||
        (catRealSolicitada == categoriaViajesL &&
            catConductor == categoriaConfort);

    return tipoOk && catOk;
  }

  /// Obtiene nombre para mostrar seguro
  static String obtenerNombreCategoria(String cat) =>
      nombresCategoriaDisplay[cat] ?? cat.toUpperCase();

  /// Obtiene nombre para mostrar seguro
  static String obtenerNombreTipo(String tipo) =>
      nombresTipoDisplay[tipo] ?? tipo.toUpperCase();

  /// Normaliza el tipo de vehículo
  static String normalizarTipoVehiculo(String tipo) {
    final t = tipo.toLowerCase().trim();
    if (t.contains('moto')) return tipoMoto;
    if (t.contains('carro') || t.contains('auto') || t.contains('taxi')) {
      return tipoCarro;
    }
    return tipoCarro; // Default
  }

  /// Normaliza la categoría
  static String normalizarCategoria(String cat) {
    if (cat.isEmpty) return '';
    final c = cat
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');

    if (c.contains('economico')) {
      return categoriaEconomico;
    }
    if (c.contains('confort') ||
        c.contains('estandar') ||
        c.contains('estándar') ||
        c.contains('normal')) {
      return categoriaConfort;
    }
    if (c.contains('viajes_largos') ||
        c.contains('viajes largos') ||
        c.contains('premium') ||
        c.contains('vip')) {
      return categoriaViajesL;
    }
    return categoriaConfort;
  }
}
