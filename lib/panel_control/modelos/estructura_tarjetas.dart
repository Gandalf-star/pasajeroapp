import 'package:flutter/material.dart';

// Clase para definir los datos de cada elemento del panel de control
class ItemPanelControl {
  final String titulo;
  final ImageProvider imagen;
  final Color color;
  final String rutaNombre;
 

  ItemPanelControl({
    required this.titulo,
    required this.imagen,
    required this.color,
    required this.rutaNombre,
    
  });
}
