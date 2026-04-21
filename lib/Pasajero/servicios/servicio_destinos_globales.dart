import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../modelos/destino_global.dart';

/// Servicio para gestionar destinos globales compartidos entre todos los usuarios
class ServicioDestinosGlobales {
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref('destinos_globales');

  /// Genera un ID único para un destino basado en coordenadas o nombre
  String _generarIdDestino({double? lat, double? lng, String? nombre}) {
    if (lat != null && lng != null) {
      // Redondear a 4 decimales (~11 metros de precisión)
      final latRedondeado = (lat * 10000).round() / 10000;
      final lngRedondeado = (lng * 10000).round() / 10000;

      return '${latRedondeado}_$lngRedondeado'
          .replaceAll('.', '_')
          .replaceAll('-', 'n');
    } else if (nombre != null) {
      // Usar nombre normalizado como ID si no hay coordenadas
      return nombre
          .toLowerCase()
          .trim()
          .replaceAll(RegExp(r'[^a-z0-9]'), '_')
          .replaceAll(RegExp(r'_+'), '_');
    }

    // Fallback: generar ID aleatorio
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Busca destinos que coincidan con el query
  Future<List<DestinoGlobal>> buscarDestinos(String query) async {
    if (query.length < 2) return [];

    try {
      debugPrint('🔍 [DESTINOS GLOBALES] Buscando: "$query"');

      final queryLower = query.toLowerCase();

      // Obtener todos los destinos (en producción, usar índices o paginación)
      final snapshot = await _dbRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        debugPrint('   No hay destinos guardados aún');
        return [];
      }

      final List<DestinoGlobal> resultados = [];
      final data = Map<String, dynamic>.from(snapshot.value as Map);

      data.forEach((id, value) {
        if (value is Map) {
          final destino = DestinoGlobal.fromMap(id, value);

          // Filtrar por nombre que contenga el query
          if (destino.nombre.toLowerCase().contains(queryLower)) {
            resultados.add(destino);
          }
        }
      });

      // Ordenar por popularidad (más usado primero)
      resultados.sort((a, b) => b.vecesUsado.compareTo(a.vecesUsado));

      debugPrint('   ✅ Encontrados ${resultados.length} destinos');
      return resultados.take(10).toList(); // Limitar a 10 resultados
    } catch (e) {
      debugPrint('❌ [DESTINOS GLOBALES] Error al buscar: $e');
      return [];
    }
  }

  /// Obtiene los destinos más populares
  Future<List<DestinoGlobal>> obtenerDestinosPopulares(
      {int limite = 10}) async {
    try {
      debugPrint('📊 [DESTINOS GLOBALES] Obteniendo destinos populares...');

      final snapshot = await _dbRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final List<DestinoGlobal> destinos = [];
      final data = Map<String, dynamic>.from(snapshot.value as Map);

      data.forEach((id, value) {
        if (value is Map) {
          destinos.add(DestinoGlobal.fromMap(id, value));
        }
      });

      // Ordenar por popularidad
      destinos.sort((a, b) => b.vecesUsado.compareTo(a.vecesUsado));

      debugPrint('   ✅ ${destinos.length} destinos populares');
      return destinos.take(limite).toList();
    } catch (e) {
      debugPrint('❌ [DESTINOS GLOBALES] Error al obtener populares: $e');
      return [];
    }
  }

