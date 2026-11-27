import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../widgets/campo_busqueda.dart';
import '../../services/procesos_secop_service.dart';
import '../../data/colombia_entities_database.dart';
import '../../widgets/archivo_entidad_secop_i.dart';
import '../../tema/cristal.dart';
import '../../utils/banderas_control.dart';
import '../../widgets/estado_proceso_chip.dart';
import '../../widgets/linea_tiempo_proceso.dart';
import '../detalle_proceso_screen.dart';

class ProcesosSection extends StatefulWidget {
  const ProcesosSection({
    super.key,
    this.nombreEntidad,
    this.nitEntidad = '',
    this.departamento = '',
  });

  final String? nombreEntidad;
  final String nitEntidad;
  final String departamento;

  @override
  State<ProcesosSection> createState() => _ProcesosSectionState();
}

class _ProcesosSectionState extends State<ProcesosSection> {
  final _entrada = TextEditingController();
  final _procesos = <ProcesoSecop>[];
  final _vistos = <String>{};
  String _texto = '';
  CampoBusquedaProceso _campo = CampoBusquedaProceso.general;
  FiltroEstadoProceso _estado = FiltroEstadoProceso.todos;
  PeriodoProcesos _periodo = PeriodoProcesos.todo;
  ModalidadProceso _modalidad = ModalidadProceso.todas;
  int _consulta = 0;
  CursorProcesos? _siguiente;
  bool _cargando = true;
  bool _error = false;

  bool get _enEntidad => widget.nombreEntidad != null;

  @override
  void initState() {
    super.initState();
    _cargar(reiniciar: true);
  }

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  void _aplicar() {
    _texto = _entrada.text.trim();
    _cargar(reiniciar: true);
  }

  void _limpiar() {
    _entrada.clear();
    _campo = CampoBusquedaProceso.general;
    _estado = FiltroEstadoProceso.todos;
    _periodo = PeriodoProcesos.todo;
    _modalidad = ModalidadProceso.todas;
    _aplicar();
  }

