import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/contratos_vinculados_service.dart';
import '../../services/supervision_service.dart';
import '../../tema/cristal.dart';
import '../gestion_contractual/estilo_contractual.dart';
import '../portal_contratista_invitado_screen.dart';
import '../supervision/bandeja_supervision_screen.dart';
import '../supervision/componentes_supervision.dart';
import '../supervision/plantilla_informe_screen.dart';

enum _Subrol { supervisor, contratista }

/// Sección del rol Supervisión de contratos. Tiene dos subroles:
/// - Supervisor: los contratos donde la entidad lo designó como supervisor
///   (o responsable de una etapa); configura y aprueba los informes.
/// - Contratista (gratis): vincula sus contratos con el enlace de la
///   entidad, sube sus documentos y presenta sus informes.
///
/// El equipo jurídico crea y organiza los contratos (y designa al
/// supervisor), pero no los supervisa.
class SupervisionContratosSection extends StatefulWidget {
  const SupervisionContratosSection({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<SupervisionContratosSection> createState() =>
      _SupervisionContratosSectionState();
}

class _SupervisionContratosSectionState
    extends State<SupervisionContratosSection> {
  _Subrol? _elegido;

  bool get _esSupervisor => AuthService.hasActiveRole('supervisor_contratos');
  bool get _esContratista => AuthService.hasActiveRole('contratista');

  _Subrol get _subrol {
    final elegido = _elegido;
    if (elegido == _Subrol.supervisor && _esSupervisor) return elegido!;
    if (elegido == _Subrol.contratista && _esContratista) return elegido!;
    return _esSupervisor ? _Subrol.supervisor : _Subrol.contratista;
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 768;
    final subrol = _subrol;
    final ambos = _esSupervisor && _esContratista;
    return ColoredBox(
      color: Cristal.vidrioSuave,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              mobile ? 16 : 40,
              mobile ? 18 : 26,
              mobile ? 16 : 40,
              0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Supervisión de contratos',
                              style: EstiloContractual.titulo.copyWith(
                                fontSize: mobile ? 26 : 32,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              subrol == _Subrol.supervisor
                                  ? 'Los contratos de prestación de servicios que te designaron: configura sus informes, revísalos y apruébalos o devuélvelos.'
                                  : 'Tus contratos de prestación de servicios: sube sus documentos y presenta tus informes de ejecución.',
                              style: EstiloContractual.subtitulo,
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (ambos)
                            SegmentedButton<_Subrol>(
                              segments: const [
                                ButtonSegment(
                                  value: _Subrol.supervisor,
                                  icon: Icon(
                                    Icons.fact_check_outlined,
                                    size: 18,
                                  ),
                                  label: Text('Supervisor'),
                                ),
                                ButtonSegment(
                                  value: _Subrol.contratista,
                                  icon: Icon(Icons.badge_outlined, size: 18),
                                  label: Text('Contratista'),
                                ),
                              ],
                              selected: {subrol},
                              showSelectedIcon: false,
                              onSelectionChanged: (s) =>
                                  setState(() => _elegido = s.first),
                            ),
                          if (subrol == _Subrol.supervisor)
                            OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const PlantillaInformeScreen(entidad: ''),
                                ),
                              ),
                              style: EstiloContractual.botonSecundario(),
                              icon: const Icon(Icons.tune_rounded, size: 18),
                              label: const Text(
                                'Mi plantilla',
                                style: EstiloContractual.etiquetaBoton,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: subrol == _Subrol.supervisor
                ? const _VistaSupervisor()
                : const _VistaContratista(),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Supervisor
// =============================================================================

class _VistaSupervisor extends StatefulWidget {
  const _VistaSupervisor();

  @override
  State<_VistaSupervisor> createState() => _VistaSupervisorState();
}

class _VistaSupervisorState extends State<_VistaSupervisor> {
  late Stream<List<ContratoSupervisado>> _contratos =
      SupervisionService.escucharMisContratos();
  bool _revisando = false;

  bool get _correoVerificado =>
      FirebaseAuth.instance.currentUser?.emailVerified ?? false;

  /// Después de verificar el correo hay que renovar el token: las reglas de
  /// Firestore leen `email_verified` del token, no del perfil.
  Future<void> _yaVerifique() async {
    setState(() => _revisando = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _revisando = false;
      _contratos = SupervisionService.escucharMisContratos();
    });
    if (!_correoVerificado) {
      _aviso(
        'Tu correo aún no aparece verificado. Abre el enlace que te enviamos y vuelve a intentarlo.',
      );
    }
  }

  Future<void> _reenviar() async {
    try {
      await AuthService.reenviarVerificacionCorreo();
      _aviso(
        'Te enviamos el correo de verificación a ${SupervisionService.emailActual}.',
      );
    } catch (e) {
      _aviso('$e');
    }
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(texto)),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (!_correoVerificado) {
      return _Lienzo(
        children: [
          TarjetaSupervision(
            titulo: 'Verifica tu correo para ver tus contratos',
            subtitulo:
                'La entidad te designa como supervisor con tu correo. Para que nadie más pueda usarlo, '
                'la app te muestra los contratos solo cuando lo verificas.',
            icono: Icons.mark_email_unread_outlined,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _revisando ? null : _yaVerifique,
                    style: EstiloContractual.botonPrincipal(),
                    icon: _revisando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text(
                      'Ya lo verifiqué',
                      style: EstiloContractual.etiquetaBoton,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _reenviar,
                    style: EstiloContractual.botonSecundario(),
                    icon: const Icon(Icons.forward_to_inbox_outlined, size: 18),
                    label: const Text(
                      'Reenviar el correo',
                      style: EstiloContractual.etiquetaBoton,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }
    return StreamBuilder<List<ContratoSupervisado>>(
      stream: _contratos,
      builder: (context, snap) {
        if (snap.hasError) {
          final permisos =
              snap.error is FirebaseException &&
              (snap.error as FirebaseException).code == 'permission-denied';
          return _Lienzo(
            children: [
              TarjetaSupervision(
                titulo: 'No fue posible cargar tus contratos',
                icono: Icons.cloud_off_rounded,
                children: [
                  Text(
                    permisos
                        ? 'El servidor no dio permiso. Si acabas de actualizar la app, publica de nuevo las reglas de Firestore.'
                        : 'Revisa tu conexión e intenta de nuevo.',
                    style: TextStyle(color: Cristal.textoMedio, height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(
                        () => _contratos =
                            SupervisionService.escucharMisContratos(),
                      ),
                      style: EstiloContractual.botonSecundario(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text(
                        'Reintentar',
                        style: EstiloContractual.etiquetaBoton,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final contratos = snap.data!;
        final expedientes = [for (final c in contratos) c.expediente];
        return BandejaSupervisionScreen(
          // La bandeja escucha los contratos que recibe al crearse.
          key: ValueKey(expedientes.map((e) => e.tokenInvitado).join(',')),
          expedientes: expedientes,
          incrustada: true,
        );
      },
    );
  }
}

// =============================================================================
// Contratista
// =============================================================================

class _VistaContratista extends StatefulWidget {
  const _VistaContratista();

  @override
  State<_VistaContratista> createState() => _VistaContratistaState();
}

class _VistaContratistaState extends State<_VistaContratista> {
  final TextEditingController _enlace = TextEditingController();
  late final Stream<List<ContratoVinculado>> _contratos =
      ContratosVinculadosService.escuchar();
  String? _error;

  @override
  void dispose() {
    _enlace.dispose();
    super.dispose();
  }

  void _vincular() {
    final token = ContratosVinculadosService.tokenDesdeTexto(_enlace.text);
    if (token.isEmpty) {
      setState(
        () => _error = 'Pega el enlace completo que te envió el equipo jurídico de la entidad.',
      );
      return;
    }
    setState(() => _error = null);
    _abrir(token);
  }

  Future<void> _abrir(String token) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PortalContratistaInvitadoScreen(
          token: token,
          desdeCuenta: true,
          alIngresar: (exp) {
            _enlace.clear();
            unawaited(
              ContratosVinculadosService.vincular(exp).catchError((_) {
                _aviso(
                  'Entraste al contrato, pero no se pudo guardar en tu cuenta. Revisa tu conexión.',
                );
              }),
            );
          },
        ),
      ),
    );
  }

  Future<void> _quitar(ContratoVinculado c) async {
    try {
      await ContratosVinculadosService.desvincular(c.token);
      _aviso(
        'Quitaste el contrato ${c.numeroContrato} de tu cuenta. Puedes volver a vincularlo con su enlace.',
      );
    } catch (_) {
      _aviso('No fue posible quitarlo. Revisa tu conexión.');
    }
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(texto)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContratoVinculado>>(
      stream: _contratos,
      builder: (context, snap) {
        final contratos = snap.data ?? const <ContratoVinculado>[];
        return _Lienzo(
          children: [
            TarjetaSupervision(
              titulo: contratos.isEmpty
                  ? 'Vincula tu contrato'
                  : 'Vincular otro contrato',
              subtitulo:
                  'Pega el enlace que te envió el equipo jurídico de la entidad. Entras con el nombre y la cédula '
                  'de tu cuenta y el contrato queda guardado aquí.',
              icono: Icons.link_rounded,
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final campo = TextField(
                      controller: _enlace,
                      onSubmitted: (_) => _vincular(),
                      decoration: decoracionCampo('Enlace del contrato')
                          .copyWith(errorText: _error),
                    );
                    final boton = FilledButton.icon(
                      onPressed: _vincular,
                      style: EstiloContractual.botonPrincipal(),
                      icon: const Icon(Icons.add_link_rounded, size: 19),
                      label: const Text(
                        'Vincular',
                        style: EstiloContractual.etiquetaBoton,
                      ),
                    );
                    if (c.maxWidth < 520) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [campo, const SizedBox(height: 10), boton],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: campo),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: boton,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (snap.hasError)
              Text(
                'No fue posible cargar tus contratos. Revisa tu conexión.',
                style: TextStyle(color: Cristal.textoMedio),
              )
            else if (!snap.hasData)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (contratos.isEmpty)
              const _SinContratos()
            else ...[
              Text('Mis contratos', style: EstiloContractual.tituloGrupo),
              const SizedBox(height: 10),
              for (final c in contratos) ...[
                _TarjetaContrato(
                  contrato: c,
                  onAbrir: () => _abrir(c.token),
                  onQuitar: () => _quitar(c),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _SinContratos extends StatelessWidget {
  const _SinContratos();

  @override
  Widget build(BuildContext context) {
    Widget paso(String numero, String texto) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Cristal.vidrioSuave,
              shape: BoxShape.circle,
              border: Border.all(color: Cristal.borde),
            ),
            child: Text(
              numero,
              style: TextStyle(
                color: Cristal.texto,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                color: Cristal.textoMedio,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
    return TarjetaSupervision(
      titulo: 'Así funciona',
      icono: Icons.route_outlined,
      children: [
        paso(
          '1',
          'El equipo jurídico de la entidad crea tu contrato y te envía su enlace.',
        ),
        paso(
          '2',
          'Lo pegas arriba: entras con tu nombre y cédula y queda en tu cuenta.',
        ),
        paso(
          '3',
          'Subes los documentos que pide el contrato y, cada periodo, tu informe de actividades.',
        ),
        paso(
          '4',
          'Tu supervisor lo revisa: si lo devuelve, ves la observación y lo corriges aquí mismo.',
        ),
      ],
    );
  }
}

class _TarjetaContrato extends StatelessWidget {
  const _TarjetaContrato({
    required this.contrato,
    required this.onAbrir,
    required this.onQuitar,
  });

  final ContratoVinculado contrato;
  final VoidCallback onAbrir;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final c = contrato;
    return Container(
      decoration: EstiloContractual.tarjeta(),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onAbrir,
          borderRadius: BorderRadius.circular(16),
          hoverDuration: Cristal.micro,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
            child: Row(
              children: [
                Icon(Icons.description_outlined, color: Cristal.texto),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contrato ${c.numeroContrato}',
                        style: TextStyle(
                          color: Cristal.texto,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (c.objetoContrato.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          c.objetoContrato,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Cristal.textoMedio,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (c.entidadNombre.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          c.entidadNombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Cristal.textoSuave,
                            fontSize: 12.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Más opciones',
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: Cristal.textoMedio,
                  ),
                  onSelected: (_) => onQuitar(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'quitar',
                      child: Text('Quitar de mi cuenta'),
                    ),
                  ],
                ),
                Icon(Icons.chevron_right_rounded, color: Cristal.textoMedio),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fondo con desplazamiento y el mismo ancho que la bandeja.
class _Lienzo extends StatelessWidget {
  const _Lienzo({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 680;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        mobile ? 16 : 40,
        mobile ? 14 : 24,
        mobile ? 16 : 40,
        36,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}
