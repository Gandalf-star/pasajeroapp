import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../servicios/servicio_calificacion.dart';

class ModalCalificacionConductor extends StatefulWidget {
  final String idViaje;
  final String idConductor;
  final String nombreConductor;
  final VoidCallback onCompletado;

  const ModalCalificacionConductor({
    super.key,
    required this.idViaje,
    required this.idConductor,
    required this.nombreConductor,
    required this.onCompletado,
  });

  @override
  State<ModalCalificacionConductor> createState() => _ModalCalificacionConductorState();
}

class _ModalCalificacionConductorState extends State<ModalCalificacionConductor> {
  int _calificacion = 5;
  final TextEditingController _comentarioController = TextEditingController();
  bool _enviando = false;
  
  final ServicioCalificacion _servicioCalificacion = ServicioCalificacion();

  Future<void> _enviarCalificacion() async {
    setState(() => _enviando = true);
    
    try {
      await _servicioCalificacion.enviarCalificacionYComentario(
        idViaje: widget.idViaje,
        idConductor: widget.idConductor,
        calificacion: _calificacion,
        comentario: _comentarioController.text,
      );
    } catch (e) {
      debugPrint('Error enviando calificación (UI): $e');
      // No bloqueamos a pesar del error por la UX original
    } finally {
      if (mounted) {
        widget.onCompletado();
      }
    }
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.center,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      elevation: 20,
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24), 
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.teal.withValues(alpha: 0.2),
              blurRadius: 30,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.tealAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: Colors.tealAccent, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              'VIAJE COMPLETADO',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.tealAccent,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '¿Qué te pareció el viaje con ${widget.nombreConductor}?',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            
            // Estrellas Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _calificacion = index + 1;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      index < _calificacion ? Icons.star_rounded : Icons.star_border_rounded,
                      color: index < _calificacion ? Colors.amber : Colors.white.withValues(alpha: 0.3),
                      size: index < _calificacion ? 46 : 40,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Text(
              _calificacion == 5 ? '¡Excelente!' : _calificacion >= 4 ? 'Muy bien' : _calificacion == 3 ? 'Aceptable' : _calificacion == 2 ? 'Con problemas' : 'Pésimo',
              style: GoogleFonts.plusJakartaSans(
                 fontSize: 16,
                 color: Colors.amber,
                 fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            
            // Comentario Opcional
            TextField(
              controller: _comentarioController,
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Añadir comentario opcional...',
                hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),

            // Botón de Enviar
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _enviando ? null : _enviarCalificacion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent.shade400,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                ),
                child: _enviando 
                 ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3))
                 : Text(
                  'ENVIAR CALIFICACIÓN',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
