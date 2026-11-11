import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/paa_service.dart';
import '../../services/verificacion_paa_service.dart';
import '../gestion_contractual/estilo_contractual.dart';
import '../../utils/texto_profesional.dart';
import 'verificacion_widgets.dart';
import '../../tema/cristal.dart';

/// Predicción de licitaciones de una cuenta de la entidad, a partir de su
/// Plan Anual de Adquisiciones: qué piensa contratar, cuándo y por cuánto.
class PrediccionPaaScreen extends StatefulWidget {
  const PrediccionPaaScreen({
    super.key,
    required this.plan,
    required this.titulo,
    required this.entidad,
  });

  final PlanPaa plan;

  /// Nombre uniforme de la cuenta ("Regional Cesar", "Nivel central").
  final String titulo;

  /// Entidad cabeza ("Servicio Nacional de Aprendizaje - SENA").
  final String entidad;

  @override
  State<PrediccionPaaScreen> createState() => _PrediccionPaaScreenState();
}

/// Situación real de una compra del plan, verificada en SECOP II.
enum _Estado { abiertas, porIniciar, enCurso, adjudicadas, vencidas, todas }

class _PrediccionPaaScreenState extends State<PrediccionPaaScreen> {
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
  static const _meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  final _filtroTexto = TextEditingController();

  PlanPaa? _plan;
  List<ItemPaa>? _items;
  String? _errorItems;

  bool _soloCompetitivas = true;
  _Estado _estado = _Estado.porIniciar;

  // Verificación en SECOP II.
  List<ProcesoSecop>? _procesos;
  String? _errorProcesos;
  Map<String, Cruce> _cruces = const {};
  Future<EjecucionPlan>? _ejecucion;
  int? _mes;
  String? _sector;
  int _mostrar = 30;
  String? _abierto;
  final Map<String, Future<List<ContratoReferencia>>> _referencias = {};

  @override
  void dispose() {
    _filtroTexto.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _abrirPlan(widget.plan);
  }

  Future<void> _abrirPlan(PlanPaa p) async {
    setState(() {
      _plan = p;
      _items = null;
      _errorItems = null;
      _mes = null;
      _sector = null;
      _mostrar = 30;
      _abierto = null;
      // De un año ya cerrado no quedan compras por venir.
      _estado = p.anio < DateTime.now().year
          ? _Estado.todas
          : _Estado.porIniciar;
      _referencias.clear();
      _filtroTexto.clear();
      _procesos = null;
      _errorProcesos = null;
      _cruces = const {};
      _ejecucion = VerificacionPaaService.ejecucion(
        p.codigoEntidad,
        p.anio,
        contarSinValor: true,
      );
    });
    final procesos = VerificacionPaaService.procesosDeCuenta(
      p.codigoEntidad,
      p.anio,
    );
    try {
      final items = await PaaService.items(p);
      if (!mounted || _plan != p) return;
      setState(() => _items = items);
    } on PaaException catch (e) {
      if (mounted) setState(() => _errorItems = e.message);
      return;
    }
    try {
      final lista = await procesos;
      if (!mounted || _plan != p) return;
      final cruces = VerificacionPaaService.cruzar(_items!, lista);
      setState(() {
        _procesos = lista;
        _cruces = cruces;
        // Se abre en la primera situación con compras: abiertas hoy, por
        // iniciar o, si no queda nada de eso, todas.
        if (p.anio >= DateTime.now().year) {
          final comp = _items!.where((i) => i.esCompetitiva).map(_situacion);
          _estado = comp.contains(_Estado.abiertas)
              ? _Estado.abiertas
              : comp.contains(_Estado.porIniciar)
              ? _Estado.porIniciar
              : _Estado.todas;
        }
      });
    } on PaaException catch (e) {
      if (mounted) setState(() => _errorProcesos = e.message);
    }
  }

