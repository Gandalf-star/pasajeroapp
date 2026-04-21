import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'servicios/firebase_db.dart';
import 'package:clickexpress/Pasajero/pantalla_seguimiento_viaje.dart';
import '../utils/constantes_interoperabilidad.dart';

// Importaciones de refactorización
import '../modelos/viaje_frecuente.dart';
import '../servicios/servicio_viajes_frecuentes.dart';
import 'widgets/tarjeta_categoria.dart';
import 'widgets/card_bienvenida.dart';
import 'widgets/badge_conductores.dart';
import 'widgets/vista_mapa.dart';
import 'widgets/hoja_solicitud_viaje.dart';
import 'widgets/dialogo_viajes_frecuentes.dart';

class PantallaPasajero extends StatefulWidget {
  const PantallaPasajero({super.key});

  @override
  State<PantallaPasajero> createState() => _PantallaPasajeroState();
}

class _PantallaPasajeroState extends State<PantallaPasajero> {
  GoogleMapController? _controladorMapa;
  bool _cargando = true;
  Position? _posicionActual;
  final Map<String, int> _contadoresPorCategoria = {
    ConstantesInteroperabilidad.categoriaEconomico: 0,
    ConstantesInteroperabilidad.categoriaConfort: 0,
    ConstantesInteroperabilidad.categoriaViajesL: 0,
  };
  final ServicioFirebase _servicioFirebase = ServicioFirebase();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Set<Marker> _marcadoresConductoresLista = {};
  BitmapDescriptor? _iconoTaxi;
  String? _uidUsuario;
  String _nombreUsuario = '';
  String _telefonoUsuario = '';
  final Map<String, double> _preciosVehiculos = {
    ConstantesInteroperabilidad.categoriaEconomico: 5.0,
    ConstantesInteroperabilidad.categoriaConfort: 7.5,
    ConstantesInteroperabilidad.categoriaViajesL: 6.0,
  };
  StreamSubscription<List<SolicitudViaje>>? _subSolicitudActiva;
  StreamSubscription<Map<String, dynamic>?>? _subPerfil;
  String? _fotoUrl;
  bool _navegandoASeguimiento = false;
  bool _mostrarTarjetas = false;
  bool _solicitudDirectaIniciada = false;
  StreamSubscription? _subConductores;

  // Viajes frecuentes
  final ServicioViajesFrecuentes _servicioViajesFrecuentes =
      ServicioViajesFrecuentes();
  List<ViajeFrecuente> _viajesFrecuentes = [];
  StreamSubscription<List<ViajeFrecuente>>? _subViajesFrecuentes;

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
        String catNormalizada = categoria;
        if (!_preciosVehiculos.containsKey(catNormalizada)) {
          catNormalizada = ConstantesInteroperabilidad.categoriaConfort;
        }

