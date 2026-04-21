import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:clickexpress/Pasajero/servicios/firebase_db.dart';
import 'package:clickexpress/widgets/menu_lateral.dart';
import 'package:clickexpress/Pasajero/widgets/hoja_solicitud_viaje.dart';
import 'package:clickexpress/Pasajero/widgets/boton_emergencia.dart';

import 'package:clickexpress/utils/constantes_interoperabilidad.dart';
import 'package:geolocator/geolocator.dart';
import 'package:clickexpress/Servicios/servicio_tasa_bcv.dart';

class PantallaPanelControl extends StatefulWidget {
  const PantallaPanelControl({super.key});

  @override
  State<PantallaPanelControl> createState() => _PantallaPanelControlState();
}

class _PantallaPanelControlState extends State<PantallaPanelControl> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('FLASHDRIVE',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            )),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.teal.shade700,
                Colors.teal.shade500,
                Colors.teal.shade800,
                Colors.black87,
              ],
              stops: const [0.0, 0.3, 0.6, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        elevation: 0,
      ),
      drawer: const MenuLateral(),
      drawerScrimColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueGrey.withValues(alpha: 0.8),
                        blurRadius: 8,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    '¿A DÓNDE QUIERES IR HOY?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (uid != null) ...[
                _CardBienvenidaDashboard(uid: uid),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.only(left: 30.0, right: 30.0),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.8),
                          blurRadius: 8,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'ACCESOS RAPIDOS',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 15.0,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _CardAccionRapida(
                        icono: Icons.calendar_month,
                        titulo: 'Reservar',
                        onTap: () => _mostrarDialogoProgramarViaje(uid),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _CardAccionRapida(
                        icono: Icons.tune,
                        titulo: 'Preferencias',
                        onTap: () =>
                            Navigator.pushNamed(context, '/preferencias_viaje'),
                      ),
                    ),
                  ],
                ),
              ] else
                const SizedBox(height: 80),
              const SizedBox(height: 24),

              // Servicos de Viaje
              Padding(
                padding: const EdgeInsets.only(left: 30.0, right: 30.0),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.0),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 8,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'SERVICIOS DE VIAJE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(
                height: 15.0,
              ),

              //Tarjetas Principales
              Row(
                children: [
                  // Tarjeta Moto
                  Expanded(
                    child: _TarjetaServicioVibrante(
                      titulo: 'Moto',
                      imagen: 'assets/imagen/moto_taxi.png',
                      colores: [
                        Colors.black,
                        Colors.teal.shade800,
                      ],
                      ruta: '/Mototaxis',
                      etiqueta: 'RÁPIDO',
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Tarjeta Taxi
                  Expanded(
                    child: _TarjetaServicioVibrante(
                      titulo: 'Taxi',
                      imagen: 'assets/imagen/taxi_2.png',
                      colores: [
                        Colors.black,
                        Colors.blue,
                      ],
                      ruta: '/Taxis',
                      etiqueta: 'CONFORT',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              //Sugerencias (Grid de Iconos)
              Padding(
                padding: const EdgeInsets.only(left: 30.0, right: 30.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.black.withValues(alpha: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.8),
                          blurRadius: 8,
                          offset: const Offset(0, 6),
                        ),
                      ]),
                  child: Center(
                    child: Text(
                      'SUGERENCIAS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Fila 1
              Row(
                children: [
                  Expanded(
                    child: _IconoSugerencia(
                      titulo: 'Favoritos',
                      iconData: Icons.favorite_rounded,
                      colorIcono: Colors.white,
                      ruta: '/favoritos',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _IconoSugerencia(
                      titulo: 'Historial',
                      imagen: 'assets/imagen/registro.png',
                      iconData: Icons.history_rounded,
                      colorIcono: Colors.white,
                      ruta: '/historial',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Fila 2
              Row(
                children: [
                  Expanded(
                    child: _IconoSugerencia(
                      titulo: 'Mi Billetera',
                      imagen: 'assets/imagen/billetera.png',
                      iconData: Icons.account_balance_wallet_rounded,
                      colorIcono: Colors.white,
                      ruta: '/billetera',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _IconoSugerencia(
                      titulo: 'Perfil',
                      imagen: 'assets/imagen/perfil.png',
                      iconData: Icons.person_rounded,
                      colorIcono: Colors.white,
                      ruta: '/perfil',
                      tamanoImagen: 45.0,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Banner Promocional
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Colors.teal.shade300, Colors.black87]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5))
                    ]),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CLICK EXPRESS CONFORT',
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Viaja con la máxima seguridad y confort.',
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.star, color: Colors.amber, size: 36)
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDialogoProgramarViaje(String uid) async {
    final messenger = ScaffoldMessenger.of(context);

    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 7)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 30))),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time == null) return;

    final finalDateTime =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (finalDateTime.isBefore(now)) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('La hora de programación debe ser a futuro'),
            backgroundColor: Colors.red),
      );
      return;
    }

    if (!mounted) return;
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Categoría de Reserva',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selecciona la opción de viaje programado',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 24),

                  // Motos
                  _ConstruirCardServicioReserva(
                    titulo: 'Moto Económico',
                    subtitulo: 'Rápido y accesible',
                    imagenPath: 'assets/imagen/moto_taxi.png',
                    colorFondoIcono: Colors.teal.shade50,
                    onTap: () {
                      Navigator.pop(ctx);
                      _lanzarHoja(
                          uid,
                          ConstantesInteroperabilidad.categoriaEconomico,
                          ConstantesInteroperabilidad.tipoMoto,
                          finalDateTime);
                    },
                  ),

                  const SizedBox(height: 8),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 8),

                  // Taxis
                  _ConstruirCardServicioReserva(
                    titulo: 'Taxi Económico',
                    subtitulo: 'Básico y accesible',
                    imagenPath: 'assets/imagen/taxi_2.png',
                    colorFondoIcono: Colors.blue.shade50,
                    onTap: () {
                      Navigator.pop(ctx);
                      _lanzarHoja(
                          uid,
                          ConstantesInteroperabilidad.categoriaEconomico,
                          ConstantesInteroperabilidad.tipoCarro,
                          finalDateTime);
                    },
                  ),
                  _ConstruirCardServicioReserva(
                    titulo: 'Taxi Confort',
                    subtitulo: 'Comodidad garantizada',
                    imagenPath: 'assets/imagen/taxi_2.png',
                    colorFondoIcono: Colors.blue.shade50,
                    onTap: () {
                      Navigator.pop(ctx);
                      _lanzarHoja(
                          uid,
                          ConstantesInteroperabilidad.categoriaConfort,
                          ConstantesInteroperabilidad.tipoCarro,
                          finalDateTime);
                    },
                  ),
                  _ConstruirCardServicioReserva(
                    titulo: 'Viajes Largos',
                    subtitulo: 'San Carlos / Valencia',
                    imagenPath: 'assets/imagen/taxi_2.png',
                    colorFondoIcono: Colors.indigo.shade50,
                    onTap: () {
                      Navigator.pop(ctx);
                      _lanzarHoja(
                          uid,
                          ConstantesInteroperabilidad.categoriaViajesL,
                          ConstantesInteroperabilidad.tipoCarro,
                          finalDateTime);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        });
  }

  void _lanzarHoja(String uid, String categoria, String tipoVehiculo,
      DateTime fechaProgramada) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final posicion = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      final datosPerfilMap =
          await ServicioFirebase().obtenerPerfilPasajeroStream(uid).first;

      if (!mounted) return;
      if (nav.canPop()) nav.pop(); // cerramos loader

      double precioEstimado = 2.5;
      if (tipoVehiculo == ConstantesInteroperabilidad.tipoCarro) {
        if (categoria == ConstantesInteroperabilidad.categoriaViajesL) {
          precioEstimado = 6.0;
        } else if (categoria == ConstantesInteroperabilidad.categoriaConfort) {
          precioEstimado = 3.5;
        } else {
          precioEstimado = 2.5; // Economico
        }
      } else {
        if (categoria == ConstantesInteroperabilidad.categoriaConfort) {
          precioEstimado = 3.5;
        } else {
          precioEstimado = 2.5; // Economico
        }
      }

      HojaSolicitudViaje.mostrar(
        context: context,
        posicionActual: posicion,
        servicioFirebase: ServicioFirebase(),
        uidPasajero: uid,
        nombrePasajero: datosPerfilMap?['nombre'] ?? 'Usuario',
        telefonoPasajero: datosPerfilMap?['telefono'] ?? 'Sin Numero',
        categoria: categoria,
        precio: precioEstimado,
        fechaProgramada: fechaProgramada,
        tipoVehiculo: tipoVehiculo,
      );
    } catch (e) {
      if (nav.canPop()) nav.pop(); // cerramos loader
      messenger.showSnackBar(SnackBar(
          content: Text('Error obteniendo ubicación: $e',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red));
    }
  }
}

