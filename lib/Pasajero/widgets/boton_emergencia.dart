import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class BotonEmergencia extends StatefulWidget {
  final String uidUsuario;
  final String nombreUsuario;
  final String? idViaje;

  const BotonEmergencia({
    super.key,
    required this.uidUsuario,
    required this.nombreUsuario,
    this.idViaje,
  });

  @override
  State<BotonEmergencia> createState() => _BotonEmergenciaState();
}

class _BotonEmergenciaState extends State<BotonEmergencia> {
  bool _alertaActiva = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  String? _idAlerta;

  @override
  void dispose() {
    _detenerAlerta();
    super.dispose();
  }

  void _mostrarConfirmacion() {
    if (_alertaActiva) {
      // Si ya está activa, preguntar si desea apagarla
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('¿Desactivar Alerta?',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          content: Text('Esto detendrá el seguimiento en tiempo real.',
              style: GoogleFonts.plusJakartaSans()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar',
                  style: GoogleFonts.plusJakartaSans(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _detenerAlerta();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Desactivar',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 28),
              const SizedBox(width: 8),
              Text('Alerta SOS',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '¿Enviar alerta de emergencia?',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Se enviará tu ubicación en tiempo real a tus contactos de confianza y a la central.',
                style:
                    GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey[700]),
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
              onPressed: () {
                Navigator.pop(context);
                _activarAlerta();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Enviar SOS',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _activarAlerta() async {
    try {
      // 1. Obtener coordenadas iniciales
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permiso de ubicación denegado')));
          return;
        }
      }

      final Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation));

      setState(() {
        _alertaActiva = true;
      });

      String nombreFinal = widget.nombreUsuario;
      try {
        final ref = FirebaseDatabase.instance
            .ref()
            .child('pasajeros')
            .child(widget.uidUsuario);
        final snap = await ref.get();
        if (snap.exists && snap.value != null) {
          final data = Map<String, dynamic>.from(snap.value as Map);
          if (data['nombre'] != null) {
            nombreFinal = data['nombre'].toString();
          }
        }
      } catch (_) {}

      // 2. Registrar en Firebase (App Administrativa)
      final DatabaseReference dbRef =
          FirebaseDatabase.instance.ref().child('alertas_emergencia').push();
      _idAlerta = dbRef.key;
      await dbRef.set({
        'uid': widget.uidUsuario,
        'nombre': nombreFinal,
        'latitud': position.latitude,
        'longitud': position.longitude,
        'timestamp': ServerValue.timestamp,
        'estado': 'activa',
        'rol': 'pasajero', 
        'idViaje': widget.idViaje, // Incluir ID de viaje activo
      });

      // 3. Iniciar Stream de ubicacion para tracking en tiempo real
      late LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
          forceLocationManager: true,
          intervalDuration: const Duration(seconds: 5),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationText: "Monitoreando ubicación por emergencia.",
            notificationTitle: "SOS Activo",
            enableWakeLock: true,
          ),
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.automotiveNavigation,
          distanceFilter: 5,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
        );
      }

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position newPos) {
        if (_idAlerta != null) {
          FirebaseDatabase.instance
              .ref()
              .child('alertas_emergencia/$_idAlerta')
              .update({
            'latitud': newPos.latitude,
            'longitud': newPos.longitude,
            'ultima_actualizacion': ServerValue.timestamp,
            'idViaje': widget.idViaje, // Mantener idViaje actualizado
          });
        }
      });

      // 4. Obtener contactos de confianza y Lanzar WhatsApp
      final contactosSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('pasajeros/${widget.uidUsuario}/contactos_confianza')
          .get();

      final String mensajeUrl =
          '🚨 *EMERGENCIA CLICK EXPRESS* 🚨\n\nSoy $nombreFinal. Necesito ayuda inmediata.\n\n📍 Mi ubicación en tiempo real:\nhttps://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

      bool sentToContacts = false;

      if (contactosSnapshot.exists && contactosSnapshot.value != null) {
        final Map<dynamic, dynamic> contactosData =
            contactosSnapshot.value as Map<dynamic, dynamic>;
        
        for (var entry in contactosData.entries) {
          final contacto = entry.value as Map<dynamic, dynamic>;
          final numeroWhatsapp = contacto['telefono']?.toString() ?? '';
          if (numeroWhatsapp.isEmpty) continue;

          final String safePhone =
              numeroWhatsapp.startsWith('+') ? numeroWhatsapp : '+$numeroWhatsapp';
          final Uri whatsappUri = Uri.parse(
              'whatsapp://send?phone=$safePhone&text=${Uri.encodeComponent(mensajeUrl)}');

          if (await canLaunchUrl(whatsappUri)) {
            await launchUrl(whatsappUri);
            sentToContacts = true;
          } else {
            // Fallback al navegador
            final Uri fallBackUri = Uri.parse(
                'https://wa.me/${safePhone.replaceAll('+', '')}?text=${Uri.encodeComponent(mensajeUrl)}');
            if (await canLaunchUrl(fallBackUri)) {
              await launchUrl(fallBackUri, mode: LaunchMode.externalApplication);
              sentToContacts = true;
            }
          }
        }
      }

      if (!sentToContacts && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No se pudo enviar WhatsApp a los contactos (o no hay registrados). La alerta central fue enviada.')));
      }

      if (mounted && sentToContacts) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Alerta activada y lista para compartir en WhatsApp',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _alertaActiva = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al activar alerta: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  void _detenerAlerta() {
    _positionStreamSubscription?.cancel();
    if (_idAlerta != null) {
      FirebaseDatabase.instance
          .ref()
          .child('alertas_emergencia/$_idAlerta')
          .update({
        'estado': 'resuelta',
        'fecha_resolucion': ServerValue.timestamp,
      });
    }
    setState(() {
      _alertaActiva = false;
      _idAlerta = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Alerta desactivada'), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _mostrarConfirmacion,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _alertaActiva 
              ? Colors.amber.shade700
              : Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _alertaActiva ? Colors.amber.shade300 : Colors.white.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _alertaActiva ? Icons.stop_circle_rounded : Icons.shield_outlined,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              _alertaActiva ? 'DETENER' : 'S.O.S',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
