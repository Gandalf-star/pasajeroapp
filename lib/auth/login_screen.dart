import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:clickexpress/registro.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PantallaInicioSesion extends StatefulWidget {
  const PantallaInicioSesion({super.key});

  @override
  State<PantallaInicioSesion> createState() => _PantallaInicioSesionState();
}

class _PantallaInicioSesionState extends State<PantallaInicioSesion> {
  final TextEditingController _controladorEmail = TextEditingController();
  final TextEditingController _controladorPassword = TextEditingController();
  final _almacenamientoSeguro = const FlutterSecureStorage();

  bool _isLoading = false;
  bool _mostrarCheck = false;
  bool _recordarme = false;
  bool _mostrarContrasena = false;

  @override
  void initState() {
    super.initState();
    // Carga diferida para no bloquear el primer frame
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _cargarCredencialesGuardadas();
    });
  }

  Future<void> _cargarCredencialesGuardadas() async {
    try {
      final correoGuardado = await _almacenamientoSeguro.read(key: 'correo');
      final contrasenaGuardada =
          await _almacenamientoSeguro.read(key: 'contrasena');
      final recordarmeGuardado =
          await _almacenamientoSeguro.read(key: 'recordarme');

      if (correoGuardado != null && contrasenaGuardada != null) {
        setState(() {
          _controladorEmail.text = correoGuardado;
          _controladorPassword.text = contrasenaGuardada;
          _recordarme = recordarmeGuardado == 'true';
        });
      }
    } catch (e) {
      // Error silencioso
    }
  }

  Future<void> _guardarCredenciales() async {
    try {
      await _almacenamientoSeguro.write(
          key: 'correo', value: _controladorEmail.text.trim());
      await _almacenamientoSeguro.write(
          key: 'contrasena', value: _controladorPassword.text.trim());
      await _almacenamientoSeguro.write(key: 'recordarme', value: 'true');
    } catch (e) {
      // Error silencioso
    }
  }

  Future<void> _limpiarCredenciales() async {
    try {
      await _almacenamientoSeguro.delete(key: 'correo');
      await _almacenamientoSeguro.delete(key: 'contrasena');
      await _almacenamientoSeguro.delete(key: 'recordarme');
    } catch (e) {
      // Error silencioso
    }
  }

  @override
  void dispose() {
    _controladorEmail.dispose();
    _controladorPassword.dispose();
    super.dispose();
  }

  // Función local para manejar errores de autenticación
  String _getAuthErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No se encontró un usuario con ese correo electrónico.';
        case 'wrong-password':
          return 'Contraseña incorrecta.';
        case 'invalid-email':
          return 'El formato del correo electrónico no es válido.';
        case 'user-disabled':
          return 'Esta cuenta ha sido deshabilitada.';
        case 'too-many-requests':
          return 'Demasiados intentos fallidos. Intenta de nuevo más tarde.';
        case 'operation-not-allowed':
          return 'Esta operación no está permitida.';
        case 'network-request-failed':
          return 'Error de conexión. Verifica tu conexión a internet.';
        case 'empty-fields':
          return 'Por favor, completa todos los campos.';
        default:
          return 'Error de autenticación: ${error.message}';
      }
    }
    return 'Ocurrió un error inesperado: $error';
  }

  // Función para manejar el inicio de sesión con correo y contraseña
  Future<void> _signInWithEmailAndPassword() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _mostrarCheck = false;
    });

    try {
      // Validación básica de campos
      final email = _controladorEmail.text.trim();
      final password = _controladorPassword.text.trim();

      if (email.isEmpty || password.isEmpty) {
        throw FirebaseAuthException(
          code: 'empty-fields',
          message: 'Por favor, completa todos los campos',
        );
      }

      // Validar formato de correo electrónico
      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: 'El formato del correo electrónico no es válido',
        );
      }

      // Iniciar sesión con Firebase Auth
      try {
        final userCredential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Verificar si el usuario existe
        if (userCredential.user != null) {
          if (!mounted) return;

          // Guardar o limpiar credenciales según el checkbox
          if (_recordarme) {
            await _guardarCredenciales();
          } else {
            await _limpiarCredenciales();
          }

          // Mostrar animación de éxito
          setState(() => _mostrarCheck = true);

          // Esperar un momento para mostrar la animación
          await Future.delayed(const Duration(seconds: 2));

          if (!mounted) return;

          // Navegar al dashboard usando pushReplacementNamed para limpiar el stack de navegación
          if (context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/dashboard',
              (Route<dynamic> route) => false,
            );
          }
        }
      } on FirebaseAuthException {
        // Relanzar la excepción para manejarla en el bloque catch externo
        rethrow;
      }
    } on FirebaseAuthException catch (e) {
      // Manejar errores específicos de Firebase Auth
      String mensajeError = _getAuthErrorMessage(e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeError),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(10.w),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
        );
      }
    } catch (e) {
      // Manejar cualquier otro error inesperado

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Ocurrió un error inesperado. Inténtalo de nuevo.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(10.w),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10.r)),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _recuperarContrasena() async {
    final correoActual = _controladorEmail.text.trim();

    final String? correoIngresado = await showDialog<String>(
      context: context,
      builder: (context) {
        final emailCtrl = TextEditingController(text: correoActual);
        return AlertDialog(
          title: Text(
            'Recuperar Contraseña',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
                style: GoogleFonts.plusJakartaSans(fontSize: 14.sp),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo electrónico',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () => Navigator.of(context).pop(emailCtrl.text.trim()),
              child: const Text('Enviar enlace',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (correoIngresado != null && correoIngresado.isNotEmpty) {
      try {
        await FirebaseAuth.instance
            .sendPasswordResetEmail(email: correoIngresado);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Se ha enviado el enlace de recuperación a tu correo.'),
              backgroundColor: Colors.teal.shade700,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al enviar el correo: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo animado optimizado y centrado
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.teal,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
              child: RepaintBoundary(
                child: Lottie.asset(
                  'assets/lottie/carro.json',
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  frameRate: FrameRate(24),
                  repeat: true,
                ),
              ),
            ),
          ),
          // Capa de éxito (check)
          if (_mostrarCheck)
            Positioned.fill(
              child: Lottie.asset(
                'assets/lottie/check.json',
                fit: BoxFit.contain,
              ),
            ),
          // Formulario de login
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(32.0.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo integrado con el fondo
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(21.r),
                          child: Image.asset(
                            'assets/imagen/FlashDrive_Fun_62.png',
                            height: 150.h,
                            width: 250.w,
                            fit: BoxFit.cover,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 19.w, vertical: 19.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Movilidad Inteligente',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Experiencia Premium',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 30.h),

                  // Campo de texto para el correo electrónico
                  TextField(
                    controller: _controladorEmail,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.sp,
                        color: const Color(0xFFFFFFFF)), // Blanco
                    enabled: !_isLoading, // Deshabilita el campo mientras carga
                    decoration: InputDecoration(
                      labelText: 'Correo Electrónico',
                      labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 14.sp,
                          color: const Color(0xFFFFFFFF)
                              .withValues(alpha: 0.7)), // Blanco con opacidad
                      prefixIcon: Icon(Icons.email_outlined,
                          size: 24.sp,
                          color: const Color(0xFFFFFFFF)), // Blanco
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                            color: const Color(0xFFFFFFFF)
                                .withValues(alpha: 0.5)), // Blanco con opacidad
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(
                            color: Color(0xFFFFFFFF), // Blanco
                            width: 2),
                      ),
                      fillColor: const Color(0xFFFFFFFF)
                          .withValues(alpha: 0.05), // Blanco con opacidad
                      filled: true,
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Campo de texto para la contraseña
                  TextField(
                    controller: _controladorPassword,
                    obscureText: !_mostrarContrasena,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.sp,
                        color: const Color(0xFFFFFFFF)), // Blanco
                    enabled: !_isLoading, // Deshabilita el campo mientras carga
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 14.sp,
                          color: const Color(0xFFFFFFFF)
                              .withValues(alpha: 0.7)), // Blanco con opacidad
                      prefixIcon: Icon(Icons.lock_outline,
                          size: 24.sp, color: Colors.white),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _mostrarContrasena
                              ? Icons.visibility
                              : Icons.visibility_off,
                          size: 24.sp,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _mostrarContrasena = !_mostrarContrasena;
                          });
                        },
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                            color: const Color(0xFFFFFFFF)
                                .withValues(alpha: 0.5)), // Blanco con opacidad
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(
                            color: Color(0xFFFFFFFF), // Blanco
                            width: 2),
                      ),
                      fillColor: const Color(0xFFFFFFFF)
                          .withValues(alpha: 0.05), // Blanco con opacidad
                      filled: true,
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Checkbox Recordarme
                  Row(
                    children: [
                      Checkbox(
                        value: _recordarme,
                        onChanged: (value) {
                          setState(() {
                            _recordarme = value ?? false;
                            if (!_recordarme) {
                              _limpiarCredenciales();
                            }
                          });
                        },
                        fillColor: WidgetStateProperty.resolveWith<Color>(
                          (Set<WidgetState> states) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.white;
                            }
                            return Colors.white.withValues(alpha: 0.3);
                          },
                        ),
                        checkColor: Colors.teal,
                      ),
                      Text(
                        'Recordarme',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.sp,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),

                  // Botón de inicio de sesión
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _signInWithEmailAndPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.teal.shade900,
                              elevation: 5,
                              shadowColor: Colors.black.withValues(alpha: 0.3),
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                            ),
                            child: Text(
                              'Iniciar Sesión',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const RegistroScreen()));
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.5),
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: Text(
                        'Crear Cuenta Nueva',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),

                  TextButton(
                    onPressed: _isLoading ? null : _recuperarContrasena,
                    child: Text(
                      '¿Olvidaste tu contraseña?',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 16.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