@override
Widget build(BuildContext context) {
  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    flexibleSpace: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.teal.shade600,
            Colors.teal.shade400,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    ),
    leading: Builder(builder: (context) {
      return IconButton(
        icon: const Icon(Icons.menu, color: Colors.white, size: 28),
        onPressed: () => Scaffold.of(context).openDrawer(),
      );
    }),
    title: Text(
      'CLICK EXPRESS',
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 22,
        letterSpacing: 0.5,
      ),
    ),
  );
}

// Tarjeta de Bienvenida Personalizada
class _CardBienvenidaDashboard extends StatelessWidget {
  final String uid;

  const _CardBienvenidaDashboard({required this.uid});

  @override
  Widget build(BuildContext context) {
    final hora = DateTime.now().hour;
    String saludo = hora < 12
        ? '¡Buenos días!'
        : hora < 18
            ? '¡Buenas tardes!'
            : '¡Buenas noches!';
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ServicioFirebase().obtenerPerfilPasajeroStream(uid),
      builder: (context, snapshot) {
        final datos = snapshot.data;
        // Lógica robusta para obtener foto
        final String? fotoUrl = datos?['fotoPerfil'] ?? datos?['fotoUrl'];
        String nombreCompleto = datos?['nombre'] ?? '';

        // Mostrar solo Primer Nombre y Primer Apellido
        String nombreMostrar = nombreCompleto;
        if (nombreCompleto.isNotEmpty) {
          final partes = nombreCompleto.trim().split(' ');
          if (partes.length >= 2) {
            nombreMostrar = '${partes[0]} ${partes[1]}';
          } else if (partes.isNotEmpty) {
            nombreMostrar = partes[0];
          }
        }

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withValues(alpha: 0.8),
                Colors.teal.shade400,
                Colors.black.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 8.0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 2)),
                      child: ClipOval(
                        child: fotoUrl != null && fotoUrl.isNotEmpty
                            ? Image.network(
                                fotoUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.person,
                                        size: 34, color: Colors.white),
                              )
                            : const Icon(Icons.person,
                                size: 34, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              saludo,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            nombreMostrar.isNotEmpty
                                ? nombreMostrar
                                : 'Usuario',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    BotonEmergencia(
                      uidUsuario: uid,
                      nombreUsuario: nombreCompleto,
                      idViaje: datos?['solicitudActiva']?['id'],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StreamBuilder<double>(
                  stream: ServicioTasaBCV().obtenerTasaStream(),
                  initialData: ServicioTasaBCV().tasaActual,
                  builder: (context, snapshotTasa) {
                    final tasa = snapshotTasa.data ?? 0.0;
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.currency_exchange,
                              size: 16, color: Colors.greenAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tasa > 0
                                  ? 'BCV al día: Bs ${tasa.toStringAsFixed(2)}'
                                  : 'Cargando BCV...',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
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
      },
    );
  }
}

// Tarjeta Grande Vibrante (Moto/Taxi) con Etiqueta
class _TarjetaServicioVibrante extends StatelessWidget {
  final String titulo;
  final String imagen;
  final List<Color> colores;
  final String ruta;
  final String? etiqueta;

