import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/acceso_planes.dart';
import '../services/auth_service.dart';
import '../services/payment_service.dart';
import '../tema/cristal.dart';
import '../widgets/ayuda_plataforma.dart';

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
  bool _ocupado = false;
  String? _mensaje;

  RolPaqueteConfig get _plan => PaymentService.obtenerConfiguracionRol(
    widget.rolId ?? AuthService.getPendingRegistrationRoleId(),
  );

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
  });

  String _fecha(DateTime fecha) =>
      '${DateFormat('dd/MM/yyyy · HH:mm').format(fecha.subtract(const Duration(hours: 5)))} (Colombia)';

  Future<void> _cancelar(RenovacionPlan renovacion) async {
    final fecha = renovacion.fecha;
    final decidido = await mostrarDialogoCristal<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar renovación automática'),
        content: Text(
          fecha == null
              ? 'Si el pago en verificación se aprueba, conservarás el periodo pagado y no se programará otro cobro.'
              : 'Conservas el tiempo pagado. Puedes evitar el siguiente cobro si cancelas hasta el ${_fecha(fecha.subtract(const Duration(days: 1)))}. Pasado ese plazo, la cancelación aplica después del cobro en curso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar cancelación'),
          ),
        ],
      ),
    );
    if (!mounted || decidido != true) return;
    await _realizar(() async {
      final resultado = await AccesoPlanes.cancelarRenovacion(_plan.id);
      if (!mounted) return;
      setState(() {
        _mensaje = resultado.cancelaDespues
            ? 'Cancelación programada después del cobro en curso.'
            : 'Renovación automática cancelada. Conservas el tiempo que ya pagaste.';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.authStateVersion,
      builder: (context, _) {
        final estado = AccesoPlanes.estado;
        final administrador = AuthService.isActiveUserAdmin;
        final aprobado =
            administrador || estado?.tieneSuscripcionVigente(_plan.id) == true;
        final renovacion = estado?.renovaciones[_plan.id];
        final finPago = estado?.finPagoMensual(_plan.id);
        const cobroEnLinea = AccesoPlanes.pagosEnLineaDisponibles;
        final conMandato =
            renovacion?.activa == true || renovacion?.pendiente == true;
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
                        Align(
                          alignment: Alignment.centerLeft,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Cristal.doradoVidrio,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Cristal.doradoBorde),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                aprobado
                                    ? Icons.verified_outlined
                                    : Icons.payments_outlined,
                                color: Cristal.dorado,
                                size: 25,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          administrador
                              ? 'Acceso de administrador activo'
                              : (aprobado
                                    ? 'Suscripción activa'
                                    : _plan.nombrePlan),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        if (aprobado &&
                            !administrador &&
                            estado?.tienePagoMensual(_plan.id) == true &&
                            finPago != null) ...[
                          Text(
                            'Tu plan está pagado hasta el ${_fecha(finPago)}.',
                          ),
                          if (!conMandato)
                            const Text(
                              'Cuando termine ese periodo, podrás renovar con el medio de pago que prefieras.',
                            ),
                        ],
                        if (!aprobado) ...[
                          if (estado?.pruebaVencida == true &&
                              estado?.rolPrueba == _plan.id)
                            const Text(
                              'Tus 30 días de prueba terminaron. Suscríbete para volver a usar este plan.',
                            )
                          else if (finPago != null && !conMandato)
                            const Text(
                              'Tu periodo pagado terminó. Renueva para continuar.',
                            ),
                          const SizedBox(height: 12),
                          Text(
                            _plan.precioMensualFormateado,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          if (cobroEnLinea && !conMandato) ...[
                            Text(
                              'Paga un mes con Nequi, Bancolombia, tarjeta u otro medio disponible en Wompi. Tu plan se activa al aprobarse el pago.',
                              style: TextStyle(color: Cristal.textoMedio),
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Cristal.doradoRelleno,
                                foregroundColor: const Color(0xFF0A1424),
                                minimumSize: const Size.fromHeight(50),
                              ),
                              onPressed: _ocupado ? null : _pagar,
                              child: Text(
                                _ocupado ? 'Abriendo Wompi…' : 'Suscribirme',
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Pago procesado por Wompi',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ] else if (!cobroEnLinea) ...[
                            const Text(
                              'Contacta a soporte para consultar la activación de tu plan.',
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => AyudaPlataforma.mostrar(context),
                              child: const Text('Contactar a soporte'),
                            ),
                          ],
                        ],
                        if (conMandato && renovacion != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            renovacion.pendiente
                                ? 'Tu pago está en proceso'
                                : 'Renovación automática activa',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (renovacion.pendiente)
                            const Text(
                              'Tu suscripción se actualizará aquí cuando Wompi responda.',
                            ),
                          if (renovacion.fecha case final fecha?)
                            Text('Próximo cobro: ${_fecha(fecha)}'),
                          if (renovacion.cancelaDespues)
                            const Text(
                              'La renovación se desactiva después del cobro en curso.',
                            )
                          else
                            TextButton(
                              onPressed: _ocupado
                                  ? null
                                  : () => _cancelar(renovacion),
                              child: const Text(
                                'Cancelar renovación automática',
                              ),
                            ),
                        ],
                        if (renovacion?.estado == 'cancelada')
                          const Text('Renovación automática cancelada.'),
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