  Future<void> _cargar({required bool reiniciar}) async {
    final desde = reiniciar ? const CursorProcesos() : _siguiente;
    if (desde == null || (!reiniciar && _cargando)) return;
    final consulta = ++_consulta;
    setState(() {
      _cargando = true;
      _error = false;
      if (reiniciar) {
        _procesos.clear();
        _vistos.clear();
        _siguiente = const CursorProcesos();
      }
    });
    try {
      final pagina = await ProcesosSecopService.buscarPagina(
        texto: _texto,
        campo: _campo,
        estado: _estado,
        periodo: _periodo,
        modalidad: _modalidad,
        desde: desde,
        nitEntidad: widget.nitEntidad,
        departamento: widget.departamento,
        entidad: widget.nitEntidad.isEmpty ? widget.nombreEntidad ?? '' : '',
      );
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _procesos.addAll(
          pagina.procesos.where(
            (p) => p.idCompartido.isEmpty || _vistos.add(p.idCompartido),
          ),
        );
        _siguiente = pagina.siguiente;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _cargando = false;
        _error = true;
      });
    }
  }

  void _verDetalle(ProcesoSecop proceso) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetalleProcesoScreen(proceso: proceso),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entidad = _enEntidad || _campo == CampoBusquedaProceso.referencia
        ? null
        : ColombiaEntitiesDatabase.entidadExacta(_texto);
    return LayoutBuilder(
      builder: (context, caja) {
        final margen = caja.maxWidth >= 700 ? 26.0 : 16.0;
        final extra = caja.maxWidth > 1232 ? (caja.maxWidth - 1232) / 2 : 0.0;
        final ancho = margen + extra;
        final columnas = caja.maxWidth - 2 * ancho >= 680 ? 2 : 1;

        return CustomScrollView(
          slivers: [
            if (!_enEntidad)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(ancho, margen, ancho, 16),
                sliver: SliverToBoxAdapter(child: _cabecera()),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                ancho,
                _enEntidad ? margen : 0,
                ancho,
                16,
              ),
              sliver: SliverToBoxAdapter(child: _filtros()),
            ),
            if (entidad != null)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(ancho, 0, ancho, 12),
                sliver: SliverToBoxAdapter(
                  child: ArchivoEntidadSecopI(
                    key: ValueKey(entidad.nit),
                    nit: entidad.nit,
                    nombre: entidad.name,
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(ancho, 0, ancho, 12),
              sliver: SliverToBoxAdapter(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _estado == FiltroEstadoProceso.todos
                          ? 'Resultados'
                          : _estado.etiqueta,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      _procesos.isNotEmpty
                          ? '${_procesos.length} ${_procesos.length == 1 ? 'proceso mostrado' : 'procesos mostrados'}'
                          : _estado == FiltroEstadoProceso.desiertos
                          ? 'Declaratorias reportadas en SECOP II'
                          : 'Procesos publicados en SECOP II',
                      style: TextStyle(color: Cristal.textoMedio),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: ancho),
              sliver: SliverList.builder(
                itemCount: (_procesos.length + columnas - 1) ~/ columnas,
                itemBuilder: (context, fila) {
                  final i = fila * columnas;
                  Widget tarjeta(int j) => _TarjetaProceso(
                    proceso: _procesos[j],
                    onTap: () => _verDetalle(_procesos[j]),
                    alineada: columnas > 1,
                  );

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: columnas == 1
                        ? tarjeta(i)
                        : IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: tarjeta(i)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: i + 1 < _procesos.length
                                      ? tarjeta(i + 1)
                                      : const SizedBox(),
                                ),
                              ],
                            ),
                          ),
                  );
                },
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(ancho, 0, ancho, 28),
              sliver: SliverToBoxAdapter(child: _pie()),
            ),
          ],
        );
      },
    );
  }

  Widget _cabecera() => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: Stack(
      children: [
        const Positioned.fill(child: FotoAmbiente.cabecera()),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 23, 22, 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Cristal.borde),
            gradient: LinearGradient(
              colors: [
                Cristal.fondo.withValues(alpha: .93),
                Cristal.fondo.withValues(alpha: .48),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 36, height: 3, color: Cristal.dorado),
              const SizedBox(height: 12),
              Text(
                'Procesos',
                style: TextStyle(
                  fontSize: 35,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.8,
                  color: Cristal.texto,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Encuentra convocatorias públicas y consulta sus plazos y etapas.',
                style: TextStyle(
                  color: Cristal.textoCuerpo,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _filtros() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Cristal.vidrio,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Cristal.borde),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final campo in CampoBusquedaProceso.values)
              if (!_enEntidad || campo != CampoBusquedaProceso.entidad)
                ChoiceChip(
                  label: Text(campo.etiqueta),
                  selected: campo == _campo,
                  onSelected: (_) {
                    if (campo == _campo) return;
                    _campo = campo;
                    _aplicar();
                  },
                ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, caja) {
            final entrada = CampoBusqueda(
              controller: _entrada,
              maxLength: 140,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _aplicar(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                counterText: '',
                labelText: switch (_campo) {
                  CampoBusquedaProceso.general =>
                    _enEntidad
                        ? 'Busca por objeto o número de proceso'
                        : 'Busca por objeto, entidad o número',
                  CampoBusquedaProceso.referencia => 'Número o código SECOP',
                  CampoBusquedaProceso.entidad => 'Nombre de la entidad o NIT',
                },
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _entrada.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Borrar búsqueda',
                        onPressed: () {
                          _entrada.clear();
                          _aplicar();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            );
            final buscar = FilledButton.icon(
              onPressed: _aplicar,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Buscar'),
            );
            return caja.maxWidth < 490
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [entrada, const SizedBox(height: 8), buscar],
                  )
                : Row(
                    children: [
                      Expanded(child: entrada),
                      const SizedBox(width: 10),
                      buscar,
                    ],
                  );
          },
        ),
        const SizedBox(height: 14),
        Divider(height: 1, color: Cristal.borde),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _menuFiltro(
              valor: _estado,
              opciones: FiltroEstadoProceso.values,
              etiqueta: (estado) => estado == FiltroEstadoProceso.todos
                  ? 'Todos los estados'
                  : estado.etiqueta,
              ayuda: 'Filtrar por estado',
              icono: Icons.tune_rounded,
              alCambiar: (estado) {
                if (_estado == estado) return;
                _estado = estado;
                _aplicar();
              },
            ),
            _menuFiltro(
              valor: _modalidad,
              opciones: ModalidadProceso.values,
              etiqueta: (m) => m.etiqueta,
              ayuda: 'Filtrar por tipo de proceso',
              icono: Icons.category_outlined,
              alCambiar: (m) {
                if (_modalidad == m) return;
                _modalidad = m;
                _aplicar();
              },
            ),
            _menuFiltro(
              valor: _periodo,
              opciones: PeriodoProcesos.values,
              etiqueta: (periodo) => periodo.etiqueta,
              ayuda: 'Filtrar por fecha de publicación',
              icono: Icons.date_range_outlined,
              alCambiar: (periodo) {
                if (_periodo == periodo) return;
                _periodo = periodo;
                _aplicar();
              },
            ),
            if (_estado != FiltroEstadoProceso.abiertos)
              OutlinedButton.icon(
                onPressed: () {
                  _estado = FiltroEstadoProceso.abiertos;
                  _aplicar();
                },
                icon: Icon(Icons.circle, size: 8, color: Cristal.verde),
                label: const Text('Ver abiertos'),
              ),
            if (_estado != FiltroEstadoProceso.todos ||
                _periodo != PeriodoProcesos.todo ||
                _modalidad != ModalidadProceso.todas ||
                _texto.isNotEmpty)
              TextButton(
                onPressed: _limpiar,
                child: const Text('Limpiar filtros'),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _menuFiltro<T>({
    required T valor,
    required List<T> opciones,
    required String Function(T) etiqueta,
    required String ayuda,
    required IconData icono,
    required ValueChanged<T> alCambiar,
  }) {
    return PopupMenuButton<T>(
      initialValue: valor,
      tooltip: ayuda,
      position: PopupMenuPosition.under,
      color: Cristal.flotante,
      onSelected: alCambiar,
      itemBuilder: (_) => [
        for (final opcion in opciones)
          PopupMenuItem(value: opcion, child: Text(etiqueta(opcion))),
      ],
      child: Container(
        constraints: const BoxConstraints(maxWidth: 275, minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: Cristal.bordeFuerte),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 16, color: Cristal.textoMedio),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                etiqueta(valor),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Cristal.texto, fontSize: 13),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: Cristal.textoMedio,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pie() {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.all(22),
        child: Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Consultando procesos',
          ),
        ),
      );
    }
    if (_error) {
      return Column(
        children: [
          const Text(
            'La fuente de datos no respondió. Intenta nuevamente.',
            textAlign: TextAlign.center,
          ),
          TextButton.icon(
            onPressed: () => _cargar(reiniciar: false),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      );
    }
    if (_siguiente != null) {
      return Column(
        children: [
          if (_procesos.isEmpty)
            const Text(
              'Todavía no aparecen coincidencias. Puedes continuar la consulta.',
              textAlign: TextAlign.center,
            ),
          OutlinedButton.icon(
            onPressed: () => _cargar(reiniciar: false),
            icon: const Icon(Icons.expand_more_rounded),
            label: const Text('Cargar más procesos'),
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        _procesos.isEmpty
            ? (_estado == FiltroEstadoProceso.desiertos
                  ? 'La fuente no reportó procesos identificados como desiertos con estos filtros.'
                  : 'No encontramos procesos con esos criterios.')
            : 'Llegaste al final de los resultados.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Cristal.textoMedio),
      ),
    );
  }
}

class _TarjetaProceso extends StatelessWidget {
  const _TarjetaProceso({
    required this.proceso,
    required this.onTap,
    required this.alineada,
  });

  final ProcesoSecop proceso;
  final VoidCallback onTap;
  final bool alineada;

  static final _cop = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final p = proceso;
    final cierre = p.cierreOfertas;
    final publicado = p.publicado;
    final fecha = cierre != null
        ? 'Cierre · ${fechaDiaMesAnio(cierre)} ${DateFormat('HH:mm').format(cierre)}'
        : publicado != null
        ? 'Publicado · ${fechaDiaMesAnio(publicado)}'
        : '';
    final radio = BorderRadius.circular(20);

    return Material(
      color: Cristal.vidrio,
      shape: RoundedRectangleBorder(
        borderRadius: radio,
        side: BorderSide(color: Cristal.borde),
      ),
      child: InkWell(
        borderRadius: radio,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  EstadoProcesoChip(p),
                  if (p.modalidad.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Cristal.vidrioSuave,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Cristal.borde),
                      ),
                      child: Text(
                        p.modalidad,
                        style: TextStyle(
                          color: Cristal.textoMedio,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (p.referencia.isNotEmpty)
                Text(
                  p.referencia,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Cristal.acentoClaro,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              Text(
                p.nombre.isNotEmpty
                    ? p.nombre
                    : (p.descripcion.isNotEmpty
                          ? p.descripcion
                          : 'Proceso de contratación'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Cristal.texto,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  height: 1.3,
                ),
              ),
              if (p.entidad.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  p.entidad,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Cristal.textoMedio, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              LineaTiempoProceso(p, compacta: true),
              if (alineada) const Spacer(),
              const SizedBox(height: 12),
              Divider(height: 1, color: Cristal.borde),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 5,
                children: [
                  if (fecha.isNotEmpty)
                    _DatoTarjeta(Icons.event_outlined, fecha),
                  if (p.precioBase > 0)
                    _DatoTarjeta(
                      Icons.payments_outlined,
                      _cop.format(p.precioBase),
                    ),
                  if (p.departamento.isNotEmpty)
                    _DatoTarjeta(Icons.location_on_outlined, p.departamento),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Ver detalle',
                    style: TextStyle(
                      color: Cristal.acentoClaro,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Cristal.acentoClaro,
                    size: 17,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatoTarjeta extends StatelessWidget {
  const _DatoTarjeta(this.icono, this.valor);

  final IconData icono;
  final String valor;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icono, size: 15, color: Cristal.textoMedio),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          valor,
          style: TextStyle(color: Cristal.textoMedio, fontSize: 12),
        ),
      ),
    ],
  );
}