  /// Situación real de la compra: la de su proceso en SECOP II si lo hay;
  /// si no, por iniciar o con la fecha prevista vencida.
  _Estado _situacion(ItemPaa i) {
    final c = _cruces[i.id];
    if (c != null) {
      return switch (c.proceso.estado) {
        EstadoProceso.abierto => _Estado.abiertas,
        EstadoProceso.enCurso ||
        EstadoProceso.estudioMercado => _Estado.enCurso,
        EstadoProceso.adjudicado => _Estado.adjudicadas,
        EstadoProceso.desierto || EstadoProceso.cancelado => _Estado.vencidas,
      };
    }
    // Vinculado por la entidad pero sin datos del proceso: en curso.
    if (i.yaTieneProceso) return _Estado.enCurso;
    return _esProxima(i) ? _Estado.porIniciar : _Estado.vencidas;
  }

  static String _cop(double v) {
    final t = v.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '\$ $t';
  }

  /// "$ 1.234 M" para cifras grandes, con un decimal bajo 10 M.
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

  static String _norm(String t) => t
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('Ñ', 'N');

  /// Sin proceso vinculado y con su mes por venir (o sin mes definido).
  bool _esProxima(ItemPaa i) {
    if (i.yaTieneProceso) return false;
    final ahora = DateTime.now();
    final anio = _plan?.anio ?? ahora.year;
    if (anio != ahora.year) return anio > ahora.year;
    return i.mes == 0 || i.mes >= ahora.month;
  }

