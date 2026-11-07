import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/paa_service.dart';
import '../gestion_contractual/estilo_contractual.dart';

/// Empresa licitante: qué piensa contratar cada entidad durante el año según
/// su Plan Anual de Adquisiciones, para prepararse antes de que salga el
/// proceso.
class OportunidadesPaaSection extends StatefulWidget {
  const OportunidadesPaaSection({super.key});

  @override
  State<OportunidadesPaaSection> createState() =>
      _OportunidadesPaaSectionState();
}

enum _Estado { proximas, pasadas, publicadas, todas }

class _OportunidadesPaaSectionState extends State<OportunidadesPaaSection> {
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

  final _busqueda = TextEditingController();
  final _filtroTexto = TextEditingController();
  late int _anio = DateTime.now().year;

  List<PlanPaa>? _planes;
  bool _buscando = false;
  String? _errorBusqueda;

  PlanPaa? _plan;
  List<ItemPaa>? _items;
  String? _errorItems;

  bool _soloCompetitivas = true;
  _Estado _estado = _Estado.proximas;
  int? _mes;
  String? _sector;
  int _mostrar = 30;
  String? _abierto;
  final Map<String, Future<List<ContratoReferencia>>> _referencias = {};

  @override
  void dispose() {
    _busqueda.dispose();
    _filtroTexto.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final t = _busqueda.text.trim();
    if (t.length < 3) {
      setState(
        () => _errorBusqueda =
            'Escribe al menos 3 letras del nombre de la entidad.',
      );
      return;
    }
    setState(() {
      _buscando = true;
      _errorBusqueda = null;
      _planes = null;
    });
    try {
      final planes = await PaaService.buscarPlanes(t, _anio);
      if (!mounted) return;
      setState(() => _planes = planes);
    } on PaaException catch (e) {
      if (mounted) setState(() => _errorBusqueda = e.message);
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
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
      _estado = p.anio < DateTime.now().year ? _Estado.todas : _Estado.proximas;
      _referencias.clear();
      _filtroTexto.clear();
    });
    try {
      final items = await PaaService.items(p);
      if (!mounted || _plan != p) return;
      setState(() => _items = items);
    } on PaaException catch (e) {
      if (mounted) setState(() => _errorItems = e.message);
    }
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
      final proxima = _esProxima(i);
      if (conEstado) {
        if (_estado == _Estado.proximas && !proxima) return false;
        if (_estado == _Estado.pasadas && (proxima || i.yaTieneProceso)) {
          return false;
        }
        if (_estado == _Estado.publicadas && !i.yaTieneProceso) return false;
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
    return Container(
      color: EstiloContractual.crema,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: mobile ? 16 : 36,
          vertical: mobile ? 16 : 28,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Plan de compras de las entidades',
                  style: EstiloContractual.titulo,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Lo que cada entidad publicó en su Plan Anual de Adquisiciones (PAA): qué piensa contratar, '
                  'en qué mes y por cuánto. Úsalo para preparar tu oferta antes de que salga el proceso.',
                  style: EstiloContractual.subtitulo,
                ),
                const SizedBox(height: 16),
                const _AvisoPrediccion(),
                const SizedBox(height: 16),
                if (_plan == null) _buscador(mobile) else ..._vistaPlan(mobile),
                const SizedBox(height: 18),
                const Text(
                  'Fuente: SECOP II, Datos Abiertos (PAA encabezado y detalle; contratos). '
                  'Cada compra del plan se cuenta una sola vez, en su versión más reciente.',
                  style: TextStyle(
                    color: EstiloContractual.gris,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Búsqueda de la entidad
  // ---------------------------------------------------------------------------

  Widget _buscador(bool mobile) {
    final anios = [
      DateTime.now().year + 1,
      DateTime.now().year,
      DateTime.now().year - 1,
    ];
    final campo = TextField(
      controller: _busqueda,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _buscar(),
      decoration: InputDecoration(
        hintText: 'Nombre de la entidad (ej. SENA Regional Cesar, Alcaldía de Valledupar)',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: EstiloContractual.borde),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: EstiloContractual.borde),
        ),
      ),
    );
    final boton = FilledButton.icon(
      onPressed: _buscando ? null : _buscar,
      style: EstiloContractual.botonPrincipal(),
      icon: const Icon(Icons.search_rounded, size: 19),
      label: const Text('Buscar plan', style: EstiloContractual.etiquetaBoton),
    );
    return Container(
      padding: EdgeInsets.all(mobile ? 16 : 22),
      decoration: EstiloContractual.tarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '¿De qué entidad quieres ver el plan?',
            style: EstiloContractual.tituloGrupo,
          ),
          const SizedBox(height: 12),
          if (mobile) ...[
            campo,
            const SizedBox(height: 10),
            boton,
          ] else
            Row(
              children: [
                Expanded(child: campo),
                const SizedBox(width: 12),
                boton,
              ],
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Año del plan:',
                style: TextStyle(color: EstiloContractual.texto, fontSize: 13),
              ),
              for (final a in anios)
                ChoiceChip(
                  label: Text('$a'),
                  selected: _anio == a,
                  selectedColor: const Color(0xFFDCE6F5),
                  checkmarkColor: EstiloContractual.navy,
                  onSelected: (_) {
                    setState(() => _anio = a);
                    if (_busqueda.text.trim().length >= 3) _buscar();
                  },
                ),
            ],
          ),
          if (_errorBusqueda != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorBusqueda!,
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
            ),
          ],
          if (_buscando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_planes != null) ...[
            const SizedBox(height: 16),
            if (_planes!.isEmpty)
              Text(
                _anio > DateTime.now().year
                    ? 'Aún no hay planes $_anio con ese nombre. Las entidades publican el PAA del año a más tardar el 31 de enero.'
                    : 'No encontramos planes $_anio con ese nombre. Prueba con otra parte del nombre (ej. "Cesar" o "Valledupar").',
                style: const TextStyle(
                  color: EstiloContractual.gris,
                  fontSize: 13,
                ),
              )
            else ...[
              Text(
                '${_planes!.length} plan${_planes!.length == 1 ? '' : 'es'} $_anio',
                style: const TextStyle(
                  color: EstiloContractual.gris,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 6),
              for (final (i, p) in _planes!.take(60).indexed) ...[
                if (i > 0) const Divider(height: 1, color: Color(0xFFEDF0F4)),
                InkWell(
                  onTap: () => _abrirPlan(p),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.nombreEntidad,
                                style: const TextStyle(
                                  color: EstiloContractual.navy,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if (p.municipio.isNotEmpty &&
                                      p.municipio != 'No definido')
                                    p.municipio,
                                  'versión ${p.version}',
                                  if (_fecha(p.actualizadoIso).isNotEmpty)
                                    'actualizado ${_fecha(p.actualizadoIso)}',
                                ].join(' · '),
                                style: const TextStyle(
                                  color: EstiloContractual.gris,
                                  fontSize: 12.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _millones(p.presupuestoGeneralCop),
                          style: const TextStyle(
                            color: EstiloContractual.navy,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: EstiloContractual.gris,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Plan de una entidad
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
                        p.nombreEntidad,
                        style: const TextStyle(
                          color: EstiloContractual.navy,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'PAA ${p.anio} · versión ${p.version}'
                        '${_fecha(p.actualizadoIso).isEmpty ? '' : ' · actualizado ${_fecha(p.actualizadoIso)}'}',
                        style: const TextStyle(
                          color: EstiloContractual.gris,
                          fontSize: 12.8,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _plan = null;
                    _items = null;
                  }),
                  style: EstiloContractual.botonSecundario(),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text(
                    'Otra entidad',
                    style: EstiloContractual.etiquetaBoton,
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
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 13,
                      ),
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
    final porSalir = comp.where(_esProxima).toList();
    final valorPorSalir = porSalir.fold<double>(0, (s, i) => s + i.valorCop);
    final valorComp = comp.fold<double>(0, (s, i) => s + i.valorCop);

    Widget cifra(String clave, String valor, String nota) => Container(
      width: mobile ? double.infinity : 250,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
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
              color: EstiloContractual.navy,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            nota,
            style: const TextStyle(
              color: EstiloContractual.gris,
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
              'Valor del plan',
              _millones(total),
              '${items.length} compras planeadas',
            ),
            cifra(
              'Donde una empresa compite',
              _millones(valorComp),
              '${comp.length} compras por licitación, selección abreviada, concurso o mínima cuantía',
            ),
            cifra(
              'Próximas',
              _millones(valorPorSalir),
              '${porSalir.length} de esas compras son de este mes en adelante y aún no tienen proceso vinculado',
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
              color: EstiloContractual.texto,
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
            '¿Cuándo piensa contratar?',
            style: EstiloContractual.tituloGrupo,
          ),
          const SizedBox(height: 4),
          Text(
            _mes == null
                ? 'Valor de todas las compras del plan por mes esperado de inicio (con los filtros de abajo). '
                      'Toca un mes para ver solo sus compras.'
                : 'Mostrando ${_meses[_mes! - 1]}. Toca de nuevo para ver todo el año.',
            style: const TextStyle(
              color: EstiloContractual.gris,
              fontSize: 12.5,
            ),
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
                                    color: EstiloContractual.gris,
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
                                      ? EstiloContractual.navy
                                      : (m < mesActual
                                            ? const Color(0xFFCBD5E1)
                                            : const Color(0xFF7FA6D9)),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _mesesCortos[m - 1],
                                style: TextStyle(
                                  color: m == mesActual
                                      ? EstiloContractual.navy
                                      : EstiloContractual.gris,
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
              style: TextStyle(color: EstiloContractual.gris, fontSize: 11.5),
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
                  (_Estado.proximas, 'Próximas'),
                  (_Estado.pasadas, 'Su mes ya pasó'),
                  (_Estado.publicadas, 'Con proceso en SECOP II'),
                  (_Estado.todas, 'Todas'),
                ])
                  ChoiceChip(
                    label: Text(t),
                    selected: _estado == e,
                    selectedColor: const Color(0xFFDCE6F5),
                    checkmarkColor: EstiloContractual.navy,
                    labelStyle: TextStyle(
                      color: EstiloContractual.navy,
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
            const Text(
              '"Con proceso" significa que la entidad vinculó la compra a un proceso de SECOP II. '
              'Si no la vinculó, el proceso puede existir igual: búscalo por el objeto.',
              style: TextStyle(
                color: EstiloContractual.gris,
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
                  color: EstiloContractual.navy,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text(
                'Quita la contratación directa, que casi siempre es prestación de servicios de personas.',
                style: TextStyle(color: EstiloContractual.gris, fontSize: 12.3),
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
            color: EstiloContractual.navy,
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
            _estado == _Estado.proximas && p.anio == ahora.year
                ? 'No quedan compras por venir en lo que resta de ${p.anio} con estos filtros. '
                      'Revisa "Su mes ya pasó" o espera el PAA ${p.anio + 1}, que las entidades '
                      'publican a más tardar el 31 de enero.'
                : 'Ninguna compra del plan coincide con los filtros.',
            style: const TextStyle(
              color: EstiloContractual.gris,
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
          mesPasado:
              !i.yaTieneProceso &&
              p.anio == ahora.year &&
              i.mes > 0 &&
              i.mes < ahora.month,
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

class _AvisoPrediccion extends StatelessWidget {
  const _AvisoPrediccion();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Esto es una predicción, no un compromiso. El PAA es la planeación de la entidad: '
              'durante el año puede cambiar fechas, valores o quitar compras. Los requisitos exactos '
              '(experiencia, capacidad financiera) solo se conocen cuando la entidad publica el proceso en SECOP II.',
              style: TextStyle(
                color: Color(0xFF78350F),
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
    required this.mesPasado,
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
  final bool mesPasado;
  final String valor;
  final bool abierta;
  final VoidCallback onTap;
  final Future<List<ContratoReferencia>>? referencias;
  final VoidCallback? onReferencias;
  final String Function(double) cop;
  final String Function(String) fecha;

  static const _navy = EstiloContractual.navy;
  static const _gris = EstiloContractual.gris;

  @override
  Widget build(BuildContext context) {
    final i = item;
    final estado = i.yaTieneProceso
        ? const EtiquetaColor(
            texto: 'Con proceso en SECOP II',
            color: Color(0xFF15803D),
            fondo: Color(0xFFDCFCE7),
          )
        : mesPasado
        ? const EtiquetaColor(
            texto: 'Su mes ya pasó, sin proceso vinculado',
            color: Color(0xFF64748B),
            fondo: Color(0xFFF1F5F9),
          )
        : const EtiquetaColor(
            texto: 'Próxima',
            color: Color(0xFFB45309),
            fondo: Color(0xFFFEF3C7),
          );

    Widget dato(String clave, String valor) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(clave.toUpperCase(), style: EstiloContractual.seccion),
          const SizedBox(height: 2),
          Text(
            valor,
            style: const TextStyle(color: _navy, fontSize: 13.2, height: 1.4),
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
                      color: _navy,
                      fondo: const Color(0xFFEFF4FB),
                      icono: Icons.event_rounded,
                    ),
                    if (i.modalidad.isNotEmpty)
                      EtiquetaColor(
                        texto:
                            i.modalidad[0] +
                            i.modalidad.substring(1).toLowerCase(),
                        color: const Color(0xFF1D4ED8),
                        fondo: const Color(0xFFEFF6FF),
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
                          color: _navy,
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
                      color: _gris,
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
                    color: _navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (abierta) ...[
                  const SizedBox(height: 6),
                  const Divider(height: 18, color: Color(0xFFEDF0F4)),
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
                          color: _gris,
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
                        i.contactoNombre,
                        i.contactoCorreo,
                      ].where((t) => t.isNotEmpty).join(' · '),
                    ),
                  if (i.yaTieneProceso)
                    dato('Proceso en SECOP II', i.procesoRelacionado),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (i.urlProceso.startsWith('http'))
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
                                color: Color(0xFFB91C1C),
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
                                color: _gris,
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                            for (final r in refs)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
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
                                        color: _navy,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if (r.proveedor.isNotEmpty)
                                      Text(
                                        r.proveedor,
                                        style: const TextStyle(
                                          color: _navy,
                                          fontSize: 12.8,
                                        ),
                                      ),
                                    const SizedBox(height: 2),
                                    Text(
                                      r.objeto,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _gris,
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
