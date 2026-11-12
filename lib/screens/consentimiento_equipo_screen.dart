import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/consent_service.dart';
import '../services/equipo_juridico_service.dart';
import 'escoger_rol_screen.dart';
import '../tema/cristal.dart';

/// Autorización de tratamiento de datos para los abogados de un equipo
/// jurídico. Su cuenta la creó el titular del equipo, así que nunca pasaron
/// por la aceptación del registro (Ley 1581 de 2012, Decreto 1377 de 2013):
/// sin aceptarla no se activa el acceso al equipo.
class ConsentimientoEquipoScreen extends StatelessWidget {
  const ConsentimientoEquipoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final equipo =
        EquipoJuridicoService.membresia.value?.masterNombre ??
        'El titular de tu equipo';
    return ConsentimientoDatosScreen(
      titulo: 'Bienvenido(a) al equipo jurídico',
      mensaje:
          '$equipo te agregó a su equipo en Contrata Legal. Antes de '
          'empezar necesitamos tu autorización para tratar tus datos personales.',
      textoBoton: 'Aceptar y entrar al equipo',
      alAceptar: EquipoJuridicoService.aceptarPoliticaDatos,
    );
  }
}

/// Autorización de tratamiento de datos de quien ya inició sesión y no la
/// ha dado para la versión vigente de la política: cuentas creadas con
/// Google o Apple, o antes de un cambio de la política.
class ConsentimientoUsuarioScreen extends StatelessWidget {
  const ConsentimientoUsuarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ConsentimientoDatosScreen(
      titulo: 'Tu autorización de datos personales',
      mensaje:
          'Antes de seguir usando Contrata Legal necesitamos tu autorización '
          'para tratar tus datos personales (Ley 1581 de 2012). Lee la '
          'política: explica qué datos tratamos, para qué y cómo ejercer tus '
          'derechos.',
      textoBoton: 'Aceptar y continuar',
      alAceptar: ConsentService.aceptarUsuarioActual,
    );
  }
}

/// Pantalla de autorización: la política vigente, la casilla y el registro
/// de la evidencia con [alAceptar]. AuthGate pasa al panel en cuanto queda
/// registrada.
class ConsentimientoDatosScreen extends StatefulWidget {
  const ConsentimientoDatosScreen({
    super.key,
    required this.titulo,
    required this.mensaje,
    required this.textoBoton,
    required this.alAceptar,
  });

  final String titulo;
  final String mensaje;
  final String textoBoton;
  final Future<void> Function() alAceptar;

  @override
  State<ConsentimientoDatosScreen> createState() =>
      _ConsentimientoDatosScreenState();
}

class _ConsentimientoDatosScreenState extends State<ConsentimientoDatosScreen> {
  bool _acepta = false;
  bool _guardando = false;
  String? _error;

  Future<void> _aceptar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.alAceptar();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No fue posible registrar tu autorización. Revisa tu conexión e inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _salir() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil('/portada', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 640;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: OnboardingUnifiedBackground(
        showScenicPhoto: false,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: mobile ? 16 : 32,
              vertical: mobile ? 18 : 32,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: ContrataLegalHdLogo(height: 52)),
                    const SizedBox(height: 26),
                    Text(
                      widget.titulo,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Cristal.texto,
                        fontSize: mobile ? 25 : 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.mensaje,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Cristal.textoMedio,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Material (no Container con color) para que la casilla
                    // muestre su efecto al tocarla.
                    Material(
                      color: Cristal.vidrio,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side: const BorderSide(
                          color: Cristal.borde,
                          width: 1.3,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Política de privacidad y tratamiento de datos personales',
                              style: TextStyle(
                                color: Cristal.texto,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 340),
                              child: const SingleChildScrollView(
                                child: Text(
                                  ConsentService.textoPolitica,
                                  style: TextStyle(
                                    color: Cristal.textoCuerpo,
                                    fontSize: 13.5,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const Divider(height: 28),
                            CheckboxListTile(
                              value: _acepta,
                              onChanged: _guardando
                                  ? null
                                  : (v) => setState(() => _acepta = v ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              activeColor: Cristal.acento,
                              title: const Text(
                                ConsentService.textoCasilla,
                                style: TextStyle(
                                  color: Cristal.texto,
                                  fontSize: 13.8,
                                ),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: Cristal.rojo,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _acepta && !_guardando
                                    ? _aceptar
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Cristal.acento,
                                  foregroundColor: Cristal.texto,
                                  disabledBackgroundColor: Cristal.vidrioFuerte,
                                  elevation: 0,
                                  shape: const StadiumBorder(),
                                ),
                                child: _guardando
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Cristal.texto,
                                        ),
                                      )
                                    : Text(
                                        widget.textoBoton,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _guardando ? null : _salir,
                              child: const Text(
                                'No acepto · cerrar sesión',
                                style: TextStyle(
                                  color: Cristal.textoSuave,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
