import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Servicio para manejar Firebase Cloud Messaging (FCM) en la app del pasajero
/// Gestiona tokens, recepción de notificaciones y navegación
class ServicioNotificacionesFCM {
  static final ServicioNotificacionesFCM _instancia = ServicioNotificacionesFCM._internal();
  factory ServicioNotificacionesFCM() => _instancia;
  ServicioNotificacionesFCM._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Callback cuando se toca una notificación (para navegación)
  Function(Map<String, dynamic>)? onNotificacionRecibida;

  /// Inicializar el servicio de notificaciones
  Future<void> inicializar() async {
    // Solicitar permisos
    await _solicitarPermisos();

    // Configurar canal de notificaciones para Android
    await _configurarCanalNotificaciones();

    // Configurar handlers de mensajes
    _configurarHandlers();

    // Obtener y registrar token FCM
    await _registrarTokenFCM();

    // Escuchar cambios de token
    _firebaseMessaging.onTokenRefresh.listen(_onTokenRefresh);
  }

  /// Solicitar permisos de notificación
  Future<void> _solicitarPermisos() async {
    final NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    debugPrint('Estado de permisos FCM: ${settings.authorizationStatus}');
  }

  /// Configurar canal de notificaciones para Android
  Future<void> _configurarCanalNotificaciones() async {
    const AndroidNotificationChannel channelViajesProgramados = AndroidNotificationChannel(
      'viajes_programados_channel',
      'Viajes Programados',
      description: 'Notificaciones sobre viajes programados',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const AndroidNotificationChannel channelViajes = AndroidNotificationChannel(
      'viajes_channel',
      'Viajes',
      description: 'Notificaciones sobre viajes en curso',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const AndroidNotificationChannel channelPromociones = AndroidNotificationChannel(
      'promociones_channel',
      'Promociones',
      description: 'Ofertas y promociones especiales',
      importance: Importance.defaultImportance,
      playSound: true,
    );

    // Crear todos los canales
    final androidPlugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(channelViajesProgramados);
    await androidPlugin?.createNotificationChannel(channelViajes);
    await androidPlugin?.createNotificationChannel(channelPromociones);

    // Configuración de inicialización
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  /// Configurar handlers para diferentes estados de mensajes
  void _configurarHandlers() {
    // Mensaje recibido mientras la app está en primer plano
    FirebaseMessaging.onMessage.listen(_onMessage);

    // Mensaje recibido cuando la app está en segundo plano y el usuario toca la notificación
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // Mensaje recibido cuando la app está terminada
    FirebaseMessaging.instance.getInitialMessage().then(_onInitialMessage);
  }

  /// Handler para mensajes en primer plano
  Future<void> _onMessage(RemoteMessage message) async {
    debugPrint('📩 Mensaje recibido en primer plano:');
    debugPrint('Título: ${message.notification?.title}');
    debugPrint('Cuerpo: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');

    // Mostrar notificación local
    await _mostrarNotificacionLocal(message);

    // Notificar a los listeners
    if (onNotificacionRecibida != null) {
      onNotificacionRecibida!(message.data);
    }
  }

  /// Handler para cuando se abre la app desde una notificación
  void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint('📱 App abierta desde notificación:');
    debugPrint('Data: ${message.data}');

    // Navegar según el tipo de notificación
    _manejarNavegacionNotificacion(message.data);
  }

  /// Handler para mensaje inicial (app estaba terminada)
  void _onInitialMessage(RemoteMessage? message) {
    if (message != null) {
      debugPrint('🚀 App iniciada desde notificación:');
      debugPrint('Data: ${message.data}');

      // Navegar según el tipo de notificación
      _manejarNavegacionNotificacion(message.data);
    }
  }

  /// Manejar navegación según el tipo de notificación
  void _manejarNavegacionNotificacion(Map<String, dynamic> data) {
    final String tipo = data['tipo'] ?? '';
    final String viajeId = data['viajeId'] ?? '';

    switch (tipo) {
      case 'conductor_asignado':
        debugPrint('Navegar a pantalla de viaje: $viajeId');
        break;
      case 'conductor_llegando':
        debugPrint('Conductor llegando al punto de encuentro');
        break;
      case 'viaje_iniciado':
        debugPrint('Viaje iniciado: $viajeId');
        break;
      case 'viaje_completado':
        debugPrint('Viaje completado: $viajeId');
        break;
      case 'recordatorio_viaje_programado':
        debugPrint('Recordatorio de viaje programado: $viajeId');
        break;
      default:
        debugPrint('Tipo de notificación desconocido: $tipo');
    }
  }

  /// Mostrar notificación local
  Future<void> _mostrarNotificacionLocal(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Determinar el canal según el tipo de notificación
    final String tipo = message.data['tipo'] ?? '';
    String channelId = 'viajes_channel';
    String channelName = 'Viajes';

    if (tipo.contains('programado')) {
      channelId = 'viajes_programados_channel';
      channelName = 'Viajes Programados';
    } else if (tipo.contains('promocion')) {
      channelId = 'promociones_channel';
      channelName = 'Promociones';
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: const BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      message.hashCode,
      notification.title,
      notification.body,
      platformDetails,
      payload: message.data.toString(),
    );
  }

  /// Handler cuando se toca una notificación local
  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      debugPrint('Notificación local tocada: ${response.payload}');
      // Parsear payload y navegar
    }
  }

