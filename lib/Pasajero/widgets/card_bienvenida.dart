import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../../Servicios/servicio_tasa_bcv.dart';

class CardBienvenida extends StatelessWidget {
  final String nombreUsuario;
  final Position? posicionActual;
  final String? fotoUrl;

  const CardBienvenida({
    super.key,
    required this.nombreUsuario,
    this.posicionActual,
    this.fotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hora = DateTime.now().hour;
    final String saludo = hora < 12
        ? '¡Buenos días!'
        : hora < 18
            ? '¡Buenas tardes!'
            : '¡Buenas noches!';

    final String nombreMostrar = () {
      if (nombreUsuario.isEmpty) return 'Usuario';
      final partes = nombreUsuario.trim().split(' ');
      if (partes.length >= 2) return '${partes[0]} ${partes[1]}';
      return partes[0];
    }();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            Colors.teal.shade50.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Fila principal: avatar + info ──────────────────────────────
            Row(
              children: [
                // Avatar
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade400, Colors.blue.shade400],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: fotoUrl != null && fotoUrl!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            fotoUrl!,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        )
                      : const Icon(Icons.person, color: Colors.white, size: 36),
                ),

                const SizedBox(width: 14),

                // Saludo + nombre + ubicación
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        saludo,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nombreMostrar,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 13, color: Colors.teal.shade600),
                          const SizedBox(width: 3),
                          Text(
                            'Ubicación actual',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Badge BCV — fila completa debajo ───────────────────────────
            StreamBuilder<double>(
              stream: ServicioTasaBCV().obtenerTasaStream(),
              initialData: ServicioTasaBCV().tasaActual,
              builder: (context, snapshot) {
                final tasa = snapshot.data ?? 0.0;
                return Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.teal.shade600,
                        Colors.blue.shade500,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.attach_money,
                          color: Colors.white, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        tasa > 0
                            ? 'Dólar BCV: Bs ${tasa.toStringAsFixed(2)}'
                            : 'Cargando tasa BCV...',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
