import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:clickexpress/Pasajero/mototaxis.dart';
import 'package:clickexpress/Pasajero/taxis.dart';
import 'package:clickexpress/auth/login_screen.dart';
import 'package:clickexpress/panel_control/pantalla_panel_control.dart';
import 'package:clickexpress/perfil/perfil.dart';
import 'package:clickexpress/Pasajero/pantalla_historial_viajes.dart';
import 'package:clickexpress/Pasajero/pantallas/pantalla_preferencias_viaje.dart';
import 'package:clickexpress/Pasajero/pantalla_favoritos.dart';
import 'package:clickexpress/Pasajero/pantalla_billetera.dart';
import 'package:clickexpress/Pasajero/pantallas/pantalla_contactos_confianza.dart';
import 'package:clickexpress/registro.dart';
import 'firebase_options.dart';
import 'package:clickexpress/Servicios/servicio_tasa_bcv.dart';

import 'package:audioplayers/audioplayers.dart';

void main() async {
  // Configuración inicial
  WidgetsFlutterBinding.ensureInitialized();

  final GoogleMapsFlutterPlatform mapsImplementation =
      GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    mapsImplementation.useAndroidViewSurface = true;
  }

  // Configuración de orientación
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    
    ServicioTasaBCV().refrescarTasa();
  } catch (e) {
    debugPrint('Error al inicializar Firebase: \$e');
  }

  // Iniciar la aplicación
  runApp(const ClickExpress());
}

class ClickExpress extends StatefulWidget {
  const ClickExpress({super.key});

  @override
  State<ClickExpress> createState() => _ClickExpressState();
}

class _ClickExpressState extends State<ClickExpress> {
  @override
  void initState() {
    super.initState();
    // Ejecutar audio con delay para dar prioridad a la renderización
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _reproducirAudioEntrada();
    });
  }

  Future<void> _reproducirAudioEntrada() async {
    try {
      final player = AudioPlayer();
      // Reproducir sonido de entrada 
      await player.play(AssetSource('audio/bocina_entrada.mp3'));
    } catch (e) {
      // Error silencioso en audio
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), 
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        final ThemeData themeBase = ThemeData(
          primaryColor: const Color(0xFF00D4AA),
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
        );

        return MaterialApp(
          title: 'Click Express',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es', 'ES'), // Español
            Locale('en', 'US'), // Inglés
          ],
          locale: const Locale('es', 'ES'), // Forzar español
          theme: themeBase.copyWith(
            textTheme:
                GoogleFonts.plusJakartaSansTextTheme(themeBase.textTheme),
          ),
          routes: {
            '/': (context) => const PantallaInicioSesion(),
            '/dashboard': (context) => PantallaPanelControl(),
            '/Taxis': (context) => const PantallaPasajero(),
            '/perfil': (context) => const PantallaPerfil(),
            '/Mototaxis': (context) => const PantallaMototaxi(),
            '/historial': (context) => const PantallaHistorialViajes(),
            '/favoritos': (context) => const PantallaFavoritos(),
            '/preferencias_viaje': (context) =>
                const PantallaPreferenciasViaje(),
            '/contactos_confianza': (context) =>
                const PantallaContactosConfianza(),
            '/billetera': (context) => const PantallaBilletera(),
            '/registro': (context) => const RegistroScreen(),
          },
        );
      },
    );
  }
}
