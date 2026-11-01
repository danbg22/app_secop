import 'package:flutter/material.dart';

import '../services/presupuesto_dependencias_service.dart';

/// Presupuesto asignado y ejecutado por cada dependencia (unidad de
/// contratación de SECOP II) de una entidad. Al tocar una dependencia se
/// consultan sus contratos y pagos.
class PresupuestoDependenciasPanel extends StatefulWidget {
  const PresupuestoDependenciasPanel({
    super.key,
    required this.nit,
    required this.alcance,
    this.anio,
    this.departamento,
    this.cuentaSecop,
  });

  final String nit;
  final int? anio;
  final String? departamento;
  final String? cuentaSecop;

  /// Texto del alcance activo, p. ej. "Cesar, vigencia 2026".
  final String alcance;

  @override
  State<PresupuestoDependenciasPanel> createState() =>
      _PresupuestoDependenciasPanelState();
}

class _PresupuestoDependenciasPanelState
    extends State<PresupuestoDependenciasPanel> {
  static const Color _navy = Color(0xFF1A2B4C);
  static const Color _gris = Color(0xFF64748B);
  static const Color _borde = Color(0xFFE2E8F0);

  List<DependenciaPresupuesto>? _dependencias;
  String? _error;
  String _filtro = '';
  String? _abierta;
  final Map<String, Future<EjecucionDependencia>> _ejecuciones = {};
  int _consulta = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant PresupuestoDependenciasPanel old) {
    super.didUpdateWidget(old);
    if (old.nit != widget.nit ||
        old.anio != widget.anio ||
        old.departamento != widget.departamento ||
        old.cuentaSecop != widget.cuentaSecop) {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    final id = ++_consulta;
    if (widget.nit.length < 8) {
      setState(() {
        _dependencias = const [];
        _error = 'Aún no se conoce el NIT de la entidad en SECOP II.';
      });
      return;
    }
    setState(() {
      _dependencias = null;
      _error = null;
      _abierta = null;
      _ejecuciones.clear();
    });
    try {
      final deps = await PresupuestoDependenciasService.dependencias(
        nit: widget.nit,
        anio: widget.anio,
        departamento: widget.departamento,
        cuentaSecop: widget.cuentaSecop,
      );
      if (!mounted || id != _consulta) return;
      setState(() => _dependencias = deps);
    } catch (e) {
      if (!mounted || id != _consulta) return;
      setState(
        () => _error = e is PresupuestoDependenciasException
            ? e.message
            : 'No fue posible consultar SECOP II. Revisa tu conexión.',
      );
    }
  }

  void _alternar(DependenciaPresupuesto d) {
    setState(() {
      _abierta = _abierta == d.clave ? null : d.clave;
      if (_abierta != null) {
        _ejecuciones.putIfAbsent(
          d.clave,
          () => PresupuestoDependenciasService.ejecucion(
            d,
            nit: widget.nit,
            anio: widget.anio,
          ),
        );
      }
    });
  }

  static String _millones(double cop) {
    final m = (cop / 1e6).round();
    final txt = m.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '\$ $txt M';
  }

  static String _norm(String t) => t
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U');

  @override
  Widget build(BuildContext context) {
    final deps = _dependencias;
    final consulta = _norm(_filtro.trim());
    final visibles = deps == null
        ? const <DependenciaPresupuesto>[]
        : deps
              .where(
                (d) =>
                    consulta.isEmpty ||
                    _norm('${d.nombre} ${d.cuentaSecop}').contains(consulta),
              )
              .toList();
    final maximo = visibles.isEmpty
        ? 1.0
        : visibles.map((d) => d.asignadoCop).reduce((a, b) => a > b ? a : b);
    final totalAsignado = deps?.fold<double>(0, (s, d) => s + d.asignadoCop);
    final mobile = MediaQuery.sizeOf(context).width < 700;
    final variasCuentas =
        widget.cuentaSecop == null &&
        (deps?.map((d) => d.cuentaSecop).toSet().length ?? 0) > 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(mobile ? 16 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Presupuesto por dependencia',
                    style: TextStyle(
                      color: _navy,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    totalAsignado == null
                        ? widget.alcance
                        : '${!variasCuentas && deps!.isNotEmpty && widget.cuentaSecop == null ? '${deps.first.cuentaSecop} · ' : ''}'
                              '${widget.alcance} · ${deps!.length} dependencias · '
                              '${_millones(totalAsignado)} asignados',
                    style: const TextStyle(color: _gris, fontSize: 12.5),
                  ),
                ],
              ),
              SizedBox(
                width: mobile ? double.infinity : 290,
                child: TextField(
                  onChanged: (v) => setState(() => _filtro = v),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Buscar dependencia (ej. despacho, Cesar)…',
                    hintStyle: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _borde),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _borde),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_error != null)
            _Mensaje(
              icono: Icons.cloud_off_rounded,
              texto: _error!,
              accion: TextButton(
                onPressed: _cargar,
                child: const Text('Reintentar'),
              ),
            )
          else if (deps == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (visibles.isEmpty)
            _Mensaje(
              icono: Icons.inbox_outlined,
              texto: deps.isEmpty
                  ? 'SECOP II no registra procesos de esta entidad en el alcance elegido.'
                  : 'Ninguna dependencia coincide con la búsqueda.',
            )
          else
            for (final d in visibles.take(80))
              _FilaDependencia(
                dependencia: d,
                proporcion: maximo <= 0 ? 0 : d.asignadoCop / maximo,
                abierta: _abierta == d.clave,
                ejecucion: _ejecuciones[d.clave],
                mostrarCuenta: variasCuentas,
                onTap: () => _alternar(d),
                onReintentar: () => setState(
                  () => _ejecuciones[d.clave] =
                      PresupuestoDependenciasService.ejecucion(
                        d,
                        nit: widget.nit,
                        anio: widget.anio,
                      ),
                ),
                millones: _millones,
              ),
          if (visibles.length > 80)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Se muestran 80 de ${visibles.length} dependencias. Usa el buscador para encontrar la tuya.',
                style: const TextStyle(color: _gris, fontSize: 12),
              ),
            ),
          const SizedBox(height: 14),
          const Text(
            'Fuente: SECOP II, Datos Abiertos. Las dependencias son las unidades de contratación que la entidad '
            'registra en cada proceso. Asignado: presupuesto oficial de sus procesos, sin cancelados ni borradores. '
            'Contratado y ejecutado: valor y pagos de los contratos de esos procesos, según lo que la entidad '
            'reporta en SECOP II. Los gastos que no pasan por contratación (como la nómina) no aparecen aquí.',
            style: TextStyle(color: _gris, fontSize: 11.5, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _FilaDependencia extends StatelessWidget {
  const _FilaDependencia({
    required this.dependencia,
    required this.proporcion,
    required this.abierta,
    required this.ejecucion,
    required this.mostrarCuenta,
    required this.onTap,
    required this.onReintentar,
    required this.millones,
  });

  final DependenciaPresupuesto dependencia;
  final double proporcion;
  final bool abierta;
  final Future<EjecucionDependencia>? ejecucion;
  final bool mostrarCuenta;
  final VoidCallback onTap;
  final VoidCallback onReintentar;
  final String Function(double) millones;

  static const Color _navy = Color(0xFF1A2B4C);
  static const Color _gris = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final d = dependencia;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: abierta ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: abierta ? const Color(0xFFCBD5E1) : const Color(0xFFEEF2F6),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.nombre,
                            style: const TextStyle(
                              color: _navy,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (mostrarCuenta && d.cuentaSecop.isNotEmpty)
                            Text(
                              d.cuentaSecop,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _gris,
                                fontSize: 11.8,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          millones(d.asignadoCop),
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'asignado · ${d.procesos} procesos',
                          style: const TextStyle(color: _gris, fontSize: 11.5),
                        ),
                      ],
                    ),
                    Icon(
                      abierta
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: _gris,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: proporcion.clamp(0, 1),
                    minHeight: 6,
                    color: const Color(0xFF93C5FD),
                    backgroundColor: const Color(0xFFF1F5F9),
                  ),
                ),
                if (abierta && ejecucion != null) ...[
                  const SizedBox(height: 12),
                  FutureBuilder<EjecucionDependencia>(
                    future: ejecucion,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                snap.error is PresupuestoDependenciasException
                                    ? '${snap.error}'
                                    : 'No fue posible consultar los contratos de esta dependencia.',
                                style: const TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: onReintentar,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        );
                      }
                      if (!snap.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Consultando contratos y pagos en SECOP II…',
                                style: TextStyle(color: _gris, fontSize: 12.5),
                              ),
                            ],
                          ),
                        );
                      }
                      return _DetalleEjecucion(
                        asignado: d.asignadoCop,
                        e: snap.data!,
                        millones: millones,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetalleEjecucion extends StatelessWidget {
  const _DetalleEjecucion({
    required this.asignado,
    required this.e,
    required this.millones,
  });

  final double asignado;
  final EjecucionDependencia e;
  final String Function(double) millones;

  static const Color _navy = Color(0xFF1A2B4C);
  static const Color _gris = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final pctContratado = asignado <= 0
        ? 0
        : (e.contratadoCop / asignado * 100).round();
    final pctEjecutado = e.contratadoCop <= 0
        ? 0
        : (e.pagadoCop / e.contratadoCop * 100).round();

    Widget cifra(
      double ancho,
      String titulo,
      String valor,
      String nota,
      Color color,
    ) => Container(
      width: ancho,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.toUpperCase(),
            style: const TextStyle(
              color: _gris,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(nota, style: const TextStyle(color: _gris, fontSize: 11.5)),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final porFila = c.maxWidth >= 640 ? 4 : 2;
            final ancho = (c.maxWidth - 10 * (porFila - 1)) / porFila;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                cifra(
                  ancho,
                  'Asignado',
                  millones(asignado),
                  'Presupuesto oficial de sus procesos',
                  _navy,
                ),
                cifra(
                  ancho,
                  'Contratado',
                  millones(e.contratadoCop),
                  '${e.contratos} contratos · $pctContratado % de lo asignado',
                  const Color(0xFF1D4ED8),
                ),
                cifra(
                  ancho,
                  'Ejecutado (pagado)',
                  millones(e.pagadoCop),
                  '$pctEjecutado % de lo contratado',
                  const Color(0xFF15803D),
                ),
                cifra(
                  ancho,
                  'Por ejecutar',
                  millones(e.pendienteCop),
                  'Pendiente según SECOP II',
                  const Color(0xFFB45309),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            child: LayoutBuilder(
              builder: (context, c) {
                final base = asignado > 0
                    ? asignado
                    : (e.contratadoCop > 0 ? e.contratadoCop : 1);
                double ancho(double v) =>
                    (v / base).clamp(0.0, 1.0) * c.maxWidth;
                return Stack(
                  children: [
                    Container(color: const Color(0xFFF1F5F9)),
                    Container(
                      width: ancho(e.contratadoCop),
                      color: const Color(0xFFBFDBFE),
                    ),
                    Container(
                      width: ancho(e.pagadoCop),
                      color: const Color(0xFF16A34A),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        if (!e.completa)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Incluye los ${e.procesosConsultados} procesos de mayor valor de ${e.procesosTotales}.',
              style: const TextStyle(color: _gris, fontSize: 11.5),
            ),
          ),
      ],
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.icono, required this.texto, this.accion});

  final IconData icono;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icono, color: const Color(0xFF94A3B8), size: 30),
          const SizedBox(height: 8),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          ?accion,
        ],
      ),
    );
  }
}
