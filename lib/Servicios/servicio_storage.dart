import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class ServicioStorage {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> subirArchivo(File archivo, String ruta) async {
    try {
      final ref = _storage.ref().child(ruta);
      final uploadTask = ref.putFile(archivo);
      final snapshot = await uploadTask.whenComplete(() {});
      final url = await snapshot.ref.getDownloadURL();
      debugPrint('✅ Archivo subido exitosamente: $url');
      return url;
    } catch (e) {
      debugPrint('❌ Error subiendo archivo: $e');
      return null;
    }
  }

  Future<String?> subirImagenPerfil(File imagen, String uid,
      {bool esConductor = false}) async {
    final carpeta = esConductor ? 'conductores' : 'usuarios';
    final ruta = '$carpeta/$uid/perfil.jpg';
    return await subirArchivo(imagen, ruta);
  }

  Future<String?> subirDocumento(File imagen, String uid, String tipoDocumento,
      {bool esConductor = true}) async {
    final carpeta = esConductor ? 'conductores' : 'usuarios';
    final ruta = '$carpeta/$uid/documentos/$tipoDocumento.jpg';
    return await subirArchivo(imagen, ruta);
  }
}
