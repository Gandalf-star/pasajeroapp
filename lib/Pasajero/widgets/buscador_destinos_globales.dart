import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../modelos/destino_global.dart';
import '../servicios/servicio_destinos_globales.dart';

/// Widget de búsqueda de destinos con autocompletado
class BuscadorDestinosGlobales extends StatefulWidget {
  final Function(DestinoGlobal) onDestinoSeleccionado;
  final String? textoInicial;

  const BuscadorDestinosGlobales({
    super.key,
    required this.onDestinoSeleccionado,
    this.textoInicial,
  });

  @override
  State<BuscadorDestinosGlobales> createState() =>
      _BuscadorDestinosGlobalesState();
}

class _BuscadorDestinosGlobalesState extends State<BuscadorDestinosGlobales> {
  final TextEditingController _controller = TextEditingController();
  final ServicioDestinosGlobales _servicio = ServicioDestinosGlobales();
  final FocusNode _focusNode = FocusNode();

  List<DestinoGlobal> _sugerencias = [];
  bool _cargando = false;
  bool _mostrarSugerencias = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    if (widget.textoInicial != null) {
      _controller.text = widget.textoInicial!;
    }
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);

    // Cargar destinos populares al inicio
    _cargarDestinosPopulares();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _sugerencias.isNotEmpty) {
      setState(() {
        _mostrarSugerencias = true;
      });
    }
  }

  void _onTextChanged() {
    // Cancelar timer anterior
    _debounceTimer?.cancel();

    final query = _controller.text.trim();

    if (query.isEmpty) {
      // Mostrar destinos populares si no hay texto
      _cargarDestinosPopulares();
      return;
    }

    if (query.length < 2) {
      setState(() {
        _sugerencias = [];
        _mostrarSugerencias = false;
      });
      return;
    }

    // Esperar 500ms antes de buscar (debounce)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _buscarDestinos(query);
    });
  }

  Future<void> _cargarDestinosPopulares() async {
    setState(() {
      _cargando = true;
    });

    try {
      final destinos = await _servicio.obtenerDestinosPopulares(limite: 10);
      if (mounted) {
        setState(() {
          _sugerencias = destinos;
          _cargando = false;
          _mostrarSugerencias = _focusNode.hasFocus;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar destinos populares: $e');
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  Future<void> _buscarDestinos(String query) async {
    setState(() {
      _cargando = true;
    });

    try {
      final resultados = await _servicio.buscarDestinos(query);
      if (mounted) {
        setState(() {
          _sugerencias = resultados;
          _cargando = false;
          _mostrarSugerencias = true;
        });
      }
    } catch (e) {
      debugPrint('Error al buscar destinos: $e');
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  void _seleccionarDestino(DestinoGlobal destino) {
    _controller.text = destino.nombre;
    setState(() {
      _mostrarSugerencias = false;
    });
    _focusNode.unfocus();
    widget.onDestinoSeleccionado(destino);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Campo de búsqueda
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Buscar destino...',
            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey),
            prefixIcon: const Icon(Icons.search, color: Colors.green),
            suffixIcon: _cargando
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          _cargarDestinosPopulares();
                        },
                      )
                    : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.green),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.green, width: 2),
            ),
          ),
          style: GoogleFonts.plusJakartaSans(),
        ),

        // Lista de sugerencias
        if (_mostrarSugerencias && _sugerencias.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _sugerencias.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final destino = _sugerencias[index];
                return _construirSugerencia(destino);
              },
            ),
          ),

        // Mensaje si no hay resultados
        if (_mostrarSugerencias &&
            _sugerencias.isEmpty &&
            !_cargando &&
            _controller.text.length >= 2)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No se encontraron destinos. Escribe el nombre y selecciona en el mapa.',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _construirSugerencia(DestinoGlobal destino) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: destino.tieneCoordenadasExactas
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          destino.tieneCoordenadasExactas
              ? Icons.location_on
              : Icons.location_off,
          color: destino.tieneCoordenadasExactas ? Colors.green : Colors.orange,
          size: 24,
        ),
      ),
      title: Text(
        destino.nombre,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Icon(
            Icons.trending_up,
            size: 14,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(
            '${destino.vecesUsado} viajes',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 8),
          if (destino.tieneCoordenadasExactas)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Ubicación exacta',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Sin coordenadas',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => _seleccionarDestino(destino),
    );
  }
}
