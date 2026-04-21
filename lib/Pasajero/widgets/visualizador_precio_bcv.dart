import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../Servicios/servicio_tasa_bcv.dart'; 

class VisualizadorPrecioBCV extends StatelessWidget {
  final double precioUSD;
  final Color colorTexto;

  const VisualizadorPrecioBCV({
    super.key,
    required this.precioUSD,
    this.colorTexto = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: ServicioTasaBCV().obtenerTasaStream(),
      initialData: ServicioTasaBCV().tasaActual,
      builder: (context, snapshot) {
        final tasa = snapshot.data ?? 0.0;
        final bs = tasa > 0 ? precioUSD * tasa : null;
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$${precioUSD.toStringAsFixed(2)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorTexto,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              bs != null
                  ? 'Bs ${bs.toStringAsFixed(2)}'
                  : 'Cargando Bs...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorTexto.withValues(alpha: 0.9),
              ),
            ),
          ],
        );
      },
    );
  }
}