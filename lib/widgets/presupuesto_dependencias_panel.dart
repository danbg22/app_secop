import 'package:flutter/material.dart';

import '../data/estructura_sena.dart';
import '../services/presupuesto_dependencias_service.dart';
import '../services/reporte_contratos_service.dart';
import 'reporte_contratos_flujo.dart';
import '../tema/cristal.dart';

/// Lo que cada dependencia (unidad de contratación de SECOP II) de una
/// entidad pone en procesos, contrata y paga en la vigencia, más las
/// órdenes de la Tienda Virtual del Estado. Los contratos y pagos de todas
/// las dependencias se consultan de una vez al cargar (el perfil de la
/// entidad ya los empieza a precargar al abrirse), así que al tocar una
/// dependencia su detalle aparece enseguida.
class PresupuestoDependenciasPanel extends StatefulWidget {
  const PresupuestoDependenciasPanel({
    super.key,
    required this.nit,
    required this.alcance,
    this.anio,
    this.departamento,
    this.cuentaSecop,
    this.entidad,
  });

  final String nit;

  /// Nombre de la entidad, para el reporte de contratos en PDF.
  final String? entidad;
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
  List<DependenciaPresupuesto>? _dependencias;
  String? _error;
  String _filtro = '';
  String? _abierta;
  final Map<String, Future<EjecucionDependencia>> _ejecuciones = {};
  int _consulta = 0;

  /// Ejecución de todas las dependencias del alcance (null mientras llega,
  /// o si el alcance es el historial completo).
  Future<EjecucionMasiva?>? _masivaEnCurso;
  EjecucionMasiva? _masiva;
  final Map<String, EjecucionDependencia> _ejecucionLista = {};

