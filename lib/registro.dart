import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:clickexpress/Servicios/servicio_storage.dart';
import 'package:clickexpress/widgets/custom_stepper.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  // Variables y Controladores
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _emailController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _passwordController = TextEditingController();

  final _confirmPasswordController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _codigoReferidoController = TextEditingController();

  File? _imagenPerfil;
  File? _imagenCedula;
  final ServicioStorage _servicioStorage = ServicioStorage();
  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Estado UI
  bool _isLoading = false;
  bool _obscureText = true;
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 2; // Paso 0: Info, Paso 1: Docs

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _emailController.dispose();
    _confirmEmailController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _passwordController.dispose();

    _confirmPasswordController.dispose();
    _cedulaController.dispose();
    _codigoReferidoController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // --- Lógica de Imágenes ---
  Future<void> _seleccionarImagen(bool esPerfil) async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galería'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final picked = await _picker.pickImage(
                      source: ImageSource.gallery, imageQuality: 70);
                  if (picked != null) {
                    setState(() {
                      if (esPerfil) {
                        _imagenPerfil = File(picked.path);
                      } else {
                        _imagenCedula = File(picked.path);
                      }
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Cámara'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final picked = await _picker.pickImage(
                      source: ImageSource.camera, imageQuality: 70);
                  if (picked != null) {
                    setState(() {
                      if (esPerfil) {
                        _imagenPerfil = File(picked.path);
                      } else {
                        _imagenCedula = File(picked.path);
                      }
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Navegación ---
  void _siguientePaso() {
    if (_currentStep == 0) {
      if (_nombreController.text.isEmpty ||
          _apellidoController.text.isEmpty ||
          _emailController.text.isEmpty ||
          _telefonoController.text.isEmpty ||
          _cedulaController.text.isEmpty ||
          _passwordController.text.isEmpty) {
        _mostrarMensaje('Por favor complete todos los campos obligatorios',
            esError: true);
        return;
      }
      if (_emailController.text != _confirmEmailController.text) {
        _mostrarMensaje('Los correos no coinciden', esError: true);
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        _mostrarMensaje('Las contraseñas no coinciden', esError: true);
        return;
      }
      if (_passwordController.text.length < 6) {
        _mostrarMensaje('La contraseña debe tener al menos 6 caracteres',
            esError: true);
        return;
      }
    }

    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    } else {
      _registrarUsuario();
    }
  }

  void _pasoAnterior() {
    if (_currentStep > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep--);
    }
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(mensaje),
          backgroundColor: esError ? Colors.red : Colors.green),
    );
  }

  // --- Registro ---
  Future<void> _registrarUsuario() async {
    if (_imagenPerfil == null || _imagenCedula == null) {
      _mostrarMensaje('Debe subir foto de perfil y de cédula', esError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final uid = userCredential.user!.uid;

      final urlPerfil = await _servicioStorage
          .subirImagenPerfil(_imagenPerfil!, uid, esConductor: false);
      final urlCedula = await _servicioStorage
          .subirDocumento(_imagenCedula!, uid, 'cedula', esConductor: false);

      if (urlPerfil == null || urlCedula == null) {
        throw Exception('Error subiendo imágenes');
      }

      await _dbRef.child('pasajeros').child(uid).set({
        'nombre': _nombreController.text.trim(),
        'apellido': _apellidoController.text.trim(),
        'cedula': _cedulaController.text.trim().toUpperCase(),
        'email': _emailController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'direccion': _direccionController.text.trim(),
        'uid': uid,
        'fotoPerfil': urlPerfil,
        'fotoCedula': urlCedula,
        'fecha_registro': DateTime.now().toIso8601String(),
        'calificacionPromedio': 5.0,
        'totalViajes': 0,
        'codigoReferido': _codigoReferidoController.text.trim(),
      });

      _mostrarMensaje('Usuario registrado exitosamente');
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Error de registro';
      if (e.code == 'weak-password') msg = 'Contraseña débil';
      if (e.code == 'email-already-in-use') msg = 'El correo ya existe';
      _mostrarMensaje(msg, esError: true);
    } catch (e) {
      _mostrarMensaje('Error inesperado: $e', esError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Registro de Usuario',
            style: TextStyle(fontFamily: 'Inter', color: Colors.white)),
        backgroundColor: Colors.teal,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            CustomStepper(
                currentStep: _currentStep,
                totalSteps: _totalSteps,
                stepTitles: const ['Datos', 'Verificación']),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPasoDatos(),
                  _buildPasoVerificacion(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _pasoAnterior,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.teal),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child:
                      const Text('Atrás', style: TextStyle(color: Colors.teal)),
                ),
              )
            else
              const Spacer(),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _siguientePaso,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        _currentStep == _totalSteps - 1
                            ? 'Registrarse'
                            : 'Siguiente',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasoDatos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _campoTexto(_nombreController, 'Nombre', Icons.person,
              textCapitalization: TextCapitalization.words),
          const SizedBox(height: 12),
          _campoTexto(_apellidoController, 'Apellido', Icons.person_outline,
              textCapitalization: TextCapitalization.words),
          const SizedBox(height: 12),
          _campoTexto(_cedulaController, 'Cédula (V-12345678)', Icons.badge,
              textCapitalization: TextCapitalization.characters),
          const SizedBox(height: 12),
          _campoTexto(_emailController, 'Correo', Icons.email,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _campoTexto(
              _confirmEmailController, 'Confirmar Correo', Icons.email_outlined,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _campoTexto(_telefonoController, 'Teléfono', Icons.phone,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          _campoTexto(_direccionController, 'Dirección (Opcional)', Icons.home),
          const SizedBox(height: 12),
          _campoTexto(_passwordController, 'Contraseña', Icons.lock,
              obscureText: _obscureText,
              isPassword: true,
              onTogglePass: () => setState(() => _obscureText = !_obscureText)),
          const SizedBox(height: 12),
          _campoTexto(_confirmPasswordController, 'Confirmar Contraseña',
              Icons.lock_outline,
              obscureText: true, isPassword: false),
          const SizedBox(height: 12),
          _campoTexto(_codigoReferidoController,
              'Código de Referido (Opcional)', Icons.star_border,
              textCapitalization: TextCapitalization.characters),
        ],
      ),
    );
  }

  Widget _buildPasoVerificacion() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text("Verificación de Identidad",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
              "Para tu seguridad y la de los conductores, necesitamos validar tu identidad.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          _fotoWidget("Foto de Perfil", _imagenPerfil, true),
          const SizedBox(height: 20),
          _fotoWidget("Cédula de Identidad", _imagenCedula, false),
        ],
      ),
    );
  }

  Widget _campoTexto(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboardType,
      TextCapitalization textCapitalization = TextCapitalization.none,
      bool obscureText = false,
      bool isPassword = false,
      VoidCallback? onTogglePass}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal),
        suffixIcon: isPassword
            ? IconButton(
                icon:
                    Icon(obscureText ? Icons.visibility_off : Icons.visibility),
                onPressed: onTogglePass)
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _fotoWidget(String label, File? archivo, bool esPerfil) {
    return GestureDetector(
      onTap: () => _seleccionarImagen(esPerfil),
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: archivo != null ? Colors.teal : Colors.grey[300]!),
        ),
        child: archivo != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.file(archivo, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(esPerfil ? Icons.person_pin : Icons.badge,
                      size: 50, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(label,
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold)),
                  const Text("Toca para subir",
                      style: TextStyle(color: Colors.teal, fontSize: 12)),
                ],
              ),
      ),
    );
  }
}
