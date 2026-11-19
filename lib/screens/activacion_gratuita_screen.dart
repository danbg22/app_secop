import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/payment_service.dart';
import '../tema/cristal.dart';
import 'escoger_rol_screen.dart';

/// Activa un rol gratuito (el Contratista de Supervisión de contratos) sin
/// pasar por Wompi y entra a la app.
class ActivacionGratuitaScreen extends StatefulWidget {
  const ActivacionGratuitaScreen({super.key, required this.rolId});

  final String rolId;

  @override
  State<ActivacionGratuitaScreen> createState() =>
      _ActivacionGratuitaScreenState();
}

class _ActivacionGratuitaScreenState extends State<ActivacionGratuitaScreen> {
  String? _error;

  RolPaqueteConfig get _rol =>
      PaymentService.obtenerConfiguracionRol(widget.rolId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _activar());
  }

  Future<void> _activar() async {
    setState(() => _error = null);
    try {
      await AuthService.activarRolGratuito(widget.rolId);
      if (!mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _cambiarRol() async {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const EscogerRolScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: OnboardingUnifiedBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(28),
                decoration: Cristal.vidrioDeco(radio: Cristal.radioPanel),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _error == null
                          ? Icons.badge_outlined
                          : Icons.error_outline_rounded,
                      size: 44,
                      color: _error == null ? Cristal.texto : Cristal.rojo,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _error == null
                          ? 'Activando tu rol ${_rol.nombre}…'
                          : 'No se pudo activar el rol',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Cristal.texto,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error ?? 'Es gratis: no pasa por la pasarela de pago. En un momento entras a la app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Cristal.textoMedio,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_error == null)
                      const CircularProgressIndicator()
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton(
                            onPressed: _activar,
                            child: const Text('Reintentar'),
                          ),
                          OutlinedButton(
                            onPressed: _cambiarRol,
                            child: const Text('Elegir otro rol'),
                          ),
                        ],
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
