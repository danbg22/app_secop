import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/consent_service.dart';
import '../services/equipo_juridico_service.dart';
import 'escoger_rol_screen.dart';

/// Autorización de tratamiento de datos para los abogados de un equipo
/// jurídico. Su cuenta la creó el titular del equipo, así que nunca pasaron
/// por la aceptación del registro (Ley 1581 de 2012, Decreto 1377 de 2013):
/// sin aceptarla no se activa el acceso al equipo.
class ConsentimientoEquipoScreen extends StatefulWidget {
  const ConsentimientoEquipoScreen({super.key});

  @override
  State<ConsentimientoEquipoScreen> createState() =>
      _ConsentimientoEquipoScreenState();
}

class _ConsentimientoEquipoScreenState
    extends State<ConsentimientoEquipoScreen> {
  static const Color _navy = Color(0xFF0E2646);
  static const Color _texto = Color(0xFF364F6B);

  bool _acepta = false;
  bool _guardando = false;
  String? _error;

  Future<void> _aceptar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      // AuthGate pasa al panel en cuanto queda registrada la aceptación.
      await EquipoJuridicoService.aceptarPoliticaDatos();
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
    final equipo =
        EquipoJuridicoService.membresia.value?.masterNombre ??
        'El titular de tu equipo';

    return Scaffold(
      backgroundColor: OnboardingUnifiedBackground.bgCream,
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
                      'Bienvenido(a) al equipo jurídico',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _navy,
                        fontSize: mobile ? 25 : 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$equipo te agregó a su equipo en Contrata Legal. Antes de '
                      'empezar necesitamos tu autorización para tratar tus datos personales.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _texto,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Material (no Container con color) para que la casilla
                    // muestre su efecto al tocarla.
                    Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side: const BorderSide(
                          color: Color(0xFFE6ECF5),
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
                                color: _navy,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 300),
                              child: const SingleChildScrollView(
                                child: Text(
                                  ConsentService.textoPolitica,
                                  style: TextStyle(
                                    color: Color(0xFF334155),
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
                              activeColor: _navy,
                              title: const Text(
                                'Autorizo de forma previa, expresa e informada el tratamiento '
                                'de mis datos personales según esta política.',
                                style: TextStyle(color: _navy, fontSize: 13.8),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFFB91C1C),
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
                                  backgroundColor: _navy,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: const Color(
                                    0xFFCBD5E1,
                                  ),
                                  elevation: 0,
                                  shape: const StadiumBorder(),
                                ),
                                child: _guardando
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Aceptar y entrar al equipo',
                                        style: TextStyle(
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
                                  color: Color(0xFF64748B),
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
