import 'package:flutter/material.dart';
import 'package:clickexpress/auth/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _RegistroScreenState createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  // --- Variables y Controladores ---
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Variables de estado
  bool _obscureText = true;
  bool _obscureConfirmText = true;
  bool _isLoading = false;

  // Referencia a Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Instancia de FirebaseAuth ---
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Función para mostrar mensajes (SnackBar)
  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? Colors.red : Colors.green,
      ),
    );
  }

  // --- Función de Registro con Firebase ---
  Future<void> _registrarUsuario() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String nombre = _nombreController.text.trim();
      String apellido = _apellidoController.text.trim();
      String email = _emailController.text.trim();
      String telefono = _telefonoController.text.trim();
      String password = _passwordController.text.trim();

      // 1. Crear el usuario en Firebase Auth
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      debugPrint('Usuario creado exitosamente: ${userCredential.user?.email}');

      // 2. Crear documento de usuario en Firestore
      await _firestore
          .collection('usuarios')
          .doc(userCredential.user!.uid)
          .set({
        'uid': userCredential.user!.uid,
        'nombre': nombre,
        'apellido': apellido,
        'nombreCompleto': '$nombre $apellido',
        'email': email,
        'telefono': telefono,
        'calificacion': 5.0, // Calificación inicial
        'fechaRegistro': FieldValue.serverTimestamp(),
        'esConductor': false,
        'estado': 'activo',
        'ultimaConexion': FieldValue.serverTimestamp(),
        'tokenNotificacion':
            '', // Se actualizará cuando el usuario inicie sesión
      });

      // 2b. Crear perfil en RTDB en el nodo 'pasajeros' para interoperabilidad
      final dbRef = FirebaseDatabase.instance.ref();
      await dbRef.child('pasajeros').child(userCredential.user!.uid).set({
        'nombre': nombre,
        'telefono': telefono,
        'email': email,
        'fotoUrl': '',
        'fechaCreacion': ServerValue.timestamp,
        'fechaActualizacion': ServerValue.timestamp,
        'ultimaConexion': ServerValue.timestamp,
      });
      debugPrint('✅ Perfil inicial creado en RTDB/pasajeros');

      // 3. Actualizar perfil en Auth
      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName('$nombre $apellido');
        await userCredential.user!.reload();
        debugPrint('Perfil de usuario actualizado exitosamente');
      }

      _mostrarMensaje(
          'Usuario registrado exitosamente. Ahora puedes iniciar sesión.');

      if (mounted) {
        // Navega a Login y elimina historial anterior
        Navigator.pushAndRemoveUntil(
          context,
          // Asegúrate que LoginScreen es la clase correcta de tu pantalla de login
          MaterialPageRoute(builder: (context) => PantallaInicioSesion()),
          (Route<dynamic> route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Error de Firebase Auth al registrar: ${e.code}');
      String mensajeError;
      switch (e.code) {
        case 'weak-password':
          mensajeError =
              'La contraseña proporcionada es demasiado débil (mínimo 6 caracteres).';
          break;
        case 'email-already-in-use':
          mensajeError =
              'El correo electrónico ya está en uso por otra cuenta.';
          break;
        case 'invalid-email':
          mensajeError = 'El formato del correo electrónico no es válido.';
          break;
        default:
          mensajeError =
              'Ocurrió un error durante el registro: ${e.message}'; // Muestra mensaje más detallado
      }
      _mostrarMensaje(mensajeError, esError: true);
    } catch (e) {
      debugPrint('Error inesperado al registrar: $e');
      _mostrarMensaje('Ocurrió un error inesperado. Inténtalo de nuevo.',
          esError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Limpieza de controladores
    _nombreController.dispose();
    _apellidoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: Text('Registro de Usuario',
            style: TextStyle(fontFamily: 'Inter', color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          // Regresa a la pantalla anterior (debería ser Login)
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: Colors.green[100],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 20.0),
                // --- Campos del Formulario ---
                TextFormField(
                  controller: _nombreController,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Ingrese su nombre',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese su nombre';
                    }
                    return null;
                  },
                  style: const TextStyle(fontFamily: 'Inter'),
                ),
                const SizedBox(height: 12.0),
                TextFormField(
                  controller: _apellidoController,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Apellido',
                    hintText: 'Ingrese su apellido',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese su apellido';
                    }
                    return null;
                  },
                  style: const TextStyle(fontFamily: 'Inter'),
                ),
                const SizedBox(height: 12.0),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico',
                    hintText: 'Ingrese su correo electrónico',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese su correo electrónico';
                    }
                    if (!RegExp(
                            r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$") // Regex mejorada
                        .hasMatch(value)) {
                      return 'Correo electrónico no válido';
                    }
                    return null;
                  },
                  style: const TextStyle(fontFamily: 'Inter'),
                ),
                const SizedBox(height: 12.0),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscureText,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText:
                        'Ingrese su contraseña (mín. 6 caracteres)', // Indicación de longitud
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureText
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese su contraseña';
                    }
                    if (value.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres';
                    }
                    return null;
                  },
                  style: const TextStyle(fontFamily: 'Inter'),
                ),
                const SizedBox(height: 12.0),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmText,
                  decoration: InputDecoration(
                    labelText: 'Confirmar Contraseña',
                    hintText: 'Confirme su contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmText
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmText = !_obscureConfirmText;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor confirme su contraseña';
                    }
                    if (value != _passwordController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                  style: const TextStyle(fontFamily: 'Inter'),
                ),
                const SizedBox(height: 24.0),

                // --- Indicador de Carga o Botón de Registro ---
                _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: Colors.teal))
                    : ElevatedButton(
                        onPressed: _isLoading ? null : _registrarUsuario,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15.0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0)),
                          backgroundColor: Colors.teal,
                        ),
                        child: const Text(
                          'Registrarse',
                          style: TextStyle(
                              fontSize: 18.0,
                              color: Colors.white,
                              fontFamily: 'Inter'),
                        ),
                      ),
                const SizedBox(height: 20.0),
                // --- Texto para ir a Iniciar Sesión ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("¿Ya tienes una cuenta? ",
                        style: TextStyle(fontFamily: 'Inter')),
                    GestureDetector(
                      onTap: () {
                        // Regresa a la pantalla anterior (Login)
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Inicia sesión",
                        style: TextStyle(
                            color: Colors.teal.shade900,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
