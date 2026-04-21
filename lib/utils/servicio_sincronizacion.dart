import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'constantes_interoperabilidad.dart';

/// Servicio para sincronizar y normalizar datos entre ClickExpress y Click_v2
class ServicioSincronizacion {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  /// Normaliza el tipo de vehículo para asegurar compatibilidad entre aplicaciones
  /// Convierte 'Moto', 'Carro', 'Camioneta' a 'moto', 'carro', 'camioneta'
  String normalizarTipoVehiculo(String tipo) {
    // Convertir a minúsculas para estandarizar
    final tipoLower = tipo.toLowerCase();
    
    // Mapeo de tipos de vehículo
    switch (tipoLower) {
      case 'moto':
      case 'motocicleta':
      case 'motocarro':
        return 'moto';
      case 'carro':
      case 'auto':
      case 'automóvil':
      case 'automovil':
        return 'carro';
      case 'camioneta':
      case 'suv':
      case 'pickup':
        return 'camioneta';
      default:
        debugPrint('⚠️ Tipo de vehículo no reconocido: $tipo, usando valor original');
        return tipoLower;
    }
  }
  
  /// Normaliza la categoría para asegurar compatibilidad entre aplicaciones
  /// Convierte 'Económico', 'Estándar', 'Premium' a 'economico', 'estandar', 'premium'
  String normalizarCategoria(String categoria) {
    if (categoria.isEmpty) return '';

    // Convertir a minúsculas y eliminar acentos
    final categoriaLower = categoria.toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    
    // Mapeo de categorías basado en ConstantesInteroperabilidad
    if (categoriaLower.contains('economico')) {
      return ConstantesInteroperabilidad.categoriaEconomico;
    }
    if (categoriaLower.contains('confort') || 
        categoriaLower.contains('estandar') || 
        categoriaLower.contains('normal') ||
        categoriaLower == 'con') {
      return ConstantesInteroperabilidad.categoriaConfort;
    }
    if (categoriaLower.contains('viajes_largos') || 
        categoriaLower.contains('viajes largos') || 
        categoriaLower.contains('premium') || 
        categoriaLower.contains('vip')) {
      return ConstantesInteroperabilidad.categoriaViajesL;
    }
    
    return ConstantesInteroperabilidad.categoriaConfort; // Default
  }
  
  /// Verifica y corrige inconsistencias en los datos de conductores
  Future<void> verificarYCorregirDatosConductores() async {
    try {
      final snapshot = await _database.ref(ConstantesInteroperabilidad.nodoConductores).get();
      
      if (snapshot.exists) {
        final conductores = snapshot.value as Map<dynamic, dynamic>;
        
        for (final entry in conductores.entries) {
          final conductorId = entry.key.toString();
          final conductorData = Map<String, dynamic>.from(entry.value);
          
          bool requiereActualizacion = false;
          final datosActualizados = Map<String, dynamic>.from(conductorData);
          
          // Verificar y corregir tipo de vehículo
          if (conductorData.containsKey(ConstantesInteroperabilidad.campoTipoVehiculo)) {
            final tipoOriginal = conductorData[ConstantesInteroperabilidad.campoTipoVehiculo].toString();
            final tipoNormalizado = normalizarTipoVehiculo(tipoOriginal);
            
            if (tipoOriginal != tipoNormalizado) {
              datosActualizados[ConstantesInteroperabilidad.campoTipoVehiculo] = tipoNormalizado;
              requiereActualizacion = true;
              debugPrint('🔄 Normalizando tipo de vehículo para conductor $conductorId: $tipoOriginal → $tipoNormalizado');
            }
          }
          
          // Verificar y corregir categoría
          if (conductorData.containsKey(ConstantesInteroperabilidad.campoCategoria)) {
            final categoriaOriginal = conductorData[ConstantesInteroperabilidad.campoCategoria].toString();
            final categoriaNormalizada = normalizarCategoria(categoriaOriginal);
            
            if (categoriaOriginal != categoriaNormalizada) {
              datosActualizados[ConstantesInteroperabilidad.campoCategoria] = categoriaNormalizada;
              requiereActualizacion = true;
              debugPrint('🔄 Normalizando categoría para conductor $conductorId: $categoriaOriginal → $categoriaNormalizada');
            }
          }
          
          // Actualizar datos si es necesario
          if (requiereActualizacion) {
            await _database.ref('${ConstantesInteroperabilidad.nodoConductores}/$conductorId').update(datosActualizados);
            debugPrint('✅ Datos del conductor $conductorId actualizados correctamente');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error al verificar y corregir datos de conductores: $e');
    }
  }
  
  /// Verifica y corrige inconsistencias en las solicitudes de viaje
  Future<void> verificarYCorregirSolicitudesViaje() async {
    try {
      final snapshot = await _database.ref(ConstantesInteroperabilidad.nodoSolicitudesViaje).get();
      
      if (snapshot.exists) {
        final solicitudes = snapshot.value as Map<dynamic, dynamic>;
        
        for (final entry in solicitudes.entries) {
          final solicitudId = entry.key.toString();
          final solicitudData = Map<String, dynamic>.from(entry.value as Map);
          
          bool requiereActualizacion = false;
          final datosActualizados = Map<String, dynamic>.from(solicitudData);
          
          // Verificar y corregir tipo de vehículo requerido
          if (solicitudData.containsKey(ConstantesInteroperabilidad.campoTipoVehiculoRequerido)) {
            final tipoOriginal = solicitudData[ConstantesInteroperabilidad.campoTipoVehiculoRequerido].toString();
            final tipoNormalizado = normalizarTipoVehiculo(tipoOriginal);
            
            if (tipoOriginal != tipoNormalizado) {
              datosActualizados[ConstantesInteroperabilidad.campoTipoVehiculoRequerido] = tipoNormalizado;
              requiereActualizacion = true;
              debugPrint('🔄 Normalizando tipo de vehículo requerido para solicitud $solicitudId: $tipoOriginal → $tipoNormalizado');
            }
          }
          
          // Verificar y corregir categoría
          if (solicitudData.containsKey(ConstantesInteroperabilidad.campoCategoriaRequerida)) {
            final categoriaOriginal = solicitudData[ConstantesInteroperabilidad.campoCategoriaRequerida].toString();
            final categoriaNormalizada = normalizarCategoria(categoriaOriginal);
            
            if (categoriaOriginal != categoriaNormalizada) {
              datosActualizados[ConstantesInteroperabilidad.campoCategoriaRequerida] = categoriaNormalizada;
              requiereActualizacion = true;
              debugPrint('🔄 Normalizando categoría para solicitud $solicitudId: $categoriaOriginal → $categoriaNormalizada');
            }
          }
          
          // Actualizar datos si es necesario
          if (requiereActualizacion) {
            await _database.ref('${ConstantesInteroperabilidad.nodoSolicitudesViaje}/$solicitudId').update(datosActualizados);
            debugPrint('✅ Datos de la solicitud $solicitudId actualizados correctamente');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error al verificar y corregir solicitudes de viaje: $e');
    }
  }
  
  /// Ejecuta todas las verificaciones y correcciones
  Future<void> sincronizarTodo() async {
    debugPrint('🔄 Iniciando sincronización de datos entre ClickExpress y Click_v2...');
    await verificarYCorregirDatosConductores();
    await verificarYCorregirSolicitudesViaje();
    debugPrint('✅ Sincronización completada');
  }
}
