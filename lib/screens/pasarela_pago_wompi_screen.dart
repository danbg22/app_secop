import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/acceso_planes.dart';
import '../services/auth_service.dart';
import '../services/payment_service.dart';
import '../tema/cristal.dart';

class PasarelaPagoWompiScreen extends StatefulWidget {
  const PasarelaPagoWompiScreen({
    super.key,
    this.rolId,
    this.esFlujoRegistro = true,
  });

  final String? rolId;
  final bool esFlujoRegistro;

  @override
  State<PasarelaPagoWompiScreen> createState() =>
      _PasarelaPagoWompiScreenState();
}

class _PasarelaPagoWompiScreenState extends State<PasarelaPagoWompiScreen> {
  final _identificador = TextEditingController();
  bool _ocupado = false;
  String? _mensaje;

  RolPaqueteConfig get _plan => PaymentService.obtenerConfiguracionRol(
    widget.rolId ?? AuthService.getPendingRegistrationRoleId(),
  );

  @override
  void dispose() {
    _identificador.dispose();
    super.dispose();
  }

  Future<void> _realizar(Future<void> Function() accion) async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _mensaje = null;
    });
    try {
      await accion();
    } on AccesoPlanesException catch (e) {
      if (mounted) setState(() => _mensaje = e.mensaje);
    } catch (_) {
      if (mounted) {
        setState(
          () => _mensaje = 'Hubo un problema con Wompi. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _pagar() => _realizar(() async {
    final url = await AccesoPlanes.iniciarPago(_plan.id);
    if (!mounted) return;
    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: kIsWeb ? '_self' : null,
    )) {
      throw const AccesoPlanesException('No se pudo abrir el sitio de Wompi.');
    }
    if (mounted) {
      setState(() {
        _mensaje = 'Completa el pago en Wompi. Al volver, confirmaremos la transacción.';
      });
    }
  });

  Future<void> _verificar() => _realizar(() async {
    final id = _identificador.text.trim();
    if (id.isEmpty) {
      await AccesoPlanes.refrescar();
      if (mounted) {
        setState(
          () => _mensaje = 'Si el pago aún está pendiente en Wompi, espera unos minutos y vuelve a verificar.',
        );
      }
      return;
    }
    final status = await AccesoPlanes.confirmarPago(id);
    if (!mounted) return;
    setState(() {
      _mensaje = switch (status) {
        'APPROVED' => 'Pago aprobado. Tu suscripción está activa.',
        'PENDING' => 'Wompi aún está procesando el pago.',
        'DECLINED' ||
        'ERROR' ||
        'VOIDED' => 'Wompi indicó que el pago no se completó.',
        _ => 'No encontramos esta transacción para tu cuenta.',
      };
    });
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.authStateVersion,
      builder: (context, _) {
        final estado = AccesoPlanes.estado;
        final administrador = AuthService.isActiveUserAdmin;
        final aprobado =
            administrador || estado?.tieneSuscripcionVigente(_plan.id) == true;
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Suscripción'),
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: AuthService.hasAuthorizedPlatformAccess,
            actions: [
              TextButton(
                onPressed: _ocupado
                    ? null
                    : () async {
                        await AuthService.signOut();
                        if (!context.mounted) return;
                        Navigator.of(context)
                            .pushNamedAndRemoveUntil('/portada', (_) => false);
                      },
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: PanelCristal(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          aprobado
                              ? Icons.verified_outlined
                              : Icons.payments_outlined,
                          color: Cristal.dorado,
                          size: 34,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          administrador
                              ? 'Acceso de administrador activo'
                              : (aprobado
                                    ? 'Suscripción activa'
                                    : _plan.nombrePlan),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        if (!aprobado) ...[
                          if (estado?.pruebaVencida == true &&
                              estado?.rolPrueba == _plan.id)
                            const Text(
                              'Tus 30 días de prueba terminaron. Suscríbete para volver a usar este plan.',
                            ),
                          if (estado?.enPrueba == true &&
                              estado?.rolPrueba == _plan.id)
                            const Text(
                              'Si pagas hoy, el periodo mensual comienza cuando Wompi confirme el pago.',
                            ),
                          const SizedBox(height: 12),
                          Text(
                            _plan.precioMensualFormateado,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Pagas en Wompi. La renovación es manual.',
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _ocupado ? null : _pagar,
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Pagar en Wompi'),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _identificador,
                            decoration: const InputDecoration(
                              labelText: 'ID de la transacción (opcional)',
                            ),
                            onSubmitted: (_) => _verificar(),
                          ),
                          TextButton(
                            onPressed: _ocupado ? null : _verificar,
                            child: const Text('Verificar un pago'),
                          ),
                        ],
                        if (_ocupado) const LinearProgressIndicator(),
                        if (_mensaje case final mensaje?)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              mensaje,
                              style: TextStyle(color: Cristal.textoMedio),
                            ),
                          ),
                        if (aprobado ||
                            (!widget.esFlujoRegistro &&
                                AuthService.hasAuthorizedPlatformAccess))
                          TextButton(
                            onPressed: () => Navigator.of(context)
                                .pushNamedAndRemoveUntil('/home', (_) => false),
                            child: Text(
                              aprobado
                                  ? 'Entrar a la plataforma'
                                  : 'Volver a la plataforma',
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
      },
    );
  }
}
