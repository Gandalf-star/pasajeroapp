import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';

class PantallaContactosConfianza extends StatefulWidget {
  const PantallaContactosConfianza({super.key});

  @override
  State<PantallaContactosConfianza> createState() => _PantallaContactosConfianzaState();
}

class _PantallaContactosConfianzaState extends State<PantallaContactosConfianza> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  void _mostrarDialogoAgregar() {
    final TextEditingController nombreController = TextEditingController();
    final TextEditingController telefonoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Agregar Contacto',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  labelStyle: GoogleFonts.plusJakartaSans(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: telefonoController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Número (Ej: +584141234567)',
                  labelStyle: GoogleFonts.plusJakartaSans(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: GoogleFonts.plusJakartaSans(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                final nombre = nombreController.text.trim();
                final telefonoRaw = telefonoController.text.trim();
                final telefono = telefonoRaw.replaceAll(RegExp(r'[^0-9+]'), '');

                if (nombre.isEmpty || telefono.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingresa nombre y teléfono válidos')),
                  );
                  return;
                }

                if (_uid != null) {
                  final newRef = _dbRef.child('pasajeros/$_uid/contactos_confianza').push();
                  await newRef.set({
                    'id': newRef.key,
                    'nombre': nombre,
                    'telefono': telefono,
                  });
                  if (nav.canPop()) nav.pop();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: Text(
                'Guardar',
                style: GoogleFonts.plusJakartaSans(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _eliminarContacto(String id) async {
    if (_uid != null) {
      await _dbRef.child('pasajeros/$_uid/contactos_confianza/$id').remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Contactos de Confianza')),
        body: Center(child: Text('Debes iniciar sesión')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Contactos de Confianza',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoAgregar,
        backgroundColor: Colors.teal.shade600,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Agregar', style: GoogleFonts.plusJakartaSans(color: Colors.white)),
      ),
      body: StreamBuilder(
        stream: _dbRef.child('pasajeros/$_uid/contactos_confianza').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Ocurrió un error.'));
          }

          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.contact_phone_outlined, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No tienes contactos configurados.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Agrega contactos para notificarles en caso de emergencia mediante el botón SOS.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final Map<dynamic, dynamic> data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final contactos = data.entries.map((e) => {'id': e.key, ...e.value as Map<dynamic, dynamic>}).toList();

          return ListView.builder(
            padding: const EdgeInsets.only(top: 10, bottom: 80), // Padding extra para FA button
            itemCount: contactos.length,
            itemBuilder: (context, index) {
              final contacto = contactos[index];
              final id = contacto['id'] ?? contacto.keys.firstWhere((k) => k != 'nombre' && k != 'telefono', orElse: () => '');
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    child: Icon(Icons.person, color: Colors.teal.shade700),
                  ),
                  title: Text(
                    contacto['nombre']?.toString() ?? 'Sin nombre',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    contacto['telefono']?.toString() ?? 'Sin teléfono',
                    style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade600),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _eliminarContacto(id.toString()),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