  /// Obtener y registrar el token FCM
  Future<void> _registrarTokenFCM() async {
    try {
      final String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _guardarTokenEnFirebase(token);
      }
    } catch (e) {
      debugPrint('Error obteniendo token FCM: $e');
    }
  }

  /// Guardar token en Firebase Database
  Future<void> _guardarTokenEnFirebase(String token) async {
    final User? usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      debugPrint('No hay usuario autenticado para guardar token FCM');
      return;
    }

    try {
      // Llamar a la Cloud Function para registrar el token
      final callable = FirebaseFunctions.instance.httpsCallable('registrarTokenFCM');
      final result = await callable.call({
        'token': token,
        'tipoUsuario': 'pasajero',
        'plataforma': 'android',
      });

      debugPrint('Token FCM registrado: ${result.data}');
    } catch (e) {
      debugPrint('Error registrando token FCM: $e');

      // Fallback: guardar directamente en Realtime Database
      try {
        await FirebaseDatabase.instance
            .ref()
            .child('pasajeros/${usuario.uid}')
            .update({
          'fcmToken': token,
          'fcmTokenActualizadoEn': ServerValue.timestamp,
        });
      } catch (e2) {
        debugPrint('Error en fallback de registro de token: $e2');
      }
    }
  }

  /// Handler cuando el token se actualiza
  Future<void> _onTokenRefresh(String token) async {
    debugPrint('Token FCM actualizado: $token');
    await _guardarTokenEnFirebase(token);
  }

  /// Obtener el token FCM actual
  Future<String?> obtenerToken() async {
    return await _firebaseMessaging.getToken();
  }

  /// Eliminar token (logout)
  Future<void> eliminarToken() async {
    await _firebaseMessaging.deleteToken();
    debugPrint('Token FCM eliminado');
  }

  /// Suscribirse a un tema (topic)
  Future<void> suscribirseATema(String tema) async {
    await _firebaseMessaging.subscribeToTopic(tema);
    debugPrint('Suscrito al tema: $tema');
  }

  /// Desuscribirse de un tema
  Future<void> desuscribirseDeTema(String tema) async {
    await _firebaseMessaging.unsubscribeFromTopic(tema);
    debugPrint('Desuscrito del tema: $tema');
  }

  /// Verificar si las notificaciones están habilitadas
  Future<bool> verificarPermisos() async {
    final settings = await _firebaseMessaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
}

/// Función de top-level para manejar mensajes en background
/// Debe ser una función global, no un método de clase
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Asegurar que Firebase está inicializado
  await Firebase.initializeApp();

  debugPrint('📨 Mensaje recibido en background:');
  debugPrint('Título: ${message.notification?.title}');
  debugPrint('Cuerpo: ${message.notification?.body}');
  debugPrint('Data: ${message.data}');

  // Aquí puedes procesar la notificación en background
  // Por ejemplo, guardar en base de datos local, etc.
}