  // Vista por estructura del SENA: Dirección General y regionales.
  bool get _esSena => esNitSena(widget.nit) && widget.cuentaSecop == null;
  final Set<String> _regionalesAbiertas = {};
  bool _nacionalAbierto = false;

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
      _regionalesAbiertas.clear();
      _nacionalAbierto = false;
      _masiva = null;
      _ejecucionLista.clear();
    });
    // En paralelo con la lista de dependencias.
    final masiva = PresupuestoDependenciasService.ejecucionMasiva(
      nit: widget.nit,
      anio: widget.anio,
      departamento: widget.departamento,
      cuentaSecop: widget.cuentaSecop,
    );
    _masivaEnCurso = masiva;
    masiva.then(
      (m) {
        if (!mounted || id != _consulta) return;
        setState(() => _masiva = m);
      },
      // Sin ejecución masiva: cada dependencia se consulta al tocarla.
      onError: (Object _) {},
    ).ignore();
    try {
      final deps = await PresupuestoDependenciasService.dependencias(
        nit: widget.nit,
        anio: widget.anio,
        departamento: widget.departamento,
        cuentaSecop: widget.cuentaSecop,
      );
      if (!mounted || id != _consulta) return;
      setState(() {
        _dependencias = deps;
        // Con una regional elegida en el perfil, se abre de una vez.
        if (_esSena && widget.departamento != null) {
          _regionalesAbiertas.addAll(
            _arbolSena(deps).regionales.keys.map((r) => r.nombre),
          );
        }
      });
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
      if (_abierta != null && _lista(d) == null) {
        _ejecuciones.putIfAbsent(d.clave, () => _ejecucionDe(d));
      }
    });
  }

  /// Ejecución de [d] ya consultada (precarga masiva), o null.
  EjecucionDependencia? _lista(DependenciaPresupuesto d) {
    final m = _masiva;
    if (m == null) return null;
    return _ejecucionLista.putIfAbsent(d.clave, () => m.de(d));
  }

  /// Espera la consulta masiva si está en curso; sin ella, consulta solo
  /// esta dependencia.
  Future<EjecucionDependencia> _ejecucionDe(DependenciaPresupuesto d) async {
    EjecucionMasiva? m = _masiva;
    if (m == null && _masivaEnCurso != null) {
      try {
        m = await _masivaEnCurso;
      } catch (_) {}
    }
    if (m != null) return m.de(d);
    return PresupuestoDependenciasService.ejecucion(
      d,
      nit: widget.nit,
      anio: widget.anio,
    );
  }

  /// Suma de lo pagado de [deps], o null si la ejecución aún no llega.
  double? _pagado(Iterable<DependenciaPresupuesto> deps) {
    if (_masiva == null) return null;
    return deps.fold<double>(0, (s, d) => s + (_lista(d)?.pagadoCop ?? 0));
  }

  /// Contratado de [deps] en SECOP II más las órdenes de [tienda], o null si
  /// la ejecución aún no llega.
  double? _contratado(
    Iterable<DependenciaPresupuesto> deps, [
    Iterable<OrdenesTienda> tienda = const [],
  ]) {
    if (_masiva == null) return null;
    return deps.fold<double>(0, (s, d) => s + (_lista(d)?.contratadoCop ?? 0)) +
        _valorTienda(tienda);
  }

  static double _valorTienda(Iterable<OrdenesTienda> ordenes) =>
      ordenes.fold<double>(0, (s, o) => s + o.valorCop);

  /// Lo que [d] puso en procesos: los publicados en la vigencia más los
  /// que SECOP II publica sin fecha y se ubican en ella por sus contratos.
  double _enProcesos(DependenciaPresupuesto d) =>
      d.asignadoCop + (_lista(d)?.asignadoSinFechaCop ?? 0);

  int _procesos(DependenciaPresupuesto d) =>
      d.procesos + (_lista(d)?.procesosSinFecha ?? 0);

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

  _ArbolSena _arbolSena(List<DependenciaPresupuesto> deps) {
    final nacional = <String, List<DependenciaPresupuesto>>{};
    final porRegional =
        <RegionalSena, Map<String, List<DependenciaPresupuesto>>>{};
    final otras = <DependenciaPresupuesto>[];
    for (final d in deps) {
      final u = EstructuraSena.ubicar(
        cuenta: d.cuentaSecop,
        unidad: d.variantes.first,
        departamento: d.departamento,
      );
      switch (u.nivel) {
        case NivelSena.nacional:
          nacional.putIfAbsent(u.nodo, () => []).add(d);
        case NivelSena.otra:
          otras.add(d);
        default:
          porRegional
              .putIfAbsent(u.regional!, () => {})
              .putIfAbsent(u.nodo, () => [])
              .add(d);
      }
    }
    DependenciaPresupuesto unir(
      String clave,
      String nombre,
      List<DependenciaPresupuesto> p,
    ) => p.length == 1
        ? DependenciaPresupuesto(
            clave: clave,
            nombre: nombre,
            cuentaSecop: p.single.cuentaSecop,
            variantes: p.single.variantes,
            procesos: p.single.procesos,
            asignadoCop: p.single.asignadoCop,
            departamento: p.single.departamento,
          )
        : DependenciaPresupuesto.agrupada(
            clave: clave,
            nombre: nombre,
            partes: p,
          );
    return _ArbolSena(
      nacional: [
        for (final e in nacional.entries) unir('nac|${e.key}', e.key, e.value),
      ]..sort((a, b) => b.asignadoCop.compareTo(a.asignadoCop)),
      regionales: {
        for (final e in porRegional.entries)
          e.key: {
            for (final n in e.value.entries)
              n.key: unir('${e.key.nombre}|${n.key}', n.key, n.value),
          },
      },
      otras: otras,
    );
  }

  List<Widget> _vistaSena(List<DependenciaPresupuesto> deps, String consulta) {
    final arbol = _arbolSena(deps);
    bool coincide(String t) => consulta.isEmpty || _norm(t).contains(consulta);
    const despacho = 'Despacho de la Dirección Regional';

    final nacional = arbol.nacional
        .where((d) => coincide(d.nombre) || coincide('direccion general'))
        .toList();
    final regionales = [
      for (final r in regionalesSena)
        if (arbol.regionales.containsKey(r) &&
            (coincide('regional ${r.nombre}') ||
                arbol.regionales[r]!.keys.any(coincide)))
          r,
    ];
    final maxNodo = [
      ...arbol.nacional,
      for (final m in arbol.regionales.values) ...m.values,
    ].fold<double>(1, (m, d) => _enProcesos(d) > m ? _enProcesos(d) : m);
    final totalRegional = {
      for (final e in arbol.regionales.entries)
        e.key: e.value.values.fold<double>(0, (s, d) => s + _enProcesos(d)),
    };
    final maxRegional = totalRegional.values.fold<double>(
      1,
      (m, v) => v > m ? v : m,
    );
    final totalNacional = arbol.nacional.fold<double>(
      0,
      (s, d) => s + _enProcesos(d),
    );

    // Órdenes de la Tienda Virtual: a su despacho o centro si el nombre de
    // la cuenta lo dice ("SENA - Regional Cesar" es la cuenta del
    // despacho); si solo nombra la regional, a la regional; si no, aparte.
    final tiendaNodo = <String, List<OrdenesTienda>>{};
    final tiendaRegional = <RegionalSena, List<OrdenesTienda>>{};
    final tiendaOtras = <OrdenesTienda>[];
    for (final o in _masiva?.tienda ?? const <OrdenesTienda>[]) {
      final u = EstructuraSena.ubicar(cuenta: o.cuenta, unidad: o.cuenta);
      final r = u.regional;
      if (r != null && arbol.regionales.containsKey(r)) {
        if (u.nivel != NivelSena.regionalSinDistinguir &&
            arbol.regionales[r]!.containsKey(u.nodo)) {
          tiendaNodo.putIfAbsent('${r.nombre}|${u.nodo}', () => []).add(o);
        } else {
          tiendaRegional.putIfAbsent(r, () => []).add(o);
        }
      } else if (u.nivel == NivelSena.nacional &&
          arbol.nacional.any((d) => d.nombre == u.nodo)) {
        tiendaNodo.putIfAbsent('nac|${u.nodo}', () => []).add(o);
      } else {
        tiendaOtras.add(o);
      }
    }
    List<OrdenesTienda> tiendaDe(Iterable<DependenciaPresupuesto> nodos) => [
      for (final d in nodos) ...?tiendaNodo[d.clave],
    ];

    Widget fila(DependenciaPresupuesto d) => _FilaDependencia(
      dependencia: d,
      asignado: _enProcesos(d),
      procesos: _procesos(d),
      tienda: tiendaNodo[d.clave] ?? const [],
      anio: widget.anio,
      proporcion: _enProcesos(d) / maxNodo,
      abierta: _abierta == d.clave,
      lista: _lista(d),
      ejecucion: _ejecuciones[d.clave],
      mostrarCuenta: false,
      onTap: () => _alternar(d),
      onReporte: () => _reporte(d),
      onReintentar: () =>
          setState(() => _ejecuciones[d.clave] = _ejecucionDe(d)),
      millones: _millones,
    );

    Widget subtitulo(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 0, 6),
      child: Text(
        t,
        style: TextStyle(
          color: Cristal.texto,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    Widget vacio(String t) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Cristal.borde),
      ),
      child: Text(
        t,
        style: TextStyle(color: Cristal.textoSuave, fontSize: 12.5),
      ),
    );

    return [
      Text(
        'Organizado como el SENA: la Dirección General y las direcciones regionales, '
        'cada una con su despacho y sus centros de formación. Son quienes tienen '
        'ordenador del gasto y firman los contratos.',
        style: TextStyle(
          color: Cristal.textoSuave,
          fontSize: 12.5,
          height: 1.45,
        ),
      ),
      const SizedBox(height: 14),
      if (nacional.isNotEmpty) ...[
        _GrupoSena(
          titulo: 'Dirección General',
          detalle:
              'Nivel nacional · ${arbol.nacional.length} dependencias que contratan',
          valor: _millones(totalNacional),
          total: totalNacional,
          contratado: _contratado(arbol.nacional, tiendaDe(arbol.nacional)),
          pagado: _pagado(arbol.nacional),
          millones: _millones,
          proporcion:
              totalNacional /
              (totalNacional > maxRegional ? totalNacional : maxRegional),
          abierto: _nacionalAbierto || consulta.isNotEmpty,
          onTap: () => setState(() => _nacionalAbierto = !_nacionalAbierto),
          hijos: [for (final d in nacional) fila(d)],
        ),
        const SizedBox(height: 16),
      ],
      if (regionales.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Direcciones regionales (${arbol.regionales.length})',
            style: TextStyle(
              color: Cristal.texto,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        for (final r in regionales)
          Builder(
            builder: (context) {
              final nodos = arbol.regionales[r]!;
              final centros = nodos.keys
                  .where((k) => r.centros.any((c) => c.nombre == k))
                  .length;
              final otros = nodos.entries.where(
                (e) =>
                    e.key != despacho &&
                    !r.centros.any((c) => c.nombre == e.key),
              );
              return _GrupoSena(
                titulo: r.nombre == 'Distrito Capital'
                    ? 'Regional Distrito Capital'
                    : 'Regional ${r.nombre}',
                detalle: centros == 0 && otros.isNotEmpty
                    ? 'Despacho y centro contratan en un solo grupo'
                    : [
                        if (nodos.containsKey(despacho)) 'Despacho',
                        '$centros de ${r.centros.length} centro${r.centros.length == 1 ? '' : 's'} con procesos',
                      ].join(' · '),
                valor: _millones(totalRegional[r]!),
                total: totalRegional[r]!,
                contratado: _contratado(nodos.values, [
                  ...tiendaDe(nodos.values),
                  ...?tiendaRegional[r],
                ]),
                pagado: _pagado(nodos.values),
                millones: _millones,
                proporcion: totalRegional[r]! / maxRegional,
                abierto:
                    _regionalesAbiertas.contains(r.nombre) ||
                    consulta.isNotEmpty,
                onTap: () => setState(
                  () => _regionalesAbiertas.contains(r.nombre)
                      ? _regionalesAbiertas.remove(r.nombre)
                      : _regionalesAbiertas.add(r.nombre),
                ),
                hijos: [
                  const SizedBox(height: 4),
                  if (nodos[despacho] case final d?)
                    fila(d)
                  else
                    vacio('Sin procesos propios del despacho en este alcance.'),
                  subtitulo('Centros de formación (${r.centros.length})'),
                  for (final c in r.centros)
                    if (nodos[c.nombre] case final d?)
                      fila(d)
                    else
                      vacio(
                        '${c.nombre}: sin procesos en SECOP II en este alcance.',
                      ),
                  if (otros.isNotEmpty) ...[
                    subtitulo('Sin identificar'),
                    for (final e in otros) fila(e.value),
                  ],
                  if (tiendaRegional[r] case final ordenes?) ...[
                    subtitulo('Tienda Virtual sin dependencia'),
                    _TiendaSinDependencia(
                      ordenes: ordenes,
                      millones: _millones,
                    ),
                  ],
                ],
              );
            },
          ),
      ],
      if (arbol.otras.isNotEmpty && consulta.isEmpty) ...[
        const SizedBox(height: 8),
        subtitulo('Otras cuentas del SENA'),
        for (final d in arbol.otras) fila(d),
      ],
      if (tiendaOtras.isNotEmpty && consulta.isEmpty) ...[
        const SizedBox(height: 8),
        subtitulo('Tienda Virtual: cuentas sin regional en su nombre'),
        _TiendaSinDependencia(ordenes: tiendaOtras, millones: _millones),
      ],
      if (nacional.isEmpty && regionales.isEmpty)
        const _Mensaje(
          icono: Icons.inbox_outlined,
          texto: 'Ninguna regional, centro o dependencia coincide con la búsqueda.',
        ),
    ];
  }

  /// Reporte exacto en PDF de los contratos de una unidad (despacho, centro).
  void _reporte(DependenciaPresupuesto d) {
    String? regional;
    var etiqueta = d.nombre;
    if (_esSena) {
      if (d.clave.startsWith('nac|')) {
        etiqueta = 'Dirección General · ${d.nombre}';
      } else {
        final nombre = d.clave.split('|').first;
        // Las "otras cuentas" conservan su clave de SECOP: sin regional.
        if (regionalesSena.any((r) => r.nombre == nombre)) {
          regional = 'Regional $nombre';
          etiqueta = '$regional · ${d.nombre}';
        }
      }
    } else if (widget.departamento != null) {
      regional = widget.departamento;
    }
    exportarReporteUnidad(
      context,
      entidad: widget.entidad ?? 'Entidad',
      nit: widget.nit,
      unidad: UnidadContratacion(
        etiqueta: etiqueta,
        partes: d.partes.isEmpty ? [d] : d.partes,
        regional: regional,
      ),
      regional: regional,
      vigencia: widget.anio,
    );
  }

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
        : visibles.map(_enProcesos).reduce((a, b) => a > b ? a : b);
    final totalAsignado = deps?.fold<double>(0, (s, d) => s + _enProcesos(d));
    final tienda = _masiva?.tienda ?? const <OrdenesTienda>[];
    final mobile = MediaQuery.sizeOf(context).width < 700;
    final variasCuentas =
        widget.cuentaSecop == null &&
        (deps?.map((d) => d.cuentaSecop).toSet().length ?? 0) > 1;

    return Container(
      decoration: BoxDecoration(
        color: Cristal.vidrio,
        borderRadius: BorderRadius.circular(18),
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
                  Text(
                    'Presupuesto por dependencia',
                    style: TextStyle(
                      color: Cristal.texto,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    totalAsignado == null
                        ? widget.alcance
                        : _esSena
                        ? 'SENA · ${widget.alcance} · ${_millones(totalAsignado)} en procesos'
                        : '${!variasCuentas && deps!.isNotEmpty && widget.cuentaSecop == null ? '${deps.first.cuentaSecop} · ' : ''}'
                              '${widget.alcance} · ${deps!.length} dependencias · '
                              '${_millones(totalAsignado)} en procesos',
                    style: TextStyle(color: Cristal.textoSuave, fontSize: 12.5),
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
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: Cristal.textoTenue,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: Cristal.campo,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Cristal.borde),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Cristal.borde),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Para que nadie lo lea como el presupuesto oficial de la entidad.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Cristal.textoSuave,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lo que cada dependencia pone en procesos, contrata y paga en SECOP II y en la '
                  'Tienda Virtual del Estado. No es la apropiación ni los compromisos del SIIF: '
                  'allí también están gastos sin contrato, como apoyos de sostenimiento, '
                  'viáticos, servicios públicos y nómina.',
                  style: TextStyle(
                    color: Cristal.textoSuave,
                    fontSize: 12.3,
                    height: 1.45,
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
          else if (_esSena && deps.isNotEmpty)
            ..._vistaSena(deps, consulta)
          else if (visibles.isEmpty)
            _Mensaje(
              icono: Icons.inbox_outlined,
              texto: deps.isEmpty
                  ? 'SECOP II no registra procesos de esta entidad en el alcance elegido.'
                  : 'Ninguna dependencia coincide con la búsqueda.',
            )
          else ...[
            if (tienda.isNotEmpty && consulta.isEmpty)
              _TiendaSinDependencia(ordenes: tienda, millones: _millones),
            for (final d in visibles.take(80))
              _FilaDependencia(
                dependencia: d,
                asignado: _enProcesos(d),
                procesos: _procesos(d),
                anio: widget.anio,
                proporcion: maximo <= 0 ? 0 : _enProcesos(d) / maximo,
                abierta: _abierta == d.clave,
                lista: _lista(d),
                ejecucion: _ejecuciones[d.clave],
                mostrarCuenta: variasCuentas,
                onTap: () => _alternar(d),
                onReporte: () => _reporte(d),
                onReintentar: () =>
                    setState(() => _ejecuciones[d.clave] = _ejecucionDe(d)),
                millones: _millones,
              ),
          ],
          if (visibles.length > 80)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Se muestran 80 de ${visibles.length} dependencias. Usa el buscador para encontrar la tuya.',
                style: TextStyle(color: Cristal.textoSuave, fontSize: 12),
              ),
            ),
          const SizedBox(height: 14),
          Text(
            'Fuente: SECOP II y Tienda Virtual del Estado Colombiano, Datos Abiertos. Las dependencias son las '
            'unidades de contratación que la entidad registra en cada proceso. En procesos: presupuesto oficial '
            'de los procesos de la vigencia, sin cancelados ni borradores. Contratado: contratos de esos '
            'procesos firmados en la vigencia y órdenes de compra de la Tienda Virtual, que no dicen la '
            'dependencia y se ubican por el nombre de la cuenta. Ejecutado: pagos reportados en SECOP II.',
            style: TextStyle(
              color: Cristal.textoSuave,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaDependencia extends StatelessWidget {
  const _FilaDependencia({
    required this.dependencia,
    required this.asignado,
    required this.procesos,
    required this.proporcion,
    required this.abierta,
    required this.ejecucion,
    required this.mostrarCuenta,
    required this.onTap,
    required this.onReintentar,
    required this.millones,
    this.lista,
    this.onReporte,
    this.tienda = const [],
    this.anio,
  });

  final DependenciaPresupuesto dependencia;

  /// En procesos (con los procesos sin fecha de la vigencia).
  final double asignado;
  final int procesos;

  /// Órdenes de la Tienda Virtual de su cuenta.
  final List<OrdenesTienda> tienda;
  final int? anio;
  final VoidCallback? onReporte;
  final double proporcion;
  final bool abierta;

  /// Ejecución ya precargada: se muestra sin esperar.
  final EjecucionDependencia? lista;
  final Future<EjecucionDependencia>? ejecucion;
  final bool mostrarCuenta;
  final VoidCallback onTap;
  final VoidCallback onReintentar;
  final String Function(double) millones;

  Widget _detalle(EjecucionDependencia e) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _DetalleEjecucion(
        asignado: asignado,
        procesos: procesos,
        e: e,
        tienda: tienda,
        anio: anio,
        millones: millones,
      ),
      if (onReporte != null) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onReporte,
          style: OutlinedButton.styleFrom(
            foregroundColor: Cristal.texto,
            side: BorderSide(color: Cristal.bordeFuerte),
            shape: const StadiumBorder(),
          ),
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: const Text(
            'Reporte de sus contratos (Excel o PDF)',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    final d = dependencia;
    // Contratado y pagado, en cuanto llega la precarga: se ven sin abrir
    // la fila.
    final ejecutado = lista == null
        ? null
        : _LineaEjecucion(
            enProcesos: asignado,
            contratado:
                lista!.contratadoCop +
                tienda.fold<double>(0, (s, o) => s + o.valorCop),
            pagado: lista!.pagadoCop,
            millones: millones,
          );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: abierta ? Cristal.azulVidrio : Cristal.vidrio,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: abierta ? Cristal.acentoBorde : Cristal.borde,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          hoverDuration: Cristal.micro,
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (MediaQuery.sizeOf(context).width < 520) ...[
                  // En el celular el nombre va completo y la cifra debajo.
                  Text(
                    d.nombre,
                    style: TextStyle(
                      color: Cristal.texto,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (mostrarCuenta && d.cuentaSecop.isNotEmpty)
                    Text(
                      d.cuentaSecop,
                      style: TextStyle(
                        color: Cristal.textoSuave,
                        fontSize: 11.8,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        millones(asignado),
                        style: TextStyle(
                          color: Cristal.texto,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'en $procesos proceso${procesos == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: Cristal.textoSuave,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      Icon(
                        abierta
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: Cristal.textoSuave,
                      ),
                    ],
                  ),
                  ?ejecutado,
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.nombre,
                              style: TextStyle(
                                color: Cristal.texto,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (mostrarCuenta && d.cuentaSecop.isNotEmpty)
                              Text(
                                d.cuentaSecop,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Cristal.textoSuave,
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
                            millones(asignado),
                            style: TextStyle(
                              color: Cristal.texto,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'en $procesos proceso${procesos == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: Cristal.textoSuave,
                              fontSize: 11.5,
                            ),
                          ),
                          ?ejecutado,
                        ],
                      ),
                      Icon(
                        abierta
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: Cristal.textoSuave,
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: proporcion.clamp(0, 1),
                    minHeight: 6,
                    color: Cristal.legible(const Color(0xFF93C5FD)),
                    backgroundColor: Cristal.vidrioFuerte,
                  ),
                ),
                if (abierta && lista != null) ...[
                  const SizedBox(height: 12),
                  _detalle(lista!),
                ] else if (abierta && ejecucion != null) ...[
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
                                style: TextStyle(
                                  color: Cristal.rojo,
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
                        return Padding(
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
                                style: TextStyle(
                                  color: Cristal.textoSuave,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return _detalle(snap.data!);
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
    required this.procesos,
    required this.e,
    required this.millones,
    this.tienda = const [],
    this.anio,
  });

  final double asignado;
  final int procesos;
  final EjecucionDependencia e;
  final List<OrdenesTienda> tienda;
  final int? anio;
  final String Function(double) millones;

  @override
  Widget build(BuildContext context) {
    final ordenes = tienda.fold<int>(0, (s, o) => s + o.ordenes);
    final valorTienda = tienda.fold<double>(0, (s, o) => s + o.valorCop);
    final contratado = e.contratadoCop + valorTienda;
    final pctContratado = asignado <= 0
        ? 0
        : (contratado / asignado * 100).round();
    // La Tienda Virtual no publica pagos: el porcentaje es sobre SECOP II.
    final pctEjecutado = e.contratadoCop <= 0
        ? 0
        : (e.pagadoCop / e.contratadoCop * 100).round();
    Widget nota(String t) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        t,
        style: TextStyle(color: Cristal.textoSuave, fontSize: 11.5),
      ),
    );

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
        color: Cristal.vidrio,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Cristal.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.toUpperCase(),
            style: TextStyle(
              color: Cristal.textoSuave,
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
          Text(
            nota,
            style: TextStyle(color: Cristal.textoSuave, fontSize: 11.5),
          ),
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
                  'En procesos',
                  millones(asignado),
                  'Presupuesto oficial de $procesos proceso${procesos == 1 ? '' : 's'}',
                  Cristal.texto,
                ),
                cifra(
                  ancho,
                  'Contratado',
                  millones(contratado),
                  ordenes == 0
                      ? '${e.contratos} contratos · $pctContratado % de sus procesos'
                      : '${e.contratos} contratos y $ordenes órdenes · $pctContratado % de sus procesos',
                  Cristal.acentoClaro,
                ),
                cifra(
                  ancho,
                  'Ejecutado (pagado)',
                  millones(e.pagadoCop),
                  ordenes == 0
                      ? '$pctEjecutado % de lo contratado'
                      : '$pctEjecutado % de sus contratos de SECOP II',
                  Cristal.verde,
                ),
                cifra(
                  ancho,
                  'Por ejecutar',
                  millones(e.pendienteCop),
                  'Pendiente según SECOP II',
                  Cristal.ambar,
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
                    : (contratado > 0 ? contratado : 1);
                double ancho(double v) =>
                    (v / base).clamp(0.0, 1.0) * c.maxWidth;
                return Stack(
                  children: [
                    Container(color: Cristal.vidrioSuave),
                    Container(
                      width: ancho(contratado),
                      color: Cristal.acentoClaro.withValues(alpha: 0.45),
                    ),
                    Container(width: ancho(e.pagadoCop), color: Cristal.verde),
                  ],
                );
              },
            ),
          ),
        ),
        if (!e.completa)
          nota(
            'Incluye los ${e.procesosConsultados} procesos de mayor valor de ${e.procesosTotales}.',
          ),
        if (e.procesosSinFecha > 0)
          nota(
            'Incluye ${e.procesosSinFecha} proceso${e.procesosSinFecha == 1 ? '' : 's'} que SECOP II '
            'publica sin fecha, ubicado${e.procesosSinFecha == 1 ? '' : 's'} en '
            '${anio ?? 'la vigencia'} por la firma de sus contratos.',
          ),
        if (ordenes > 0)
          nota(
            'Contratado incluye ${millones(valorTienda)} en $ordenes órdenes de compra de la Tienda '
            'Virtual del Estado (${tienda.map((o) => '«${o.cuenta}»').join(', ')}), '
            'que no publica pagos.',
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
          Icon(icono, color: Cristal.textoTenue, size: 30),
          const SizedBox(height: 8),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(color: Cristal.textoSuave, fontSize: 13),
          ),
          ?accion,
        ],
      ),
    );
  }
}

