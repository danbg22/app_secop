import 'package:flutter/material.dart';

import '../../services/juridico_contratacion_service.dart';
import '../../services/supervision_service.dart';
import '../gestion_contractual/estilo_contractual.dart';
import 'componentes_supervision.dart';
import 'plantilla_informe_screen.dart';
import 'revision_supervisor_screen.dart';
import 'supervision_contrato_screen.dart';
import '../../tema/cristal.dart';

/// Bandeja de supervisión del equipo: informes de todos los contratos
/// agrupados por paso, con lo que le toca al usuario primero.
class BandejaSupervisionScreen extends StatefulWidget {
  const BandejaSupervisionScreen({super.key, required this.expedientes});

  final List<ExpedienteContratoPs> expedientes;

  @override
  State<BandejaSupervisionScreen> createState() =>
      _BandejaSupervisionScreenState();
}

enum _Filtro {
  meToca('Me toca'),
  porRevisar('En revisión'),
  porAprobar('Última etapa'),
  devueltos('Devueltos'),
  aprobados('Aprobados'),
  pagados('Pagados');

  const _Filtro(this.etiqueta);
  final String etiqueta;
}

class _BandejaSupervisionScreenState extends State<BandejaSupervisionScreen> {
  late final Stream<List<InformeEnBandeja>> _bandeja =
      SupervisionService.escucharBandeja(widget.expedientes);
  _Filtro _filtro = _Filtro.meToca;
  String _buscar = '';

  bool _meToca(InformeEnBandeja i) => switch (i.informe.estado) {
    EstadoInforme.enRevision => SupervisionService.puedeDecidir(
      i.expediente,
      i.plan,
      i.informe,
    ),
    EstadoInforme.aprobado => SupervisionService.puedeRegistrarPago(
      i.expediente,
    ),
    _ => false,
  };

  bool _pasa(InformeEnBandeja i, _Filtro f) => switch (f) {
    _Filtro.meToca => _meToca(i),
    _Filtro.porRevisar => i.informe.estado == EstadoInforme.enRevision,
    _Filtro.porAprobar =>
      i.informe.estado == EstadoInforme.enRevision &&
          i.informe.etapaActual >= i.plan.etapas.length - 1,
    _Filtro.devueltos => i.informe.estado == EstadoInforme.devuelto,
    _Filtro.aprobados => i.informe.estado == EstadoInforme.aprobado,
    _Filtro.pagados => i.informe.estado == EstadoInforme.pagado,
  };

