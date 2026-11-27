import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/detalle_proceso_screen.dart';
import '../services/procesos_secop_service.dart';
import '../tema/cristal.dart';
import '../utils/banderas_control.dart';
import 'linea_tiempo_proceso.dart';

/// Procesos de contratación de SECOP II en cualquier estado: en borrador o
/// aprobación, recibiendo observaciones u ofertas, en evaluación,
/// adjudicados o cancelados. Sirve para revisar un proceso (pliegos,
/// estudios previos) antes de que se adjudique.
class BuscadorProcesos extends StatefulWidget {
  const BuscadorProcesos({
    super.key,
    this.nitEntidad = '',
    this.departamento = '',
    this.nombreEntidad = '',
  });

  /// Desde el perfil de una entidad: solo sus procesos (y los de la
  /// regional elegida), sin pedir la entidad.
  final String nitEntidad;
  final String departamento;
  final String nombreEntidad;

  bool get deEntidad =>
      nitEntidad.replaceAll(RegExp(r'[^0-9]'), '').length >= 8;

  @override
  State<BuscadorProcesos> createState() => _BuscadorProcesosState();
}

class _BuscadorProcesosState extends State<BuscadorProcesos> {
  final _texto = TextEditingController();
  final _entidad = TextEditingController();
  // Un perfil muestra el historial de la entidad y permite acotar por vigencia.
  late FiltroEstadoProceso _estado = widget.deEntidad
      ? FiltroEstadoProceso.todos
      : FiltroEstadoProceso.abiertos;
  late PeriodoProcesos _periodo = widget.deEntidad
      ? PeriodoProcesos.todo
      : PeriodoProcesos.mes;

  @override
  void initState() {
    super.initState();
    // Se cargan solos, como los contratos firmados; buscar es opcional.
    _buscar();
  }

  List<ProcesoSecop>? _resultados;
  bool _buscando = false;
  String? _error;
  CursorProcesos? _siguiente;
  String _textoActivo = '';
  String _entidadActiva = '';
  int _consulta = 0;

  @override
  void dispose() {
    _texto.dispose();
    _entidad.dispose();
    super.dispose();
  }

  Future<void> _buscar({bool mas = false}) async {
    final cursor = mas ? _siguiente : const CursorProcesos();
    if (cursor == null || (mas && _buscando)) return;
    final id = ++_consulta;
    setState(() {
      _buscando = true;
      _error = null;
      if (!mas) {
        _textoActivo = _texto.text;
        _entidadActiva = widget.deEntidad ? '' : _entidad.text;
        _resultados = null;
        _siguiente = null;
      }
    });
    try {
      final pagina = await ProcesosSecopService.buscarPagina(
        texto: _textoActivo,
        entidad: _entidadActiva,
        estado: _estado,
        periodo: _periodo,
        desde: cursor,
        nitEntidad: widget.nitEntidad,
        departamento: widget.departamento,
      );
      if (!mounted || id != _consulta) return;
      final anteriores = _resultados ?? const <ProcesoSecop>[];
      final ids = anteriores.map((proceso) => proceso.idCompartido).toSet();
      setState(() {
        _resultados = [
          ...anteriores,
          ...pagina.procesos.where(
            (proceso) =>
                proceso.idCompartido.isEmpty || ids.add(proceso.idCompartido),
          ),
        ];
        _siguiente = pagina.siguiente;
        _buscando = false;
      });
    } catch (_) {
      if (!mounted || id != _consulta) return;
      setState(() {
        _buscando = false;
        _error = 'SECOP II no respondió a tiempo. Intenta de nuevo o acota la búsqueda.';
      });
    }
  }

