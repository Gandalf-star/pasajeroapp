import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

// ————————————————————————————————————————————————————————
//  Constantes
// ————————————————————————————————————————————————————————
const _kApiKey = 'AIzaSyA7QmnEK36qat8Sam-Rpbu_mfOfAt1JtqQ';
const _kAndroidPackage = 'click_express.project';
const _kAndroidCert = '50EF7093A7572E7A53F70CC1B5EAD150AE5CC2CC';

Map<String, String> get _androidHeaders => {
      'X-Android-Package': _kAndroidPackage,
      'X-Android-Cert': _kAndroidCert,
    };

// Radio en metros para búsqueda local (≈ radio de una ciudad mediana).
const double _radioLocalM = 12000;
// Radio en metros para modo viajes largos (cubre Tinaquillo→Valencia ~140 km).
const double _radioViajeLargoM = 150000;

// ————————————————————————————————————————————————————————
//  Modelos públicos
// ————————————————————————————————————————————————————————
class LugarPrediccion {
  final String placeId;
  final String descripcion;
  const LugarPrediccion({required this.placeId, required this.descripcion});
}

class LugarSeleccionado {
  final String nombre;
  final double lat;
  final double lng;
  const LugarSeleccionado(
      {required this.nombre, required this.lat, required this.lng});
}

// ————————————————————————————————————————————————————————
//  Widget
// ————————————————————————————————————————————————————————
class CampoDestinoAutocomplete extends StatefulWidget {
  /// Posición actual del pasajero (requerida para el bias geográfico).
  final double? origenLat;
  final double? origenLng;

  /// Controlador del campo de texto.
  final TextEditingController controller;

  /// Callback cuando el usuario selecciona una sugerencia.
  final void Function(LugarSeleccionado lugar) onLugarSeleccionado;

  /// Cuando es `true`, las sugerencias cubren las tres ciudades
  /// (Tinaquillo, San Carlos y Valencia) en lugar de restringirse
  /// solo a la ciudad actual.
  final bool esViajeLargo;

  // Parámetro ignorado — la clave se mantiene internamente.
  final String? apiKey;

  const CampoDestinoAutocomplete({
    super.key,
    required this.controller,
    required this.onLugarSeleccionado,
    this.origenLat,
    this.origenLng,
    this.esViajeLargo = false,
    this.apiKey,
  });

  @override
  State<CampoDestinoAutocomplete> createState() =>
      _CampoDestinoAutocompleteState();
}

class _CampoDestinoAutocompleteState extends State<CampoDestinoAutocomplete> {
  final FocusNode _focusNode = FocusNode();
  List<LugarPrediccion> _predicciones = [];
  bool _cargando = false;
  bool _mostrarSugerencias = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  // ── Listener ─────────────────────────────────────────
  void _onTextChanged() {
    final texto = widget.controller.text.trim();
    if (texto.length < 3) {
      if (_predicciones.isNotEmpty || _mostrarSugerencias) {
        setState(() {
          _predicciones = [];
          _mostrarSugerencias = false;
        });
      }
      return;
    }
    _debounce?.cancel();
    _debounce =
        Timer(const Duration(milliseconds: 450), () => _buscarLugares(texto));
  }

  // ── Construcción de parámetros según modo ─────────────
  Map<String, String> _buildParams(String input) {
    final params = <String, String>{
      'input': input,
      'key': _kApiKey,
      'language': 'es',
    };

    if (widget.esViajeLargo) {
      // Centroide aproximado de Tinaquillo + San Carlos + Valencia
      const centroLat = 9.9086; // (9.9028 + 9.6603 + 10.1626) / 3
      const centroLng = -68.2844; // (-68.3045 + -68.5742 + -67.9956) / 3
      params['location'] = '$centroLat,$centroLng';
      params['radius'] = '${_radioViajeLargoM.toInt()}';
      params['components'] = 'country:ve';
      // NO ponemos strictbounds para que Google pueda devolver los tres
      // municipios aunque el usuario esté físicamente en uno solo.
    } else {
      // Modo local: bias hacia la posición actual del usuario
      // con radio pequeño + strictbounds para que sólo aparezcan lugares
      // del municipio donde se encuentra.
      final lat = widget.origenLat;
      final lng = widget.origenLng;
      if (lat != null && lng != null) {
        params['location'] = '$lat,$lng';
        params['radius'] = '${_radioLocalM.toInt()}';
        params['strictbounds'] = 'true';
      }
      params['components'] = 'country:ve';
    }

    return params;
  }

