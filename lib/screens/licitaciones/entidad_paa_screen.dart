import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/estructura_paa.dart';
import '../../services/paa_service.dart';
import '../../services/verificacion_paa_service.dart';
import '../gestion_contractual/estilo_contractual.dart';
import 'prediccion_paa_screen.dart';
import 'verificacion_widgets.dart';

/// Una entidad con todas las cuentas que publican PAA, ordenadas como está
/// organizada (nivel central y regionales). Cada una abre su proyección.
class EntidadPaaScreen extends StatefulWidget {
  const EntidadPaaScreen({
    super.key,
    required this.nit,
    this.familia,
    required this.nombre,
    required this.anio,
  });

  final String nit;

  /// Entidad cuyas seccionales tienen NIT propio (se buscan por nombre).
  final FamiliaPaa? familia;
  final String nombre;
  final int anio;

  @override
  State<EntidadPaaScreen> createState() => _EntidadPaaScreenState();
}

class _EntidadPaaScreenState extends State<EntidadPaaScreen> {
  static const _mesesCortos = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  List<GrupoPaa>? _grupos;
  int _cuentas = 0;
  String? _error;
  Map<String, ({int compras, double total})>? _totales;
  String? _errorTotales;
  final Set<String> _abiertos = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _error = null;
      _grupos = null;
    });
    try {
      final familia = widget.familia;
      final cuentas = familia == null
          ? await PaaService.cuentasDe(widget.nit, widget.anio)
          : [
              for (final c in await PaaService.cuentasPorNombre(
                familia.patrones,
                widget.anio,
              ))
                // Confirma que la frase es de la familia y no casual.
                if (EstructuraPaa.familiaDe(c.plan.nombreEntidad) == familia) c,
            ];
      if (!mounted) return;
      final grupos = EstructuraPaa.agrupar(
        widget.nit,
        cuentas,
        familia: familia,
      );
      setState(() {
        _grupos = grupos;
        _cuentas = cuentas.length;
      });
      // Una sola cuenta: directo a su proyección.
      if (cuentas.length == 1) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PrediccionPaaScreen(
              plan: cuentas.single.plan,
              titulo: grupos.first.nodos.first.nombre,
              entidad: widget.nombre,
            ),
          ),
        );
        return;
      }
      _cargarTotales(cuentas);
      _cargarEjecucion(cuentas);
      _cargarAbiertos(grupos);
    } on PaaException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  StreamSubscription<(String, ({int compras, double total}))>? _sub;
  int _pendientes = 0;

  // Contratado en el año por cuenta (código), para lo que falta por contratar.
  StreamSubscription<(String, EjecucionPlan)>? _subEj;
  Map<String, EjecucionPlan> _contratado = {};
  int _pendientesEj = 0;
  bool _errorEj = false;
  bool _porContratar = false;

  // Procesos abiertos hoy en todas las cuentas.
  StreamSubscription<(String, List<ProcesoSecop>)>? _subAb;
  List<ProcesoSecop> _abiertosHoy = [];
  Map<String, String> _cuentaDe = {};
  int _pendientesAb = 0;
  bool _errorAb = false;

  void _cargarAbiertos(List<GrupoPaa> grupos) {
    _subAb?.cancel();
    final nombre = <String, String>{
      for (final g in grupos)
        for (final n in g.nodos)
          n.cuenta.plan.codigoEntidad: g.nodos.length == 1 && !g.esCentral
              ? g.titulo
              : (g.esCentral ? n.nombre : '${g.titulo} · ${n.nombre}'),
    };
    setState(() {
      _abiertosHoy = [];
      _cuentaDe = {};
      _pendientesAb = nombre.length;
      _errorAb = false;
    });
    _subAb = VerificacionPaaService.abiertosDe(nombre.keys.toList()).listen(
      (r) {
        if (!mounted) return;
        setState(() {
          _abiertosHoy = [..._abiertosHoy, ...r.$2];
          _cuentaDe = {
            ..._cuentaDe,
            for (final p in r.$2) p.referencia: nombre[r.$1] ?? '',
          };
          _pendientesAb--;
        });
      },
      onError: (Object _) {
        if (mounted) {
          setState(() {
            _pendientesAb--;
            _errorAb = true;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _subEj?.cancel();
    _subAb?.cancel();
    super.dispose();
  }

  void _cargarEjecucion(List<CuentaPaa> cuentas) {
    _subEj?.cancel();
    final codigos = {for (final c in cuentas) c.plan.codigoEntidad}.toList();
    setState(() {
      _contratado = {};
      _pendientesEj = codigos.length;
      _errorEj = false;
    });
    _subEj = VerificacionPaaService.ejecucionDe(codigos, widget.anio).listen(
      (r) {
        if (!mounted) return;
        setState(() {
          _contratado = {..._contratado, r.$1: r.$2};
          _pendientesEj--;
        });
      },
      onError: (Object _) {
        if (mounted) {
          setState(() {
            _pendientesEj--;
            _errorEj = true;
          });
        }
      },
    );
  }

  /// Contratado en el año por las cuentas del grupo (null si falta alguna).
  double? _contratadoDe(GrupoPaa g) {
    var s = 0.0;
    for (final n in g.nodos) {
      final e = _contratado[n.cuenta.plan.codigoEntidad];
      if (e == null) return null;
      s += e.contratadoCop;
    }
    return s;
  }

  /// Proyectado menos contratado (aprox.); null mientras falten datos.
  double? _faltaDe(GrupoPaa g) {
    final t = g.total(_totales), c = _contratadoDe(g);
    if (t == null || c == null) return null;
    return (t - c).clamp(0, double.infinity).toDouble();
  }

  void _cargarTotales(List<CuentaPaa> cuentas) {
    _sub?.cancel();
    setState(() {
      _errorTotales = null;
      _totales = {};
      _pendientes = cuentas.length;
    });
    _sub = PaaService.totalesDe(cuentas).listen(
      (r) {
        if (!mounted) return;
        setState(() {
          _totales = {...?_totales, r.$1: r.$2};
          _pendientes--;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _pendientes--;
          _errorTotales = e is PaaException
              ? e.message
              : 'No fue posible calcular algunos valores.';
        });
      },
    );
  }

  static String _millones(double v) {
    final m = v / 1e6;
    if (m.abs() < 10) {
      return '\$ ${m.toStringAsFixed(1).replaceAll('.', ',')} M';
    }
    final t = m.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '\$ $t M';
  }

  String _fecha(String iso) {
    final d = DateTime.tryParse(iso.replaceFirst(' ', 'T').split('.').first);
    if (d == null) return '';
    return '${d.day} ${_mesesCortos[d.month - 1]} ${d.year}';
  }

  void _abrir(NodoPaa n) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PrediccionPaaScreen(
          plan: n.cuenta.plan,
          titulo: n.nombre,
          entidad: widget.nombre,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grupos = _grupos;
    // Con alguna cuenta fallida el total quedaría incompleto: no se muestra.
    final totalEntidad =
        _pendientes > 0 || _totales == null || _errorTotales != null
        ? null
        : _totales!.values.fold<double>(0, (s, t) => s + t.total);
    final contratadoEntidad = _pendientesEj > 0 || _errorEj
        ? null
        : _contratado.values.fold<double>(0, (s, e) => s + e.contratadoCop);
    final centrales = grupos?.where((g) => g.esCentral).toList() ?? const [];
    final regionales = [...?grupos?.where((g) => !g.esCentral)];
    if (_porContratar) {
      // Donde queda más por contratar primero; sin datos aún, al final.
      regionales.sort(
        (a, b) => (_faltaDe(b) ?? -1).compareTo(_faltaDe(a) ?? -1),
      );
    }
    final maxRegional = [for (final g in regionales) g.total(_totales) ?? 0]
        .fold<double>(1, (m, v) => v > m ? v : m);

    return PantallaContractual(
      anchoMaximo: 1080,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PildoraVolver(
            etiqueta: 'Proyección de contratación',
            onTap: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(height: 18),
        Text(widget.nombre, style: EstiloContractual.titulo),
        const SizedBox(height: 6),
        Text(
          grupos == null
              ? 'Buscando las cuentas que publican Plan Anual de Adquisiciones ${widget.anio}…'
              : '$_cuentas cuenta${_cuentas == 1 ? '' : 's'} con PAA ${widget.anio}. '
                    'Cada una publica su propio plan: toca una para ver su proyección verificada en SECOP II.',
          style: EstiloContractual.subtitulo,
        ),
        const SizedBox(height: 16),
        const AvisoPrediccionPaa(),
        const SizedBox(height: 16),
        if (_error != null)
          _Mensaje(texto: _error!, onReintentar: _cargar)
        else if (grupos == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (grupos.isEmpty)
          const _Mensaje(
            texto: 'No encontramos cuentas de esta entidad con PAA publicado para este año.',
          )
        else ...[
          _Resumen(
            total: totalEntidad,
            contratado: contratadoEntidad,
            anio: widget.anio,
            pendientes: _pendientes,
            error: _errorTotales,
            onReintentar: () => _cargarTotales([
              for (final g in grupos) ...g.nodos.map((n) => n.cuenta),
            ]),
            millones: _millones,
          ),
          const SizedBox(height: 14),
          if (widget.anio >= DateTime.now().year) ...[
            PanelProcesosAbiertos(
              procesos: _pendientesAb > 0 && _abiertosHoy.isEmpty
                  ? null
                  : _abiertosHoy,
              enPlan: const {},
              entidad: widget.nombre,
              error: _errorAb && _abiertosHoy.isEmpty
                  ? 'No fue posible consultar los procesos abiertos.'
                  : null,
              cuentaDe: _cuentaDe,
              titulo: 'Abiertos hoy en todas sus cuentas',
              vacio: _pendientesAb > 0 ? 'Consultando…' : 'Hoy ninguna de sus cuentas tiene procesos competitivos recibiendo ofertas.',
            ),
            const SizedBox(height: 14),
          ],
          for (final g in centrales) ...[
            _Grupo(
              grupo: g,
              totales: _totales,
              contratado: _contratadoDe(g),
              proporcion: 1,
              abierto: true,
              onTap: null,
              onAbrir: _abrir,
              millones: _millones,
              fecha: _fecha,
            ),
            const SizedBox(height: 14),
          ],
          if (regionales.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${regionales.first.titulo.startsWith('Regional') ? 'Regionales' : 'Regionales y territoriales'} (${regionales.length})',
                    style: EstiloContractual.tituloGrupo,
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final (v, t) in [
                        (false, 'Por nombre'),
                        (true, 'Más por contratar'),
                      ])
                        ChoiceChip(
                          label: Text(t),
                          selected: _porContratar == v,
                          selectedColor: const Color(0xFFDCE6F5),
                          checkmarkColor: EstiloContractual.navy,
                          onSelected: (_) => setState(() => _porContratar = v),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            for (final g in regionales)
              _Grupo(
                grupo: g,
                totales: _totales,
                contratado: _contratadoDe(g),
                proporcion: (g.total(_totales) ?? 0) / maxRegional,
                abierto: _abiertos.contains(g.titulo),
                // Con una sola cuenta, el grupo abre su proyección.
                onTap: g.nodos.length == 1
                    ? () => _abrir(g.nodos.single)
                    : () => setState(
                        () => _abiertos.contains(g.titulo)
                            ? _abiertos.remove(g.titulo)
                            : _abiertos.add(g.titulo),
                      ),
                onAbrir: _abrir,
                millones: _millones,
                fecha: _fecha,
              ),
          ],
        ],
        const SizedBox(height: 18),
        const Text(
          'Fuente: SECOP II, Datos Abiertos (PAA encabezado y detalle; contratos). Lo proyectado suma las '
          'compras publicadas en cada plan, una vez cada una; no se usa el presupuesto que declara el '
          'encabezado porque algunas entidades lo diligencian distinto a sus compras. Lo contratado son los '
          'contratos firmados en el año por cada cuenta; "por contratar" es una aproximación.',
          style: TextStyle(
            color: EstiloContractual.gris,
            fontSize: 11.5,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({
    required this.total,
    required this.contratado,
    required this.anio,
    required this.pendientes,
    required this.error,
    required this.onReintentar,
    required this.millones,
  });

  final double? total;
  final double? contratado;
  final int anio;
  final int pendientes;
  final String? error;
  final VoidCallback onReintentar;
  final String Function(double) millones;

  @override
  Widget build(BuildContext context) {
    final t = total, c = contratado;
    Widget cifra(String k, String v, String nota) => SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k.toUpperCase(), style: EstiloContractual.seccion),
          const SizedBox(height: 4),
          Text(
            v,
            style: const TextStyle(
              color: EstiloContractual.navy,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            nota,
            style: const TextStyle(
              color: EstiloContractual.gris,
              fontSize: 12.3,
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: EstiloContractual.tarjeta(),
      child: (t != null && c != null)
          ? Wrap(
              spacing: 18,
              runSpacing: 14,
              children: [
                cifra(
                  'Proyectado en sus planes',
                  millones(t),
                  'PAA $anio, todas las cuentas',
                ),
                cifra(
                  'Contratado en $anio',
                  millones(c),
                  t <= 0
                      ? 'Contratos firmados'
                      : '${(c / t * 100).round()} % de lo proyectado',
                ),
                cifra(
                  'Por contratar (aprox.)',
                  millones((t - c).clamp(0, double.infinity).toDouble()),
                  'Incluye lo que ya está en proceso de selección',
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Proyectado en todos sus planes'.toUpperCase(),
                        style: EstiloContractual.seccion,
                      ),
                      const SizedBox(height: 4),
                      if (total != null)
                        Text(
                          millones(total!),
                          style: const TextStyle(
                            color: EstiloContractual.navy,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      else if (error != null)
                        Text(
                          error!,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 13,
                          ),
                        )
                      else
                        Text(
                          'Calculando con cada compra de cada plan…'
                          '${pendientes > 0 ? ' faltan $pendientes cuenta${pendientes == 1 ? '' : 's'}.' : ''}',
                          style: const TextStyle(
                            color: EstiloContractual.gris,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                if (total == null && error == null)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                if (error != null)
                  TextButton(
                    onPressed: onReintentar,
                    child: const Text('Reintentar'),
                  ),
              ],
            ),
    );
  }
}

class _Grupo extends StatelessWidget {
  const _Grupo({
    required this.grupo,
    required this.totales,
    required this.contratado,
    required this.proporcion,
    required this.abierto,
    required this.onTap,
    required this.onAbrir,
    required this.millones,
    required this.fecha,
  });

  final GrupoPaa grupo;
  final Map<String, ({int compras, double total})>? totales;

  /// Contratado en el año por sus cuentas (null mientras se consulta).
  final double? contratado;
  final double proporcion;
  final bool abierto;
  final VoidCallback? onTap;
  final ValueChanged<NodoPaa> onAbrir;
  final String Function(double) millones;
  final String Function(String) fecha;

  @override
  Widget build(BuildContext context) {
    final g = grupo;
    final total = g.total(totales);
    final unaSola = g.nodos.length == 1;
    final detalle = unaSola
        ? (g.nodos.single.nombre == g.titulo
              ? 'Versión ${g.nodos.single.cuenta.plan.version} del PAA'
              : g.nodos.single.nombre)
        : '${g.nodos.length} cuentas con plan propio';
    final mostrarHijos = !unaSola && (abierto || g.esCentral);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: EstiloContractual.tarjeta(),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: g.esCentral
                  ? (unaSola ? () => onAbrir(g.nodos.single) : null)
                  : onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
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
                                g.titulo,
                                style: const TextStyle(
                                  color: EstiloContractual.navy,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                detalle,
                                style: const TextStyle(
                                  color: EstiloContractual.gris,
                                  fontSize: 12.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _Valor(
                          total: total,
                          sinCompras: g.nodos.every(
                            (n) =>
                                totales?[n.cuenta.plan.encabezadoId]?.compras ==
                                0,
                          ),
                          millones: millones,
                        ),
                        if (!g.esCentral || unaSola)
                          Icon(
                            unaSola
                                ? Icons.chevron_right_rounded
                                : (abierto
                                      ? Icons.expand_less_rounded
                                      : Icons.expand_more_rounded),
                            color: EstiloContractual.gris,
                          ),
                      ],
                    ),
                    if (!g.esCentral) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: total == null ? 0 : proporcion.clamp(0, 1),
                          minHeight: 6,
                          color: EstiloContractual.navy,
                          backgroundColor: const Color(0xFFF1F5F9),
                        ),
                      ),
                    ],
                    if (total != null && contratado != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        total <= 0
                            ? 'Contratado en el año: ${millones(contratado!)}'
                            : 'Contratado en el año: ${millones(contratado!)} '
                                  '(${(contratado! / total * 100).round()} % del plan) · '
                                  'por contratar (aprox.) ${millones((total - contratado!).clamp(0, double.infinity).toDouble())}',
                        style: const TextStyle(
                          color: EstiloContractual.texto,
                          fontSize: 12.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (mostrarHijos)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  children: [
                    for (final n in g.nodos)
                      _FilaCuenta(
                        nodo: n,
                        total: totales?[n.cuenta.plan.encabezadoId]?.total,
                        cargando:
                            totales?.containsKey(n.cuenta.plan.encabezadoId) !=
                            true,
                        sinCompras:
                            totales?[n.cuenta.plan.encabezadoId]?.compras == 0,
                        onTap:
                            totales?[n.cuenta.plan.encabezadoId]?.compras == 0
                            ? null
                            : () => onAbrir(n),
                        millones: millones,
                        fecha: fecha,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilaCuenta extends StatelessWidget {
  const _FilaCuenta({
    required this.nodo,
    required this.total,
    required this.cargando,
    required this.sinCompras,
    required this.onTap,
    required this.millones,
    required this.fecha,
  });

  final NodoPaa nodo;
  final double? total;
  final bool cargando;
  final bool sinCompras;
  final VoidCallback? onTap;
  final String Function(double) millones;
  final String Function(String) fecha;

  @override
  Widget build(BuildContext context) {
    final p = nodo.cuenta.plan;
    final actualizado = fecha(p.actualizadoIso);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nodo.nombre,
                    style: const TextStyle(
                      color: EstiloContractual.navy,
                      fontSize: 13.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    [
                      'Versión ${p.version}',
                      if (actualizado.isNotEmpty) 'actualizado $actualizado',
                    ].join(' · '),
                    style: const TextStyle(
                      color: EstiloContractual.gris,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _Valor(
              total: cargando ? null : (total ?? 0),
              sinCompras: sinCompras,
              millones: millones,
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: onTap == null
                  ? const Color(0xFFCBD5E1)
                  : EstiloContractual.gris,
            ),
          ],
        ),
      ),
    );
  }
}

class _Valor extends StatelessWidget {
  const _Valor({
    required this.total,
    required this.sinCompras,
    required this.millones,
  });

  final double? total;
  final bool sinCompras;
  final String Function(double) millones;

  @override
  Widget build(BuildContext context) {
    if (sinCompras) {
      return const Text(
        'Sin compras publicadas',
        style: TextStyle(color: EstiloContractual.gris, fontSize: 12),
      );
    }
    if (total == null) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          millones(total!),
          style: const TextStyle(
            color: EstiloContractual.navy,
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Text(
          'previsto',
          style: TextStyle(color: EstiloContractual.gris, fontSize: 11.5),
        ),
      ],
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.texto, this.onReintentar});

  final String texto;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: EstiloContractual.tarjeta(),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                color: EstiloContractual.texto,
                fontSize: 13.5,
              ),
            ),
          ),
          if (onReintentar != null)
            TextButton(
              onPressed: onReintentar,
              child: const Text('Reintentar'),
            ),
        ],
      ),
    );
  }
}