  static String _norm(String t) => t
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
    return StreamBuilder<List<InformeEnBandeja>>(
      stream: _bandeja,
      builder: (context, snap) {
        final todos = snap.data ?? const <InformeEnBandeja>[];
        final conteo = {
          for (final f in _Filtro.values)
            f: todos.where((i) => _pasa(i, f)).length,
        };
        final q = _norm(_buscar.trim());
        final visibles = todos
            .where((i) => _pasa(i, _filtro))
            .where(
              (i) =>
                  q.isEmpty ||
                  _norm(
                    '${i.expediente.contratistaNombreEsperado} ${i.expediente.numeroContrato} informe ${i.informe.numero}',
                  ).contains(q),
            )
            .toList();
        final email = SupervisionService.emailActual;

        return PantallaContractual(
          anchoMaximo: 1120,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: PildoraVolver(
                etiqueta: 'Equipo jurídico',
                onTap: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Supervisión mensual',
                        style: EstiloContractual.titulo,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'El contratista llena su informe en la app; cada etapa de la entidad lo aprueba o lo devuelve, y al final se registra el pago.',
                        style: EstiloContractual.subtitulo,
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PlantillaInformeScreen(
                        entidad: widget.expedientes.isEmpty
                            ? ''
                            : widget.expedientes.first.entidadNombre,
                      ),
                    ),
                  ),
                  style: EstiloContractual.botonSecundario(),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text(
                    'Plantilla de la entidad',
                    style: EstiloContractual.etiquetaBoton,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, c) {
                final columnas = c.maxWidth >= 860 ? 4 : 2;
                final ancho = (c.maxWidth - 12 * (columnas - 1)) / columnas;
                Widget contador(_Filtro f, IconData icono, Color color) =>
                    SizedBox(
                      width: ancho,
                      child: _Contador(
                        titulo: f.etiqueta,
                        valor: conteo[f] ?? 0,
                        icono: icono,
                        color: color,
                        activo: _filtro == f,
                        onTap: () => setState(() => _filtro = f),
                      ),
                    );
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    contador(
                      _Filtro.meToca,
                      Icons.notifications_active_outlined,
                      Cristal.rojo,
                    ),
                    contador(
                      _Filtro.porRevisar,
                      Icons.fact_check_outlined,
                      Cristal.acentoClaro,
                    ),
                    contador(
                      _Filtro.porAprobar,
                      Icons.verified_user_outlined,
                      const Color(0xFFA78BFA),
                    ),
                    contador(
                      _Filtro.devueltos,
                      Icons.undo_rounded,
                      Cristal.ambar,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(mobile ? 14 : 18),
              decoration: EstiloContractual.tarjeta(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final f in _Filtro.values) ...[
                              ChoiceChip(
                                label: Text(
                                  '${f.etiqueta} (${conteo[f] ?? 0})',
                                ),
                                selected: _filtro == f,
                                showCheckmark: false,
                                onSelected: (_) => setState(() => _filtro = f),
                                selectedColor: Cristal.acento,
                                backgroundColor: Cristal.vidrio,
                                side: const BorderSide(color: Cristal.borde),
                                labelStyle: TextStyle(
                                  color: _filtro == f
                                      ? Cristal.texto
                                      : Cristal.texto,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                                shape: const StadiumBorder(),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(
                        width: mobile ? double.infinity : 260,
                        child: TextField(
                          onChanged: (v) => setState(() => _buscar = v),
                          decoration:
                              decoracionCampo('Buscar contratista o contrato')
                                  .copyWith(
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      size: 18,
                                    ),
                                    isDense: true,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (snap.connectionState == ConnectionState.waiting &&
                      !snap.hasData)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (visibles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.inbox_outlined,
                            size: 36,
                            color: Cristal.textoTenue,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _filtro == _Filtro.meToca
                                ? 'No tienes informes pendientes. ¡Al día!'
                                : 'No hay informes en "${_filtro.etiqueta}".',
                            style: const TextStyle(color: Cristal.textoSuave),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final i in visibles)
                      _FilaInforme(
                        item: i,
                        meToca: _meToca(i),
                        soySupervisor: i.etapa?.esResponsable(email) ?? false,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => RevisionSupervisorScreen(
                              expediente: i.expediente,
                              informeId: i.informe.id,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Contratos(expedientes: widget.expedientes),
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
    required this.activo,
    required this.onTap,
  });

  final String titulo;
  final int valor;
  final IconData icono;
  final Color color;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Cristal.vidrio,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        hoverDuration: Cristal.micro,
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: activo ? color : Cristal.borde,
              width: activo ? 1.8 : 1.3,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$valor',
                      style: const TextStyle(
                        color: Cristal.texto,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: Cristal.textoSuave,
                        fontSize: 12.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaInforme extends StatelessWidget {
  const _FilaInforme({
    required this.item,
    required this.meToca,
    required this.soySupervisor,
    required this.onTap,
  });

  final InformeEnBandeja item;
  final bool meToca;
  final bool soySupervisor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = item.expediente;
    final inf = item.informe;
    final enviado = DateTime.tryParse(inf.enviadoEnIso);
    final dias = enviado == null
        ? null
        : DateTime.now().difference(enviado).inDays;
    final iniciales = e.contratistaNombreEsperado
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    final mobile = MediaQuery.sizeOf(context).width < 680;

    final datos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          e.contratistaNombreEsperado.isEmpty
              ? 'Contratista'
              : e.contratistaNombreEsperado,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Cristal.texto,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          'Contrato ${e.numeroContrato} · informe N.º ${inf.numero}'
          '${item.etapa == null ? '' : ' · ${item.etapa!.nombre}'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Cristal.textoSuave, fontSize: 12.3),
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: meToca ? Cristal.vidrioSuave : Cristal.vidrio,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: meToca ? const Color(0xFFF5C77E) : Cristal.borde,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          hoverDuration: Cristal.micro,
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Cristal.azulVidrio,
                  child: Text(
                    iniciales.isEmpty ? '?' : iniciales,
                    style: const TextStyle(
                      color: Cristal.texto,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: mobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            datos,
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ChipEstadoInforme(inf.estado),
                                Text(
                                  formatoCop(inf.valorCobradoCop),
                                  style: const TextStyle(
                                    color: Cristal.textoMedio,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(flex: 5, child: datos),
                            Expanded(
                              flex: 2,
                              child: Text(
                                formatoCop(inf.valorCobradoCop),
                                style: const TextStyle(
                                  color: Cristal.texto,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ChipEstadoInforme(inf.estado),
                                  if (inf.estado == EstadoInforme.enRevision)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        dias == null || dias == 0
                                            ? 'Enviado hoy'
                                            : 'Enviado hace $dias día${dias == 1 ? '' : 's'}',
                                        style: TextStyle(
                                          color: (dias ?? 0) > 5
                                              ? Cristal.rojo
                                              : Cristal.textoSuave,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
                if (meToca)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: EtiquetaColor(
                      texto:
                          soySupervisor &&
                              inf.estado == EstadoInforme.enRevision
                          ? 'Tu aprobación'
                          : 'Te toca',
                      color: Cristal.ambar,
                      fondo: Cristal.ambarVidrio,
                    ),
                  ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Cristal.textoSuave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Contratos del equipo para abrir o configurar su supervisión.
class _Contratos extends StatefulWidget {
  const _Contratos({required this.expedientes});
  final List<ExpedienteContratoPs> expedientes;

  @override
  State<_Contratos> createState() => _ContratosState();
}

class _ContratosState extends State<_Contratos> {
  // Con pocos contratos se muestran de una vez.
  late bool _abierto = widget.expedientes.length <= 6;

  @override
  Widget build(BuildContext context) {
    if (widget.expedientes.isEmpty) {
      return const TarjetaSupervision(
        titulo: 'Contratos',
        subtitulo:
            'Aún no hay contratos de prestación de servicios en este equipo.',
        icono: Icons.folder_shared_outlined,
        children: [
          Text(
            'Para empezar: vuelve a Equipo jurídico, toca "Nuevo proceso" y elige Prestación de servicios. '
            'Cuando el expediente exista, ábrelo aquí para configurar su supervisión: periodos, obligaciones y quién aprueba. '
            'Después invita al contratista, que llena cada informe desde su portal.',
            style: TextStyle(
              color: Cristal.textoMedio,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      );
    }
    return TarjetaSupervision(
      titulo: 'Contratos',
      subtitulo: 'Abre un contrato para configurar su supervisión o ver todos sus meses.',
      icono: Icons.folder_shared_outlined,
      accion: TextButton(
        onPressed: () => setState(() => _abierto = !_abierto),
        style: TextButton.styleFrom(foregroundColor: Cristal.texto),
        child: Text(_abierto ? 'Ocultar' : 'Ver ${widget.expedientes.length}'),
      ),
      children: [
        if (_abierto)
          for (final e in widget.expedientes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.description_outlined,
                color: Cristal.texto,
              ),
              title: Text(
                e.contratistaNombreEsperado.isEmpty
                    ? 'Contrato ${e.numeroContrato}'
                    : e.contratistaNombreEsperado,
                style: const TextStyle(
                  color: Cristal.texto,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              subtitle: Text(
                'Contrato ${e.numeroContrato}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => SupervisionContratoScreen(expediente: e),
                ),
              ),
            ),
      ],
    );
  }
}
