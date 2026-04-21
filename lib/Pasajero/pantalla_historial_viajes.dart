import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../widgets/menu_lateral.dart';
import 'servicios/firebase_db.dart';
import '../Servicios/servicio_tasa_bcv.dart';

class PantallaHistorialViajes extends StatelessWidget {
  const PantallaHistorialViajes({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final servicioFirebase = ServicioFirebase();

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi Historial')),
        body: const Center(child: Text('Debes iniciar sesión')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mis Viajes',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      drawer: const MenuLateral(),
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<List<SolicitudViaje>>(
        stream: servicioFirebase.obtenerHistorialViajes(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final viajes = snapshot.data ?? [];

          if (viajes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('Aún no tienes viajes registrados',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: viajes.length,
            itemBuilder: (context, index) {
              final viaje = viajes[index];
              return _TarjetaViaje(viaje: viaje, uidPasajero: user.uid);
            },
          );
        },
      ),
    );
  }
}

class _TarjetaViaje extends StatefulWidget {
  final SolicitudViaje viaje;
  final String uidPasajero;

  const _TarjetaViaje({required this.viaje, required this.uidPasajero});

  @override
  State<_TarjetaViaje> createState() => _TarjetaViajeState();
}

class _TarjetaViajeState extends State<_TarjetaViaje> {
  final ServicioFirebase _servicioFirebase = ServicioFirebase();
  bool _isFavorito = false;
  bool _isLoadingFavorito = true;

  @override
  void initState() {
    super.initState();
    _checkFavorito();
  }

  Future<void> _checkFavorito() async {
    if (widget.viaje.idConductor == null) {
      setState(() => _isLoadingFavorito = false);
      return;
    }
    try {
      final esFav = await _servicioFirebase.esFavorito(
          widget.uidPasajero, widget.viaje.idConductor!);
      if (mounted) {
        setState(() {
          _isFavorito = esFav;
          _isLoadingFavorito = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFavorito = false);
    }
  }

  Future<void> _toggleFavorito() async {
    if (widget.viaje.idConductor == null) return;
    try {
      await _servicioFirebase.toggleFavorito(
          widget.uidPasajero, widget.viaje.idConductor!);
      setState(() {
        _isFavorito = !_isFavorito;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFavorito
                ? 'Conductor agregado a favoritos ❤️'
                : 'Conductor eliminado de favoritos 💔'),
            duration: const Duration(seconds: 2),
            backgroundColor: _isFavorito ? Colors.teal : Colors.grey,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggle favorito: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final viaje = widget.viaje;
    final isMoto = viaje.tipoVehiculoRequerido == 'moto';
    final fecha = DateTime.fromMillisecondsSinceEpoch(viaje.timestamp);
    final formatoFecha = DateFormat('dd MMM yyyy, hh:mm a').format(fecha);

    final imageAsset =
        isMoto ? 'assets/imagen/moto_taxi.png' : 'assets/imagen/taxi_2.png';

    Color estadoColor;
    String estadoTexto;
    IconData estadoIcono;
    List<Color> gradienteColores;

    switch (viaje.estado.toLowerCase()) {
      case 'completado':
      case 'finalizado':
        estadoColor = Colors.green;
        estadoTexto = 'Finalizado';
        estadoIcono = Icons.check_circle;
        gradienteColores = [Colors.green.shade50, Colors.white];
        break;
      case 'cancelado':
        estadoColor = Colors.red;
        estadoTexto = 'Cancelado';
        estadoIcono = Icons.cancel;
        gradienteColores = [Colors.red.shade50, Colors.white];
        break;
      case 'cancelado_por_conductor':
      case 'canceladoporconductor':
        estadoColor = Colors.red.shade700;
        estadoTexto = 'Cancelado por conductor';
        estadoIcono = Icons.person_off;
        gradienteColores = [Colors.red.shade50, Colors.white];
        break;
      case 'cancelado_por_pasajero':
      case 'canceladoporpasajero':
        estadoColor = Colors.red;
        estadoTexto = 'Cancelado';
        estadoIcono = Icons.cancel;
        gradienteColores = [Colors.red.shade50, Colors.white];
        break;
      case 'en_camino':
      case 'encamino':
        estadoColor = Colors.blue;
        estadoTexto = 'En camino';
        estadoIcono = Icons.directions_car;
        gradienteColores = [Colors.blue.shade50, Colors.white];
        break;
      case 'en_viaje':
      case 'en_curso':
      case 'encurso':
        estadoColor = Colors.blue.shade700;
        estadoTexto = 'En curso';
        estadoIcono = Icons.navigation;
        gradienteColores = [Colors.blue.shade50, Colors.white];
        break;
      case 'aceptado':
        estadoColor = Colors.orange;
        estadoTexto = 'Aceptado';
        estadoIcono = Icons.thumb_up;
        gradienteColores = [Colors.orange.shade50, Colors.white];
        break;
      case 'solicitado':
      case 'pendiente':
      case 'buscando_conductor':
        estadoColor = Colors.orange.shade700;
        estadoTexto = 'Pendiente';
        estadoIcono = Icons.hourglass_empty;
        gradienteColores = [Colors.orange.shade50, Colors.white];
        break;
      default:
        estadoColor = Colors.grey;
        estadoTexto = viaje.estado;
        estadoIcono = Icons.info;
        gradienteColores = [Colors.grey.shade50, Colors.white];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradienteColores,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: estadoColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: estadoColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                estadoColor.withValues(alpha: 0.1),
                                estadoColor.withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: estadoColor.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Image.asset(imageAsset, fit: BoxFit.contain),
                        ),
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: estadoColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: estadoColor.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              estadoIcono,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMoto ? 'Moto Express' : 'Taxi Express',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time,
                                  size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                formatoFecha,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Badge y Favorito
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  estadoColor,
                                  estadoColor.withValues(alpha: 0.8)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: estadoColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              estadoTexto,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (viaje.idConductor != null && !_isLoadingFavorito)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: GestureDetector(
                                onTap: _toggleFavorito,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withValues(alpha: 0.2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _isFavorito
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: _isFavorito
                                        ? Colors.red
                                        : Colors.grey.shade400,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        estadoColor.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.my_location,
                              size: 18, color: Colors.blue.shade700),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Origen',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                viaje.origen['nombre'] ?? 'Origen desconocido',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.location_on,
                              size: 18, color: Colors.red.shade700),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Destino',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                viaje.destino is String
                                    ? viaje.destino
                                    : (viaje.destino['nombre'] ??
                                        'Destino desconocido'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        estadoColor.withValues(alpha: 0.08),
                        estadoColor.withValues(alpha: 0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.attach_money,
                              color: estadoColor, size: 24),
                          const SizedBox(width: 4),
                          Text(
                            'Total',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${viaje.precio.toStringAsFixed(2)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: estadoColor,
                            ),
                          ),
                          Text(
                            ServicioTasaBCV().formatearSoloBs(viaje.precio),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: estadoColor.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
