import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clickexpress/Pasajero/servicios/firebase_db.dart';
import 'package:clickexpress/Pasajero/servicios/servicio_ubicacion.dart';
import 'package:clickexpress/Pasajero/pantalla_seguimiento_viaje.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/constantes_interoperabilidad.dart';
import 'pantalla_seleccion_destino.dart';
import '../Servicios/servicio_tasa_bcv.dart';
import 'modelos/viaje_programado.dart';
import 'servicios/servicio_preferencias.dart';
import 'servicios/servicio_viajes_programados.dart';
import 'widgets/campo_destino_autocomplete.dart';

class PantallaMototaxi extends StatefulWidget {
  const PantallaMototaxi({super.key});

  @override
  State<PantallaMototaxi> createState() => _PantallaMototaxiState();
}

class _PantallaMototaxiState extends State<PantallaMototaxi> {
  final ServicioUbicacion _servicioUbicacion = ServicioUbicacion();
  final ServicioFirebase _servicioFirebase = ServicioFirebase();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Position? _posicionActual;
  GoogleMapController? _controladorMapa;
  bool _mapaMovidoInicialmente = false;
  Set<Marker> _marcadoresConductores = {};
  StreamSubscription<String?>? _subSolicitudActiva;
  StreamSubscription<SolicitudViaje?>? _subSolicitudDetalle;
  StreamSubscription<Map<String, dynamic>?>? _subPerfil;
  bool _navegandoASeguimiento = false;
  bool _mostrarTarjetas = false; // Estado para la visibilidad de las tarjetas
  bool _solicitudDirectaIniciada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _verificarArgumentosIniciales();
  }

  void _verificarArgumentosIniciales() {
    if (_solicitudDirectaIniciada) return;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args != null && args.containsKey('idConductor')) {
      final idConductor = args['idConductor'] as String;
      final categoria = args['categoria'] as String? ??
          ConstantesInteroperabilidad.categoriaConfort;

      _solicitudDirectaIniciada = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Normalizar categoría por si viene diferente
        String catNormalizada = categoria;
        if (!_preciosVehiculos.containsKey(catNormalizada)) {
          catNormalizada = ConstantesInteroperabilidad.categoriaConfort;
        }

        _mostrarHojaSolicitud(catNormalizada, idConductor: idConductor);
      });
    }
  }

  // Información del usuario
  String? _uidUsuario;
  String _nombreUsuario = '';
  String _telefonoUsuario = '';
  String? _fotoUrl;

  // Contadores por categoría
  final Map<String, int> _contadoresPorCategoria = {
    ConstantesInteroperabilidad.categoriaEconomico: 0,
    ConstantesInteroperabilidad.categoriaConfort: 0,
  };

  // Precios por categoría
  final Map<String, double> _preciosVehiculos = {
    ConstantesInteroperabilidad.categoriaEconomico: 2.5,
    ConstantesInteroperabilidad.categoriaConfort: 3.5,
  };

  @override
  void initState() {
    super.initState();
    _inicializarPerfil();
    _obtenerUbicacionActual();
    _escucharConductoresCercanos();
    _verificarViajeActivoAlEntrar();
    _escucharSolicitudActiva();
  }

  void _inicializarPerfil() {
    final user = _auth.currentUser;
    if (user != null) {
      _uidUsuario = user.uid;
      // Suscribirse a cambios en el perfil (nombre, foto, etc.)
      _subPerfil = _servicioFirebase
          .obtenerPerfilPasajeroStream(user.uid)
          .listen((datos) {
        if (mounted) {
          setState(() {
            if (datos != null) {
              _nombreUsuario = datos[ConstantesInteroperabilidad.campoNombre] ??
                  user.displayName ??
                  'Usuario';
              _telefonoUsuario =
                  datos[ConstantesInteroperabilidad.campoTelefono] ??
                      user.phoneNumber ??
                      '';
              _fotoUrl = datos['fotoPerfil'] ?? datos['fotoUrl'];
            } else {
              _nombreUsuario = user.displayName ?? 'Usuario';
              _telefonoUsuario = user.phoneNumber ?? '';
            }
          });
        }
      });
    }
  }

  void _verificarViajeActivoAlEntrar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final solicitud = await _servicioFirebase.verificarViajeActivo(user.uid);
      if (solicitud != null && mounted && !_navegandoASeguimiento) {
        _navegandoASeguimiento = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PantallaSeguimientoViaje(idViaje: solicitud.id),
          ),
        );
      }
    }
  }

  void _escucharSolicitudActiva() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    debugPrint(
        '[MOTOTAXIS] Iniciando listener de solicitudes activas para usuario: ${user.uid}');

    _subSolicitudActiva?.cancel();
    _subSolicitudActiva = _servicioFirebase
        .obtenerIdSolicitudActivaStream(user.uid)
        .listen((idSolicitud) {
      if (!mounted) return;

      if (idSolicitud != null &&
          idSolicitud.isNotEmpty &&
          !_navegandoASeguimiento) {
        debugPrint('[MOTOTAXIS] Solicitud activa detectada: $idSolicitud');

        _subSolicitudDetalle?.cancel();
        _subSolicitudDetalle = _servicioFirebase
            .obtenerSolicitudEnTiempoReal(idSolicitud)
            .listen((solicitud) {
          if (!mounted || solicitud == null) return;

          debugPrint(
              '[MOTOTAXIS] Detalle de solicitud recibido - Tipo: ${solicitud.tipoVehiculoRequerido}, Estado: ${solicitud.estado}');

// Verificar tipo moto - null o vacío
          final tipoSolicitud = solicitud.tipoVehiculoRequerido;
          if (tipoSolicitud != '' &&
              tipoSolicitud.isNotEmpty &&
              tipoSolicitud != ConstantesInteroperabilidad.tipoMoto &&
              tipoSolicitud != 'moto') {
            debugPrint(
                '[MOTOTAXIS] Solicitud de $tipoSolicitud detectada. Ignorando navegación.');
            return;
          }

          debugPrint('[MOTOTAXIS] Solicitud de MOTO confirmada. Procesando...');

          final estado = solicitud.estado;
          final esEstadoActivo =
              estado == ConstantesInteroperabilidad.estadoAceptado ||
                  estado == ConstantesInteroperabilidad.estadoEnCamino ||
                  estado == ConstantesInteroperabilidad.estadoEnViaje ||
                  estado == 'aceptado' ||
                  estado == 'en_camino' ||
                  estado == 'en_viaje';

          if (esEstadoActivo && !_navegandoASeguimiento) {
            _navegandoASeguimiento = true;
            debugPrint(
                '[MOTOTAXIS] Conductor aceptó! Estado: $estado. Navegando a seguimiento...');

            // Clear driver markers before navigating
            if (mounted) {
              setState(() {
                _marcadoresConductores.clear();
              });
            }

            // Dismiss the "Buscando conductor..." dialog if it's open
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    PantallaSeguimientoViaje(idViaje: idSolicitud),
              ),
            );
          }
        });
      } else if (idSolicitud == null || idSolicitud.isEmpty) {
        debugPrint('[MOTOTAXIS] No hay solicitud activa');
      }
    });
  }

  Future<void> _obtenerUbicacionActual() async {
    final posicion = await _servicioUbicacion.obtenerUbicacionActual(context);
    if (mounted) {
      setState(() {
        _posicionActual = posicion;
      });

      if (_posicionActual != null && !_mapaMovidoInicialmente) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _controladorMapa?.animateCamera(
              CameraUpdate.newLatLngZoom(
                LatLng(_posicionActual!.latitude, _posicionActual!.longitude),
                15.0,
              ),
            );
            _mapaMovidoInicialmente = true;
          }
        });
      }
    }
  }

  void _escucharConductoresCercanos() {
    if (_posicionActual == null) {
      // Re-intentar cuando llegue la posición
      Future.delayed(const Duration(seconds: 2), _escucharConductoresCercanos);
      return;
    }

    // FIX Problema 6: Pasar lat/lng para búsqueda por Geohash en lugar del modo global legacy
    final stream = _servicioFirebase.obtenerConductoresDisponiblesStream(
      ConstantesInteroperabilidad.tipoMoto,
      '', // categoria vacía = cualquiera
      lat: _posicionActual!.latitude,
      lng: _posicionActual!.longitude,
    );

    stream.listen((conductores) {
      if (_posicionActual == null) return;

      final Set<Marker> nuevosMarcadores = {};

      for (final conductor in conductores) {
        if (conductor.ubicacionActual[ConstantesInteroperabilidad.campoLat] ==
                null ||
            conductor.ubicacionActual[ConstantesInteroperabilidad.campoLng] ==
                null) {
          continue;
        }

        final lat =
            conductor.ubicacionActual[ConstantesInteroperabilidad.campoLat];
        final lng =
            conductor.ubicacionActual[ConstantesInteroperabilidad.campoLng];

        if (lat != null && lng != null) {
          final posConductor =
              LatLng((lat as num).toDouble(), (lng as num).toDouble());
          final distanciaMetros = Geolocator.distanceBetween(
            _posicionActual!.latitude,
            _posicionActual!.longitude,
            posConductor.latitude,
            posConductor.longitude,
          );

          // Mostrar conductores hasta a 5km de distancia
          if (distanciaMetros <= 5000) {
            nuevosMarcadores.add(
              Marker(
                markerId: MarkerId('moto_${lat}_$lng'),
                position: posConductor,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(conductor.nombre),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mototaxi - ${conductor.categoria.toUpperCase()}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Aprox. ${(distanciaMetros / 1000).toStringAsFixed(1)} km de distancia',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Placa: ${conductor.placa}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${conductor.calificacion.toStringAsFixed(1)} (${conductor.telefono})',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _marcadoresConductores = nuevosMarcadores;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_posicionActual == null) {
      return Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade700, Colors.blue.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: Text(
            'CLICK EXPRESS',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.account_circle, color: Colors.white),
              onPressed: () {
                Navigator.pushNamed(context, '/perfil');
              },
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'CLICK EXPRESS',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22.0,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.teal.shade600,
                Colors.teal.shade400,
                Colors.blue.shade500,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 8),
            child: CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: IconButton(
                icon: const Icon(Icons.person, color: Colors.white),
                onPressed: () {
                  Navigator.pushNamed(context, '/perfil');
                },
                tooltip: 'Perfil',
              ),
            ),
          ),
        ],
      ),
      body: _construirInterfaz(),
    );
  }

  Widget _construirInterfaz() {
    return Stack(
      children: [
        _VistaMapa(
          onMapCreated: (controller) {
            _controladorMapa = controller;
            if (_posicionActual != null) {
              _controladorMapa?.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(_posicionActual!.latitude, _posicionActual!.longitude),
                  15.0,
                ),
              );
            }
          },
          onMyLocationTap: () {
            if (_posicionActual != null) {
              _controladorMapa?.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(_posicionActual!.latitude, _posicionActual!.longitude),
                  15.0,
                ),
              );
            }
          },
          posicionActual: _posicionActual!,
          marcadoresExtras: _marcadoresConductores,
        ),

        // Card de bienvenida
        Positioned(
          top: 100,
          left: 16,
          right: 16,
          child: _CardBienvenida(
            nombreUsuario: _nombreUsuario,
            posicionActual: _posicionActual,
            fotoUrl: _fotoUrl,
          ),
        ),

        // Contenedor colapsable de tarjetas
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!_mostrarTarjetas)
                // Botón para mostrar servicios
                Center(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _mostrarTarjetas = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF0F172A).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset('assets/imagen/moto_taxi.png',
                              height: 24),
                          const SizedBox(width: 12),
                          Text(
                            'Servicios De Viaje',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.keyboard_arrow_up,
                              color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ),
                )
              else
                // Lista de tarjetas con botón para ocultar
                Column(
                  children: [
                    // Botón para cerrar
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _mostrarTarjetas = false;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.keyboard_arrow_down,
                            color: Colors.grey),
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _TarjetaCategoria(
                            titulo: 'Económico',
                            subtitulo: 'Rápido y accesible',
                            precio: _preciosVehiculos[
                                    ConstantesInteroperabilidad
                                        .categoriaEconomico] ??
                                2.5,
                            conductores: _contadoresPorCategoria[
                                    ConstantesInteroperabilidad
                                        .categoriaEconomico] ??
                                0,
                            gradiente: [
                              Colors.teal.shade600,
                              Colors.teal.shade400
                            ],
                            onTap: () => _mostrarHojaSolicitud(
                                ConstantesInteroperabilidad.categoriaEconomico),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Badge de conductores cercanos
        Positioned(
          top: 110,
          right: 24,
          child: _BadgeConductores(
            cantidad: _contadoresPorCategoria.values.fold(0, (a, b) => a + b),
          ),
        ),
      ],
    );
  }

  void _mostrarHojaSolicitud(String categoria, {String? idConductor}) {
    _HojaSolicitudViaje.mostrar(
      context: context,
      state: this,
      posicionActual: _posicionActual!,
      servicioFirebase: _servicioFirebase,
      uidPasajero: _uidUsuario ?? '',
      nombrePasajero: _nombreUsuario,
      telefonoPasajero: _telefonoUsuario,
      categoria: categoria,
      precio: _preciosVehiculos[categoria] ?? 2.5,
      idConductor: idConductor,
    );
  }

  @override
  void dispose() {
    _subSolicitudActiva?.cancel();
    _subSolicitudDetalle?.cancel();
    _subPerfil?.cancel();
    _controladorMapa?.dispose();
    super.dispose();
  }
}

