import 'package:flutter/material.dart';

import '../../services/procesos_contratacion_service.dart';
import 'estado_secop.dart';
import 'estilo_contractual.dart';
import 'importar_proceso_screen.dart';
import 'proceso_detalle_screen.dart';
import '../../tema/cristal.dart';

/// Panel de seguimiento de los procesos del equipo en SECOP II: estado de
/// cada uno, novedades desde la última revisión y sincronización.
class SeguimientoSecopScreen extends StatefulWidget {
  const SeguimientoSecopScreen({super.key});

  @override
  State<SeguimientoSecopScreen> createState() => _SeguimientoSecopScreenState();
}

class _SeguimientoSecopScreenState extends State<SeguimientoSecopScreen> {
  late final Stream<List<ProcesoContratacion>> _procesos =
      ProcesosContratacionService.escucharProcesos();
  GrupoEstadoSecop? _filtro;
  bool _soloNovedades = false;
  final Set<String> _sincronizando = {};
  (int, int)? _progresoTodos;

  void _mensaje(String t, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(t),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? const Color(0xFFB91C1C) : Cristal.flotante,
        ),
      );
  }

  Future<void> _sincronizar(ProcesoContratacion p, {bool avisar = true}) async {
    setState(() => _sincronizando.add(p.id));
    try {
      final n = await ProcesosContratacionService.sincronizarConSecop(p);
      if (avisar && mounted) {
        _mensaje(
          n.isEmpty
              ? '${p.numeroProceso}: sin cambios en SECOP II.'
              : '${p.numeroProceso}: ${n.length} novedad${n.length == 1 ? '' : 'es'}.',
        );
      }
    } on ProcesoContratacionException catch (e) {
      if (avisar && mounted) _mensaje(e.message, error: true);
    } catch (_) {
      if (avisar && mounted) {
        _mensaje(
          'No fue posible sincronizar. Revisa tu conexión.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _sincronizando.remove(p.id));
    }
  }

  /// De uno en uno para no saturar Datos Abiertos.
  Future<void> _sincronizarTodos(List<ProcesoContratacion> lista) async {
    final vinculados = lista
        .where((p) => p.idProcesoSecop.isNotEmpty || p.urlSecop.isNotEmpty)
        .toList();
    if (vinculados.isEmpty) return;
    setState(() => _progresoTodos = (0, vinculados.length));
    for (final (i, p) in vinculados.indexed) {
      await _sincronizar(p, avisar: false);
      if (!mounted) return;
      setState(() => _progresoTodos = (i + 1, vinculados.length));
    }
    setState(() => _progresoTodos = null);
    _mensaje('Se actualizaron ${vinculados.length} procesos desde SECOP II.');
  }

  Future<void> _verNovedades(ProcesoContratacion p) async {
    final revisar = await mostrarDialogoCristal<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cristal.flotante,
        title: Text('Novedades en SECOP II · ${p.numeroProceso}'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final n in p.secopNovedades)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.fiber_new_rounded,
                        size: 18,
                        color: Color(0xFFFB923C),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(n, style: const TextStyle(fontSize: 13.5)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: EstiloContractual.botonPrincipal(),
            child: const Text('Marcar como revisadas'),
          ),
        ],
      ),
    );
    if (revisar == true) {
      await ProcesosContratacionService.marcarNovedadesRevisadas(p);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
    return StreamBuilder<List<ProcesoContratacion>>(
      stream: _procesos,
      builder: (context, snap) {
        final todos =
            (snap.data ?? const <ProcesoContratacion>[])
                .where((p) => p.modalidad.id != 'prestacion_servicios')
                .toList()
              ..sort((a, b) {
                final n = b.secopNovedades.length.compareTo(
                  a.secopNovedades.length,
                );
                return n != 0
                    ? n
                    : b.actualizadoEnMs.compareTo(a.actualizadoEnMs);
              });
        final conteo = {
          for (final g in GrupoEstadoSecop.values)
            g: todos.where((p) => GrupoEstadoSecop.de(p.secop) == g).length,
        };
        final novedades = todos
            .where((p) => p.secopNovedades.isNotEmpty)
            .length;
        final visibles = todos
            .where(
              (p) => _filtro == null || GrupoEstadoSecop.de(p.secop) == _filtro,
            )
            .where((p) => !_soloNovedades || p.secopNovedades.isNotEmpty)
            .toList();
        final progreso = _progresoTodos;

        return PantallaContractual(
          anchoMaximo: 1160,
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
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seguimiento en SECOP II',
                        style: EstiloContractual.titulo,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Procesos importados de SECOP II con su estado, documentos y novedades.',
                        style: EstiloContractual.subtitulo,
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: progreso != null || todos.isEmpty
                          ? null
                          : () => _sincronizarTodos(todos),
                      style: EstiloContractual.botonSecundario(),
                      icon: progreso == null
                          ? const Icon(Icons.sync_rounded, size: 19)
                          : const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                      label: Text(
                        progreso == null
                            ? 'Actualizar todos desde SECOP II'
                            : 'Actualizando ${progreso.$1} de ${progreso.$2}…',
                        style: EstiloContractual.etiquetaBoton,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const ImportarProcesoScreen(),
                        ),
                      ),
                      style: EstiloContractual.botonPrincipal(),
                      icon: const Icon(Icons.cloud_download_outlined, size: 19),
                      label: const Text(
                        'Importar proceso',
                        style: EstiloContractual.etiquetaBoton,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FiltroChip(
                    texto: 'Todos (${todos.length})',
                    activo: _filtro == null && !_soloNovedades,
                    color: Cristal.texto,
                    onTap: () => setState(() {
                      _filtro = null;
                      _soloNovedades = false;
                    }),
                  ),
                  _FiltroChip(
                    texto: 'Con novedades ($novedades)',
                    activo: _soloNovedades,
                    color: const Color(0xFFFB923C),
                    icono: Icons.fiber_new_rounded,
                    onTap: () =>
                        setState(() => _soloNovedades = !_soloNovedades),
                  ),
                  for (final g in GrupoEstadoSecop.values)
                    if ((conteo[g] ?? 0) > 0)
                      _FiltroChip(
                        texto: '${g.etiqueta} (${conteo[g]})',
                        activo: _filtro == g,
                        color: g.color,
                        icono: g.icono,
                        onTap: () =>
                            setState(() => _filtro = _filtro == g ? null : g),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snap.hasError)
              const Text('No fue posible cargar los procesos del equipo.')
            else if (todos.isEmpty)
              _Vacio(
                onImportar: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ImportarProcesoScreen(),
                  ),
                ),
              )
            else if (visibles.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(
                  child: Text(
                    'Ningún proceso coincide con el filtro.',
                    style: TextStyle(color: Cristal.textoSuave),
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, c) {
                  final columnas = c.maxWidth >= 900 ? 2 : 1;
                  final ancho = (c.maxWidth - 14 * (columnas - 1)) / columnas;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      for (final p in visibles)
                        SizedBox(
                          width: ancho,
                          child: _TarjetaSeguimiento(
                            proceso: p,
                            sincronizando: _sincronizando.contains(p.id),
                            mobile: mobile,
                            onSincronizar: () => _sincronizar(p),
                            onNovedades: () => _verNovedades(p),
                            onAbrir: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    ProcesoDetalleScreen(procesoId: p.id),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }
}

class _FiltroChip extends StatelessWidget {
  const _FiltroChip({
    required this.texto,
    required this.activo,
    required this.color,
    required this.onTap,
    this.icono,
  });
  final String texto;
  final bool activo;
  final Color color;
  final IconData? icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      avatar: icono == null
          ? null
          : Icon(icono, size: 16, color: activo ? Cristal.texto : color),
      label: Text(texto),
      selected: activo,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: color,
      backgroundColor: Cristal.vidrio,
      side: BorderSide(color: activo ? color : Cristal.borde),
      labelStyle: TextStyle(
        color: activo ? Cristal.texto : Cristal.texto,
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
      shape: const StadiumBorder(),
    ),
  );
}

class _TarjetaSeguimiento extends StatelessWidget {
  const _TarjetaSeguimiento({
    required this.proceso,
    required this.sincronizando,
    required this.mobile,
    required this.onSincronizar,
    required this.onNovedades,
    required this.onAbrir,
  });

  final ProcesoContratacion proceso;
  final bool sincronizando;
  final bool mobile;
  final VoidCallback onSincronizar;
  final VoidCallback onNovedades;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    final p = proceso;
    final s = p.secop;
    final m = p.modalidad;
    final vinculado = p.idProcesoSecop.isNotEmpty || p.urlSecop.isNotEmpty;
    final novedades = p.secopNovedades.length;
    return Container(
      decoration: EstiloContractual.tarjeta(
        colorBorde: novedades > 0 ? Cristal.ambarBorde : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          hoverDuration: Cristal.micro,
          onTap: onAbrir,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChipEstadoSecop(secop: s),
                    EtiquetaColor(
                      texto: m.nombre,
                      color: m.color,
                      fondo: m.fondo,
                      icono: m.icono,
                    ),
                    if (novedades > 0)
                      InkWell(
                        hoverDuration: Cristal.micro,
                        onTap: onNovedades,
                        borderRadius: BorderRadius.circular(12),
                        child: EtiquetaColor(
                          texto:
                              '$novedades novedad${novedades == 1 ? '' : 'es'}',
                          color: const Color(0xFFFB923C),
                          fondo: Cristal.ambarVidrio,
                          icono: Icons.fiber_new_rounded,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  p.numeroProceso,
                  style: const TextStyle(
                    color: Cristal.texto,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  s != null &&
                          s.nombre.isNotEmpty &&
                          s.nombre != p.numeroProceso
                      ? s.nombre
                      : p.objeto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Cristal.textoMedio,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p.entidadNombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Cristal.textoSuave,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    _Mini(
                      Icons.payments_outlined,
                      copMillones(p.presupuestoCop),
                    ),
                    if (s != null)
                      _Mini(
                        Icons.description_outlined,
                        '${s.documentos.length} documentos',
                      ),
                    if (s != null && s.ofertas > 0)
                      _Mini(
                        Icons.inbox_outlined,
                        s.ofertas == 1 ? '1 oferta' : '${s.ofertas} ofertas',
                      ),
                    if (s?.fechas['recepcionOfertas'] != null)
                      _Mini(
                        Icons.event_rounded,
                        'Cierre ${s!.fechas['recepcionOfertas']}',
                      ),
                    if (s != null && s.adjudicado)
                      _Mini(Icons.verified_outlined, s.proveedor),
                  ],
                ),
                if (novedades > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Cristal.ambarVidrio,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      p.secopNovedades.last,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFFB923C),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1, color: Cristal.borde),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      vinculado
                          ? Icons.cloud_done_outlined
                          : Icons.link_off_rounded,
                      size: 16,
                      color: Cristal.textoSuave,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        !vinculado
                            ? 'Sin vincular a SECOP II'
                            : (p.secopSincronizadoEnIso.isEmpty
                                  ? 'Aún no se ha sincronizado'
                                  : 'Sincronizado ${haceCuanto(p.secopSincronizadoEnIso)}'),
                        style: const TextStyle(
                          color: Cristal.textoSuave,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (vinculado)
                      sincronizando
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : TextButton.icon(
                              onPressed: onSincronizar,
                              style: TextButton.styleFrom(
                                foregroundColor: Cristal.texto,
                              ),
                              icon: const Icon(Icons.sync_rounded, size: 18),
                              label: Text(
                                mobile
                                    ? 'Actualizar'
                                    : 'Actualizar estado desde SECOP',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.icono, this.texto);
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icono, size: 15, color: Cristal.textoSuave),
      const SizedBox(width: 5),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(
          texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Cristal.texto,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.onImportar});
  final VoidCallback onImportar;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(32),
    decoration: EstiloContractual.tarjeta(),
    child: Column(
      children: [
        const Icon(
          Icons.cloud_download_outlined,
          size: 42,
          color: Cristal.texto,
        ),
        const SizedBox(height: 10),
        const Text(
          'Aún no hay procesos en seguimiento',
          style: TextStyle(
            color: Cristal.texto,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Importa un proceso de SECOP II con su ID o enlace para seguir su estado y sus documentos.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Cristal.textoMedio),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onImportar,
          style: EstiloContractual.botonPrincipal(),
          icon: const Icon(Icons.cloud_download_outlined, size: 19),
          label: const Text(
            'Importar proceso',
            style: EstiloContractual.etiquetaBoton,
          ),
        ),
      ],
    ),
  );
}