class _ArbolSena {
  const _ArbolSena({
    required this.nacional,
    required this.regionales,
    required this.otras,
  });

  final List<DependenciaPresupuesto> nacional;

  /// Regional → despacho, centros y unidades sin identificar.
  final Map<RegionalSena, Map<String, DependenciaPresupuesto>> regionales;
  final List<DependenciaPresupuesto> otras;
}

/// Fila plegable de la Dirección General o de una regional.
class _GrupoSena extends StatelessWidget {
  const _GrupoSena({
    required this.titulo,
    required this.detalle,
    required this.valor,
    required this.proporcion,
    required this.abierto,
    required this.onTap,
    required this.hijos,
    required this.millones,
    required this.total,
    this.contratado,
    this.pagado,
  });

  final String titulo;
  final String detalle;
  final String valor;

  /// En procesos del grupo (el número detrás de [valor]).
  final double total;

  /// Contratado y pagado del grupo, cuando ya llegó la precarga.
  final double? contratado;
  final double? pagado;
  final String Function(double) millones;
  final double proporcion;
  final bool abierto;
  final VoidCallback onTap;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    // En el celular la línea de contratado y ejecutado va bajo el título,
    // para no apretarlo.
    final estrecho = MediaQuery.sizeOf(context).width < 560;
    final linea = contratado != null && pagado != null
        ? _LineaEjecucion(
            enProcesos: total,
            contratado: contratado!,
            pagado: pagado!,
            millones: millones,
          )
        : null;
    // La regional abierta se distingue de las demás: fondo más oscuro, borde
    // y cabecera en azul y una sombra que la separa de las de arriba y abajo.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.only(bottom: abierto ? 14 : 10, top: abierto ? 4 : 0),
      decoration: BoxDecoration(
        color: abierto
            ? (Cristal.esClaro ? Cristal.vidrioFuerte : Cristal.vidrioOscuro)
            : Cristal.vidrio,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: abierto ? Cristal.acentoBorde : Cristal.borde,
          width: abierto ? 1.4 : 1,
        ),
        boxShadow: abierto
            ? [
                BoxShadow(
                  color: Cristal.sombra,
                  blurRadius: 22,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: abierto ? Cristal.acentoVidrio : Colors.transparent,
            borderRadius: abierto
                ? const BorderRadius.vertical(top: Radius.circular(15))
                : BorderRadius.circular(16),
            child: InkWell(
              hoverDuration: Cristal.micro,
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
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
                                titulo,
                                style: TextStyle(
                                  color: Cristal.texto,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                detalle,
                                style: TextStyle(
                                  color: abierto
                                      ? Cristal.textoMedio
                                      : Cristal.textoSuave,
                                  fontSize: 12.3,
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
                              valor,
                              style: TextStyle(
                                color: Cristal.texto,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'en procesos',
                              style: TextStyle(
                                color: abierto
                                    ? Cristal.textoMedio
                                    : Cristal.textoSuave,
                                fontSize: 11.5,
                              ),
                            ),
                            if (!estrecho) ?linea,
                          ],
                        ),
                        Icon(
                          abierto
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: abierto
                              ? Cristal.acentoClaro
                              : Cristal.textoSuave,
                        ),
                      ],
                    ),
                    if (estrecho && linea != null) ...[
                      const SizedBox(height: 4),
                      linea,
                    ],
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: proporcion.clamp(0, 1),
                        minHeight: 6,
                        color: Cristal.acentoClaro,
                        backgroundColor: Cristal.vidrioFuerte,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (abierto)
            Padding(
              padding: EdgeInsets.fromLTRB(
                MediaQuery.sizeOf(context).width < 520 ? 8 : 14,
                12,
                MediaQuery.sizeOf(context).width < 520 ? 8 : 14,
                8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: hijos,
              ),
            ),
        ],
      ),
    );
  }
}

