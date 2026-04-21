import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'package:clickexpress/Pasajero/modelos/viaje_modelo.dart';
import 'package:clickexpress/Pasajero/servicios/servicio_seguimiento_viaje.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'servicios/firebase_db.dart';
import '../../utils/constantes_interoperabilidad.dart';
import '../../Servicios/servicio_tasa_bcv.dart';
import 'package:clickexpress/Pasajero/widgets/modal_calificacion_conductor.dart';

// Stubs para servicios faltantes
class ServicioContactosConfianza {
  static final ServicioContactosConfianza _instancia =
      ServicioContactosConfianza._internal();
  factory ServicioContactosConfianza() => _instancia;
  ServicioContactosConfianza._internal();
  void enviarAlerta(String userId) {}

  Future<void> inicializar() async {}

  Future<List<Map<String, dynamic>>> obtenerContactosActivos({
    bool notificarEmergencia = false,
  }) async {
    return [];
  }
}

class ServicioWhatsApp {
  static final ServicioWhatsApp _instancia = ServicioWhatsApp._internal();
  factory ServicioWhatsApp() => _instancia;
  ServicioWhatsApp._internal();
  void compartirUbicacion(String phoneNumber, String message) {}

  Future<List<Map<String, dynamic>>> enviarEmergenciaMultiple({
    required List<Map<String, dynamic>> contactos,
    required double ubicacionLat,
    required double ubicacionLng,
    required String tipoEmergencia,
  }) async {
    return [];
  }
}

class PantallaSeguimientoViaje extends StatefulWidget {
  final String idViaje;
  final String? uidPasajero;

  const PantallaSeguimientoViaje({
    super.key,
    required this.idViaje,
    this.uidPasajero,
  });

  @override
  State<PantallaSeguimientoViaje> createState() =>
      _PantallaSeguimientoViajeState();
}

