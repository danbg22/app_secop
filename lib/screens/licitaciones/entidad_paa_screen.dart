import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/estructura_paa.dart';
import '../../services/paa_service.dart';
import '../gestion_contractual/estilo_contractual.dart';
import 'prediccion_paa_screen.dart';

/// Una entidad con todas las cuentas que publican PAA, ordenadas como está
/// organizada (nivel central y regionales). Cada una abre su predicción.
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
      // Una sola cuenta: directo a su predicción.
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
    } on PaaException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  StreamSubscription<(String, ({int compras, double total}))>? _sub;
  int _pendientes = 0;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
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
    final centrales = grupos?.where((g) => g.esCentral).toList() ?? const [];
    final regionales = grupos?.where((g) => !g.esCentral).toList() ?? const [];
    final maxRegional = [for (final g in regionales) g.total(_totales) ?? 0]
        .fold<double>(1, (m, v) => v > m ? v : m);

    return PantallaContractual(
      anchoMaximo: 1080,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PildoraVolver(
            etiqueta: 'Predicción de licitaciones',
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
                    'Cada una publica su propio plan: toca una para ver qué se prevé licitar.',
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
            pendientes: _pendientes,
            error: _errorTotales,
            onReintentar: () => _cargarTotales([
              for (final g in grupos) ...g.nodos.map((n) => n.cuenta),
            ]),
            millones: _millones,
          ),
          const SizedBox(height: 14),
          for (final g in centrales) ...[
            _Grupo(
              grupo: g,
              totales: _totales,
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
              child: Text(
                '${regionales.first.titulo.startsWith('Regional') ? 'Regionales' : 'Regionales y territoriales'} (${regionales.length})',
                style: EstiloContractual.tituloGrupo,
              ),
            ),
            for (final g in regionales)
              _Grupo(
                grupo: g,
                totales: _totales,
                proporcion: (g.total(_totales) ?? 0) / maxRegional,
                abierto: _abiertos.contains(g.titulo),
                // Con una sola cuenta, el grupo abre su predicción.
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
          'Fuente: SECOP II, Datos Abiertos (PAA encabezado y detalle). Los valores suman las compras '
          'publicadas en cada plan, una vez cada una; no se usa el presupuesto que declara el encabezado '
          'porque algunas entidades lo diligencian distinto a sus compras.',
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
    required this.pendientes,
    required this.error,
    required this.onReintentar,
    required this.millones,
  });

  final double? total;
  final int pendientes;
  final String? error;
  final VoidCallback onReintentar;
  final String Function(double) millones;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: EstiloContractual.tarjeta(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Valor previsto en todos sus planes'.toUpperCase(),
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
    required this.proporcion,
    required this.abierto,
    required this.onTap,
    required this.onAbrir,
    required this.millones,
    required this.fecha,
  });

  final GrupoPaa grupo;
  final Map<String, ({int compras, double total})>? totales;
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
