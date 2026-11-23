import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../services/contratos_vinculados_service.dart';
import '../../services/juridico_contratacion_service.dart';
import '../../services/supervision_service.dart';
import '../../tema/cristal.dart';
import '../gestion_contractual/estilo_contractual.dart';
import '../portal_contratista_invitado_screen.dart';
import '../supervision/bandeja_supervision_screen.dart';
import '../supervision/componentes_supervision.dart';
import '../supervision/informes_contratista_view.dart';
import '../supervision/plantilla_informe_screen.dart';
import '../supervision/registro_supervision.dart';

class SupervisionContratosSection extends StatefulWidget {
  const SupervisionContratosSection({super.key, required this.onLogout});
  final VoidCallback onLogout;
  @override
  State<SupervisionContratosSection> createState() =>
      _SupervisionContratosSectionState();
}

class _SupervisionContratosSectionState
    extends State<SupervisionContratosSection> {
  PerfilSupervision? _elegido;
  bool _verificando = false;

  Future<void> _verificar(bool reenviar) async {
    setState(() => _verificando = true);
    try {
      if (reenviar) {
        await AuthService.reenviarVerificacionCorreo();
      } else {
        await FirebaseAuth.instance.currentUser?.reload();
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
      }
      if (mounted && FirebaseAuth.instance.currentUser?.emailVerified != true) {
        mensajeSupervision(
          context,
          reenviar ? 'Enviamos el correo de verificación.' : 'Abre el enlace de verificación de tu correo y vuelve a intentar.',
        );
      }
    } catch (_) {
      if (mounted) {
        mensajeSupervision(
          context,
          'No pudimos verificar tu correo. Intenta de nuevo.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = PerfilSupervision.values
        .where((r) => AuthService.hasActiveRole(r.rol))
        .toList();
    if (roles.isEmpty) {
      return const Center(
        child: Text('Selecciona un rol de supervisión para entrar.'),
      );
    }
    final rol = roles.contains(_elegido)
        ? _elegido!
        : roles.firstWhere(
            (r) => r.rol == AuthService.getPendingRegistrationRoleId(),
            orElse: () => roles.first,
          );
    final user = FirebaseAuth.instance.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Supervisión de contratos', style: EstiloContractual.titulo),
              if (roles.length > 1)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final r in roles)
                      ChoiceChip(
                        label: Text(r.nombre),
                        selected: r == rol,
                        onSelected: (_) => setState(() => _elegido = r),
                      ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: user == null
              ? const Center(
                  child: Text('Inicia sesión para acceder a tus contratos.'),
                )
              : rol != PerfilSupervision.contratista && !user.emailVerified
              ? _Lienzo(
                  children: [
                    TarjetaSupervision(
                      titulo: 'Verifica tu correo',
                      subtitulo:
                          'Abre el enlace enviado a ${user.email} para entrar con tu identidad verificada.',
                      icono: Icons.mark_email_unread_outlined,
                      children: [
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton(
                              onPressed: _verificando
                                  ? null
                                  : () => _verificar(false),
                              child: const Text('Ya lo verifiqué'),
                            ),
                            OutlinedButton(
                              onPressed: _verificando
                                  ? null
                                  : () => _verificar(true),
                              child: const Text('Reenviar correo'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                )
              : rol == PerfilSupervision.contratista
              ? _Contratista(key: ValueKey(user.uid))
              : _Revision(key: ValueKey('${user.uid}/${rol.name}'), rol: rol),
        ),
      ],
    );
  }
}

class _Revision extends StatefulWidget {
  const _Revision({super.key, required this.rol});
  final PerfilSupervision rol;
  @override
  State<_Revision> createState() => _RevisionState();
}

class _RevisionState extends State<_Revision> {
  late final _perfil = RegistroSupervisionService.perfil();
  late final _designaciones =
      RegistroSupervisionService.designacionesJuridicas();
  late final _contratos = RegistroSupervisionService.contratos(widget.rol);
  late final _anteriores = SupervisionService.escucharMisContratos();

  Widget _bandejaConHistorico() => StreamBuilder(
    stream: _anteriores,
    builder: (context, snap) => Column(
      children: [
        if (snap.hasError)
          const Text('No se pudieron cargar los contratos anteriores.'),
        Expanded(
          child: _bandeja([
            for (final c in snap.data ?? const <ContratoSupervisado>[])
              if (widget.rol == PerfilSupervision.supervisor ||
                  !c.asignacion.esSupervisor(SupervisionService.emailActual))
                c.expediente,
          ]),
        ),
      ],
    ),
  );

  Widget _bandeja([
    List<ExpedienteContratoPs> anteriores = const [],
  ]) => StreamBuilder(
    stream: _contratos,
    builder: (context, snap) {
      if (snap.hasError) {
        return const Center(
          child: Text('No fue posible cargar los contratos de supervisión.'),
        );
      }
      if (!snap.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final todos = [
        ...snap.data!.where((e) => e.vinculacionAprobada),
        ...anteriores,
      ];
      final pendientes = snap.data!.where(
        (e) => e.estadoVinculacion == 'pendiente',
      );
      return BandejaSupervisionScreen(
        key: ValueKey(todos.map((e) => e.id).join(',')),
        expedientes: todos,
        incrustada: true,
        solicitudes: [
          if (widget.rol == PerfilSupervision.supervisor &&
              pendientes.isNotEmpty)
            TarjetaSupervision(
              titulo: 'Solicitudes de vinculación',
              subtitulo: 'Verifica los datos del contrato y confirma quién podrá enviarte informes.',
              icono: Icons.group_add_outlined,
              children: [
                for (final exp in pendientes)
                  _SolicitudVinculacion(key: ValueKey(exp.id), contrato: exp),
              ],
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    if (widget.rol == PerfilSupervision.juridico) {
      return Column(
        children: [
          StreamBuilder(
            stream: _designaciones,
            builder: (context, snap) => Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                snap.hasError
                    ? 'No se pudieron consultar tus designaciones.'
                    : snap.data?.isNotEmpty == true
                    ? 'Jurídico de ${snap.data!.join(' · ')}'
                    : 'Aquí recibirás las etapas asignadas a ${SupervisionService.emailActual}.',
              ),
            ),
          ),
          Expanded(child: _bandejaConHistorico()),
        ],
      );
    }
    return StreamBuilder(
      stream: _perfil,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(
            child: Text('No se pudo cargar el perfil de supervisión.'),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final datos = snap.data;
        if (datos == null) {
          return const _Lienzo(
            children: [RegistroSupervision(esSupervisor: true)],
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                children: [
                  Text(
                    '${datos['entidadNombre']} · NIT ${datos['entidadNit']} · ${datos['dependencia']}',
                  ),
                  _CodigoSupervisor(
                    codigo: (datos['codigoSupervisor'] ?? '').toString(),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => PantallaContractual(
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: PildoraVolver(
                                etiqueta: 'Supervisión',
                                onTap: () => Navigator.pop(ctx),
                              ),
                            ),
                            RegistroSupervision(
                              esSupervisor: true,
                              perfil: datos,
                              alGuardar: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const Text('Mi vinculación y Jurídico'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlantillaInformeScreen(
                          entidad: datos['entidadNombre'],
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.tune),
                    label: const Text('Editar flujo y plantilla'),
                  ),
                ],
              ),
            ),
            Expanded(child: _bandejaConHistorico()),
          ],
        );
      },
    );
  }
}

class _Contratista extends StatefulWidget {
  const _Contratista({super.key});
  @override
  State<_Contratista> createState() => _ContratistaState();
}

class _ContratistaState extends State<_Contratista> {
  late final _contratos = RegistroSupervisionService.contratos(
    PerfilSupervision.contratista,
  );
  late final _anteriores = ContratosVinculadosService.escuchar();
  bool _agregando = false;

  Future<void> _abrirAnterior(String token) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PortalContratistaInvitadoScreen(
          token: token,
          desdeCuenta: true,
          alIngresar: (exp) async {
            try {
              await ContratosVinculadosService.vincular(exp);
            } catch (_) {
              if (mounted) {
                mensajeSupervision(
                  context,
                  'No se pudo guardar el enlace.',
                  error: true,
                );
              }
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: _contratos,
    builder: (context, snap) {
      if (snap.hasError) {
        return const Center(
          child: Text('No fue posible cargar tus contratos.'),
        );
      }
      if (!snap.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return _Lienzo(
        children: [
          if (snap.data!.isEmpty || _agregando)
            RegistroSupervision(
              esSupervisor: false,
              alGuardar: () {
                setState(() => _agregando = false);
                mensajeSupervision(context, 'Solicitud enviada al supervisor.');
              },
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _agregando = true),
                icon: const Icon(Icons.add),
                label: const Text('Registrar otro contrato'),
              ),
            ),
          for (final exp in snap.data!)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: TarjetaSupervision(
                titulo: 'Contrato ${exp.numeroContrato}',
                subtitulo: '${exp.entidadNombre} · ${exp.dependencia}',
                children: [
                  Text(
                    '${exp.objetoContrato}\n${formatoCop(exp.valorContratoCop)} · ${exp.plazoEjecucion} · ${exp.formaPago}\nAprobación SECOP ${exp.aprobacionSecop} · RP ${exp.rp} · CDP ${exp.cdp}',
                  ),
                  if (exp.vinculacionAprobada)
                    InformesContratistaView(
                      key: ValueKey(exp.id),
                      expediente: exp,
                      contratistaNombre: exp.contratistaNombreEsperado,
                    )
                  else if (exp.estadoVinculacion == 'devuelta') ...[
                    Text('Solicitud devuelta. ${exp.observacionVinculacion}'),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<ExpedienteContratoPs>(
                          builder: (_) => PantallaContractual(
                            children: [
                              RegistroSupervision(
                                esSupervisor: false,
                                contrato: exp,
                                reenviar: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Corregir y reenviar'),
                    ),
                  ] else
                    const Text('Pendiente de aprobación del supervisor.'),
                ],
              ),
            ),
          StreamBuilder(
            stream: _anteriores,
            builder: (context, prev) => Column(
              children: [
                for (final c in prev.data ?? const <ContratoVinculado>[])
                  _TarjetaContrato(
                    contrato: c,
                    onAbrir: () => _abrirAnterior(c.token),
                    onQuitar: () async {
                      try {
                        await ContratosVinculadosService.desvincular(c.token);
                      } catch (_) {
                        if (context.mounted) {
                          mensajeSupervision(
                            context,
                            'No se pudo quitar el enlace.',
                          );
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
          ExpansionTile(
            title: const Text('Abrir un contrato anterior con enlace'),
            children: [
              TextField(
                decoration: decoracionCampo('Pega el enlace y pulsa Intro'),
                onSubmitted: (texto) {
                  final token = ContratosVinculadosService.tokenDesdeTexto(
                    texto,
                  );
                  if (token.isEmpty) {
                    mensajeSupervision(
                      context,
                      'El enlace de contrato no es válido.',
                    );
                    return;
                  }
                  _abrirAnterior(token);
                },
              ),
            ],
          ),
        ],
      );
    },
  );
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

class _CodigoSupervisor extends StatefulWidget {
  const _CodigoSupervisor({required this.codigo});

  final String codigo;

  @override
  State<_CodigoSupervisor> createState() => _CodigoSupervisorState();
}

class _CodigoSupervisorState extends State<_CodigoSupervisor> {
  Future<void>? _alta;

  @override
  void initState() {
    super.initState();
    if (widget.codigo.isEmpty) {
      _alta = RegistroSupervisionService.asignarCodigoExistente();
    }
  }

  @override
  Widget build(BuildContext context) {
    final codigo = widget.codigo;
    if (codigo.isNotEmpty) {
      return OutlinedButton.icon(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: codigo));
          if (context.mounted) mensajeSupervision(context, 'Código copiado.');
        },
        icon: const Icon(Icons.copy_outlined),
        label: Text('Mi código: $codigo'),
      );
    }
    return FutureBuilder<void>(
      future: _alta,
      builder: (context, snap) => TextButton(
        onPressed: snap.connectionState == ConnectionState.waiting
            ? null
            : () => setState(() {
                _alta = RegistroSupervisionService.asignarCodigoExistente();
              }),
        child: Text(
          snap.connectionState == ConnectionState.waiting
              ? 'Generando código…'
              : 'Obtener código de supervisor',
        ),
      ),
    );
  }
}

class _SolicitudVinculacion extends StatefulWidget {
  const _SolicitudVinculacion({super.key, required this.contrato});

  final ExpedienteContratoPs contrato;

  @override
  State<_SolicitudVinculacion> createState() => _SolicitudVinculacionState();
}

class _SolicitudVinculacionState extends State<_SolicitudVinculacion> {
  bool _ocupada = false;

  Future<void> _decidir({String? observacion}) async {
    setState(() => _ocupada = true);
    try {
      await RegistroSupervisionService.decidirVinculacion(
        widget.contrato,
        observacion: observacion,
      );
    } on SupervisionException catch (e) {
      if (mounted) mensajeSupervision(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _ocupada = false);
    }
  }

  Future<void> _devolver() async {
    var motivo = '';
    final resultado = await mostrarDialogoCristal<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, actualizar) => AlertDialog(
          title: const Text('Devolver solicitud'),
          content: TextField(
            autofocus: true,
            maxLength: 1000,
            maxLines: 4,
            decoration: decoracionCampo(
              'Datos que debe corregir el contratista',
            ),
            onChanged: (texto) => actualizar(() => motivo = texto.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: motivo.length < 10
                  ? null
                  : () => Navigator.pop(ctx, motivo),
              child: const Text('Devolver solicitud'),
            ),
          ],
        ),
      ),
    );
    if (mounted && resultado != null) await _decidir(observacion: resultado);
  }

  @override
  Widget build(BuildContext context) {
    final exp = widget.contrato;
    return ExpansionTile(
      title: Text('Contrato ${exp.numeroContrato}'),
      subtitle: Text(
        '${exp.contratistaNombreEsperado} · ${exp.contratistaCorreo}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(exp.objetoContrato),
        const SizedBox(height: 8),
        Text(
          '${exp.entidadNombre} · ${exp.dependencia}\n'
          '${formatoCop(exp.valorContratoCop)} · ${exp.plazoEjecucion} · ${exp.formaPago}\n'
          'Aprobación SECOP ${exp.aprobacionSecop} · RP ${exp.rp} · CDP ${exp.cdp}',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _ocupada ? null : () => _decidir(),
              icon: const Icon(Icons.check),
              label: const Text('Aprobar vinculación'),
            ),
            OutlinedButton(
              onPressed: _ocupada ? null : _devolver,
              child: const Text('Devolver solicitud'),
            ),
          ],
        ),
      ],
    );
  }
}