// ============================================================================
// WIDGETS MODERNOS
// ============================================================================

class _VistaMapa extends StatelessWidget {
  final void Function(GoogleMapController)? onMapCreated;
  final Position posicionActual;
  final Set<Marker> marcadoresExtras;
  final VoidCallback? onMyLocationTap;

  const _VistaMapa({
    this.onMapCreated,
    required this.posicionActual,
    required this.marcadoresExtras,
    this.onMyLocationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(posicionActual.latitude, posicionActual.longitude),
            zoom: 15.0,
          ),
          onMapCreated: onMapCreated,
          markers: {
            ...marcadoresExtras,
            Marker(
              markerId: const MarkerId('posicion_actual_moto'),
              position:
                  LatLng(posicionActual.latitude, posicionActual.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueCyan),
            ),
          },
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapType: MapType.normal,
        ),
        Positioned(
          bottom: 220,
          right: 20,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.teal.shade600,
                  Colors.blue.shade500,
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onMyLocationTap,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CardBienvenida extends StatelessWidget {
  final String nombreUsuario;
  final Position? posicionActual;
  final String? fotoUrl;

  const _CardBienvenida({
    required this.nombreUsuario,
    this.posicionActual,
    this.fotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hora = DateTime.now().hour;
    String saludo = hora < 12
        ? '¡Buenos días!'
        : hora < 18
            ? '¡Buenas tardes!'
            : '¡Buenas noches!';

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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
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
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 32,
                              );
                            },
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 32,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        saludo,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (() {
                          String nombreMostrar = nombreUsuario;
                          if (nombreUsuario.isNotEmpty) {
                            final partes = nombreUsuario.trim().split(' ');
                            if (partes.length >= 2) {
                              nombreMostrar = '${partes[0]} ${partes[1]}';
                            } else if (partes.isNotEmpty) {
                              nombreMostrar = partes[0];
                            }
                          }
                          return nombreMostrar.isNotEmpty
                              ? nombreMostrar
                              : 'Usuario';
                        })(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 12,
                            color: Colors.teal.shade600,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              'Ubicación actual',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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

class _TarjetaCategoria extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final double precio;
  final int conductores;
  final List<Color> gradiente;
  final VoidCallback onTap;

  const _TarjetaCategoria({
    required this.titulo,
    required this.subtitulo,
    required this.precio,
    required this.conductores,
    required this.gradiente,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradiente,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradiente[0].withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge de conductores disponibles
                if (conductores > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '$conductores disponibles',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                // Titulo
                Text(
                  titulo,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                // Subtitulo
                Text(
                  subtitulo,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                StreamBuilder<double>(
                  stream: ServicioTasaBCV().obtenerTasaStream(),
                  initialData: ServicioTasaBCV().tasaActual,
                  builder: (context, snapshot) {
                    final tasa = snapshot.data ?? 0.0;
                    final bs = tasa > 0 ? precio * tasa : null;
                    return Column(
                      children: [
                        Text(
                          '\$${precio.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Boton
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_circle_outline,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Solicitar',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
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

class _BadgeConductores extends StatefulWidget {
  final int cantidad;

  const _BadgeConductores({required this.cantidad});

  @override
  State<_BadgeConductores> createState() => _BadgeConductoresState();
}

class _BadgeConductoresState extends State<_BadgeConductores>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.cantidad > 5
        ? Colors.green
        : widget.cantidad > 0
            ? Colors.orange
            : Colors.grey;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.cantidad > 0 ? _animation.value : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_taxi,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '${widget.cantidad}',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// HOJA DE SOLICITUD DE VIAJE
// ============================================================================

class _HojaSolicitudViaje {
  static void mostrar({
    required BuildContext context,
    required _PantallaMototaxiState state,
    required Position posicionActual,
    required ServicioFirebase servicioFirebase,
    required String uidPasajero,
    required String? nombrePasajero,
    required String? telefonoPasajero,
    required String categoria,
    required double precio,
    String? idConductor,
    DateTime? fechaProgramada,
  }) {
    final TextEditingController controladorOrigen = TextEditingController();
    final TextEditingController controladorDestino = TextEditingController();
    double? destinoLat;
    double? destinoLng;

    controladorOrigen.text = 'Mi Ubicacion Actual';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                  top: 24,
                  left: 24,
                  right: 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Indicador de solicitud directa
                      if (idConductor != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.teal.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Solicitud directa a tu conductor favorito',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.teal.shade800,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 48,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '¿A Donde Quieres Ir Hoy?',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Image.asset(
                          'assets/imagen/taxi_2.png',
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFFE2E8F0), width: 1.5),
                        ),
                        child: TextField(
                          controller: controladorOrigen,
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: const Color(0xFF1E293B)),
                          decoration: InputDecoration(
                            labelText: 'Punto de recogida',
                            labelStyle: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF64748B), fontSize: 13),
                            prefixIcon: const Icon(Icons.adjust_rounded,
                                size: 18, color: Colors.teal),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: CampoDestinoAutocomplete(
                              apiKey: 'AIzaSyA7QmnEK36qat8Sam-Rpbu_mfOfAt1JtqQ',
                              controller: controladorDestino,
                              origenLat: posicionActual.latitude,
                              origenLng: posicionActual.longitude,
                              esViajeLargo: categoria == 'viajes_largos',
                              onLugarSeleccionado: (lugar) {
                                setModalState(() {
                                  destinoLat = lugar.lat;
                                  destinoLng = lugar.lng;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.map, color: Colors.white),
                              onPressed: () async {
                                final resultado = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PantallaSeleccionDestino(
                                      ubicacionInicial: LatLng(
                                        posicionActual.latitude,
                                        posicionActual.longitude,
                                      ),
                                    ),
                                  ),
                                );

                                if (resultado != null &&
                                    resultado is Map<String, dynamic>) {
                                  setModalState(() {
                                    destinoLat = resultado['lat'];
                                    destinoLng = resultado['lng'];
                                    if (controladorDestino.text.isEmpty) {
                                      controladorDestino.text =
                                          resultado['nombre'];
                                    }
                                  });
                                }
                              },
                              tooltip: 'Seleccionar en mapa',
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                        ],
                      ),
                      if (destinoLat != null && destinoLng != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  size: 14, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                'Ubicación exacta seleccionada',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      if (fechaProgramada != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.teal.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.event_available,
                                  color: Colors.teal.shade700, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Viaje programado: ${fechaProgramada.day}/${fechaProgramada.month} - ${fechaProgramada.hour}:${fechaProgramada.minute.toString().padLeft(2, '0')}',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.teal.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        'Estilo de viaje',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tarjeta de categoría seleccionada
                      GestureDetector(
                        onTap: () async {
                          final textoOrigen = controladorOrigen.text.trim();
                          final textoDestino = controladorDestino.text.trim();

                          if (textoOrigen.isEmpty || textoDestino.isEmpty) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Por favor, completa todos los campos'),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          // Intento de geocodificación si no hay coords, pero NO bloquea el envío
                          if (destinoLat == null || destinoLng == null) {
                            final textoDestino2 =
                                controladorDestino.text.trim();
                            if (textoDestino2.isNotEmpty) {
                              try {
                                final geoUri = Uri.https(
                                  'maps.googleapis.com',
                                  '/maps/api/geocode/json',
                                  {
                                    'address': textoDestino2,
                                    'key':
                                        'AIzaSyA7QmnEK36qat8Sam-Rpbu_mfOfAt1JtqQ',
                                  },
                                );
                                final resp = await http.get(geoUri, headers: {
                                  'X-Android-Package': 'click_express.project',
                                  'X-Android-Cert':
                                      '50EF7093A7572E7A53F70CC1B5EAD150AE5CC2CC',
                                }).timeout(const Duration(seconds: 6));
                                if (resp.statusCode == 200) {
                                  final geoData = json.decode(resp.body)
                                      as Map<String, dynamic>;
                                  final results =
                                      geoData['results'] as List<dynamic>?;
                                  if (results != null && results.isNotEmpty) {
                                    final loc = results[0]['geometry']
                                        ['location'] as Map<String, dynamic>;
                                    destinoLat = (loc['lat'] as num).toDouble();
                                    destinoLng = (loc['lng'] as num).toDouble();
                                  }
                                }
                              } catch (_) {
                                // Geocodificación falló: se envía con coords nulas
                              }
                            }
                            // Si aún null, usar 0.0 (no bloquear al pasajero)
                            destinoLat ??= 0.0;
                            destinoLng ??= 0.0;
                          }

                          if (!context.mounted) return;
                          Navigator.pop(sheetContext);

                          _confirmarYProcesarPagoBilletera(
                            context: context,
                            uid: uidPasajero,
                            monto: precio,
                            servicioFirebase: servicioFirebase,
                            onSuccess: () {
                              _mostrarLoader(context);
                              if (fechaProgramada != null) {
                                ServicioViajesProgramados()
                                    .validarDisponibilidad(
                                        uidPasajero, fechaProgramada)
                                    .then((validacion) {
                                  if (validacion != null) {
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                    if (context.mounted) {
                                      _mostrarMensaje(
                                          context, validacion, Colors.red);
                                    }
                                    return;
                                  }

                                  ServicioPreferencias.obtenerPreferencias()
                                      .then((prefs) {
                                    final viajeProg = ViajeProgramado(
                                      id: '',
                                      idPasajero: uidPasajero,
                                      nombrePasajero:
                                          nombrePasajero ?? 'Usuario',
                                      telefonoPasajero: telefonoPasajero ?? '',
                                      origenNombre: textoOrigen,
                                      origenLatLng: LatLng(
                                          posicionActual.latitude,
                                          posicionActual.longitude),
                                      destinoNombre: textoDestino,
                                      destinoLatLng:
                                          LatLng(destinoLat!, destinoLng!),
                                      fechaHoraProgramada: fechaProgramada,
                                      tipoVehiculo:
                                          ConstantesInteroperabilidad.tipoMoto,
                                      categoria: categoria,
                                      precioEstimado: precio,
                                      preferencias: prefs,
                                      timestampCreacion:
                                          DateTime.now().millisecondsSinceEpoch,
                                      timestampActualizacion: null,
                                    );

                                    ServicioViajesProgramados()
                                        .programarViaje(viajeProg)
                                        .then((_) {
                                      if (context.mounted) {
                                        Navigator.of(context)
                                            .pop(); // Quitar loader
                                        _mostrarMensaje(
                                            context,
                                            'Viaje programado exitosamente para el ${fechaProgramada.day}/${fechaProgramada.month}',
                                            Colors.green);
                                      }
                                    }).catchError((e) {
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                      }
                                      if (context.mounted) {
                                        _mostrarMensaje(
                                            context,
                                            'Error al programar: $e',
                                            Colors.red);
                                      }
                                    });
                                  });
                                });
                              } else {
                                ServicioPreferencias.obtenerPreferencias()
                                    .then((prefs) {
                                  servicioFirebase.enviarSolicitudViaje(
                                    uidPasajero: uidPasajero,
                                    tipoVehiculo:
                                        ConstantesInteroperabilidad.tipoMoto,
                                    categoria: categoria,
                                    precio: precio,
                                    origenNombre: textoOrigen,
                                    destinoNombre: textoDestino,
                                    destinoLat: destinoLat,
                                    destinoLng: destinoLng,
                                    posicionActual: posicionActual,
                                    nombrePasajero: nombrePasajero ?? 'Usuario',
                                    telefonoPasajero: telefonoPasajero ?? '',
                                    idConductor: idConductor,
                                    preferencias: prefs.toMapa(),
                                    onSuccess: (mensaje, idViaje) {
                                      if (!context.mounted) return;
                                      Navigator.of(context)
                                          .pop(); // Quitar loader
                                      _mostrarBuscandoConductor(
                                          context, idViaje, servicioFirebase);
                                    },
                                    onError: (error) {
                                      if (Navigator.of(context).canPop()) {
                                        Navigator.of(context).pop();
                                      }
                                      _mostrarMensaje(
                                          context, error, Colors.red);
                                    },
                                  );
                                });
                              }
                            },
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: const Color(0xFFF1F5F9), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E293B)
                                    .withValues(alpha: 0.04),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(Icons.two_wheeler,
                                        color: Colors.teal.shade700, size: 28),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          categoria[0].toUpperCase() +
                                              categoria.substring(1),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Llega rápido a tu destino',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '\$${precio.toStringAsFixed(2)}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      StreamBuilder<double>(
                                        stream: ServicioTasaBCV()
                                            .obtenerTasaStream(),
                                        initialData:
                                            ServicioTasaBCV().tasaActual,
                                        builder: (context, snap) {
                                          final tasa = snap.data ?? 0.0;
                                          final bs =
                                              tasa > 0 ? precio * tasa : null;
                                          return Text(
                                            bs != null
                                                ? 'Bs ${bs.toStringAsFixed(2)}'
                                                : 'Cargando...',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF64748B),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A)
                                          .withValues(alpha: 0.2),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Confirmar Viaje',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static void _confirmarYProcesarPagoBilletera({
    required BuildContext context,
    required String uid,
    required double monto,
    required ServicioFirebase servicioFirebase,
    required VoidCallback onSuccess,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Confirmar Pago',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet,
                size: 60, color: Colors.blue),
            const SizedBox(height: 20),
            Text(
              'Se descontarán ${ServicioTasaBCV().formatearPrecio(monto)} de tu billetera para este viaje.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: GoogleFonts.plusJakartaSans(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(context); // Cerrar confirmación
              _mostrarLoader(context);

              final result =
                  await servicioFirebase.verificarYDescontarSaldo(uid, monto);

              if (!context.mounted) return;
              Navigator.pop(context); // Cerrar loader

              if (result['success'] == true) {
                onSuccess();
              } else {
                _mostrarErrorSaldo(
                    context, result['error'] ?? 'Error de saldo');
              }
            },
            child: Text('Confirmar y Solicitar',
                style:
                    GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void _mostrarErrorSaldo(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Text('Saldo Insuficiente',
                style:
                    GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'No tienes saldo suficiente en tu billetera para este viaje. Por favor, realiza una recarga.',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Ir a Billetera'),
          ),
        ],
      ),
    );
  }

  static void _mostrarLoader(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }

  static void _mostrarMensaje(
      BuildContext context, String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void _mostrarBuscandoConductor(
      BuildContext context, String idViaje, ServicioFirebase servicioFirebase) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Column(
              children: [
                Text('Buscando conductor...'),
                SizedBox(height: 10),
                LinearProgressIndicator(),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 20),
                Text(
                  'Tu solicitud ha sido enviada.',
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Esperando aceptación...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  await servicioFirebase.cancelarSolicitud(idViaje);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Solicitud cancelada'),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  if (nav.canPop()) {
                    nav.pop();
                  }
                },
                child: const Text('Cancelar'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ViajeFrecuente model - TODO: implement or import correct model
class ViajeFrecuente {
  final String id;
  final String nombre;
  final String direccion;
  final String? icono;
  final String? horarioHabitual;
  final int contadorUsos;
  final String origenNombre;
  final String destinoNombre;
  final String? tipoVehiculoPreferido;

  ViajeFrecuente({
    required this.id,
    required this.nombre,
    required this.direccion,
    this.icono,
    this.horarioHabitual,
    this.contadorUsos = 0,
    required this.origenNombre,
    required this.destinoNombre,
    this.tipoVehiculoPreferido,
  });
}
