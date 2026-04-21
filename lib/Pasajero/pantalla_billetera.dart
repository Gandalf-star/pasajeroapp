import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'servicios/servicio_pagos.dart';
import '../Servicios/servicio_tasa_bcv.dart';
import '../Servicios/servicio_config_remota.dart';
import '../../utils/constantes_interoperabilidad.dart';

class PantallaBilletera extends StatefulWidget {
  const PantallaBilletera({super.key});

  @override
  State<PantallaBilletera> createState() => _PantallaBilleteraState();
}

class _PantallaBilleteraState extends State<PantallaBilletera> {
  final ServicioPagos _servicioPagos = ServicioPagos();
  final ServicioConfigRemota _configRemota = ServicioConfigRemota();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // ── Guard anti-doble-pago ──────────────────────────────────────────────────
  bool _procesandoPago = false; // Bandera atómica procesamiento activo
  DateTime? _ultimoPagoExitoso;
  static const Duration _cooldownPago = Duration(seconds: 60);

  // ── Datos bancarios (desde config remota) ──────────────────────────────────
  Map<String, dynamic> _datosBancarios = {
    'banco': 'Cargando...',
    'codigoBanco': '',
    'telefono': '',
    'rifCi': '',
    'titular': '',
  };
  bool _cargandoConfig = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosBancarios();
  }

  Future<void> _cargarDatosBancarios() async {
    try {
      final config = await _configRemota.cargarConfig();
      final datos = config['datosRecarga'];
      if (mounted && datos is Map) {
        setState(() {
          _datosBancarios = Map<String, dynamic>.from(datos);
          _cargandoConfig = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoConfig = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('No autenticado')));
    }

    final String pathBilletera =
        '${ConstantesInteroperabilidad.nodoPasajeros}/${user.uid}/billetera';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Mi Billetera',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.teal.shade700, Colors.blue.shade800],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          StreamBuilder<DatabaseEvent>(
            stream: _dbRef.child('$pathBilletera/saldo').onValue,
            builder: (context, snapshot) {
              double saldo = 0.0;
              if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                saldo =
                    double.tryParse(snapshot.data!.snapshot.value.toString()) ??
                        0.0;
              }
              return _buildHeaderSaldo(saldo);
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickActions(context),
                  const SizedBox(height: 30),
                  _buildSeccionDatosBancarios(),
                  const SizedBox(height: 30),
                  Text(
                    'Actividad Reciente',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey.shade800,
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildHistorialReal(pathBilletera),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSaldo(double saldo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 25, right: 25, bottom: 40, top: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.teal.shade700, Colors.blue.shade800],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Column(
        children: [
          Text(
            'Saldo Disponible',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '\$${saldo.toStringAsFixed(2)}',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          StreamBuilder<double>(
            stream: ServicioTasaBCV().obtenerTasaStream(),
            initialData: ServicioTasaBCV().tasaActual,
            builder: (context, snap) {
              final tasa = snap.data ?? 0.0;
              final bs = tasa > 0 ? saldo * tasa : null;
              return Column(
                children: [
                  Text(
                    bs != null
                        ? 'Bs ${bs.toStringAsFixed(2)}'
                        : 'Cargando Bs...',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tasa > 0
                          ? 'Tasa del día: ${tasa.toStringAsFixed(2)} Bs/\$'
                          : 'Cargando tasa BCV...',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _actionButton(
          label: 'Recargar',
          icon: Icons.add_circle_outline,
          color: Colors.blue.shade600,
          onTap: () => _mostrarDialogoRecarga(context),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.blueGrey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildSeccionDatosBancarios() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.account_balance,
                    color: Colors.blue.shade700, size: 20),
              ),
              const SizedBox(width: 15),
              Text(
                'Datos para Recarga',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blueGrey.shade800,
                ),
              ),
              if (_cargandoConfig) ...[
                const SizedBox(width: 10),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          _datoFila(
            'Banco',
            _cargandoConfig
                ? 'Cargando...'
                : '${_datosBancarios['banco'] ?? ''} (${_datosBancarios['codigoBanco'] ?? ''})',
          ),
          _datoFila('Teléfono', _datosBancarios['telefono']?.toString() ?? ''),
          _datoFila('RIF / CI', _datosBancarios['rifCi']?.toString() ?? ''),
          if ((_datosBancarios['titular']?.toString() ?? '').isNotEmpty)
            _datoFila('Titular', _datosBancarios['titular'].toString()),
          const SizedBox(height: 8),
          // Botón copiar datos
          TextButton.icon(
            onPressed: _cargandoConfig
                ? null
                : () {
                    final texto =
                        'Banco: ${_datosBancarios['banco']} (${_datosBancarios['codigoBanco']})\n'
                        'Teléfono: ${_datosBancarios['telefono']}\n'
                        'RIF: ${_datosBancarios['rifCi']}\n'
                        'Titular: ${_datosBancarios['titular']}';
                    Clipboard.setData(ClipboardData(text: texto));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Datos copiados al portapapeles'),
                          duration: Duration(seconds: 2)),
                    );
                  },
            icon: const Icon(Icons.copy, size: 16),
            label: Text('Copiar datos',
                style: GoogleFonts.plusJakartaSans(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _datoFila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.blueGrey.shade500, fontSize: 14)),
          Text(valor,
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.blueGrey.shade800,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildHistorialReal(String pathBilletera) {
    return StreamBuilder<DatabaseEvent>(
      stream: _dbRef.child('$pathBilletera/actividad').limitToLast(10).onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return Center(
            child: Text('No hay actividad reciente',
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.blueGrey.shade400)),
          );
        }

        final Map<dynamic, dynamic> data =
            snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> items = data.entries.map((e) {
          return Map<String, dynamic>.from(e.value as Map);
        }).toList();

        items.sort((a, b) => (b['fecha'] ?? 0).compareTo(a['fecha'] ?? 0));

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            bool esSuma = item['tipo']?.toString().contains('recarga') ?? true;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blueGrey.shade100),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        esSuma ? Colors.green.shade50 : Colors.red.shade50,
                    child: Icon(esSuma ? Icons.add : Icons.remove,
                        color: esSuma ? Colors.green : Colors.red),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(esSuma ? 'Recarga C2P' : 'Gasto de Viaje',
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(item['referencia'] ?? 'Transacción',
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.blueGrey.shade400, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text(
                    '${esSuma ? '+' : '-'}\$${(item['monto'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        color: esSuma ? Colors.green : Colors.red,
                        fontSize: 16),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarDialogoRecarga(BuildContext context) {
    // ── Guard: Verificar cooldown de pago ─────────────────────────────────
    if (_procesandoPago) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ Ya hay un pago en proceso. Por favor espera.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_ultimoPagoExitoso != null) {
      final diferencia = DateTime.now().difference(_ultimoPagoExitoso!);
      if (diferencia < _cooldownPago) {
        final restantes = (_cooldownPago - diferencia).inSeconds;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✋ Espera $restantes segundos antes de realizar otra recarga.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    final TextEditingController montoController = TextEditingController();
    final TextEditingController cedulaController = TextEditingController();
    final TextEditingController telefonoController = TextEditingController();
    final TextEditingController claveController = TextEditingController();
    String bancoSeleccionado = '0105';
    bool procesandoEnModal = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Text('Recarga con C2P',
                style:
                    GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ServicioPagos.modoMock)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Text(
                        '🧪 MODO PRUEBAS: Usa clave 123456',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.orange.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  _textField(
                      montoController, 'Monto (\$)', Icons.attach_money, true),
                  const SizedBox(height: 12),
                  _textField(
                      cedulaController, 'Cédula del pagador', Icons.badge, false),
                  const SizedBox(height: 12),
                  _textField(telefonoController, 'Teléfono móvil',
                      Icons.phone_android, true),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: bancoSeleccionado,
                    decoration:
                        _inputDecoration('Banco', Icons.account_balance),
                    items: const [
                      DropdownMenuItem(value: '0105', child: Text('Mercantil')),
                      DropdownMenuItem(value: '0102', child: Text('Venezuela')),
                      DropdownMenuItem(value: '0134', child: Text('Banesco')),
                      DropdownMenuItem(value: '0108', child: Text('Provincial')),
                      DropdownMenuItem(
                          value: '0175', child: Text('Bicentenario')),
                    ],
                    onChanged: (val) =>
                        setModalState(() => bancoSeleccionado = val!),
                  ),
                  const SizedBox(height: 12),
                  _textField(claveController, 'Clave Dinámica C2P',
                      Icons.lock_clock, true),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: procesandoEnModal
                      ? null
                      : () => Navigator.pop(context),
                  child: Text('Cancelar',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.blueGrey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                // ── GUARD DOBLE-TAP: onPressed se bloquea si procesandoEnModal ──
                onPressed: procesandoEnModal
                    ? null
                    : () async {
                        final monto =
                            double.tryParse(montoController.text.trim()) ?? 0;
                        if (montoController.text.isEmpty ||
                            cedulaController.text.isEmpty ||
                            telefonoController.text.isEmpty ||
                            claveController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Por favor completa todos los campos')),
                          );
                          return;
                        }
                        if (monto <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('El monto debe ser mayor a 0')),
                          );
                          return;
                        }
                        if (monto > 500) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'El monto máximo por recarga es \$500')),
                          );
                          return;
                        }

                        // Bloquear el botón en el modal
                        setModalState(() => procesandoEnModal = true);

                        final navigator = Navigator.of(context);
                        navigator.pop();
                        _procesarPago(
                          monto,
                          cedulaController.text.trim(),
                          telefonoController.text.trim(),
                          bancoSeleccionado,
                          claveController.text.trim(),
                        );
                      },
                child: procesandoEnModal
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Recargar Ahora',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _textField(TextEditingController controller, String label,
      IconData icon, bool numeric) {
    return TextField(
      controller: controller,
      decoration: _inputDecoration(label, icon),
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      style: GoogleFonts.plusJakartaSans(fontSize: 14),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: Colors.blueGrey.shade400),
      labelStyle: GoogleFonts.plusJakartaSans(
          color: Colors.blueGrey.shade400, fontSize: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blueGrey.shade200)),
      filled: true,
      fillColor: Colors.blueGrey.shade50,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
    );
  }

  /// Procesa el pago con guard anti-doble-cargo
  void _procesarPago(double monto, String cedula, String telefono,
      String banco, String clave) async {
    // Verificación final de doble procesamiento (race condition entre taps rápidos)
    if (_procesandoPago) return;
    if (!mounted) return;

    setState(() => _procesandoPago = true);

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
              canPop: false,
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text('Procesando pago...',
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text('No cierres la aplicación',
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ));

    try {
      final result = await _servicioPagos.procesarPagoC2P(
          monto: monto,
          cedula: cedula,
          telefono: telefono,
          banco: banco,
          claveC2P: clave);

      if (mounted) {
        Navigator.pop(context); // Cerrar loading

        if (result['success'] == true) {
          // Solo actualizamos cooldown en caso de éxito real
          setState(() {
            _ultimoPagoExitoso = DateTime.now();
          });
          _mostrarResultado(true,
              'Recarga de \$${monto.toStringAsFixed(2)} aplicada exitosamente.\nRef: ${result['referencia'] ?? 'N/A'}');
        } else {
          _mostrarResultado(
              false, result['error']?.toString() ?? 'Error desconocido');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _mostrarResultado(false, 'Error inesperado: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _procesandoPago = false);
      }
    }
  }

  void _mostrarResultado(bool exito, String msj) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(exito ? Icons.check_circle : Icons.error,
                color: exito ? Colors.green : Colors.red, size: 80),
            const SizedBox(height: 20),
            Text(exito ? '¡Hecho!' : 'Error',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(msj,
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.plusJakartaSans(color: Colors.blueGrey)),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido')),
          ],
        ),
      ),
    );
  }
}