  List<ItemPaa> _filtrados({bool conMes = true, bool conEstado = true}) {
    final items = _items ?? const <ItemPaa>[];
    final q = _norm(_filtroTexto.text.trim());
    return items.where((i) {
      if (_soloCompetitivas && !i.esCompetitiva) return false;
      if (conEstado && _estado != _Estado.todas && _situacion(i) != _estado) {
        return false;
      }
      if (conMes && _mes != null && i.mes != _mes) return false;
      if (_sector != null &&
          !i.codigosUnspsc.any((c) => c.startsWith(_sector!))) {
        return false;
      }
      if (q.isNotEmpty && !_norm(i.descripcion).contains(q)) return false;
      return true;
    }).toList()..sort((a, b) {
      final ma = a.mes == 0 ? 13 : a.mes;
      final mb = b.mes == 0 ? 13 : b.mes;
      return ma != mb ? ma.compareTo(mb) : b.valorCop.compareTo(a.valorCop);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
    return PantallaContractual(
      anchoMaximo: 1120,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PildoraVolver(
            etiqueta: 'Volver',
            onTap: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Proyección de contratación',
          style: EstiloContractual.titulo,
        ),
        const SizedBox(height: 6),
        Text(
          '${widget.entidad} · ${widget.titulo}. Lo que proyecta contratar según su Plan Anual de '
          'Adquisiciones, verificado contra los procesos y contratos reales de SECOP II.',
          style: EstiloContractual.subtitulo,
        ),
        const SizedBox(height: 16),
        const AvisoPrediccionPaa(),
        const SizedBox(height: 16),
        ..._vistaPlan(mobile),
        const SizedBox(height: 18),
        const Text(
          'Fuente: SECOP II, Datos Abiertos: PAA (encabezado y detalle), procesos, contratos y '
          'modificaciones a contratos. Cada compra del plan se cuenta una sola vez, en su versión más '
          'reciente. Cuando la entidad no vinculó el proceso, se busca por el parecido del objeto y del valor.',
          style: TextStyle(
            color: Cristal.textoSuave,
            fontSize: 11.5,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Predicción de la cuenta
  // ---------------------------------------------------------------------------

  List<Widget> _vistaPlan(bool mobile) {
    final p = _plan!;
    final items = _items;
    return [
      Container(
        padding: EdgeInsets.all(mobile ? 16 : 22),
        decoration: EstiloContractual.tarjeta(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.titulo,
                        style: const TextStyle(
                          color: Cristal.texto,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Cuenta en SECOP II: ${p.nombreEntidad}',
                        style: const TextStyle(
                          color: Cristal.textoMedio,
                          fontSize: 12.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Con base en el PAA ${p.anio} · versión ${p.version}'
                        '${_fecha(p.actualizadoIso).isEmpty ? '' : ' · actualizado ${_fecha(p.actualizadoIso)}'}',
                        style: const TextStyle(
                          color: Cristal.textoSuave,
                          fontSize: 12.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_errorItems != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _errorItems!,
                      style: const TextStyle(color: Cristal.rojo, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _abrirPlan(p),
                    child: const Text('Reintentar'),
                  ),
                ],
              )
            else if (items == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              _cifras(p, items, mobile),
          ],
        ),
      ),
      if (items != null && items.isNotEmpty) ...[
        const SizedBox(height: 14),
        if (p.anio >= DateTime.now().year) ...[
          PanelProcesosAbiertos(
            procesos: _procesos,
            enPlan: {for (final c in _cruces.values) c.proceso.referencia},
            entidad: widget.entidad,
            error: _errorProcesos,
          ),
          const SizedBox(height: 14),
        ],
        TarjetaEjecucion(
          anio: p.anio,
          proyectadoCop: items.fold<double>(0, (s, i) => s + i.valorCop),
          ejecucion: _ejecucion,
          enProcesoCop: _procesos
              ?.where(
                (x) =>
                    x.estado == EstadoProceso.abierto ||
                    x.estado == EstadoProceso.enCurso,
              )
              .fold<double>(0, (s, x) => s + x.precioBaseCop),
          procesosEnCurso:
              _procesos
                  ?.where(
                    (x) =>
                        x.estado == EstadoProceso.abierto ||
                        x.estado == EstadoProceso.enCurso,
                  )
                  .length ??
              0,
        ),
        const SizedBox(height: 14),
        _calendario(mobile),
        const SizedBox(height: 14),
        _filtros(mobile),
        const SizedBox(height: 12),
        ..._lista(p),
      ],
    ];
  }

  Widget _cifras(PlanPaa p, List<ItemPaa> items, bool mobile) {
    final total = items.fold<double>(0, (s, i) => s + i.valorCop);
    final comp = items.where((i) => i.esCompetitiva).toList();
    final verificado = _procesos != null;
    final abiertas = comp
        .where((i) => _situacion(i) == _Estado.abiertas)
        .toList();
    final porIniciar = comp
        .where((i) => _situacion(i) == _Estado.porIniciar)
        .toList();
    double suma(List<ItemPaa> l) => l.fold<double>(0, (s, i) => s + i.valorCop);
    final valorComp = comp.fold<double>(0, (s, i) => s + i.valorCop);

    Widget cifra(String clave, String valor, String nota) => Container(
      width: mobile ? double.infinity : 250,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Cristal.vidrioSuave,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(clave.toUpperCase(), style: EstiloContractual.seccion),
          const SizedBox(height: 4),
          Text(
            valor,
            style: const TextStyle(
              color: Cristal.texto,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            nota,
            style: const TextStyle(
              color: Cristal.textoSuave,
              fontSize: 12.3,
              height: 1.35,
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            cifra(
              'Valor proyectado',
              _millones(total),
              '${items.length} contrataciones en el PAA',
            ),
            cifra(
              'Procesos competitivos',
              _millones(valorComp),
              '${comp.length} por licitación, selección abreviada, concurso o mínima cuantía',
            ),
            cifra(
              'Abiertas hoy',
              verificado ? _millones(suma(abiertas)) : '…',
              verificado
                  ? '${abiertas.length} de esas compras reciben ofertas hoy en SECOP II'
                  : 'Verificando en SECOP II…',
            ),
            cifra(
              'Por iniciar',
              verificado ? _millones(suma(porIniciar)) : '…',
              verificado
                  ? '${porIniciar.length} sin proceso en SECOP II, con fecha prevista de este mes en adelante'
                  : 'Verificando en SECOP II…',
            ),
          ],
        ),
        if (p.menorCuantiaCop > 0) ...[
          const SizedBox(height: 12),
          Text(
            'Topes de la entidad para ${p.anio}: menor cuantía hasta ${_cop(p.menorCuantiaCop)} '
            'y mínima cuantía hasta ${_cop(p.minimaCuantiaCop)}. Por encima de la menor cuantía, '
            'la compra suele ir por licitación pública.',
            style: const TextStyle(
              color: Cristal.textoMedio,
              fontSize: 12.8,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }

  Widget _calendario(bool mobile) {
    // Todo el plan, con o sin proceso: muestra cuándo suele contratar.
    final base = _filtrados(conMes: false, conEstado: false);
    final porMes = List<double>.filled(12, 0);
    final cuenta = List<int>.filled(12, 0);
    for (final i in base) {
      if (i.mes >= 1) {
        porMes[i.mes - 1] += i.valorCop;
        cuenta[i.mes - 1]++;
      }
    }
    final maximo = porMes.fold<double>(1, (m, v) => v > m ? v : m);
    final ahora = DateTime.now();
    final mesActual = _plan!.anio == ahora.year ? ahora.month : 0;
    return Container(
      padding: EdgeInsets.all(mobile ? 16 : 22),
      decoration: EstiloContractual.tarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '¿Cuándo proyecta contratar?',
            style: EstiloContractual.tituloGrupo,
          ),
          const SizedBox(height: 4),
          Text(
            _mes == null
                ? 'Valor de todas las contrataciones previstas por mes esperado de inicio (con los filtros de abajo). '
                      'Toca un mes para ver solo sus compras.'
                : 'Mostrando ${_meses[_mes! - 1]}. Toca de nuevo para ver todo el año.',
            style: const TextStyle(color: Cristal.textoSuave, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var m = 1; m <= 12; m++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      label:
                          '${_meses[m - 1]}: ${cuenta[m - 1]} compras, ${_millones(porMes[m - 1])}',
                      child: InkWell(
                        hoverDuration: Cristal.micro,
                        onTap: () => setState(() {
                          _mes = _mes == m ? null : m;
                          _mostrar = 30;
                        }),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: mobile ? 1.5 : 4,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (!mobile && cuenta[m - 1] > 0)
                                Text(
                                  '${cuenta[m - 1]}',
                                  style: const TextStyle(
                                    color: Cristal.textoSuave,
                                    fontSize: 11.5,
                                  ),
                                ),
                              const SizedBox(height: 3),
                              Container(
                                height: porMes[m - 1] <= 0
                                    ? 3
                                    : 4 + 96 * porMes[m - 1] / maximo,
                                decoration: BoxDecoration(
                                  color: _mes == m
                                      ? Cristal.acentoVidrio
                                      : (m < mesActual
                                            ? Cristal.vidrioIntenso
                                            : const Color(0xFF7FA6D9)),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _mesesCortos[m - 1],
                                style: TextStyle(
                                  color: m == mesActual
                                      ? Cristal.texto
                                      : Cristal.textoSuave,
                                  fontSize: 11.5,
                                  fontWeight: m == mesActual
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (mesActual > 1) ...[
            const SizedBox(height: 8),
            const Text(
              'En gris, los meses que ya pasaron.',
              style: TextStyle(color: Cristal.textoSuave, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filtros(bool mobile) {
    final sectores = <String, int>{};
    for (final i in _items!) {
      if (_soloCompetitivas && !i.esCompetitiva) continue;
      for (final s in {for (final c in i.codigosUnspsc) c.substring(0, 2)}) {
        sectores[s] = (sectores[s] ?? 0) + 1;
      }
    }
    final ordenados = sectores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: EdgeInsets.all(mobile ? 14 : 18),
      decoration: EstiloContractual.tarjeta(),
      // Material propio para que el interruptor pinte su efecto.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (e, t) in [
                  (_Estado.abiertas, 'Abiertas para ofertas'),
                  (_Estado.porIniciar, 'Por iniciar'),
                  (_Estado.enCurso, 'En evaluación'),
                  (_Estado.adjudicadas, 'Adjudicadas'),
                  (_Estado.vencidas, 'Fecha vencida sin proceso'),
                  (_Estado.todas, 'Todas'),
                ])
                  ChoiceChip(
                    label: Text(t),
                    selected: _estado == e,
                    selectedColor: Cristal.azulVidrio,
                    checkmarkColor: Cristal.texto,
                    labelStyle: TextStyle(
                      color: Cristal.texto,
                      fontWeight: _estado == e
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                    onSelected: (_) => setState(() {
                      _estado = e;
                      _mostrar = 30;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _procesos == null
                  ? 'Verificando cada compra contra los procesos de SECOP II…'
                  : 'Cada compra se verificó contra los ${_procesos!.length} procesos que la cuenta '
                        'publicó en SECOP II desde enero: por la referencia que vinculó la entidad o, si no '
                        'la vinculó, por el parecido del objeto y del valor.',
              style: TextStyle(
                color: Cristal.textoSuave,
                fontSize: 12.3,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _soloCompetitivas,
              onChanged: (v) => setState(() {
                _soloCompetitivas = v;
                _sector = null;
                _mostrar = 30;
              }),
              title: const Text(
                'Solo compras donde una empresa puede competir',
                style: TextStyle(
                  color: Cristal.texto,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text(
                'Quita la contratación directa, que casi siempre es prestación de servicios de personas.',
                style: TextStyle(color: Cristal.textoSuave, fontSize: 12.3),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: mobile ? double.infinity : 360,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _sector,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Sector (UNSPSC)',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todos los sectores'),
                      ),
                      for (final e in ordenados)
                        DropdownMenuItem<String?>(
                          value: e.key,
                          child: Text(
                            '${segmentosUnspsc[e.key] ?? 'Segmento ${e.key}'} (${e.value})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _sector = v;
                      _mostrar = 30;
                    }),
                  ),
                ),
                SizedBox(
                  width: mobile ? double.infinity : 320,
                  child: TextField(
                    controller: _filtroTexto,
                    onChanged: (_) => setState(() => _mostrar = 30),
                    decoration: InputDecoration(
                      labelText:
                          'Buscar en las compras (ej. mantenimiento, dotación)',
                      isDense: true,
                      prefixIcon: const Icon(
                        Icons.filter_list_rounded,
                        size: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _lista(PlanPaa p) {
    final lista = _filtrados();
    final valor = lista.fold<double>(0, (s, i) => s + i.valorCop);
    final ahora = DateTime.now();
    return [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          '${lista.length} compra${lista.length == 1 ? '' : 's'} · ${_millones(valor)}',
          style: const TextStyle(
            color: Cristal.texto,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      if (lista.isEmpty)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: EstiloContractual.tarjeta(),
          child: Text(
            _estado == _Estado.porIniciar && p.anio == ahora.year
                ? 'No quedan compras sin iniciar en lo que resta de ${p.anio} con estos filtros. '
                      'Revisa "Abiertas para ofertas" y los procesos abiertos hoy, o espera el PAA '
                      '${p.anio + 1}, que las entidades publican a más tardar el 31 de enero.'
                : 'Ninguna compra del plan coincide con los filtros.',
            style: const TextStyle(
              color: Cristal.textoSuave,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      for (final i in lista.take(_mostrar))
        _TarjetaCompra(
          item: i,
          mesTexto: i.mes == 0
              ? 'Mes sin definir'
              : 'Inicio esperado: ${_meses[i.mes - 1]}',
          situacion: _situacion(i),
          verificando: _procesos == null && _errorProcesos == null,
          cruce: _cruces[i.id],
          anio: p.anio,
          valor: _cop(i.valorCop),
          abierta: _abierto == i.id,
          onTap: () =>
              setState(() => _abierto = _abierto == i.id ? null : i.id),
          referencias: _referencias[i.id],
          onReferencias: i.codigosUnspsc.isEmpty
              ? null
              : () => setState(
                  () => _referencias[i.id] = PaaService.contratosParecidos(
                    nombreEntidad: p.nombreEntidad,
                    codigoUnspsc: i.codigosUnspsc.first,
                  ),
                ),
          cop: _cop,
          fecha: _fecha,
        ),
      if (lista.length > _mostrar)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Center(
            child: OutlinedButton(
              onPressed: () => setState(() => _mostrar += 30),
              style: EstiloContractual.botonSecundario(),
              child: Text(
                'Ver más (${lista.length - _mostrar} restantes)',
                style: EstiloContractual.etiquetaBoton,
              ),
            ),
          ),
        ),
    ];
  }
}

class AvisoPrediccionPaa extends StatelessWidget {
  const AvisoPrediccionPaa({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Cristal.ambarVidrio,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Cristal.ambarBorde),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Cristal.ambar, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Es una proyección, no un compromiso: el PAA es la planeación de la entidad y durante el año '
              'puede cambiar fechas, valores o quitar compras. El estado de cada compra se verifica contra '
              'SECOP II, pero los requisitos exactos (experiencia, capacidad financiera) solo se conocen en '
              'el pliego del proceso.',
              style: TextStyle(
                color: Cristal.ambar,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaCompra extends StatelessWidget {
  const _TarjetaCompra({
    required this.item,
    required this.mesTexto,
    required this.situacion,
    required this.verificando,
    required this.cruce,
    required this.anio,
    required this.valor,
    required this.abierta,
    required this.onTap,
    required this.referencias,
    required this.onReferencias,
    required this.cop,
    required this.fecha,
  });

  final ItemPaa item;
  final String mesTexto;
  final _Estado situacion;
  final bool verificando;
  final Cruce? cruce;
  final int anio;
  final String valor;
  final bool abierta;
  final VoidCallback onTap;
  final Future<List<ContratoReferencia>>? referencias;
  final VoidCallback? onReferencias;
  final String Function(double) cop;
  final String Function(String) fecha;

  @override
  Widget build(BuildContext context) {
    final i = item;
    final estado = verificando
        ? const EtiquetaColor(
            texto: 'Verificando en SECOP II…',
            color: Cristal.textoSuave,
            fondo: Cristal.vidrioSuave,
          )
        : cruce != null
        ? EtiquetaColor(
            texto: cruce!.proceso.estado.etiqueta,
            color: coloresEstado(cruce!.proceso.estado).$1,
            fondo: coloresEstado(cruce!.proceso.estado).$2,
          )
        : switch (situacion) {
            _Estado.porIniciar => const EtiquetaColor(
              texto: 'Por iniciar',
              color: Cristal.ambar,
              fondo: Cristal.ambarVidrio,
            ),
            _Estado.enCurso => const EtiquetaColor(
              texto: 'Proceso vinculado',
              color: Cristal.acentoClaro,
              fondo: Cristal.azulVidrio,
            ),
            _ => const EtiquetaColor(
              texto: 'Fecha vencida, sin proceso en SECOP II',
              color: Cristal.textoSuave,
              fondo: Cristal.vidrioSuave,
            ),
          };

    Widget dato(String clave, String valor) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(clave.toUpperCase(), style: EstiloContractual.seccion),
          const SizedBox(height: 2),
          Text(
            valor,
            style: const TextStyle(
              color: Cristal.texto,
              fontSize: 13.2,
              height: 1.4,
            ),
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: EstiloContractual.tarjeta(),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          hoverDuration: Cristal.micro,
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    EtiquetaColor(
                      texto: mesTexto,
                      color: Cristal.texto,
                      fondo: Cristal.vidrioSuave,
                      icono: Icons.event_rounded,
                    ),
                    if (i.modalidad.isNotEmpty)
                      EtiquetaColor(
                        texto: TextoProfesional.etiqueta(i.modalidad),
                        color: Cristal.acentoClaro,
                        fondo: Cristal.azulVidrio,
                      ),
                    estado,
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        i.descripcion,
                        maxLines: abierta ? null : 3,
                        overflow: abierta ? null : TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Cristal.texto,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
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
                const SizedBox(height: 8),
                Text(
                  [
                    valor,
                    if (i.duracion.isNotEmpty) 'duración ${i.duracion}',
                  ].join(' · '),
                  style: const TextStyle(
                    color: Cristal.texto,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (abierta) ...[
                  const SizedBox(height: 6),
                  const Divider(height: 18, color: Cristal.borde),
                  if (i.codigosUnspsc.isNotEmpty)
                    dato(
                      'Códigos UNSPSC',
                      [
                        for (final c in i.codigosUnspsc)
                          sectorUnspsc(c).isEmpty
                              ? c
                              : '$c · ${sectorUnspsc(c)}',
                      ].join('\n'),
                    ),
                  if (i.codigosUnspsc.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'La experiencia se acredita en el RUP con códigos UNSPSC; estos son los que la entidad '
                        'asignó a la compra. El pliego dirá cuáles exige y por qué valor.',
                        style: TextStyle(
                          color: Cristal.textoSuave,
                          fontSize: 12.3,
                          height: 1.4,
                        ),
                      ),
                    ),
                  if (i.origenRecursos.isNotEmpty)
                    dato('Origen de los recursos', i.origenRecursos),
                  if (i.contactoNombre.isNotEmpty ||
                      i.contactoCorreo.isNotEmpty)
                    dato(
                      'Contacto en la entidad',
                      [
                        TextoProfesional.titulo(i.contactoNombre),
                        i.contactoCorreo,
                      ].where((t) => t.isNotEmpty).join(' · '),
                    ),
                  DetalleVerificacion(
                    item: i,
                    cruce: cruce,
                    verificando: verificando,
                    anio: anio,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (cruce == null && i.urlProceso.startsWith('http'))
                        OutlinedButton.icon(
                          onPressed: () => launchUrl(Uri.parse(i.urlProceso)),
                          style: EstiloContractual.botonSecundario(),
                          icon: const Icon(Icons.open_in_new_rounded, size: 17),
                          label: const Text(
                            'Ver el proceso en SECOP II',
                            style: EstiloContractual.etiquetaBoton,
                          ),
                        ),
                      if (onReferencias != null && referencias == null)
                        OutlinedButton.icon(
                          onPressed: onReferencias,
                          style: EstiloContractual.botonSecundario(),
                          icon: const Icon(Icons.history_rounded, size: 17),
                          label: const Text(
                            'Contratos parecidos que ya firmó',
                            style: EstiloContractual.etiquetaBoton,
                          ),
                        ),
                    ],
                  ),
                  if (referencias != null)
                    FutureBuilder<List<ContratoReferencia>>(
                      future: referencias,
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Text(
                              'No fue posible consultar los contratos. Intenta de nuevo.',
                              style: TextStyle(
                                color: Cristal.rojo,
                                fontSize: 12.8,
                              ),
                            ),
                          );
                        }
                        if (!snap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: LinearProgressIndicator(minHeight: 3),
                          );
                        }
                        final refs = snap.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 12),
                            Text(
                              refs.isEmpty
                                  ? 'La entidad no tiene contratos recientes en SECOP II con el código ${i.codigosUnspsc.first.substring(0, 6)}.'
                                  : 'Últimos contratos de esta entidad con el código ${i.codigosUnspsc.first.substring(0, 6)}: '
                                        'te muestran qué valores maneja y quién se los ha ganado.',
                              style: const TextStyle(
                                color: Cristal.textoSuave,
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                            for (final r in refs)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Cristal.vidrioSuave,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      [
                                        cop(r.valorCop),
                                        fecha(r.fechaIso),
                                        r.modalidad,
                                      ].where((t) => t.isNotEmpty).join(' · '),
                                      style: const TextStyle(
                                        color: Cristal.texto,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if (r.proveedor.isNotEmpty)
                                      Text(
                                        r.proveedor,
                                        style: const TextStyle(
                                          color: Cristal.texto,
                                          fontSize: 12.8,
                                        ),
                                      ),
                                    const SizedBox(height: 2),
                                    Text(
                                      r.objeto,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Cristal.textoSuave,
                                        fontSize: 12.3,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
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