  // ── Llamada a Places Autocomplete API ────────────────
  Future<void> _buscarLugares(String input) async {
    if (!mounted) return;
    setState(() => _cargando = true);

    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        _buildParams(input),
      );

      debugPrint('🔍 [Places] → $uri');
      final response = await http
          .get(uri, headers: _androidHeaders)
          .timeout(const Duration(seconds: 10));

      final preview = response.body.length > 300
          ? response.body.substring(0, 300)
          : response.body;
      debugPrint('🔍 [Places] ← ${response.statusCode} | $preview');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final apiStatus = data['status'] as String? ?? '';
        debugPrint('🔍 [Places] status=$apiStatus');

        if (apiStatus == 'OK') {
          final preds = (data['predictions'] as List<dynamic>?) ?? [];
          setState(() {
            _predicciones = preds
                .map((p) => LugarPrediccion(
                      placeId: p['place_id'] as String? ?? '',
                      descripcion: p['description'] as String? ?? '',
                    ))
                .where((p) => p.placeId.isNotEmpty)
                .toList();
            _mostrarSugerencias = _predicciones.isNotEmpty;
            _cargando = false;
          });
          return;
        }

        if (apiStatus == 'REQUEST_DENIED') {
          debugPrint('⚠️ [Places] REQUEST_DENIED – intentando Places API v1…');
          await _buscarLugaresV1(input);
          return;
        }
      }
      if (mounted) setState(() => _cargando = false);
    } catch (e) {
      debugPrint('⚠️ [Places] Error: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ── Fallback: New Places API v1 (POST) ───────────────
  Future<void> _buscarLugaresV1(String input) async {
    try {
      final uri = Uri.https('places.googleapis.com', '/v1/places:autocomplete');

      Map<String, dynamic> locationBias;
      if (widget.esViajeLargo) {
        // Centroide fijo de las 3 ciudades
        const centroLat = 9.9086;
        const centroLng = -68.2844;
        locationBias = {
          'circle': {
            'center': {'latitude': centroLat, 'longitude': centroLng},
            'radius': _radioViajeLargoM,
          }
        };
      } else {
        final lat = widget.origenLat ?? 9.9028; // fallback: Tinaquillo
        final lng = widget.origenLng ?? -68.3045;
        locationBias = {
          'circle': {
            'center': {'latitude': lat, 'longitude': lng},
            'radius': _radioLocalM,
          }
        };
      }

      final body = json.encode({
        'input': input,
        'languageCode': 'es',
        'includedRegionCodes': ['ve'],
        'locationBias': locationBias,
      });

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _kApiKey,
              ..._androidHeaders,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final suggestions = (data['suggestions'] as List<dynamic>?) ?? [];
        final preds = suggestions
            .map((s) {
              final place = s['placePrediction'] as Map<String, dynamic>?;
              if (place == null) return null;
              return LugarPrediccion(
                placeId: place['placeId'] as String? ?? '',
                descripcion: (place['text']?['text'] as String?) ??
                    (place['structuredFormat']?['mainText']?['text']
                        as String?) ??
                    '',
              );
            })
            .whereType<LugarPrediccion>()
            .where((p) => p.placeId.isNotEmpty && p.descripcion.isNotEmpty)
            .toList();

        setState(() {
          _predicciones = preds;
          _mostrarSugerencias = preds.isNotEmpty;
          _cargando = false;
        });
      } else {
        setState(() => _cargando = false);
      }
    } catch (e) {
      debugPrint('⚠️ [Places v1] Error: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ── Selección de sugerencia → obtener coordenadas ────
  Future<void> _seleccionarLugar(LugarPrediccion prediccion) async {
    widget.controller.text = prediccion.descripcion;
    setState(() {
      _mostrarSugerencias = false;
      _predicciones = [];
      _cargando = true;
    });
    Future.delayed(
        const Duration(milliseconds: 100), () => _focusNode.unfocus());

    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        {
          'place_id': prediccion.placeId,
          'fields': 'geometry,name,formatted_address',
          'key': _kApiKey,
          'language': 'es',
        },
      );

      final response = await http
          .get(uri, headers: _androidHeaders)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final location =
            data['result']?['geometry']?['location'] as Map<String, dynamic>?;
        if (location != null) {
          final lat = (location['lat'] as num).toDouble();
          final lng = (location['lng'] as num).toDouble();
          widget.onLugarSeleccionado(LugarSeleccionado(
              nombre: prediccion.descripcion, lat: lat, lng: lng));
          debugPrint('✅ [Places] → ${prediccion.descripcion} ($lat, $lng)');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [Places] Details error: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _ocultarSugerencias() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _mostrarSugerencias = false);
    });
  }

  // ── UI ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Indicador de modo viaje largo
        if (widget.esViajeLargo)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade700, Colors.indigo.shade400],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.route, size: 13, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'Destinos: Tinaquillo · San Carlos · Valencia',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        // Campo de texto
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
            onTap: () {
              if (widget.controller.text.trim().length >= 3 &&
                  _predicciones.isNotEmpty) {
                setState(() => _mostrarSugerencias = true);
              }
            },
            onEditingComplete: _ocultarSugerencias,
            decoration: InputDecoration(
              labelText: 'Destino',
              hintText: widget.esViajeLargo
                  ? 'Escribe el destino en San Carlos o Valencia…'
                  : 'Escribe el lugar de destino…',
              prefixIcon: const Icon(Icons.location_on_rounded,
                  color: Colors.redAccent),
              suffixIcon: _cargando
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.teal),
                      ),
                    )
                  : widget.controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              size: 18, color: Colors.grey),
                          onPressed: () {
                            widget.controller.clear();
                            setState(() {
                              _predicciones = [];
                              _mostrarSugerencias = false;
                            });
                          },
                        )
                      : const Icon(Icons.search, color: Colors.grey, size: 18),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),

        // Lista de sugerencias
        if (_mostrarSugerencias && _predicciones.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: widget.esViajeLargo
                      ? Colors.indigo.shade100
                      : Colors.teal.shade100),
              boxShadow: [
                BoxShadow(
                  color: (widget.esViajeLargo ? Colors.indigo : Colors.teal)
                      .withValues(alpha: 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          widget.esViajeLargo
                              ? Icons.directions_car
                              : Icons.place,
                          size: 14,
                          color: widget.esViajeLargo
                              ? Colors.indigo.shade600
                              : Colors.teal.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.esViajeLargo
                              ? 'Destinos de viaje largo'
                              : 'Sugerencias locales',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: widget.esViajeLargo
                                ? Colors.indigo.shade700
                                : Colors.teal.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1),
                  ...List.generate(
                    _predicciones.length > 5 ? 5 : _predicciones.length,
                    (index) {
                      final pred = _predicciones[index];
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (index > 0) const Divider(height: 1),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _seleccionarLugar(pred),
                              splashColor: widget.esViajeLargo
                                  ? Colors.indigo.shade50
                                  : Colors.teal.shade50,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 13),
                                child: Row(
                                  children: [
                                    Icon(
                                      widget.esViajeLargo
                                          ? Icons.location_city
                                          : Icons.location_city_rounded,
                                      size: 16,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        pred.descripcion,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          color: Colors.grey.shade800,
                                          height: 1.3,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right,
                                        size: 16, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
