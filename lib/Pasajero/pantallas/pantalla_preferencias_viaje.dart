import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../modelos/preferencias_viaje.dart';
import '../servicios/servicio_preferencias.dart';

class PantallaPreferenciasViaje extends StatefulWidget {
  const PantallaPreferenciasViaje({super.key});

  @override
  State<PantallaPreferenciasViaje> createState() =>
      _PantallaPreferenciasViajeState();
}

class _PantallaPreferenciasViajeState extends State<PantallaPreferenciasViaje> {
  bool _cargando = true;
  late PreferenciasViaje _prefs;

  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
  }

  Future<void> _cargarPreferencias() async {
    final prefsLocales = await ServicioPreferencias.obtenerPreferencias();
    setState(() {
      _prefs = prefsLocales;
      _cargando = false;
    });
  }

  void _guardarCambios() async {
    await ServicioPreferencias.guardarPreferencias(_prefs);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Preferencias guardadas exitosamente',
            style: GoogleFonts.plusJakartaSans(),
          ),
          backgroundColor: Colors.teal.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _actualizarPrefs(PreferenciasViaje nuevasPrefs) {
    setState(() {
      _prefs = nuevasPrefs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        title: Text(
          'Preferencias de Viaje',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personaliza tu experiencia',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Estas opciones se enviarán al conductor cuando acepten tu viaje. Nos ayuda a brindarte el mejor servicio.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // —— AMBIENTE ——
                  _SeccionTitulo(
                      titulo: 'Ambiente y Clima', icono: Icons.thermostat),
                  _CardOpciones(children: [
                    _SwitchListTileAct(
                      titulo: 'Aire Acondicionado',
                      subtitulo: 'Mantener el A/C encendido durante el viaje',
                      valor: _prefs.aireAcondicionado,
                      onChanged: (val) => _actualizarPrefs(
                          _prefs.copyWith(aireAcondicionado: val)),
                    ),
                    if (_prefs.aireAcondicionado)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Temperatura deseada: ${_prefs.temperatura.toInt()}°C',
                              style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500),
                            ),
                            Slider(
                              value: _prefs.temperatura,
                              min: 16,
                              max: 28,
                              divisions: 12,
                              activeColor: Colors.teal,
                              inactiveColor: Colors.white,
                              label: '${_prefs.temperatura.toInt()}°C',
                              onChanged: (val) => _actualizarPrefs(
                                  _prefs.copyWith(temperatura: val)),
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: 1),
                    _SwitchListTileAct(
                      titulo: 'Ventanas abiertas',
                      subtitulo: 'Prefiero viajar con las ventanas abajo',
                      valor: _prefs.ventanasAbiertas,
                      onChanged: (val) => _actualizarPrefs(
                          _prefs.copyWith(ventanasAbiertas: val)),
                    ),
                  ]),

                  // —— MÚSICA ——
                  const SizedBox(height: 24),
                  _SeccionTitulo(titulo: 'Música', icono: Icons.music_note),
                  _CardOpciones(children: [
                    _SwitchListTileAct(
                      titulo: 'Escuchar música',
                      subtitulo: 'Permitir música durante el trayecto',
                      valor: _prefs.musicaHabilitada,
                      onChanged: (val) {
                        _actualizarPrefs(_prefs.copyWith(
                          musicaHabilitada: val,
                          modoSilencio: val ? false : _prefs.modoSilencio,
                        ));
                      },
                    ),
                    if (_prefs.musicaHabilitada) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Género musical preferido',
                              style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _prefs.generoMusical ??
                                      PreferenciasViaje.generosMusicales.first,
                                  items: PreferenciasViaje.generosMusicales
                                      .map((e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val ==
                                        PreferenciasViaje
                                            .generosMusicales.first) {
                                      _actualizarPrefs(
                                          _prefs.copyWith(generoMusical: null));
                                    } else {
                                      _actualizarPrefs(
                                          _prefs.copyWith(generoMusical: val));
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]
                  ]),

                  // —— CONVERSACIÓN ——
                  const SizedBox(height: 24),
                  _SeccionTitulo(titulo: 'Interacción', icono: Icons.forum),
                  _CardOpciones(children: [
                    _SwitchListTileAct(
                      titulo: 'Viaje en silencio',
                      subtitulo:
                          'Prefiero un viaje tranquilo y sin mucha charla',
                      valor: _prefs.modoSilencio,
                      onChanged: (val) {
                        _actualizarPrefs(_prefs.copyWith(
                          modoSilencio: val,
                          conversacionHabilitada: !val,
                        ));
                      },
                    ),
                  ]),

                  // —— EXTRA ——
                  const SizedBox(height: 24),
                  _SeccionTitulo(
                      titulo: 'Extras del Vehículo',
                      icono: Icons.airline_seat_recline_normal),
                  _CardOpciones(children: [
                    _SwitchListTileAct(
                      titulo: 'Asiento trasero',
                      subtitulo: 'Prefiero viajar en la parte posterior',
                      valor: _prefs.asientoTrasero,
                      onChanged: (val) => _actualizarPrefs(
                          _prefs.copyWith(asientoTrasero: val)),
                    ),
                  ]),

                  const SizedBox(height: 48),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _guardarCambios,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Guardar Preferencias',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

class _SeccionTitulo extends StatelessWidget {
  final String titulo;
  final IconData icono;
  const _SeccionTitulo({required this.titulo, required this.icono});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icono, color: Colors.teal, size: 20),
          const SizedBox(width: 8),
          Text(
            titulo,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.teal.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardOpciones extends StatelessWidget {
  final List<Widget> children;
  const _CardOpciones({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SwitchListTileAct extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final bool valor;
  final ValueChanged<bool> onChanged;

  const _SwitchListTileAct({
    required this.titulo,
    required this.subtitulo,
    required this.valor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      title: Text(
        titulo,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w500,
          fontSize: 15,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitulo,
        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade500),
      ),
      value: valor,
      activeColor: Colors.teal,
      onChanged: onChanged,
    );
  }
}