  InputDecoration _campo(String etiqueta, String ayuda, IconData icono) =>
      InputDecoration(
        labelText: etiqueta,
        hintText: ayuda,
        prefixIcon: Icon(icono, size: 20),
        filled: true,
        fillColor: Cristal.campo,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Cristal.radioCampo),
          borderSide: BorderSide(color: Cristal.bordeFuerte),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Cristal.radioCampo),
          borderSide: BorderSide(color: Cristal.bordeFuerte),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final angosto = MediaQuery.sizeOf(context).width < 700;
    final campoTexto = TextField(
      controller: _texto,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _buscar(),
      decoration: _campo(
        'Buscar dentro de los procesos (opcional)',
        'Ej.: juegos zonales, vigilancia, mantenimiento…',
        Icons.search_rounded,
      ),
    );
    final campoEntidad = TextField(
      controller: _entidad,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _buscar(),
      decoration: _campo(
        'Entidad (opcional)',
        'Nombre o NIT: SENA, 899999034…',
        Icons.account_balance_outlined,
      ),
    );
    final boton = FilledButton.icon(
      onPressed: _buscando ? null : _buscar,
      style: FilledButton.styleFrom(
        backgroundColor: Cristal.acento,
        foregroundColor: Cristal.blanco,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      icon: const Icon(Icons.search_rounded, size: 19),
      label: const Text(
        'Buscar procesos',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(angosto ? 14 : 20),
          decoration: BoxDecoration(
            color: Cristal.vidrio,
            borderRadius: BorderRadius.circular(Cristal.radioTarjeta),
            border: Border.all(color: Cristal.borde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.deEntidad
                    ? 'Procesos de ${widget.nombreEntidad.isEmpty ? 'la entidad' : widget.nombreEntidad}'
                          '${widget.departamento.isEmpty ? '' : ' en ${widget.departamento}'} en cualquier estado: '
                          'en borrador o aprobación, recibiendo observaciones u ofertas, en evaluación, adjudicados '
                          'o cancelados. Ábrelos en SECOP II para ver los pliegos antes de que se adjudiquen.'
                    : 'Procesos en cualquier estado: en borrador o aprobación, recibiendo observaciones u ofertas, '
                          'en evaluación, adjudicados o cancelados. Ábrelos en SECOP II para ver los pliegos y los '
                          'estudios previos antes de que se adjudiquen.',
                style: TextStyle(
                  color: Cristal.textoMedio,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              if (angosto) ...[
                campoTexto,
                if (!widget.deEntidad) ...[
                  const SizedBox(height: 10),
                  campoEntidad,
                ],
                const SizedBox(height: 10),
                boton,
              ] else
                Row(
                  children: [
                    Expanded(flex: 3, child: campoTexto),
                    if (!widget.deEntidad) ...[
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: campoEntidad),
                    ],
                    const SizedBox(width: 10),
                    boton,
                  ],
                ),
              const SizedBox(height: 14),
              Text(
                'Estado',
                style: TextStyle(
                  color: Cristal.textoSuave,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in FiltroEstadoProceso.values)
                    ChoiceChip(
                      label: Text(e.etiqueta),
                      selected: _estado == e,
                      onSelected: (_) {
                        setState(() => _estado = e);
                        _buscar();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Publicados en',
                style: TextStyle(
                  color: Cristal.textoSuave,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in PeriodoProcesos.values)
                    ChoiceChip(
                      label: Text(p.etiqueta),
                      selected: _periodo == p,
                      onSelected: (_) {
                        setState(() => _periodo = p);
                        _buscar();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_buscando && _resultados == null)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_resultados == null && _error == null)
          const _Aviso(
            texto:
                'Escribe qué buscas (por ejemplo "juegos zonales") y presiona Enter. Puedes dejar el texto vacío y '
                'escribir solo la entidad para ver todos sus procesos del estado elegido.',
            icono: Icons.info_outline_rounded,
          )
        else if (_resultados?.isEmpty == true && _siguiente == null)
          const _Aviso(
            texto: 'No hay procesos con esos criterios. Prueba con otra palabra, otro estado o un periodo más largo.',
            icono: Icons.search_off_rounded,
          )
        else if (_resultados?.isNotEmpty == true) ...[
          Text(
            _resultados!.length == 1
                ? '1 proceso'
                : '${_resultados!.length} procesos mostrados',
            style: TextStyle(
              color: Cristal.texto,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Datos Abiertos de SECOP II, con 1 a 3 días de retraso. Los borradores solo aparecen si la entidad los registró.',
            style: TextStyle(color: Cristal.textoSuave, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          for (final p in _resultados!) ...[
            _TarjetaProceso(proceso: p),
            const SizedBox(height: 10),
          ],
        ],
        if (_error != null)
          _Aviso(texto: _error!, icono: Icons.cloud_off_rounded),
        if (_siguiente != null)
          Center(
            child: OutlinedButton(
              onPressed: _buscando ? null : () => _buscar(mas: true),
              child: Text(_buscando ? 'Consultando…' : 'Cargar más procesos'),
            ),
          ),
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, required this.icono});
  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Cristal.vidrioSuave,
        borderRadius: BorderRadius.circular(Cristal.radioCampo),
        border: Border.all(color: Cristal.borde),
      ),
      child: Row(
        children: [
          Icon(icono, color: Cristal.textoMedio),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                color: Cristal.textoMedio,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaProceso extends StatelessWidget {
  const _TarjetaProceso({required this.proceso});
  final ProcesoSecop proceso;

  static String _pesos(double v) {
    final s = v.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '\$ $s';
  }

  static String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final p = proceso;
    final (color, fondo) = switch (p.tipo) {
      TipoEstadoProceso.abierto => (Cristal.verde, Cristal.verdeVidrio),
      TipoEstadoProceso.preparacion => (Cristal.ambar, Cristal.ambarVidrio),
      TipoEstadoProceso.evaluacion => (
        Cristal.acentoClaro,
        Cristal.acentoVidrio,
      ),
      TipoEstadoProceso.adjudicado => (
        Cristal.legible(const Color(0xFFA78BFA)),
        const Color(0x248B5CF6),
      ),
      TipoEstadoProceso.cancelado => (Cristal.rojo, Cristal.rojoVidrio),
    };
    final cierre = p.cierreOfertas;
    final ahora = DateTime.now();
    // Días de calendario (no horas): mañana a las 17:00 es "1 día".
    final faltan = cierre != null && cierre.isAfter(ahora) && p.abierto
        ? DateTime(
            cierre.year,
            cierre.month,
            cierre.day,
          ).difference(DateTime(ahora.year, ahora.month, ahora.day)).inDays
        : null;
    final valor = p.adjudicado && p.valorAdjudicado > 0
        ? 'Adjudicado por ${_pesos(p.valorAdjudicado)}'
        : p.precioBase > 0
        ? 'Presupuesto ${_pesos(p.precioBase)}'
        : null;
    void abrirDetalle() => Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => DetalleProcesoScreen(proceso: p)),
    );
    // Toda la tarjeta abre el detalle (datos, fases y documentos).
    return InkWell(
      onTap: abrirDetalle,
      borderRadius: BorderRadius.circular(16),
      hoverDuration: Cristal.micro,
      child: Container(
        decoration: BoxDecoration(
          color: Cristal.vidrio,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: p.tipo == TipoEstadoProceso.abierto
                ? Cristal.verdeBorde
                : Cristal.borde,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: fondo,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    p.estado,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (faltan != null)
                  Text(
                    faltan == 0
                        ? 'Cierra hoy a las ${_hora(cierre!)}'
                        : faltan == 1
                        ? 'Cierra mañana a las ${_hora(cierre!)}'
                        : 'Cierra en $faltan días · ${fechaDiaMesAnio(cierre!)} ${_hora(cierre)}',
                    style: TextStyle(
                      color: Cristal.verde,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (p.referencia.isNotEmpty)
                  Text(
                    p.referencia,
                    style: TextStyle(color: Cristal.textoSuave, fontSize: 12.5),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              p.nombre.isEmpty ? p.descripcion : p.nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Cristal.texto,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            if (p.descripcion.isNotEmpty && p.descripcion != p.nombre) ...[
              const SizedBox(height: 4),
              Text(
                p.descripcion,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Cristal.textoMedio,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              [
                p.entidad,
                p.departamento,
              ].where((t) => t.isNotEmpty).join(' · '),
              style: TextStyle(
                color: Cristal.textoCuerpo,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              [
                p.modalidad,
                if (p.fase.isNotEmpty) 'Fase: ${p.fase}',
                if (p.publicado != null)
                  'Publicado ${fechaDiaMesAnio(p.publicado!)}',
                if (p.adjudicado && p.proveedor.isNotEmpty)
                  'Adjudicado a ${p.proveedor}',
              ].where((t) => t.isNotEmpty).join(' · '),
              style: TextStyle(color: Cristal.textoSuave, fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            LineaTiempoProceso(p, compacta: true),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                if (valor != null)
                  Text(
                    valor,
                    style: TextStyle(
                      color: Cristal.texto,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                Wrap(
                  spacing: 4,
                  children: [
                    if (p.url.startsWith('http'))
                      TextButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse(p.url),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('SECOP II'),
                      ),
                    FilledButton.tonalIcon(
                      onPressed: abrirDetalle,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('Ver detalle y documentos'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
