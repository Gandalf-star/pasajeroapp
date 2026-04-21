import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'servicios/firebase_db.dart';
import '../utils/constantes_interoperabilidad.dart';

class PantallaFavoritos extends StatefulWidget {
  const PantallaFavoritos({super.key});

  @override
  State<PantallaFavoritos> createState() => _PantallaFavoritosState();
}

class _PantallaFavoritosState extends State<PantallaFavoritos> {
  final ServicioFirebase _servicioFirebase = ServicioFirebase();
  final String? _uidPasajero = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (_uidPasajero == null) {
      return const Scaffold(
        body: Center(child: Text('Error: No identificado')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50], // Fondo claro moderno
      appBar: AppBar(
        title: Text(
          'Mis Conductores Favoritos',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade600, Colors.blue.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: const BotonAtras(),
      ),
      body: StreamBuilder<List<String>>(
        stream: _servicioFirebase.obtenerIdsFavoritosStream(_uidPasajero),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final ids = snapshot.data ?? [];

          if (ids.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border,
                      size: 64, color: Colors.grey.shade400),
                  SizedBox(height: 16.h),
                  Text(
                    'No tienes conductores favoritos aún',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.grey.shade600,
                      fontSize: 16.sp,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Agrega uno desde tu próximo viaje',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.grey.shade500,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: ids.length,
            itemBuilder: (context, index) {
              return _TarjetaConductorFavorito(
                idConductor: ids[index],
                servicioFirebase: _servicioFirebase,
                uidPasajero: _uidPasajero,
              );
            },
          );
        },
      ),
    );
  }
}

class BotonAtras extends StatelessWidget {
  const BotonAtras({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
      onPressed: () => Navigator.of(context).pop(),
    );
  }
}

class _TarjetaConductorFavorito extends StatelessWidget {
  final String idConductor;
  final String uidPasajero;
  final ServicioFirebase servicioFirebase;

  const _TarjetaConductorFavorito({
    required this.idConductor,
    required this.uidPasajero,
    required this.servicioFirebase,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Conductor?>(
      stream: servicioFirebase.obtenerConductorStream(idConductor),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink(); // Aún cargando o eliminado
        }

        final conductor = snapshot.data!;

        // Lógica de disponibilidad CORRECTA usando el modelo Conductor
        final bool estaEnLinea = conductor.estaEnLinea;
        final bool sinViajeActivo =
            conductor.idViajeActivo == null || conductor.idViajeActivo!.isEmpty;
        final bool estaDisponible = estaEnLinea && sinViajeActivo;

        return Container(
          margin: EdgeInsets.only(bottom: 12.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                // Foto
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30.r,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: conductor.fotoPerfil != null &&
                              conductor.fotoPerfil!.isNotEmpty
                          ? NetworkImage(conductor.fotoPerfil!)
                          : null,
                      child: (conductor.fotoPerfil == null ||
                              conductor.fotoPerfil!.isEmpty)
                          ? Text(
                              conductor.nombre.isNotEmpty
                                  ? conductor.nombre[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.montserrat(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14.w,
                        height: 14.w,
                        decoration: BoxDecoration(
                          color: estaDisponible ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 16.w),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conductor.nombre,
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                          color: Colors.blueGrey.shade900,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${conductor.modeloVehiculo ?? "Vehículo"} • ${conductor.placa}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14.sp, color: Colors.amber),
                          SizedBox(width: 4.w),
                          Text(
                            (conductor.calificacion).toStringAsFixed(1),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Botones de Acción
                Column(
                  children: [
                    // Botón Eliminar Favorito
                    IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.red),
                      onPressed: () {
                        servicioFirebase.toggleFavorito(
                            uidPasajero, idConductor);
                      },
                    ),
                    // Botón Solicitar
                    if (estaDisponible)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            // Navegar a la pantalla correcta según el tipo de vehículo
                            final tipo = conductor.tipoVehiculo.toLowerCase();
                            final ruta =
                                (tipo == ConstantesInteroperabilidad.tipoMoto ||
                                        tipo.contains('moto'))
                                    ? '/Mototaxis'
                                    : '/Taxis';

                            Navigator.pushNamed(
                              context,
                              ruta,
                              arguments: {
                                'idConductor': conductor.id,
                                'categoria': conductor.categoria,
                              },
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Iniciando solicitud para ${conductor.nombre}. ¡Selecciona tu destino!'),
                                backgroundColor: Colors.teal,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.teal.shade400,
                                  Colors.blue.shade600
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              'Solicitar',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