class _PantallaSeguimientoViajeState extends State<PantallaSeguimientoViaje>
    with TickerProviderStateMixin {
  final ServicioSeguimientoViaje _servicioSeguimiento =
      ServicioSeguimientoViaje();
  final ServicioFirebase _servicioFirebase = ServicioFirebase();
  GoogleMapController? _mapController;

  ViajeModelo? _viajeActual;
  UbicacionModelo? _ubicacionConductor;
  bool _mostrandoChat = false;
  final TextEditingController _mensajeController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  List<LatLng> _puntosRuta = [];
  int _ultimoUpdateRuta = 0;
  StreamSubscription<DatabaseEvent>? _bocinaSubscription;
  StreamSubscription<dynamic>? _viajeSubscription;
  late String _currentChatId;

  // Notificaciones Chat - Matching Click_v2 style
  int _mensajesNoLeidos = 0;
  Timer? _notificationTimer;
  bool _iconoRojo = false;
  final AudioPlayer _audioPlayer = AudioPlayer(); // Instancia persistente

  Stream<List<Map<String, dynamic>>>? _chatStream; // Stream persistente

  // Info Conductor Extra
  String? _fotoConductor;
  double _calificacionConductor = 5.0;
  String? _modeloVehiculo;
  String? _colorVehiculo;

  String? _ultimoIdConductor;
  bool _esFavorito = false;

  // Flag para prevenir navegación múltiple
  bool _navegacionFinalEjecutada = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[CLICKEXPRESS] PantallaSeguimientoViaje: initState con idViaje=${widget.idViaje}');
    _currentChatId = widget.idViaje;

    try {
      _iniciarSeguimiento();
      _escucharBocina();
      debugPrint('[CLICKEXPRESS] Seguimiento y bocina iniciados');
    } catch (e) {
      debugPrint('[CLICKEXPRESS] ERROR en initState inicio: $e');
    }

    // Listen for trip ID changes (Request ID -> Active Trip ID) with proper cleanup
    _viajeSubscription = _servicioSeguimiento.viajeStream.listen((viaje) {
      if (viaje != null && viaje.id.isNotEmpty && viaje.id != _currentChatId) {
        debugPrint(
            '[SYNC] Switching IDs (Chat & Bocina): $_currentChatId -> ${viaje.id}');
        if (mounted) {
          setState(() {
            _currentChatId = viaje.id;
            _chatStream = _servicioSeguimiento.escucharChat(_currentChatId);
            _escucharBocina(_currentChatId);
          });
        }
      }
    });
  }

  Future<void> _checkFavorito(String idConductor) async {
    if (widget.uidPasajero == null) return;
    try {
      final esFav =
          await _servicioFirebase.esFavorito(widget.uidPasajero!, idConductor);
      if (mounted) {
        setState(() {
          _esFavorito = esFav;
        });
      }
    } catch (e) {
      debugPrint('Error verificando favorito: $e');
    }
  }

  Future<void> _toggleFavorito() async {
    if (widget.uidPasajero == null || _viajeActual?.idConductor == null) return;
    if (!mounted) return;

    try {
      // Optimismo UI
      setState(() {
        _esFavorito = !_esFavorito;
      });

      await _servicioFirebase.toggleFavorito(
          widget.uidPasajero!, _viajeActual!.idConductor!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_esFavorito
              ? 'Agregado a conductores favoritos'
              : 'Eliminado de favoritos'),
          duration: const Duration(seconds: 2),
          backgroundColor: _esFavorito ? Colors.pink : Colors.grey,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      // Revertir si falla
      if (!mounted) return;
      setState(() {
        _esFavorito = !_esFavorito;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al actualizar favoritos')),
      );
    }
  }

  Future<void> _obtenerInfoConductor(String idConductor) async {
    try {
      if (!mounted) return;
      debugPrint('Buscando info extra del conductor: $idConductor');
      final snapshot = await FirebaseDatabase.instance
          .ref('${ConstantesInteroperabilidad.nodoConductores}/$idConductor')
          .get();

      if (!mounted) return;

      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        if (mounted) {
          setState(() {
            _fotoConductor = data['fotoPerfil']?.toString();
            final cal = data['calificacionPromedio'] ?? data['calificacion'];
            if (cal != null) {
              _calificacionConductor = double.tryParse(cal.toString()) ?? 5.0;
            }
            _modeloVehiculo = data['modeloVehiculo']?.toString();
            _colorVehiculo = data['colorVehiculo']?.toString();
          });
          debugPrint(
              'Info conductor actualizada: $_modeloVehiculo $_colorVehiculo, Rating: $_calificacionConductor');
        }
      }
    } catch (e) {
      debugPrint('Error obteniendo info conductor: $e');
    }
  }

  void _escucharBocina([String? idViaje]) {
    // Cancelar suscripción anterior si existe
    _bocinaSubscription?.cancel();

    final targetId = idViaje ?? widget.idViaje;
    debugPrint(
        '[BOCINA] Configurando listener en viajes_activos/$targetId/bocina');

    final ref =
        FirebaseDatabase.instance.ref('viajes_activos/$targetId/bocina');

    _bocinaSubscription = ref.onValue.listen((event) async {
      if (event.snapshot.exists) {
        try {
          debugPrint("BOCINA: Evento recibido del conductor!");
          final player = AudioPlayer();

          // Configurar contexto de audio para asegurar reproducción
          await player.setAudioContext(AudioContext(
            android: AudioContextAndroid(
              isSpeakerphoneOn: true,
              stayAwake: true,
              contentType: AndroidContentType.music,
              usageType: AndroidUsageType.media,
              audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: {
                AVAudioSessionOptions.duckOthers,
                AVAudioSessionOptions.mixWithOthers
              },
            ),
          ));

          await player.setVolume(1.0);
          await player.play(AssetSource('audio/bocina_llegada.mp3'));

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🔔 ¡Tu conductor ha llegado!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 5),
              ),
            );
          }
        } catch (e) {
          debugPrint("Error reproduciendo bocina de llegada: $e");
        }
      }
    });
  }

  Future<void> _reproducirNotificacionChat() async {
    if (!mounted) return;
    try {
      // Detener cualquier reproducción anterior
      if (_audioPlayer.state == PlayerState.playing) {
        await _audioPlayer.stop();
      }
      // Asegurar volumen máximo
      await _audioPlayer.setVolume(1.0);
      // Reproducir notificación
      await _audioPlayer.play(AssetSource('audio/notificacion_chat_apple.mp3'));
      debugPrint('[CLICKEXPRESS] Reproduciendo notificación de chat');
    } catch (e) {
      debugPrint('Error no fatal en sonido chat: $e');
    }
  }

  void _iniciarSeguimiento() {
    debugPrint(
        '[CLICKEXPRESS] Iniciando seguimiento del viaje: ${widget.idViaje}');

    Future.microtask(() async {
      try {
        await _servicioSeguimiento.iniciarSeguimientoViaje(widget.idViaje);
        _chatStream = _servicioSeguimiento.escucharChat(_currentChatId);

        _servicioSeguimiento.escucharChat(_currentChatId).listen((mensajes) {
          if (mounted && mensajes.isNotEmpty) {
            final ultimo = mensajes.last;
            final esMio = ultimo['remitente'] == 'pasajero';

            if (!_mostrandoChat && !esMio) {
              if (_notificationTimer == null || !_notificationTimer!.isActive) {
                _reproducirNotificacionChat();
                setState(() {
                  _mensajesNoLeidos = 1;
                });
                _notificationTimer = Timer.periodic(
                  const Duration(milliseconds: 500),
                  (timer) {
                    if (mounted) {
                      setState(() {
                        _iconoRojo = !_iconoRojo;
                      });
                    }
                  },
                );
              }
            }
          }
        });
      } catch (e) {
        debugPrint('[CLICKEXPRESS] Error al iniciar seguimiento: $e');
      }
    });

    EstadoViaje? estadoAnterior;
    _servicioSeguimiento.viajeStream.listen((viaje) {
      if (!mounted) return;
      final estadoPrevio = estadoAnterior;
      setState(() {
        _viajeActual = viaje;
        estadoAnterior = viaje?.estado;

        if (viaje?.idConductor != null &&
            viaje!.idConductor != _ultimoIdConductor) {
          _ultimoIdConductor = viaje.idConductor;
          _obtenerInfoConductor(viaje.idConductor!);
          _checkFavorito(viaje.idConductor!);
        }
      });

      if (viaje != null &&
          viaje.estado == EstadoViaje.enCurso &&
          estadoPrevio != EstadoViaje.enCurso) {
        debugPrint(
            '[CLICKEXPRESS] Estado cambió a enCurso - Redibujando polilínea al destino');
        _ultimoUpdateRuta = 0;
        Future.microtask(() async {
          await _obtenerRuta();
          _actualizarVistaMapa();
        });
      }

      if (viaje != null) {
        final estadosFinales = [
          EstadoViaje.completado,
          EstadoViaje.cancelado,
          EstadoViaje.canceladoPorConductor,
          EstadoViaje.canceladoPorPasajero,
        ];

        if (estadosFinales.contains(viaje.estado) &&
            !_navegacionFinalEjecutada) {
          _navegacionFinalEjecutada = true;
          debugPrint(
              '[CLICKEXPRESS] Viaje finalizado con estado: ${viaje.estado}');

          if (viaje.estado == EstadoViaje.completado) {
            _mostrarDialogoViajeCompletado();
          } else {
            _mostrarDialogoViajeCancelado();
          }

          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _navegacionFinalEjecutada) {
              _procesarSalidaSegura(
                exito: viaje.estado == EstadoViaje.completado,
                mensaje: viaje.estado == EstadoViaje.completado
                    ? 'Viaje completado'
                    : 'Viaje cancelado',
              );
            }
          });
        }
      }
    }, onError: (error) {
      debugPrint('[CLICKEXPRESS] Error en viajeStream: $error');
    });

    _servicioSeguimiento.ubicacionConductorStream.listen((ubicacion) {
      if (mounted) {
        setState(() {
          _ubicacionConductor = ubicacion;
        });

        if (ubicacion != null && _viajeActual != null) {
          _actualizarVistaMapa();
        }
      }
    }, onError: (error) {
      debugPrint('[CLICKEXPRESS] Error en ubicacionConductorStream: $error');
    });

    debugPrint('[CLICKEXPRESS] Listeners configurados correctamente');
  }

  void _actualizarVistaMapa() {
    if (_viajeActual == null) return;

    final List<LatLng> puntos = [];

    // Punto A: Conductor (si existe)
    if (_ubicacionConductor != null) {
      puntos.add(LatLng(_ubicacionConductor!.lat, _ubicacionConductor!.lng));
    }

    // Punto B: Meta actual (Origen o Destino según estado)
    if (_viajeActual!.estado == EstadoViaje.enCurso) {
      puntos.add(LatLng(_viajeActual!.destinoLat, _viajeActual!.destinoLng));
    } else {
      puntos.add(LatLng(_viajeActual!.origen.lat, _viajeActual!.origen.lng));
    }

    if (_ubicacionConductor != null) {
      // FIX: Hacer la obtención de ruta asíncrona para no bloquear la UI
      Future.microtask(() => _obtenerRuta());
    }

    if (puntos.length > 1) {
      double minLat = puntos.map((p) => p.latitude).reduce(min);
      double maxLat = puntos.map((p) => p.latitude).reduce(max);
      double minLng = puntos.map((p) => p.longitude).reduce(min);
      double maxLng = puntos.map((p) => p.longitude).reduce(max);

      // Agregar margen proporcional (30%) para vista más amplia
      final latPadding = (maxLat - minLat) * 0.3;
      final lngPadding = (maxLng - minLng) * 0.3;

      final bounds = LatLngBounds(
        southwest: LatLng(minLat - latPadding, minLng - lngPadding),
        northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
      );

      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          100.0, // padding fijo adicional en píxeles
        ),
      );
    } else if (puntos.length == 1) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(puntos.first, 15.0),
      );
    }
  }

  Future<void> _obtenerRuta() async {
    if (_viajeActual == null || _ubicacionConductor == null) return;

    final ahora = DateTime.now().millisecondsSinceEpoch;
    if (ahora - _ultimoUpdateRuta < 5000) return; // Throttle 5s

    _ultimoUpdateRuta = ahora;

    try {
      final startLat = _ubicacionConductor!.lat;
      final startLng = _ubicacionConductor!.lng;

      // Lógica de destino dinámica
      double endLat;
      double endLng;
      String tipoRuta = 'Recogida';

      if (_viajeActual!.estado == EstadoViaje.enCurso) {
        // Hacia el Destino Final
        endLat = _viajeActual!.destinoLat;
        endLng = _viajeActual!.destinoLng;
        tipoRuta = 'Destino Final';
      } else {
        // Hacia el Pasajero (Origen)
        endLat = _viajeActual!.origen.lat;
        endLng = _viajeActual!.origen.lng;
      }

      debugPrint(
          ' [CLICKEXPRESS] Calculando ruta ($tipoRuta): ($startLat, $startLng) -> ($endLat, $endLng)');

      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=geojson');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final geometry = data['routes'][0]['geometry'];
          final coordinates = geometry['coordinates'] as List;

          if (mounted) {
            setState(() {
              _puntosRuta = coordinates
                  .map((coord) =>
                      LatLng(coord[1].toDouble(), coord[0].toDouble()))
                  .toList();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error obteniendo ruta: $e');
    }
  }

  Future<void> _llamarConductor() async {
    if (_viajeActual?.telefonoConductor == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Número de teléfono no disponible'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final telefono = _viajeActual!.telefonoConductor!;
    final url = Uri.parse('tel:$telefono');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se puede realizar la llamada'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al intentar llamar: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al intentar llamar'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Seguimiento de Viaje',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green,
        elevation: 0,
        actions: [
          // Chat icon
          IconButton(
            icon: Icon(
              _mostrandoChat ? Icons.close : Icons.chat,
              color: (_mensajesNoLeidos > 0 && _iconoRojo)
                  ? Colors.red
                  : Colors.white,
            ),
            onPressed: () {
              if (!mounted) return;
              setState(() {
                _mostrandoChat = !_mostrandoChat;
                // Si abrimos el chat, limpiamos notificaciones
                if (_mostrandoChat) {
                  _mensajesNoLeidos = 0;
                  _iconoRojo = false;
                  _notificationTimer?.cancel();
                  _notificationTimer = null;
                }
              });
            },
          ),
        ],
      ),
      body: _viajeActual == null
          ? () {
              debugPrint('[CLICKEXPRESS] Renderizando esqueleto (viajeActual es null)');
              return _construirCargaEsqueleto();
            }()
          : Stack(
              children: [
                // Mapa de fondo completo
                Positioned.fill(
                  child: () {
                    debugPrint('[CLICKEXPRESS] Renderizando mapa para id=${_viajeActual!.id}');
                    return _construirMapa();
                  }(),
                ),

                // Contenedor Flotante (Chat o Panel de Información)
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _mostrandoChat
                        ? SizedBox(
                            key: const ValueKey('chat'),
                            height: 400.h,
                            child: _construirChat(),
                          )
                        : SizedBox(
                            key: const ValueKey('panel'),
                            child: _construirPanelInformacion(),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _construirCargaEsqueleto() {
    return Stack(
      children: [
        Container(color: Colors.grey[200]),
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: Container(
            height: 280.h,
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _construirShimmerLoader(width: 100, height: 28, radius: 14),
                SizedBox(height: 16.h),
                _construirShimmerLoader(height: 14),
                SizedBox(height: 8.h),
                _construirShimmerLoader(width: 200.w, height: 14),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    _construirShimmerLoader(width: 56, height: 56, radius: 28),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _construirShimmerLoader(height: 16, width: 100),
                          SizedBox(height: 8.h),
                          _construirShimmerLoader(height: 12, width: 80),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Expanded(child: _construirShimmerLoader(height: 44)),
                    SizedBox(width: 12.w),
                    Expanded(child: _construirShimmerLoader(height: 44)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirShimmerLoader({
    double width = double.infinity,
    required double height,
    double radius = 8,
  }) {
    return _ShimmerWidget(
      width: width,
      height: height,
      borderRadius: radius,
    );
  }

  Widget _construirMapa() {
    // Si no hay datos del viaje, mostrar loading
    if (_viajeActual == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando información del viaje...'),
          ],
        ),
      );
    }

    final Set<Marker> marcadores = {};

    // Marcador del Pasajero (Origen)
    if (_viajeActual!.estado != EstadoViaje.enCurso) {
      marcadores.add(
        Marker(
          markerId: const MarkerId('origen'),
          position: LatLng(_viajeActual!.origen.lat, _viajeActual!.origen.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    } else {
      // En viaje: Mostrar Destino
      marcadores.add(
        Marker(
          markerId: const MarkerId('destino'),
          position: LatLng(_viajeActual!.destinoLat, _viajeActual!.destinoLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    // Marcador del conductor (si está disponible)
    if (_ubicacionConductor != null) {
      marcadores.add(
        Marker(
          markerId: const MarkerId('conductor'),
          position: LatLng(_ubicacionConductor!.lat, _ubicacionConductor!.lng),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    final Set<Polyline> polylines = {};
    if (_puntosRuta.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('ruta'),
          points: _puntosRuta,
          color: Colors.blue,
          width: 4,
        ),
      );
    }

    return GoogleMap(
      onMapCreated: (controller) {
        _mapController = controller;
        _actualizarVistaMapa();
      },
      initialCameraPosition: CameraPosition(
        target: LatLng(_viajeActual!.origen.lat, _viajeActual!.origen.lng),
        zoom: 14.0,
      ),
      markers: marcadores,
      polylines: polylines,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapType: MapType.normal,
    );
  }

  Widget _construirPanelInformacion() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(20.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Estado del viaje con diseño profesional
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _obtenerColorEstado(_viajeActual!.estado),
                  _obtenerColorEstado(_viajeActual!.estado)
                      .withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: _obtenerColorEstado(_viajeActual!.estado)
                      .withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _obtenerIconoEstado(_viajeActual!.estado),
                  color: Colors.white,
                  size: 18.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  _viajeActual!.estado.displayName,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 12.h),

          // Descripción del estado
          Text(
            _viajeActual!.estado.descripcion,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 16.h),

          // Información del conductor (si está disponible)
          if (_viajeActual!.nombreConductor != null) ...[
            _construirInfoConductor(),
            SizedBox(height: 16.h),
          ],

          // Información del viaje
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _construirInfoItem(
                Icons.location_on,
                'Destino',
                _viajeActual!.destino,
              ),
              _construirInfoItem(
                Icons.attach_money,
                'Precio',
                ServicioTasaBCV().formatearPrecio(_viajeActual!.precio),
              ),
              _construirInfoItem(
                Icons.directions_car,
                'Vehículo',
                _viajeActual!.tipoVehiculo,
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // Botones de acción
          _construirBotonesAccion(),
        ],
      ),
    );
  }

  Widget _construirInfoConductor() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20.r,
            backgroundColor: Colors.green,
            backgroundImage:
                _fotoConductor != null ? NetworkImage(_fotoConductor!) : null,
            child: _fotoConductor == null
                ? Text(
                    _viajeActual!.nombreConductor![0].toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  )
                : null,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _viajeActual!.nombreConductor!,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
                Text(
                  '${_modeloVehiculo ?? _viajeActual!.tipoVehiculo} • ${_colorVehiculo ?? ""} • ${_viajeActual!.placaVehiculo ?? "Sin Placa"}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.grey[600],
                    fontSize: 12.sp,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 16.sp),
                    SizedBox(width: 4.w),
                    Text(
                      _calificacionConductor.toStringAsFixed(1),
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_viajeActual!.telefonoConductor != null)
            IconButton(
              icon: const Icon(Icons.phone),
              onPressed: () => _llamarConductor(),
              color: Colors.green,
            ),
          // Botón Favorito
          IconButton(
            icon: Icon(
              _esFavorito ? Icons.favorite : Icons.favorite_border,
              color: _esFavorito ? Colors.pink : Colors.grey,
            ),
            onPressed: _toggleFavorito,
          ),
        ],
      ),
    );
  }

  Widget _construirInfoItem(IconData icono, String titulo, String valor) {
    return Column(
      children: [
        Icon(icono, color: Colors.green, size: 24.sp),
        SizedBox(height: 4.h),
        Text(
          titulo,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.sp,
            color: Colors.grey[600],
          ),
        ),
        Text(
          valor,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _construirBotonesAccion() {
    final List<Widget> botones = [];

    // Botón de cancelar (solo si el viaje no ha comenzado)
    if (_viajeActual!.estado == EstadoViaje.pendiente ||
        _viajeActual!.estado == EstadoViaje.aceptado ||
        _viajeActual!.estado == EstadoViaje.enCamino) {
      botones.add(
        Expanded(
          child: ElevatedButton(
            onPressed: () => _mostrarDialogoCancelar(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              minimumSize: Size(double.infinity, 50.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              'Cancelar',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold, fontSize: 16.sp),
            ),
          ),
        ),
      );
    }

    // Botón de calificar (solo si el viaje está completado)
    if (_viajeActual!.estado == EstadoViaje.completado) {
      botones.add(
        Expanded(
          child: ElevatedButton(
            onPressed: () => _mostrarDialogoCalificacion(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              minimumSize: Size(double.infinity, 50.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              'Calificar',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold, fontSize: 16.sp),
            ),
          ),
        ),
      );
    }

    if (botones.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: botones
          .expand((widget) =>
              [widget, if (widget != botones.last) const SizedBox(width: 12)])
          .toList(),
    );
  }

  Widget _construirChat() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Header del chat elegante
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat_bubble_outline_rounded,
                        color: Colors.white, size: 20),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      _viajeActual!.nombreConductor ?? "Tu Conductor",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      if (!mounted) return;
                      setState(() {
                        _mostrandoChat = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // Mensajes del chat
            Expanded(
              child: Container(
                color: Colors.white, //Fondo blanco para el área de mensajes
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _chatStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      debugPrint(
                          '[CHAT UI] Error en StreamBuilder: ${snapshot.error}');
                      return Center(
                          child: Text('Error en el chat: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final mensajes = snapshot.data!;

                    return ListView.builder(
                      controller: _chatScrollController,
                      padding: EdgeInsets.all(16.w),
                      itemCount: mensajes.length,
                      itemBuilder: (context, index) {
                        final mensaje = mensajes[index];
                        debugPrint(
                            'Displaying message $index: ${mensaje['mensaje']} from ${mensaje['remitente']}');
                        final esPasajero = mensaje['remitente'] == 'pasajero';

                        return Align(
                          alignment: esPasajero
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              //Invertir colores - pasajero gris, conductor verde
                              color:
                                  esPasajero ? Colors.grey[300] : Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              mensaje['mensaje'],
                              style: GoogleFonts.plusJakartaSans(
                                //Invertir colores de texto - pasajero negro, conductor blanco
                                color: esPasajero ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            // Input para escribir mensajes
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white, // Asegurar fondo blanco en el input también
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _mensajeController,
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        filled: true,
                        fillColor:
                            Colors.grey[100], // Fondo claro para el campo
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _enviarMensaje,
                    color: Colors.green,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _obtenerColorEstado(EstadoViaje estado) {
    switch (estado) {
      case EstadoViaje.pendiente:
        return Colors.orange;
      case EstadoViaje.aceptado:
        return Colors.blue;
      case EstadoViaje.enCamino:
        return Colors.green;
      case EstadoViaje.llegado:
        return Colors.purple;
      case EstadoViaje.enCurso:
        return Colors.green;
      case EstadoViaje.completado:
        return Colors.green[700]!;
      case EstadoViaje.cancelado:
      case EstadoViaje.canceladoPorConductor:
      case EstadoViaje.canceladoPorPasajero:
        return Colors.red;
    }
  }

  IconData _obtenerIconoEstado(EstadoViaje estado) {
    switch (estado) {
      case EstadoViaje.pendiente:
        return Icons.hourglass_empty;
      case EstadoViaje.aceptado:
        return Icons.check_circle_outline;
      case EstadoViaje.enCamino:
        return Icons.directions_car;
      case EstadoViaje.llegado:
        return Icons.location_on;
      case EstadoViaje.enCurso:
        return Icons.local_taxi;
      case EstadoViaje.completado:
        return Icons.check_circle;
      case EstadoViaje.cancelado:
      case EstadoViaje.canceladoPorConductor:
      case EstadoViaje.canceladoPorPasajero:
        return Icons.cancel;
    }
  }

  void _enviarMensaje() async {
    final mensaje = _mensajeController.text.trim();
    if (mensaje.isNotEmpty) {
      final exito = await _servicioSeguimiento.enviarMensajeConductor(
          _currentChatId, mensaje);
      if (!mounted) return;
      if (exito) {
        _mensajeController.clear();
        // Scroll al final del chat
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_chatScrollController.hasClients) {
            _chatScrollController
                .jumpTo(_chatScrollController.position.maxScrollExtent);
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar mensaje')),
        );
      }
    }
  }

  bool _navegandoSalida = false;

  void _procesarSalidaSegura({bool exito = true, String mensaje = ''}) {
    if (_navegandoSalida) return;
    _navegandoSalida = true;

    // 1. Cancelar todos los listeners inmediatamente
    _servicioSeguimiento.detenerSeguimiento();

    // 2. Mostrar feedback si es necesario
    if (mounted && mensaje.isNotEmpty) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: exito ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      } catch (e) {
        // Ignorar error si el context ya no es válido para snackbar
        debugPrint('Error mostrando SnackBar: $e');
      }
    }

    // 3. Navegación Destructiva (Force Reset)
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;

      // Determinar destino
      String rutaDestino = '/Taxis'; // Default
      if (_viajeActual != null) {
        final tipo = _viajeActual!.tipoVehiculo.toLowerCase();
        if (tipo.contains('moto')) {
          rutaDestino = '/Mototaxis';
        }
      }

      try {
        if (Navigator.canPop(context)) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
        // rootNavigator: true asegura que eliminamos diálogos y cualquier otra ruta encima
        Navigator.of(
          context,
          rootNavigator: true,
        ).pushNamedAndRemoveUntil(rutaDestino, (route) => false);
      } catch (e) {
        debugPrint('Error en navegación de salida: $e');
        // Intento desesperado final
        try {
          Navigator.of(context, rootNavigator: true)
              .pushReplacementNamed(rutaDestino);
        } catch (_) {
          debugPrint('Error en fallback de navegación');
        }
      }
    });
  }

  Future<void> _mostrarDialogoCancelar() async {
    if (!mounted) return;

    final confirmar = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Cancelar Viaje',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Estás seguro de que quieres cancelar este viaje?',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('No', style: GoogleFonts.plusJakartaSans()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Sí, cancelar',
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    // Mostrar loader con Root Navigator
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      //Actualizar estado directamente en Firebase con TIMEOUT
      await FirebaseDatabase.instance
          .ref('solicitudes_viaje/${widget.idViaje}')
          .update({
        'estado': 'cancelado_por_pasajero',
        'razonCancelacion': 'Cancelado por el pasajero',
        'timestampCancelacion': DateTime.now().millisecondsSinceEpoch,
      }).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Timeout al cancelar viaje en Firebase');
          throw TimeoutException('Cancelación timeout');
        },
      );

      // Actualizar también en viajes_activos
      try {
        await FirebaseDatabase.instance
            .ref('viajes_activos/${widget.idViaje}')
            .update({
          'estado': 'cancelado_por_pasajero',
          'timestampCancelacion': DateTime.now().millisecondsSinceEpoch,
        }).timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Error no crítico cancelando en viajes_activos: $e');
      }

      //Intentar limpiar solicitudActiva
      if (widget.uidPasajero != null) {
        try {
          await FirebaseDatabase.instance
              .ref('pasajeros/${widget.uidPasajero}/solicitudActiva')
              .set(null)
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          debugPrint('Error no crítico limpiando solicitudActiva: $e');
          // Ignorar error de limpieza
        }
      }

      // 3. Cerrar loader y salir exitosamente
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Cerrar loader
        _procesarSalidaSegura(
          exito: true,
          mensaje: 'Viaje cancelado exitosamente',
        );
      }
    } catch (e) {
      // CRÍTICO: Manejar error y forzar salida
      debugPrint('Error CRÍTICO en cancelación: $e');

      if (mounted) {
        // Intentar cerrar loader de forma segura
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          debugPrint('Error cerrando loader');
        }

        // Mostrar error al usuario
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cancelar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );

        //Forzar salida después de 3 segundos
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _procesarSalidaSegura(
              exito: false,
              mensaje: 'Saliendo...',
            );
          }
        });
      }
    }
  }

  void _mostrarDialogoViajeCompletado() {
    if (_navegandoSalida) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ModalCalificacionConductor(
        idViaje: widget.idViaje,
        idConductor: _viajeActual?.idConductor ?? '',
        nombreConductor: _viajeActual?.nombreConductor ?? 'Tu Conductor',
        onCompletado: () {
          Navigator.of(context).pop();
          _procesarSalidaSegura(
            exito: true,
            mensaje: 'Viaje completado exitosamente',
          );
        },
      ),
    );
  }

  void _mostrarDialogoViajeCancelado() {
    if (_navegandoSalida) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final nav = Navigator.of(context);
        // Auto-cerrar después de 3 segundos
        Future.delayed(const Duration(seconds: 3), () {
          if (nav.canPop()) {
            nav.pop();
          }
        });

        return AlertDialog(
          title: Text(
            'Viaje Cancelado',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          ),
          content: Text(
            _viajeActual!.estado == EstadoViaje.canceladoPorConductor
                ? 'El conductor ha cancelado el viaje.'
                : 'El viaje ha sido cancelado.',
            style: GoogleFonts.plusJakartaSans(),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Cerrar diálogo
                _procesarSalidaSegura(
                  exito: false,
                  mensaje: 'Viaje cancelado',
                );
              },
              child: Text('Entendido', style: GoogleFonts.plusJakartaSans()),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoCalificacion() {
    double rating = 5.0;
    final comentarioController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.r),
              ),
              elevation: 10,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: 550.h,
                  maxWidth: 400.w,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.shade50,
                      Colors.white,
                      Colors.teal.shade50,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icono de estrella animado
                      Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade400,
                              Colors.orange.shade400
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.star,
                          size: 40.sp,
                          color: Colors.white,
                        ),
                      ),

                      SizedBox(height: 16.h),

                      // Título
                      Text(
                        '¡Califica tu Viaje!',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: 8.h),

                      // Información del conductor
                      if (_viajeActual?.nombreConductor != null) ...[
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 20.r,
                                backgroundColor: Colors.green,
                                backgroundImage: _fotoConductor != null
                                    ? NetworkImage(_fotoConductor!)
                                    : null,
                                child: _fotoConductor == null
                                    ? Text(
                                        _viajeActual!.nombreConductor![0]
                                            .toUpperCase(),
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16.sp,
                                        ),
                                      )
                                    : null,
                              ),
                              SizedBox(width: 12.w),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _viajeActual!.nombreConductor!,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.sp,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  Text(
                                    'Tu conductor',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.sp,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20.h),
                      ],

                      // Pregunta
                      Text(
                        '¿Cómo fue tu experiencia?',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.sp,
                          color: Colors.grey.shade700,
                        ),
                      ),

                      SizedBox(height: 16.h),

                      // Estrellas interactivas con animación
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final isSelected = index < rating;
                          return GestureDetector(
                            onTap: () {
                              setStateDialog(() {
                                rating = index + 1.0;
                              });
                            },
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              padding: EdgeInsets.all(4.w),
                              child: Icon(
                                isSelected ? Icons.star : Icons.star_border,
                                color: isSelected
                                    ? Colors.amber.shade600
                                    : Colors.grey.shade400,
                                size: isSelected ? 40.sp : 36.sp,
                              ),
                            ),
                          );
                        }),
                      ),

                      SizedBox(height: 20.h),

                      // Campo de comentario opcional
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: comentarioController,
                          maxLines: 3,
                          maxLength: 200,
                          decoration: InputDecoration(
                            hintText: 'Comentario (opcional)',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              color: Colors.grey.shade400,
                              fontSize: 13.sp,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(12.w),
                            counterStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 11.sp,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          style: GoogleFonts.plusJakartaSans(fontSize: 13.sp),
                        ),
                      ),

                      SizedBox(height: 24.h),

                      // Botones de acción
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _procesarSalidaSegura(
                                  exito: true,
                                  mensaje: 'Viaje finalizado',
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 14.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              child: Text(
                                'Omitir',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green.shade600,
                                    Colors.teal.shade600,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _enviarCalificacion(
                                    rating,
                                    comentarioController.text.trim(),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: EdgeInsets.symmetric(vertical: 14.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.send, size: 18.sp),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'Enviar',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Future<void> _enviarCalificacion(double rating, String comentario) async {
    if (_viajeActual?.idConductor == null) {
      _procesarSalidaSegura(exito: true, mensaje: 'Viaje finalizado');
      return;
    }

    try {
      final conductorRef = FirebaseDatabase.instance.ref(
        '${ConstantesInteroperabilidad.nodoConductores}/${_viajeActual!.idConductor}',
      );

      // Obtener calificaciones actuales
      final snapshot = await conductorRef.child('calificaciones').get();

      double promedioActual = 5.0;
      int cantidadActual = 0;

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        promedioActual = (data['promedio'] ?? 5.0).toDouble();
        cantidadActual = (data['cantidad'] ?? 0) as int;
      }

      // Calcular nuevo promedio
      final nuevaCantidad = cantidadActual + 1;
      final nuevoPromedio =
          ((promedioActual * cantidadActual) + rating) / nuevaCantidad;

      // Actualizar en Firebase
      await conductorRef.update({
        'calificaciones': {
          'promedio': nuevoPromedio,
          'cantidad': nuevaCantidad,
        },
      });

      // Guardar calificación individual con comentario
      if (widget.uidPasajero != null) {
        await FirebaseDatabase.instance
            .ref(
          'calificaciones_conductores/${_viajeActual!.idConductor}/${widget.idViaje}',
        )
            .set({
          'calificacion': rating,
          'comentario': comentario.isNotEmpty ? comentario : null,
          'idPasajero': widget.uidPasajero,
          'nombrePasajero': _viajeActual!.origen.nombre,
          'timestamp': ServerValue.timestamp,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    '¡Gracias por tu calificación!',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            margin: EdgeInsets.all(16.w),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error enviando calificación: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al enviar calificación',
              style: GoogleFonts.plusJakartaSans(),
            ),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      _procesarSalidaSegura(exito: true, mensaje: 'Viaje finalizado');
    }
  }

  @override
  void dispose() {
    _viajeSubscription?.cancel();
    _bocinaSubscription?.cancel();
    _notificationTimer?.cancel();
    _servicioSeguimiento.detenerSeguimiento();
    _audioPlayer.dispose();
    _mapController?.dispose();
    _mensajeController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }
}

class _ShimmerWidget extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _ShimmerWidget({
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<_ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<_ShimmerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Colors.grey[300]!;
    final highlight = Colors.grey[100]!;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

class PulsanteBadgeEstado extends StatefulWidget {
  final Widget child;
  final bool active;

  const PulsanteBadgeEstado({
    super.key,
    required this.child,
    this.active = true,
  });

  @override
  State<PulsanteBadgeEstado> createState() => _PulsanteBadgeEstadoState();
}

class _PulsanteBadgeEstadoState extends State<PulsanteBadgeEstado>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _animation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.active) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulsanteBadgeEstado oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}
