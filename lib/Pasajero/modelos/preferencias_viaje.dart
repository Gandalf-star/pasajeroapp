/// Modelo para preferencias de viaje del pasajero
class PreferenciasViaje {
  // Preferencias de ambiente
  final bool modoSilencio;
  final double temperatura; // 16-30 grados
  final bool ventanasAbiertas;

  // Preferencias de música
  final bool musicaHabilitada;
  final String? generoMusical; // pop, rock, clásica, reggaeton, etc
  final int volumen; // 0-100

  // Preferencias de conversación
  final bool conversacionHabilitada; // false = viaje en silencio

  // Preferencias de ruta
  final bool evitarPeajes;
  final bool rutaMasRapida; // true = ruta mas rapida, false = ruta mas corta

  // Preferencias adicionales
  final bool aireAcondicionado;
  final bool cinturonAjustado;
  final bool asientoTrasero; // preferencia por sentarse atrás
  final String? notasAdicionales;

  const PreferenciasViaje({
    this.modoSilencio = false,
    this.temperatura = 22.0,
    this.ventanasAbiertas = false,
    this.musicaHabilitada = true,
    this.generoMusical,
    this.volumen = 50,
    this.conversacionHabilitada = true,
    this.evitarPeajes = false,
    this.rutaMasRapida = true,
    this.aireAcondicionado = true,
    this.cinturonAjustado = false,
    this.asientoTrasero = false,
    this.notasAdicionales,
  });

  /// Crear desde mapa de Firebase o local
  factory PreferenciasViaje.desdeMapa(Map<dynamic, dynamic>? data) {
    if (data == null) return const PreferenciasViaje();

    String toStr(dynamic v, [String def = '']) =>
        v == null ? def : v.toString();

    double toDouble(dynamic v, [double def = 0.0]) {
      if (v == null) return def;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? def;
    }

    int toInt(dynamic v, [int def = 0]) {
      if (v == null) return def;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? def;
    }

    return PreferenciasViaje(
      modoSilencio: data['modoSilencio'] == true,
      temperatura: toDouble(data['temperatura'], 22.0),
      ventanasAbiertas: data['ventanasAbiertas'] == true,
      musicaHabilitada: data['musicaHabilitada'] != false,
      generoMusical: toStr(data['generoMusical']).isEmpty
          ? null
          : toStr(data['generoMusical']),
      volumen: toInt(data['volumen'], 50).clamp(0, 100),
      conversacionHabilitada: data['conversacionHabilitada'] != false,
      evitarPeajes: data['evitarPeajes'] == true,
      rutaMasRapida: data['rutaMasRapida'] != false,
      aireAcondicionado: data['aireAcondicionado'] != false,
      cinturonAjustado: data['cinturonAjustado'] == true,
      asientoTrasero: data['asientoTrasero'] == true,
      notasAdicionales: toStr(data['notasAdicionales']).isEmpty
          ? null
          : toStr(data['notasAdicionales']),
    );
  }

  /// Convertir a mapa para Firebase
  Map<String, dynamic> toMapa() {
    return {
      'modoSilencio': modoSilencio,
      'temperatura': temperatura,
      'ventanasAbiertas': ventanasAbiertas,
      'musicaHabilitada': musicaHabilitada,
      'generoMusical': generoMusical,
      'volumen': volumen,
      'conversacionHabilitada': conversacionHabilitada,
      'evitarPeajes': evitarPeajes,
      'rutaMasRapida': rutaMasRapida,
      'aireAcondicionado': aireAcondicionado,
      'cinturonAjustado': cinturonAjustado,
      'asientoTrasero': asientoTrasero,
      'notasAdicionales': notasAdicionales,
    };
  }

  /// Crear copia con modificaciones
  PreferenciasViaje copyWith({
    bool? modoSilencio,
    double? temperatura,
    bool? ventanasAbiertas,
    bool? musicaHabilitada,
    String? generoMusical,
    int? volumen,
    bool? conversacionHabilitada,
    bool? evitarPeajes,
    bool? rutaMasRapida,
    bool? aireAcondicionado,
    bool? cinturonAjustado,
    bool? asientoTrasero,
    String? notasAdicionales,
  }) {
    return PreferenciasViaje(
      modoSilencio: modoSilencio ?? this.modoSilencio,
      temperatura: temperatura ?? this.temperatura,
      ventanasAbiertas: ventanasAbiertas ?? this.ventanasAbiertas,
      musicaHabilitada: musicaHabilitada ?? this.musicaHabilitada,
      generoMusical: generoMusical ?? this.generoMusical,
      volumen: volumen ?? this.volumen,
      conversacionHabilitada:
          conversacionHabilitada ?? this.conversacionHabilitada,
      evitarPeajes: evitarPeajes ?? this.evitarPeajes,
      rutaMasRapida: rutaMasRapida ?? this.rutaMasRapida,
      aireAcondicionado: aireAcondicionado ?? this.aireAcondicionado,
      cinturonAjustado: cinturonAjustado ?? this.cinturonAjustado,
      asientoTrasero: asientoTrasero ?? this.asientoTrasero,
      notasAdicionales: notasAdicionales ?? this.notasAdicionales,
    );
  }

  /// Preferencias por defecto
  static const PreferenciasViaje porDefecto = PreferenciasViaje();

  /// Lista de géneros musicales disponibles
  static const List<String> generosMusicales = [
    'Ninguno en particular',
    'Pop',
    'Rock',
    'Clásica',
    'Jazz',
    'Reggaetón',
    'Salsa',
    'Bachata',
    'Electrónica',
    'Llanera',
  ];
}
