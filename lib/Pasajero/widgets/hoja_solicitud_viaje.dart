import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../utils/constantes_interoperabilidad.dart';
import '../servicios/firebase_db.dart';
import '../pantalla_billetera.dart';
import '../../Servicios/servicio_tasa_bcv.dart';
import '../../utils/click_logger.dart';
import '../modelos/preferencias_viaje.dart';
import '../modelos/viaje_programado.dart';
import '../servicios/servicio_preferencias.dart';
import '../servicios/servicio_viajes_programados.dart';
import '../servicios/servicio_geocodificacion.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'campo_destino_autocomplete.dart';

class HojaSolicitudViaje {
  static void mostrar({
    required BuildContext context,
    required Position posicionActual,
    required ServicioFirebase servicioFirebase,
    required String uidPasajero,
    required String nombrePasajero,
    required String telefonoPasajero,
    required String categoria,
    required double precio,
    String? idConductor,
    DateTime? fechaProgramada, // Recibido externamente
    String tipoVehiculo = ConstantesInteroperabilidad.tipoCarro,
  }) {
    final TextEditingController controladorOrigen = TextEditingController();
    final TextEditingController controladorDestino = TextEditingController();
    double? destinoLat;
    double? destinoLng;
    double precioEditable = precio;
    PreferenciasViaje preferenciasGlobales = const PreferenciasViaje();
    bool preferenciasCargadas = false;

    controladorOrigen.text = 'Mi Ubicación Actual';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext sbContext, StateSetter setModalState) {
            if (!preferenciasCargadas) {
              ServicioPreferencias.obtenerPreferencias().then((prefs) {
                if (sbContext.mounted) {
                  setModalState(() {
                    preferenciasGlobales = prefs;
                    preferenciasCargadas = true;
                  });
                }
              });
            }

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
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'A DONDE QUIERES IR HOY?',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Image.asset(
                          'assets/imagen/FlashDrive_3D_101.png',
                          height: 200,
                          fit: BoxFit.fill,
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
                                size: 18, color: Colors.blue),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Campo de destino con autocompletado de Google Places
                      CampoDestinoAutocomplete(
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
                      if (destinoLat != null && destinoLng != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  size: 14, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                'Ubicación exacta confirmada',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Estilo de viaje',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (fechaProgramada != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.teal.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.event_available,
                                      color: Colors.teal.shade700, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${fechaProgramada.day}/${fechaProgramada.month} - ${fechaProgramada.hour}:${fechaProgramada.minute.toString().padLeft(2, '0')}',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.teal.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
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

                          // Intento de geocodificación si no hay coords usando el servicio limpio
                          if (destinoLat == null || destinoLng == null) {
                            final coordenadas = await ServicioGeocodificacion
                                .obtenerCoordenadasPorDireccion(
                                    controladorDestino.text);

                            if (coordenadas != null) {
                              destinoLat = coordenadas.latitude;
                              destinoLng = coordenadas.longitude;
                            } else {
                              // Si falla la geocodificación, usar 0.0 (no bloquear al pasajero)
                              destinoLat = 0.0;
                              destinoLng = 0.0;
                            }
                          }

                          if (!context.mounted) return;

                          ClickLogger.d(
                              'DEBUG: Iniciando flujo de solicitud...');
                          _confirmarYProcesarPagoBilletera(
                            context:
                                context, // Usar el context de mostrar (estable)
                            uid: uidPasajero,
                            monto: precioEditable,
                            servicioFirebase: servicioFirebase,
                            onSuccess: () async {
                              ClickLogger.d(
                                  'DEBUG: Pago confirmado, cerrando hoja...');
                              Navigator.pop(sheetContext); //cerramos la hoja

                              _mostrarLoader(context);

                              if (fechaProgramada != null) {
                                // Flujo: Viaje Programado
                                final validacion =
                                    await ServicioViajesProgramados()
                                        .validarDisponibilidad(
                                            uidPasajero, fechaProgramada);
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

                                final viajeProg = ViajeProgramado(
                                  id: '', // se asigna al enviar a DB
                                  idPasajero: uidPasajero,
                                  nombrePasajero: nombrePasajero,
                                  telefonoPasajero: telefonoPasajero,
                                  origenNombre: textoOrigen,
                                  origenLatLng: LatLng(posicionActual.latitude,
                                      posicionActual.longitude),
                                  destinoNombre: textoDestino,
                                  destinoLatLng:
                                      LatLng(destinoLat!, destinoLng!),
                                  fechaHoraProgramada: fechaProgramada,
                                  tipoVehiculo: tipoVehiculo,
                                  categoria: categoria,
                                  precioEstimado: precioEditable,
                                  preferencias: preferenciasGlobales,
                                  timestampCreacion:
                                      DateTime.now().millisecondsSinceEpoch,
                                  timestampActualizacion: null,
                                );

                                try {
                                  await ServicioViajesProgramados()
                                      .programarViaje(viajeProg);
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    _mostrarMensaje(
                                        context,
                                        'Viaje programado exitosamente para el ${fechaProgramada.day}/${fechaProgramada.month}',
                                        Colors.green);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                  if (context.mounted) {
                                    _mostrarMensaje(context,
                                        'Error al programar: $e', Colors.red);
                                  }
                                }
                              } else {
                                // Flujo: Solicitud de Viaje Inmediato Normal
                                servicioFirebase.enviarSolicitudViaje(
                                  uidPasajero: uidPasajero,
                                  tipoVehiculo: tipoVehiculo,
                                  categoria: categoria,
                                  precio: precioEditable,
                                  origenNombre: textoOrigen,
                                  destinoNombre: textoDestino,
                                  destinoLat: destinoLat,
                                  destinoLng: destinoLng,
                                  preferencias: preferenciasGlobales
                                      .toMapa(), // Inyecta las preferencias globales
                                  posicionActual: posicionActual,
                                  nombrePasajero: nombrePasajero,
                                  telefonoPasajero: telefonoPasajero,
                                  idConductor: idConductor,
                                  onSuccess: (mensaje, idViaje) {
                                    ClickLogger.d(
                                        'DEBUG: Solicitud enviada con éxito: $idViaje');
                                    if (!context.mounted) return;
                                    Navigator.of(context)
                                        .pop(); // Quitar loader
                                    _mostrarBuscandoConductor(
                                        context, idViaje, servicioFirebase);
                                  },
                                  onError: (error) {
                                    ClickLogger.d(
                                        'DEBUG: Error en enviarSolicitudViaje: $error');
                                    if (Navigator.of(context).canPop()) {
                                      Navigator.of(context).pop();
                                    }
                                    _mostrarMensaje(context, error, Colors.red);
                                  },
                                );
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
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Image.asset(
                                      'assets/imagen/FlashDrive_3D_101.png',
                                      width: 28,
                                      height: 28,
                                      fit: BoxFit.contain,
                                    ),
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
                                          'Viaje confortable y seguro',
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
                                        '\$${precioEditable.toStringAsFixed(2)}',
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
                                          final bs = tasa > 0
                                              ? precioEditable * tasa
                                              : null;
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
                size: 60, color: Colors.teal),
            const SizedBox(height: 20),
            Text(
              'El costo estimado de este viaje es ${ServicioTasaBCV().formatearPrecio(monto)}. El pago se procesará al finalizar el viaje.',
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
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(context); // Cerrar confirmación
              _mostrarLoader(context);

              final result = await servicioFirebase.verificarSaldo(uid, monto);

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
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => PantallaBilletera()));
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
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (sbContext, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: Column(
                  children: [
                    Text(
                      'Buscando conductor...',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(
                      backgroundColor: Colors.teal,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Tu solicitud ha sido enviada a los conductores cercanos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      // Listener del estado del viaje
                      StreamBuilder(
                        stream: FirebaseDatabase.instance
                            .ref()
                            .child(ConstantesInteroperabilidad
                                .nodoSolicitudesViaje)
                            .child(idViaje)
                            .child(ConstantesInteroperabilidad.campoEstado)
                            .onValue,
                        builder: (context, AsyncSnapshot<DatabaseEvent> event) {
                          if (event.hasData &&
                              event.data!.snapshot.value != null) {
                            final estado =
                                event.data!.snapshot.value.toString();

                            // Si ya fue aceptado, cerramos y el listener principal se encarga
                            if (estado ==
                                ConstantesInteroperabilidad.estadoAceptado) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (sbContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }
                              });
                            }
                          }

                          return Column(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 48, color: Colors.teal),
                              const SizedBox(height: 10),
                              Text(
                                'Esperando que un compañero acepte tu viaje.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14, color: Colors.teal.shade700),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      try {
                        final resultado =
                            await servicioFirebase.cancelarSolicitud(idViaje);
                        if (!context.mounted) return;
                        final penalizado = resultado['penalizado'] == true;
                        if (penalizado) {
                          final monto =
                              (resultado['montoPenalizacion'] as double)
                                  .toStringAsFixed(2);
                          final compensacion =
                              (resultado['montoAcreditadoConductor'] as double)
                                  .toStringAsFixed(2);
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              title: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text('Penalización Aplicada',
                                        style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                  ),
                                ],
                              ),
                              content: Text(
                                'Se cobró una penalización de \$$monto '
                                '(50% del viaje) por cancelar tras la aceptación del conductor.\n\n'
                                'El conductor recibió \$$compensacion como compensación.',
                                style:
                                    GoogleFonts.plusJakartaSans(fontSize: 14),
                              ),
                              actions: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text('Entendido',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        } else {
                          _mostrarMensaje(
                              context, 'Solicitud cancelada', Colors.orange);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          _mostrarMensaje(
                              context, 'Error al cancelar: $e', Colors.red);
                        }
                      }
                    },
                    child: const Text('Cancelar'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