  /// Busca si ya existe un destino similar (por nombre o coordenadas)
  Future<DestinoGlobal?> _buscarDestinoSimilar({
    required String nombre,
    double? lat,
    double? lng,
  }) async {
    try {
      final snapshot = await _dbRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final nombreNormalizado = nombre.toLowerCase().trim();

      // Si hay coordenadas, buscar por proximidad
      if (lat != null && lng != null) {
        for (final entry in data.entries) {
          if (entry.value is Map) {
            final destino = DestinoGlobal.fromMap(entry.key, entry.value);

            if (destino.lat != null && destino.lng != null) {
              final distancia = Geolocator.distanceBetween(
                lat,
                lng,
                destino.lat!,
                destino.lng!,
              );

              // Considerar duplicado si está a menos de 50 metros
              if (distancia < 50) {
                debugPrint(
                  '   🎯 Destino similar encontrado por proximidad: ${destino.nombre} (${distancia.toStringAsFixed(0)}m)',
                );
                return destino;
              }
            }
          }
        }
      }

      // Buscar por nombre similar
      for (final entry in data.entries) {
        if (entry.value is Map) {
          final destino = DestinoGlobal.fromMap(entry.key, entry.value);
          final destinoNombreNormalizado = destino.nombre.toLowerCase().trim();

          // Coincidencia exacta o muy similar
          if (destinoNombreNormalizado == nombreNormalizado ||
              destinoNombreNormalizado.contains(nombreNormalizado) ||
              nombreNormalizado.contains(destinoNombreNormalizado)) {
            debugPrint(
              '   🎯 Destino similar encontrado por nombre: ${destino.nombre}',
            );
            return destino;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error al buscar destino similar: $e');
      return null;
    }
  }

  /// Guarda o actualiza un destino global
  Future<bool> guardarDestino({
    required String nombre,
    double? lat,
    double? lng,
    String? direccion,
  }) async {
    try {
      debugPrint('💾 [DESTINOS GLOBALES] Guardando destino: "$nombre"');
      debugPrint(
          '   Coordenadas: ${lat != null ? "$lat, $lng" : "Sin coordenadas"}');

      // Validar nombre
      if (nombre.trim().length < 3) {
        debugPrint('   ❌ Nombre muy corto');
        return false;
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;

      // Buscar si ya existe un destino similar
      final destinoExistente = await _buscarDestinoSimilar(
        nombre: nombre,
        lat: lat,
        lng: lng,
      );

      if (destinoExistente != null) {
        // Actualizar destino existente
        debugPrint(
            '   📝 Actualizando destino existente: ${destinoExistente.id}');

        final updates = <String, dynamic>{
          'vecesUsado': destinoExistente.vecesUsado + 1,
          'ultimaActualizacion': ServerValue.timestamp,
        };

        // Si el destino NO tenía coordenadas pero ahora sí, actualizarlas
        if (lat != null &&
            lng != null &&
            (destinoExistente.lat == null || destinoExistente.lng == null)) {
          debugPrint('   ✨ Agregando coordenadas al destino existente');
          updates['lat'] = lat;
          updates['lng'] = lng;
          updates['tieneCoordenadasExactas'] = true;
        }

        // Actualizar dirección si es mejor que la actual
        if (direccion != null &&
            direccion.length > (destinoExistente.direccion?.length ?? 0)) {
          updates['direccion'] = direccion;
        }

        await _dbRef.child(destinoExistente.id).update(updates);
        debugPrint('   ✅ Destino actualizado exitosamente');
        return true;
      } else {
        // Crear nuevo destino
        final destinoId = _generarIdDestino(lat: lat, lng: lng, nombre: nombre);
        debugPrint('   ✨ Creando nuevo destino: $destinoId');

        final nuevoDestino = DestinoGlobal(
          id: destinoId,
          nombre: nombre.trim(),
          lat: lat,
          lng: lng,
          direccion: direccion ?? nombre.trim(),
          vecesUsado: 1,
          creadoPor: uid,
          tieneCoordenadasExactas: lat != null && lng != null,
        );

        await _dbRef.child(destinoId).set(nuevoDestino.toMap());
        debugPrint('   ✅ Nuevo destino creado exitosamente');
        return true;
      }
    } catch (e) {
      debugPrint('❌ [DESTINOS GLOBALES] Error al guardar destino: $e');
      return false;
    }
  }

  /// Obtiene un destino específico por ID
  Future<DestinoGlobal?> obtenerDestinoPorId(String id) async {
    try {
      final snapshot = await _dbRef.child(id).get();

      if (snapshot.exists && snapshot.value != null) {
        return DestinoGlobal.fromMap(id, snapshot.value as Map);
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error al obtener destino por ID: $e');
      return null;
    }
  }
}
