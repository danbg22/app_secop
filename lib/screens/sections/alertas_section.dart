import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/seguimiento_service.dart';
import '../../tema/cristal.dart';
import '../../utils/dependencia_contrato.dart';
import '../detalle_screen.dart';
import '../gestion_contractual/estilo_contractual.dart';
import '../perfil_contratista_screen.dart';
import '../perfil_entidad_screen.dart';
import 'entidades_section.dart';

/// Contratos nuevos en SECOP II de las entidades y contratistas que la
/// persona sigue. Se revisan al abrir la app (sin servidor): lo seguido
/// está en su cuenta y se cuenta en Datos Abiertos.
class AlertasSection extends StatefulWidget {
  const AlertasSection({super.key, required this.onIrASeccion});

  /// Lleva a Entidades o Contratistas desde el estado vacío.
  final ValueChanged<int> onIrASeccion;

  @override
  State<AlertasSection> createState() => _AlertasSectionState();
}

class _AlertasSectionState extends State<AlertasSection> {
  @override
  void initState() {
    super.initState();
    // Al entrar se revisa de nuevo (la revisión de inicio puede ser vieja).
    unawaited(SeguimientoService.revisar());
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 768;
    return ColoredBox(
      color: Cristal.vidrioSuave,
      child: ListenableBuilder(
        listenable: SeguimientoService.cambios,
        builder: (context, _) {
          final seguidos = [...SeguimientoService.seguidos]
            ..sort(
              (a, b) => (SeguimientoService.nuevos(b) ?? 0).compareTo(
                SeguimientoService.nuevos(a) ?? 0,
              ),
            );
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              mobile ? 16 : 40,
              mobile ? 18 : 26,
              mobile ? 16 : 40,
              36,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
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
                                'Alertas',
                                style: EstiloContractual.titulo.copyWith(
                                  fontSize: mobile ? 26 : 32,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Contratos nuevos en SECOP II de las entidades y los contratistas que sigues. '
                                'Se revisan cada vez que abres la app; SECOP II publica con hasta un día de retraso.',
                                style: EstiloContractual.subtitulo,
                              ),
                            ],
                          ),
                        ),
                        if (seguidos.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: SeguimientoService.revisando
                                ? null
                                : () => SeguimientoService.revisar(),
                            style: EstiloContractual.botonSecundario(),
                            icon: SeguimientoService.revisando
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(
                              SeguimientoService.revisando
                                  ? 'Revisando…'
                                  : 'Revisar ahora',
                              style: EstiloContractual.etiquetaBoton,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (seguidos.isEmpty)
                      _SinSeguidos(onIrASeccion: widget.onIrASeccion)
                    else
                      for (final s in seguidos) ...[
                        _TarjetaSeguido(key: ValueKey(s.id), seguido: s),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SinSeguidos extends StatelessWidget {
  const _SinSeguidos({required this.onIrASeccion});

  final ValueChanged<int> onIrASeccion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: EstiloContractual.tarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 36,
            color: Cristal.texto,
          ),
          const SizedBox(height: 12),
          Text(
            'Aún no sigues ninguna entidad ni ningún contratista',
            style: TextStyle(
              color: Cristal.texto,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Abre el perfil de una entidad o de un contratista y toca "Seguir". '
            'Cada vez que firme contratos nuevos en SECOP II, aparecerán aquí.',
            style: TextStyle(
              color: Cristal.textoMedio,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => onIrASeccion(3),
                style: EstiloContractual.botonPrincipal(),
                icon: const Icon(Icons.account_balance_outlined, size: 18),
                label: const Text(
                  'Buscar entidades',
                  style: EstiloContractual.etiquetaBoton,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => onIrASeccion(4),
                style: EstiloContractual.botonSecundario(),
                icon: const Icon(Icons.people_outline, size: 18),
                label: const Text(
                  'Buscar contratistas',
                  style: EstiloContractual.etiquetaBoton,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarjetaSeguido extends StatefulWidget {
  const _TarjetaSeguido({super.key, required this.seguido});

  final Seguido seguido;

  @override
  State<_TarjetaSeguido> createState() => _TarjetaSeguidoState();
}

class _TarjetaSeguidoState extends State<_TarjetaSeguido> {
  bool _abierta = false;
  Future<List<Map<String, dynamic>>>? _recientes;

  Seguido get _s => widget.seguido;

  void _alternar() {
    setState(() {
      _abierta = !_abierta;
      _recientes ??= SeguimientoService.recientes(_s);
    });
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(texto)),
      );
  }

  Future<void> _marcarVisto() async {
    try {
      await SeguimientoService.marcarVisto(_s);
    } catch (_) {
      _aviso('No fue posible guardar. Revisa tu conexión.');
    }
  }

  Future<void> _dejarDeSeguir() async {
    try {
      await SeguimientoService.dejarDeSeguir(_s.tipo, _s.clave);
      _aviso('Dejaste de seguir a ${_s.nombre}.');
    } catch (_) {
      _aviso('No fue posible guardar. Revisa tu conexión.');
    }
  }

  void _abrirPerfil() {
    final pantalla = _s.tipo == TipoSeguido.entidad
        ? PerfilEntidadScreen(
            entity: EntitySummaryRecord(
              name: _s.nombre,
              nit: _s.clave,
              location: '',
              municipio: '',
              departamento: '',
              category: 'Entidad pública',
              emblemType: EntityEmblemType.alcaldiaCoatOfArms,
              contractsCount: 0,
              contractsFormatted: '',
              amountMillions: 0,
              amountFormatted: '',
              dependenciesCount: 0,
              uniqueContractors: 0,
              secopKeywords: const [],
            ),
          )
        : PerfilContratistaScreen(
            nombreContratista: _s.nombre,
            nit: _s.clave,
            documentoProveedor: _s.clave,
          );
    if (pantalla is PerfilEntidadScreen) {
      PerfilEntidadScreen.abrir(context, pantalla.entity);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => pantalla),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final angosta = MediaQuery.sizeOf(context).width < 600;
    final nuevos = SeguimientoService.nuevos(_s);
    final hayNuevos = (nuevos ?? 0) > 0;
    final estado = nuevos == null
        ? 'Revisando…'
        : nuevos == 0
        ? 'Sin contratos nuevos'
        : nuevos == 1
        ? '1 contrato nuevo'
        : '$nuevos contratos nuevos';
    return Container(
      decoration: EstiloContractual.tarjeta(
        colorBorde: hayNuevos ? Cristal.acentoBorde : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: _alternar,
              borderRadius: BorderRadius.circular(16),
              hoverDuration: Cristal.micro,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: hayNuevos
                            ? Cristal.acentoVidrio
                            : Cristal.vidrioSuave,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _s.tipo == TipoSeguido.entidad
                            ? Icons.account_balance_outlined
                            : Icons.person_outline,
                        color: hayNuevos ? Cristal.acentoClaro : Cristal.texto,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _s.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Cristal.texto,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_s.tipo.etiqueta} · $estado',
                            maxLines: 2,
                            style: TextStyle(
                              color: hayNuevos
                                  ? Cristal.acentoClaro
                                  : Cristal.textoSuave,
                              fontSize: 13,
                              fontWeight: hayNuevos
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                          if (hayNuevos && angosta)
                            TextButton(
                              onPressed: _marcarVisto,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 36),
                                alignment: Alignment.centerLeft,
                              ),
                              child: const Text('Marcar como visto'),
                            ),
                        ],
                      ),
                    ),
                    if (hayNuevos && !angosta)
                      TextButton(
                        onPressed: _marcarVisto,
                        child: const Text('Marcar como visto'),
                      ),
                    PopupMenuButton<String>(
                      tooltip: 'Más opciones',
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: Cristal.textoMedio,
                      ),
                      onSelected: (v) =>
                          v == 'perfil' ? _abrirPerfil() : _dejarDeSeguir(),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'perfil',
                          child: Text('Abrir el perfil'),
                        ),
                        PopupMenuItem(
                          value: 'dejar',
                          child: Text('Dejar de seguir'),
                        ),
                      ],
                    ),
                    Icon(
                      _abierta
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: Cristal.textoMedio,
                    ),
                  ],
                ),
              ),
            ),
            if (_abierta)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _recientes,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final filas = snap.data ?? const [];
                    if (snap.hasError || filas.isEmpty) {
                      return Text(
                        snap.hasError
                            ? 'SECOP II no respondió. Intenta de nuevo en un momento.'
                            : 'No hay contratos firmados desde ${_fecha(_s.desdeIso)}.',
                        style: TextStyle(color: Cristal.textoSuave),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(height: 1, color: Cristal.borde),
                        const SizedBox(height: 10),
                        Text(
                          'Últimos contratos firmados',
                          style: TextStyle(
                            color: Cristal.textoSuave,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final c in filas)
                          _FilaContrato(contrato: c, tipo: _s.tipo),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _fecha(String iso) {
    final p = iso.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
  }
}

class _FilaContrato extends StatelessWidget {
  const _FilaContrato({required this.contrato, required this.tipo});

  final Map<String, dynamic> contrato;
  final TipoSeguido tipo;

  static final _miles = NumberFormat('#,##0', 'es_CO');

  @override
  Widget build(BuildContext context) {
    final objeto =
        '${contrato['objeto_del_contrato'] ?? contrato['descripcion_del_proceso'] ?? ''}'
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    // De una entidad interesa con quién contrató; de un contratista, con qué
    // entidad (y la dependencia, si el objeto la nombra).
    final otraParte = tipo == TipoSeguido.entidad
        ? '${contrato['proveedor_adjudicado'] ?? ''}'
        : [
            '${contrato['nombre_entidad'] ?? ''}',
            ?DependenciaContrato.desde(contrato),
          ].where((t) => t.trim().isNotEmpty).join(' · ');
    final valor = double.tryParse('${contrato['valor_del_contrato'] ?? ''}');
    final firma = '${contrato['fecha_de_firma'] ?? ''}'.split('T').first;
    final p = firma.split('-');
    final fecha = p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : '';
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      hoverDuration: Cristal.micro,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => DetalleContratoScreen(contrato: contrato),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    objeto.isEmpty ? 'Contrato sin objeto publicado' : objeto,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Cristal.texto,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  if (otraParte.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      otraParte,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Cristal.textoSuave,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (valor != null)
                  Text(
                    '\$ ${_miles.format(valor)}',
                    style: TextStyle(
                      color: Cristal.texto,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                if (fecha.isNotEmpty)
                  Text(
                    fecha,
                    style: TextStyle(color: Cristal.textoSuave, fontSize: 12.5),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