        _mostrarHojaSolicitud(catNormalizada, idConductor: idConductor);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _inicializarPerfil();
    _obtenerUbicacionActual();
    _limpiarSolicitudesAntiguas();
    _verificarViajeActivoAlEntrar();
    _escucharSolicitudActiva();
    _escucharConductoresCercanos();
    _escucharViajesFrecuentes();
    _cargarIconoTaxi();
  }

  void _limpiarSolicitudesAntiguas() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _servicioFirebase.limpiarSolicitudesAntiguas(user.uid);
    }
  }

  Future<void> _cargarIconoTaxi() async {
    try {
      _iconoTaxi = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(40, 40)),
        'assets/imagen/taxi_2.png',
      );
    } catch (e) {
      debugPrint('Error cargando icono de taxi: \$e');
    }
  }

  void _verificarViajeActivoAlEntrar() async {
    final user = _auth.currentUser;
    if (user != null) {
      final solicitud = await _servicioFirebase.verificarViajeActivo(user.uid);
      if (solicitud != null && mounted && !_navegandoASeguimiento) {
        final estadosParaNavegar = {
          ConstantesInteroperabilidad.estadoAceptado,
          ConstantesInteroperabilidad.estadoEnCamino,
          ConstantesInteroperabilidad.estadoEnViaje,
        };
        if (estadosParaNavegar.contains(solicitud.estado)) {
          _navegandoASeguimiento = true;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PantallaSeguimientoViaje(
                  idViaje: solicitud.id, uidPasajero: _uidUsuario!),
            ),
          );
        }
      }
    }
  }

  void _escucharConductoresCercanos() {
    _subConductores?.cancel();

    debugPrint('Iniciando escucha de conductores. Ubicación: $_posicionActual');

    final stream = _servicioFirebase.obtenerConductoresDisponiblesStream(
      ConstantesInteroperabilidad.tipoCarro,
      '',
      lat: _posicionActual?.latitude,
      lng: _posicionActual?.longitude,
    );

    _subConductores = stream.listen((conductores) {
      if (_posicionActual == null) return;
      final Set<Marker> nuevosMarcadores = {};

      for (final conductor in conductores) {
        final lat = conductor.ubicacionActual['lat'];
        final lng = conductor.ubicacionActual['lng'];
        if (lat == null || lng == null) continue;
        final posConductor =
            LatLng((lat as num).toDouble(), (lng as num).toDouble());

        final distanciaMetros = Geolocator.distanceBetween(
            _posicionActual!.latitude,
            _posicionActual!.longitude,
            posConductor.latitude,
            posConductor.longitude);

        if (distanciaMetros <= 5000) {
          nuevosMarcadores.add(
            Marker(
              markerId: MarkerId('conductor_\${lat}_\${lng}'),
              position: posConductor,
              icon: _iconoTaxi ??
                  BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueYellow),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(conductor.nombre),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Taxi - ${conductor.categoria.toUpperCase()}'),
                        const SizedBox(height: 8),
                        Text(
                            'Aprox. ${(distanciaMetros / 1000).toStringAsFixed(1)} km'),
                        const SizedBox(height: 8),
                        Text('Placa: ${conductor.placa}'),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(conductor.calificacion.toStringAsFixed(1)),
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
      if (mounted) {
        setState(() {
          _marcadoresConductoresLista.clear();
          _marcadoresConductoresLista.addAll(nuevosMarcadores);
        });
      }
    });
  }

  void _escucharSolicitudActiva() {
    final user = _auth.currentUser;
    if (user == null) return;

    _subSolicitudActiva?.cancel();
    // Escucha directamente de solicitudes_viaje
    _subSolicitudActiva = _servicioFirebase
        .escucharSolicitudesPorPasajero(user.uid)
        .listen((solicitudes) {
      if (!mounted) return;

      // Buscar la solicitud activa más reciente
      for (final solicitud in solicitudes) {
// Verificar que sea tipo carro - aceptar null o vacío
        final tipoSolicitudLower = solicitud.tipoVehiculoRequerido.toLowerCase();
        // Solo ignoramos si es explícitamente MOTO. 
        // Aceptamos 'carro', categorías (confort, etc) y el alias 'Buscando_conductor'
        if (tipoSolicitudLower == ConstantesInteroperabilidad.tipoMoto || 
            tipoSolicitudLower == 'moto') {
          debugPrint('Ignorando solicitud ${solicitud.id} - tipo: $tipoSolicitudLower');
          continue;
        }

        final estado = solicitud.estado;
        final esEstadoActivo =
            estado == ConstantesInteroperabilidad.estadoAceptado ||
                estado == ConstantesInteroperabilidad.estadoEnCamino ||
                estado == ConstantesInteroperabilidad.estadoEnViaje ||
                estado == 'aceptado' ||
                estado == 'en_camino' ||
                estado == 'en_viaje';

        if (esEstadoActivo && !_navegandoASeguimiento) {
          debugPrint(
              '[NAV] Iniciando transición a seguimiento - ID: ${solicitud.id}, Estado: $estado');
          _navegandoASeguimiento = true;

          if (mounted) {
            setState(() {
              _marcadoresConductoresLista.clear();
            });
          }

          debugPrint('[NAV] Cerrando diálogos y hojas modales...');
          // Cerrar diálogos (Buscando conductor) y hojas modales, pero quedarse en la página actual
          try {
            Navigator.of(context)
                .popUntil((route) => route is PageRoute || route.isFirst);
          } catch (e) {
            debugPrint('[NAV] Error al cerrar diálogos: $e');
          }

          debugPrint('[NAV] Reemplazando pantalla por seguimiento...');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PantallaSeguimientoViaje(
                  idViaje: solicitud.id, uidPasajero: _auth.currentUser?.uid),
            ),
          );
          break; // Detener el bucle ya que estamos navegando
        } else {
          debugPrint(
              'Solicitud ${solicitud.id} - estado: $estado, navegando: $_navegandoASeguimiento');
        }
      }
    });

    _limpiarSolicitudesAntiguas();
  }

  void _inicializarPerfil() {
    final user = _auth.currentUser;
    if (user != null) {
      _uidUsuario = user.uid;
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

  Future<void> _obtenerUbicacionActual() async {
    try {
      bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      if (!servicioHabilitado) return;

      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied) return;
      }

      if (permiso == LocationPermission.deniedForever) return;

      Position posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        _posicionActual = posicion;
        _cargando = false;
      });

      _controladorMapa?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(posicion.latitude, posicion.longitude),
          15.0,
        ),
      );

      _escucharConductoresCercanos();
    } catch (e) {
      debugPrint('Error al obtener la ubicación: $e');
      if (!mounted) return;
      setState(() {
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _construirInterfaz(),
    );
  }

  Widget _construirInterfaz() {
    return Stack(
      children: [
        VistaMapa(
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
          marcadoresConductores: _marcadoresConductoresLista,
        ),
        Positioned(
          top: 100,
          left: 16,
          right: 16,
          child: CardBienvenida(
            nombreUsuario: _nombreUsuario,
            posicionActual: _posicionActual,
            fotoUrl: _fotoUrl,
          ),
        ),
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!_mostrarTarjetas)
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
                          Image.asset('assets/imagen/taxi_2.png', height: 24),
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
                Column(
                  children: [
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
                          TarjetaCategoria(
                            titulo: 'Económico',
                            subtitulo: 'Básico y accesible',
                            precio: _preciosVehiculos[
                                    ConstantesInteroperabilidad
                                        .categoriaEconomico] ??
                                2.30,
                            conductores: _contadoresPorCategoria[
                                    ConstantesInteroperabilidad
                                        .categoriaEconomico] ??
                                0,
                            gradiente: [
                              Colors.blue.shade600,
                              Colors.blue.shade400
                            ],
                            onTap: () => _mostrarHojaSolicitud(
                                ConstantesInteroperabilidad.categoriaEconomico),
                          ),
                          const SizedBox(width: 12),
                          TarjetaCategoria(
                            titulo: 'Confort',
                            subtitulo: 'Comodidad garantizada',
                            precio: _preciosVehiculos[
                                    ConstantesInteroperabilidad
                                        .categoriaConfort] ??
                                3.5,
                            conductores: _contadoresPorCategoria[
                                    ConstantesInteroperabilidad
                                        .categoriaConfort] ??
                                0,
                            gradiente: [
                              Colors.teal.shade600,
                              Colors.teal.shade400
                            ],
                            onTap: () => _mostrarHojaSolicitud(
                                ConstantesInteroperabilidad.categoriaConfort),
                          ),
                          const SizedBox(width: 12),
                          TarjetaCategoria(
                            titulo: 'Viajes Largos',
                            subtitulo: 'S. Carlos / Valencia',
                            precio: 6.0,
                            conductores: _contadoresPorCategoria[
                                    ConstantesInteroperabilidad
                                        .categoriaViajesL] ??
                                0,
                            gradiente: [
                              Colors.indigo.shade700,
                              Colors.indigo.shade500
                            ],
                            onTap: () => _mostrarHojaSolicitud(
                                ConstantesInteroperabilidad.categoriaViajesL),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Positioned(
          top: 110,
          right: 24,
          child: BadgeConductores(
            cantidad: _contadoresPorCategoria.values.fold(0, (a, b) => a + b),
          ),
        ),
        if (_viajesFrecuentes.isNotEmpty)
          Positioned(
            top: 110,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.amber.shade600,
                    Colors.orange.shade600,
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(30),
                child: InkWell(
                  onTap: _mostrarDialogoViajesFrecuentes,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bookmark,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Viajes Frecuentes',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_viajesFrecuentes.length}',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _mostrarHojaSolicitud(String categoria, {String? idConductor}) {
    HojaSolicitudViaje.mostrar(
      context: context,
      posicionActual: _posicionActual!,
      servicioFirebase: _servicioFirebase,
      uidPasajero: _uidUsuario ?? '',
      nombrePasajero: _nombreUsuario,
      telefonoPasajero: _telefonoUsuario,
      categoria: categoria,
      precio: _preciosVehiculos[categoria] ?? 5.0,
      idConductor: idConductor,
    );
  }

  void _escucharViajesFrecuentes() {
    final user = _auth.currentUser;
    if (user == null) return;

    _subViajesFrecuentes?.cancel();
    _subViajesFrecuentes = _servicioViajesFrecuentes
        .escucharViajesFrecuentes(user.uid)
        .listen((viajes) {
      if (mounted) {
        setState(() {
          _viajesFrecuentes = viajes;
        });
      }
    }, onError: (e) {
      debugPrint('Error escuchando viajes frecuentes: $e');
    });
  }

  void _mostrarDialogoViajesFrecuentes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DialogoViajesFrecuentes(
        viajes: _viajesFrecuentes,
        onViajeSeleccionado: (viaje) {
          Navigator.pop(context);
          _solicitarViajeFrecuente(viaje);
        },
      ),
    );
  }

  Future<void> _solicitarViajeFrecuente(ViajeFrecuente viaje) async {
    if (_posicionActual == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede determinar tu ubicación actual'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String categoria = ConstantesInteroperabilidad.categoriaConfort;
    if (viaje.tipoVehiculoPreferido == 'Económico') {
      categoria = ConstantesInteroperabilidad.categoriaEconomico;
    } else if (viaje.tipoVehiculoPreferido == 'Premium') {
      categoria = ConstantesInteroperabilidad.categoriaViajesL;
    }

    await _servicioViajesFrecuentes.incrementarUso(viaje.idPasajero, viaje.id);

    if (!mounted) return;

    _mostrarHojaSolicitud(categoria);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Solicitando viaje a: ${viaje.destinoNombre}'),
        backgroundColor: Colors.teal,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _subSolicitudActiva?.cancel();
    _subPerfil?.cancel();
    _subConductores?.cancel();
    _subViajesFrecuentes?.cancel();
    _controladorMapa?.dispose();
    super.dispose();
  }
}
