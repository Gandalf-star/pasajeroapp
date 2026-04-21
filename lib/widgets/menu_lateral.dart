import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Pasajero/servicios/firebase_db.dart';

class MenuLateral extends StatelessWidget {
  const MenuLateral({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final servicioFirebase = ServicioFirebase();

    return Drawer(
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Container(
        color: Colors.white,
        child: Column(
          children: <Widget>[
            // Header Dinámico Moderno
            _buildUserHeader(user, servicioFirebase),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: <Widget>[
                  _construirItemCajon(
                      context, Icons.dashboard_rounded, 'Inicio', () {
                    Navigator.pushReplacementNamed(context, '/dashboard');
                  }),
                  _construirItemCajon(
                      context, Icons.two_wheeler_rounded, 'Mototaxis', () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/Mototaxis');
                  }),
                  _construirItemCajon(
                      context, Icons.local_taxi_rounded, 'Taxis', () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/Taxis');
                  }),
                  _construirItemCajon(
                      context, Icons.history_rounded, 'Historial de Viajes',
                      () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/historial');
                  }),
                  // NUEVAS FUNCIONALIDADES MIGRADAS
                  const Divider(height: 20, indent: 20, endIndent: 20),
                  _construirItemCajon(context, Icons.calendar_today_rounded,
                      'Viajes Programados', () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/viajes_programados');
                  }),
                  _construirItemCajon(
                      context, Icons.tune_rounded, 'Preferencias de Viaje', () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/preferencias_viaje');
                  }),
                  _construirItemCajon(context, Icons.contact_emergency_rounded,
                      'Contactos de Confianza', () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/contactos_confianza');
                  }),
                  const Divider(height: 20, indent: 20, endIndent: 20),
                  _construirItemCajon(
                      context, Icons.person_rounded, 'Mi Perfil', () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/perfil');
                  }),
                  const SizedBox(height: 10),
                  const Divider(indent: 24, endIndent: 24),
                  const SizedBox(height: 10),
                  _construirItemCajon(
                      context,
                      Icons.account_balance_wallet_rounded,
                      'Recarga (Pronto)', () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Funcionalidad de recarga próximamente',
                          style: GoogleFonts.montserrat(),
                        ),
                        backgroundColor: Colors.teal,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: InkWell(
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                        '/', (Route<dynamic> route) => false);
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded,
                          color: Colors.red.shade400, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Cerrar Sesión',
                        style: GoogleFonts.montserrat(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeader(User? user, ServicioFirebase servicio) {
    if (user == null) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.teal.shade600,
              Colors.blue.shade700,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            'Invitado',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: servicio.obtenerPerfilPasajeroStream(user.uid),
      builder: (context, snapshot) {
        String nombre = user.displayName ?? 'Usuario';
        String telefono = user.phoneNumber ?? '';
        String fotoUrl = user.photoURL ?? '';

        if (snapshot.hasData && snapshot.data != null) {
          final data = snapshot.data!;
          if (data.containsKey('nombre')) nombre = data['nombre'];
          if (data.containsKey('telefono')) telefono = data['telefono'];
          if (data.containsKey('fotoPerfil') && data['fotoPerfil'].isNotEmpty) {
            fotoUrl = data['fotoPerfil'];
          }
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.teal.shade600,
                Colors.blue.shade700,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5), width: 1),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: fotoUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: fotoUrl,
                            width: 65,
                            height: 65,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                                color: Colors.white24,
                                child: const Icon(Icons.person,
                                    color: Colors.white)),
                            errorWidget: (context, url, error) => Container(
                                color: Colors.white24,
                                child: const Icon(Icons.person,
                                    color: Colors.white)),
                          )
                        : Container(
                            width: 65,
                            height: 65,
                            color: Colors.white24,
                            child: const Icon(Icons.person,
                                size: 35, color: Colors.white),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      nombre,
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        telefono.isNotEmpty ? telefono : 'Pasajero',
                        style: GoogleFonts.montserrat(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _construirItemCajon(
      BuildContext context, IconData icono, String titulo, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icono, color: Colors.blueGrey.shade700, size: 22),
      ),
      title: Text(
        titulo,
        style: GoogleFonts.montserrat(
          fontSize: 15,
          color: Colors.blueGrey.shade800,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: Colors.grey.shade400),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    );
  }
}