/// "contratado 75 % · $ 7.515 M ejecutado": cuánto de lo puesto en procesos
/// se contrató y cuánto se ha pagado.
class _LineaEjecucion extends StatelessWidget {
  const _LineaEjecucion({
    required this.enProcesos,
    required this.contratado,
    required this.pagado,
    required this.millones,
  });

  final double enProcesos;
  final double contratado;
  final double pagado;
  final String Function(double) millones;

  @override
  Widget build(BuildContext context) {
    final pct = enProcesos <= 0
        ? null
        : (contratado / enProcesos * 100).round();
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: pct == null
                ? 'contratado ${millones(contratado)} · '
                : 'contratado $pct % · ',
            style: TextStyle(color: Cristal.textoMedio),
          ),
          TextSpan(
            text: '${millones(pagado)} ejecutado',
            style: TextStyle(color: Cristal.verde),
          ),
        ],
      ),
      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
    );
  }
}

/// Órdenes de la Tienda Virtual que no se pueden ubicar en una dependencia:
/// la Tienda Virtual solo dice la cuenta que compra.
class _TiendaSinDependencia extends StatelessWidget {
  const _TiendaSinDependencia({required this.ordenes, required this.millones});

  final List<OrdenesTienda> ordenes;
  final String Function(double) millones;

  @override
  Widget build(BuildContext context) {
    final total = ordenes.fold<double>(0, (s, o) => s + o.valorCop);
    final n = ordenes.fold<int>(0, (s, o) => s + o.ordenes);
    final cuentas = ordenes.map((o) => '«${o.cuenta}»').toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Cristal.vidrio,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Cristal.borde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.storefront_outlined, size: 20, color: Cristal.textoMedio),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${millones(total)} en $n orden${n == 1 ? '' : 'es'} de compra',
                  style: TextStyle(
                    color: Cristal.texto,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${cuentas.length > 3 ? '${cuentas.take(3).join(', ')} y ${cuentas.length - 3} cuentas más' : cuentas.join(', ')} '
                  'en la Tienda Virtual del Estado, que no dice qué dependencia compra.',
                  style: TextStyle(
                    color: Cristal.textoSuave,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