  const _TarjetaServicioVibrante({
    required this.titulo,
    required this.imagen,
    required this.colores,
    required this.ruta,
    this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (ruta.isNotEmpty) {
          Navigator.pushNamed(context, ruta);
        }
      },
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colores,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black,
              blurRadius: 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decoración abstracta de fondo
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Imagen
            Positioned(
              right: -10,
              bottom: -10,
              child: Image.asset(imagen, width: 110, height: 110),
            ),
            // Texto
            Positioned(
              top: 20,
              left: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (etiqueta != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(etiqueta!,
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Iconos Tarjeta de seccion sugerencias.
class _IconoSugerencia extends StatelessWidget {
  final String titulo;
  final IconData? iconData;
  final Color colorIcono;
  final String ruta;
  final String? imagen;
  final double tamanoImagen;

  const _IconoSugerencia({
    required this.titulo,
    this.iconData,
    required this.colorIcono,
    required this.ruta,
    this.imagen,
    this.tamanoImagen = 45.0,
  });

  @override
  Widget build(BuildContext context) {
    // Gradiente Unificado (Azul y Teal)
    final List<Color> gradienteElegante = [
      Colors.black.withValues(alpha: 0.8),
      Colors.teal,
    ];

    return GestureDetector(
      onTap: () {
        if (ruta.isNotEmpty) {
          Navigator.pushNamed(context, ruta);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Abriendo $titulo...'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: gradienteElegante[0],
            ),
          );
        }
      },
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradienteElegante,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decoración sutil de fondo
            Positioned(
              right: -15,
              bottom: -15,
              child: imagen != null
                  ? Opacity(
                      opacity: 0.15,
                      child: Image.asset(imagen!,
                          width: 95, height: 95, fit: BoxFit.contain))
                  : Icon(
                      iconData,
                      size: 95,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white
                            .withValues(alpha: 0.15), // Fondo sutil para icono
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        )),
                    child: imagen != null
                        ? Image.asset(imagen!,
                            width: tamanoImagen,
                            height: tamanoImagen,
                            fit: BoxFit.contain)
                        : Icon(iconData, color: colorIcono, size: tamanoImagen),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    titulo,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.95),
                      letterSpacing: 0.8,
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardAccionRapida extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final VoidCallback onTap;

  const _CardAccionRapida(
      {required this.icono, required this.titulo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.teal,
              Colors.black.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConstruirCardServicioReserva extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String imagenPath;
  final Color colorFondoIcono;
  final VoidCallback onTap;

  const _ConstruirCardServicioReserva({
    required this.titulo,
    required this.subtitulo,
    required this.imagenPath,
    required this.colorFondoIcono,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorFondoIcono,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(imagenPath, height: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }
}
