import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constantes_interoperabilidad.dart';
import 'servicios/firebase_db.dart';
import 'package:clickexpress/Pasajero/widgets/boton_emergencia.dart';

class SeguimientoSolicitudScreen extends StatefulWidget {
  final String idSolicitud;
  final String uidPasajero;
  final ServicioFirebase _servicio = ServicioFirebase();

  SeguimientoSolicitudScreen(
      {super.key, required this.idSolicitud, required this.uidPasajero});

  @override
  State<SeguimientoSolicitudScreen> createState() =>
      _SeguimientoSolicitudScreenState();
}

class _SeguimientoSolicitudScreenState
    extends State<SeguimientoSolicitudScreen> {
  bool _isCancelling = false;

  Future<void> _cancelarSolicitud() async {
    setState(() => _isCancelling = true);
    try {
      final exito = await widget._servicio
          .cancelarSolicitudViaje(widget.idSolicitud, widget.uidPasajero);
      if (exito && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud cancelada exitosamente')),
        );
        Navigator.of(context).pop(); // Go back to taxi screen
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cancelar la solicitud')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  void _mostrarDialogoConfirmacion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar solicitud'),
        content: const Text(
            '¿Estás seguro de que quieres cancelar esta solicitud de viaje?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cancelarSolicitud();
            },
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Seguimiento',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.teal,
      ),
      floatingActionButton: BotonEmergencia(
        uidUsuario: widget.uidPasajero,
        nombreUsuario: 'Usuario',
      ),
      body: StreamBuilder(
        stream:
            widget._servicio.obtenerSolicitudEnTiempoReal(widget.idSolicitud),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final solicitud = snapshot.data;
          if (solicitud == null) {
            return Center(
              child: Text(
                'No hay información de la solicitud',
                style: GoogleFonts.plusJakartaSans(fontSize: 16),
              ),
            );
          }

          final estado = solicitud.estado;
          final estadoWidget = _EstadoChip(estado: estado);

          final idConductor = solicitud.idConductor;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solicitud: ${solicitud.id}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Estado: ', style: GoogleFonts.plusJakartaSans()),
                    estadoWidget,
                  ],
                ),
                const SizedBox(height: 16),
                Text('Origen: ${solicitud.origen['nombre'] ?? ''}',
                    style: GoogleFonts.plusJakartaSans()),
                const SizedBox(height: 4),
                Text('Destino: ${solicitud.destino['nombre'] ?? ''}',
                    style: GoogleFonts.plusJakartaSans()),
                const Divider(height: 32),
                if (idConductor != null)
                  Expanded(
                    child: StreamBuilder(
                      stream: widget._servicio
                          .obtenerConductorEnTiempoReal(idConductor),
                      builder: (context, snapC) {
                        final conductor = snapC.data;
                        if (conductor == null) {
                          return Text('Buscando conductor...',
                              style: GoogleFonts.plusJakartaSans());
                        }
                        return ListView(
                          children: [
                            Text('Conductor asignado',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text('Nombre: ${conductor.nombre}',
                                style: GoogleFonts.plusJakartaSans()),
                            Text('Teléfono: ${conductor.telefono}',
                                style: GoogleFonts.plusJakartaSans()),
                            Text(
                                'Vehículo: ${conductor.tipoVehiculo} • ${conductor.categoria}',
                                style: GoogleFonts.plusJakartaSans()),
                            Text('Placa: ${conductor.placa}',
                                style: GoogleFonts.plusJakartaSans()),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.circle,
                                    size: 10, color: Colors.green),
                                const SizedBox(width: 6),
                                Text(
                                    conductor.estaEnLinea
                                        ? 'enLinea'
                                        : 'Desconectado',
                                    style: GoogleFonts.plusJakartaSans()),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  )
                else
                  Expanded(
                    child: Column(
                      children: [
                        Text('Esperando asignación de conductor...',
                            style: GoogleFonts.plusJakartaSans()),
                        const SizedBox(height: 20),
                        if (estado ==
                                ConstantesInteroperabilidad.estadoSolicitado ||
                            estado ==
                                ConstantesInteroperabilidad
                                    .estadoBuscandoConductor)
                          ElevatedButton(
                            onPressed: _isCancelling
                                ? null
                                : _mostrarDialogoConfirmacion,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: _isCancelling
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Cancelar solicitud'),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  final String estado;
  const _EstadoChip({required this.estado});

  Color _colorPorEstado(String e) {
    switch (e) {
      case 'solicitado':
        return Colors.orange;
      case 'aceptado':
      case 'en_camino':
        return Colors.blue;
      case 'en_viaje':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      case 'completado':
        return Colors.grey;
      default:
        return Colors.black54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _colorPorEstado(estado).withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colorPorEstado(estado)),
      ),
      child: Text(
        estado,
        style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600, color: _colorPorEstado(estado)),
      ),
    );
  }
}
