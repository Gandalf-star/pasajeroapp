import 'package:flutter/material.dart';

class VehicleOptionTile extends StatelessWidget {
  final String nombre;
  final IconData icono;
  final double precio;
  final VoidCallback onTap;

  const VehicleOptionTile({
    super.key,
    required this.nombre,
    required this.icono,
    required this.precio,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icono, color: Colors.teal, size: 40),
        title: Text(
          nombre,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        trailing: Text(
          '\$${precio.toStringAsFixed(2)}',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
