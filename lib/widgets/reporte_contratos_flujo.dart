import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/reporte_contratos_pdf_service.dart';
import '../services/reporte_contratos_service.dart';
import '../services/reporte_xlsx_service.dart';
import '../utils/anios_secop.dart';

/// Motivo por el que no se genera el reporte (se muestra tal cual).
class ReporteException implements Exception {
  const ReporteException(this.message);
  final String message;
}

const Color _navy = Color(0xFF0E2646);
const Color _gris = Color(0xFF64748B);

/// El PDF de miles de filas tarda minutos en el navegador; la hoja de
/// cálculo no tiene ese problema.
const int maxFilasPdf = 1500;
const int maxFilasXlsx = 20000;

String _miles(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

/// Periodo del reporte como se lista en los criterios.
String periodoTexto(int desde, DateTime corte) =>
    '01/01/$desde a ${fechaDia(corte)}';

/// Notas que explican cómo se armó el reporte.
List<String> notasReporte({
  required OpcionesReporte o,
  UnidadContratacion? unidad,
  bool dependenciaPorPalabras = false,
}) => [
  if (unidad != null)
    'Criterio exacto: contratos que nacieron de los procesos que la entidad registró en SECOP II con '
        '${unidad.esConsolidado ? 'cada una de estas unidades de contratación' : 'esta unidad de contratación'} '
        '(${unidad.variantes.map((v) => '"$v"').join(', ')}'
        '${unidad.cuentas.isEmpty ? '' : '; cuenta ${unidad.cuentas.join(', ')}'}).',
  if (dependenciaPorPalabras)
    'Dependencia aproximada: SECOP II no publica en los contratos la dependencia que los firma; aquí se '
        'identifica por palabras clave del objeto y puede dejar contratos por fuera. Para un dato exacto use '
        'el reporte por unidad de contratación.',
  'Contratos con fecha de firma entre el 01/01/${o.desde} y el ${fechaDia(o.corte)} (o fecha de inicio, si '
      'SECOP II no registra la firma). Solo SECOP II: los contratos de SECOP I no se incluyen.',
  if (o.soloPrestacionServicios)
    'Solo contratos de prestación de servicios profesionales y de apoyo a la gestión (tipo "Prestación de '
        'servicios" con esa justificación de la modalidad en SECOP II).',
  'Se excluyen registros con valor \$ 0 o igual o mayor a \$ 500.000 millones, que en SECOP II corresponden '
      'a errores de digitación.',
  if (o.columnas.contains(ColumnaReporte.plazo)) 'Plazo: el pactado en SECOP II, en días calendario (los meses se cuentan desde la fecha de inicio).',
  if (o.columnas.contains(ColumnaReporte.sucesivos))
    'Contratos sucesivos: todos los contratos del contratista (mismo documento) con la entidad, en cualquiera '
        'de sus cuentas de SECOP II, firmados en el periodo.',
  if (o.columnas.contains(ColumnaReporte.interrupcion))
    'Interrupción: días hábiles (sin fines de semana ni festivos de Colombia) entre el fin del contrato '
        'anterior del contratista con la entidad y el inicio de este. La SUJ-025-CE-S2-2021 toma 30 días '
        'hábiles como referencia de continuidad.',
  if (o.columnas.contains(ColumnaReporte.supervision))
    'Supervisión u ordenación del gasto: si el documento del contratista figura en SECOP II como supervisor '
        'u ordenador del gasto de contratos de la entidad. El manejo de bienes no se registra en SECOP II: '
        'la entidad debe completarlo.',
  if (o.columnas.contains(ColumnaReporte.fuente)) 'Fuente de financiación: según los valores por fuente y el destino del gasto que registra SECOP II.',
];

/// Ventana para configurar el reporte: formato, contratos (unidad exacta o
/// filtros de pantalla), periodo, columnas y tipo de archivo.
class DialogoReporte extends StatefulWidget {
  const DialogoReporte({
    super.key,
    required this.criterios,
    this.unidades,
    this.unidadFija,
    this.sugerida,
    this.descripcionFiltros,
    this.exactoPorDefecto = false,
    this.vigencia,
  });

  /// Vista previa de lo que contendrá el reporte.
  final List<(String, String)> Function(
    OpcionesReporte o,
    UnidadContratacion? unidad,
  )
  criterios;

  /// Unidades de contratación para el criterio exacto (null: sin elección).
  final Future<List<UnidadContratacion>>? unidades;

  /// Unidad ya elegida (desde Presupuesto por dependencia).
  final UnidadContratacion? unidadFija;
  final UnidadContratacion? Function(List<UnidadContratacion>)? sugerida;

  /// Si se permite usar los filtros de la pantalla, cómo se describen.
  final String? descripcionFiltros;
  final bool exactoPorDefecto;
  final int? vigencia;

  @override
  State<DialogoReporte> createState() => _DialogoReporteState();
}

class _DialogoReporteState extends State<DialogoReporte> {
  FormatoReporte _formato = FormatoReporte.general;
  List<ColumnaReporte> _columnas = FormatoReporte.general.columnas;
  late int _desde = widget.vigencia ?? 2023;
  late DateTime _corte = widget.vigencia == null || widget.vigencia == _hoy.year
      ? _hoy
      : DateTime(widget.vigencia!, 12, 31);
  bool _soloPs = false;
  bool _pdf = true;
  bool _xlsx = false;
  late bool _exacto =
      widget.unidadFija != null ||
      (widget.unidades != null &&
          (widget.exactoPorDefecto || widget.descripcionFiltros == null));
  UnidadContratacion? _unidad;
  bool _sugeridaAplicada = false;
  bool _verColumnas = false;

  static DateTime get _hoy {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void _elegirFormato(FormatoReporte f) {
    setState(() {
      _formato = f;
      if (f == FormatoReporte.personalizado) {
        _verColumnas = true;
        return;
      }
      _columnas = f.columnas;
      if (f == FormatoReporte.anexoDirectiva018) {
        // Lo que pide el oficio: vigencias 2023–2026 con corte al 31 de
        // octubre de 2026, en hoja de cálculo.
        _soloPs = true;
        _desde = 2023;
        final corteOficio = DateTime(2026, 10, 31);
        _corte = _hoy.isBefore(corteOficio) ? _hoy : corteOficio;
        _xlsx = true;
        _pdf = false;
        // Para responder por toda la regional, el consolidado.
        widget.unidades?.then((lista) {
          if (!mounted || !_exacto) return;
          final consolidado = lista.where((u) => u.esConsolidado);
          if (consolidado.isNotEmpty) {
            setState(() => _unidad = consolidado.first);
          }
        });
      } else {
        _soloPs = false;
        _pdf = true;
        _xlsx = false;
      }
    });
  }

  void _alternarColumna(ColumnaReporte c) {
    setState(() {
      _formato = FormatoReporte.personalizado;
      if (_columnas.contains(c)) {
        if (_columnas.length > 1) _columnas = [..._columnas]..remove(c);
      } else {
        // Se inserta en el orden del catálogo, con "No." siempre primero.
        const orden = ColumnaReporte.values;
        _columnas = [..._columnas, c]
          ..sort((a, b) => orden.indexOf(a).compareTo(orden.indexOf(b)));
      }
    });
  }

  Future<void> _elegirCorte() async {
    final f = await showDatePicker(
      context: context,
      initialDate: _corte,
      firstDate: DateTime(_desde),
      lastDate: _hoy,
      helpText: 'Fecha de corte',
    );
    if (f != null) setState(() => _corte = f);
  }

  OpcionesReporte get _opciones => OpcionesReporte(
    formato: _formato,
    columnas: _columnas,
    desde: _desde,
    corte: _corte,
    soloPrestacionServicios: _soloPs,
    pdf: _pdf,
    xlsx: _xlsx,
    unidad: _exacto ? (widget.unidadFija ?? _unidad) : null,
  );

  Widget _seccion(String t) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      t,
      style: const TextStyle(
        color: _navy,
        fontWeight: FontWeight.w800,
        fontSize: 13.5,
      ),
    ),
  );

  Widget _opcion(
    bool activa,
    String titulo,
    String detalle,
    VoidCallback onTap,
  ) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: activa ? const Color(0xFFEFF4FB) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activa ? _navy : const Color(0xFFE2E8F0),
          width: activa ? 1.4 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            activa
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: _navy,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalle,
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
      ),
    ),
  );

  Widget _atajo(String t, int desde) {
    final sel = _desde == desde && _corte == _hoy;
    return ChoiceChip(
      label: Text(t),
      selected: sel,
      selectedColor: const Color(0xFFDCE6F5),
      checkmarkColor: _navy,
      onSelected: (_) => setState(() {
        _desde = desde;
        _corte = _hoy;
      }),
    );
  }

  Widget _unidades() => FutureBuilder<List<UnidadContratacion>>(
    future: widget.unidades,
    builder: (context, snap) {
      if (snap.hasError) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'No fue posible consultar las unidades de contratación.',
            style: TextStyle(color: Color(0xFFB91C1C), fontSize: 12.5),
          ),
        );
      }
      if (!snap.hasData) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: LinearProgressIndicator(minHeight: 3),
        );
      }
      final lista = snap.data!;
      if (!_sugeridaAplicada) {
        _sugeridaAplicada = true;
        final s = widget.sugerida?.call(lista);
        if (s != null && _unidad == null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => setState(() => _unidad = s),
          );
        }
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<UnidadContratacion>(
          // Se reconstruye cuando se aplica la sugerida o el consolidado.
          key: ValueKey(_unidad?.etiqueta),
          initialValue: lista.contains(_unidad) ? _unidad : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Unidad de contratación',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: [
            for (final u in lista)
              DropdownMenuItem(
                value: u,
                child: Text(
                  '${u.etiqueta} · ${_miles(u.procesos)} procesos',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: u.esConsolidado
                        ? FontWeight.w800
                        : FontWeight.w400,
                  ),
                ),
              ),
          ],
          onChanged: (u) => setState(() => _unidad = u),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final hoy = _hoy;
    final unidad = widget.unidadFija ?? _unidad;
    final criterios = widget.criterios(_opciones, _exacto ? unidad : null);
    final puedeGenerar = (_pdf || _xlsx) && (!_exacto || unidad != null);
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'Exportar reporte de contratos',
        style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _seccion('Formato'),
              for (final f in FormatoReporte.values)
                _opcion(
                  _formato == f,
                  f.titulo,
                  f.descripcion,
                  () => _elegirFormato(f),
                ),
              if (widget.unidadFija != null) ...[
                _seccion('Contratos de'),
                Text(
                  '${widget.unidadFija!.etiqueta} (criterio exacto de SECOP II)',
                  style: const TextStyle(color: _navy, fontSize: 13.2),
                ),
              ] else if (widget.unidades != null) ...[
                _seccion('¿Qué contratos incluir?'),
                _opcion(
                  _exacto,
                  'Por unidad de contratación de SECOP II (exacto)',
                  'Los contratos que nacieron de los procesos que la entidad registró con esa unidad. '
                      'Para responder por toda la regional elige su consolidado.',
                  () => setState(() => _exacto = true),
                ),
                if (_exacto) _unidades(),
                if (widget.descripcionFiltros != null)
                  _opcion(
                    !_exacto,
                    'Con los filtros de la pantalla',
                    widget.descripcionFiltros!,
                    () => setState(() => _exacto = false),
                  ),
              ],
              _seccion('Periodo'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _atajo('Vigencia ${hoy.year}', hoy.year),
                  _atajo('Desde 2023 hasta hoy', 2023),
                  _atajo('Últimos 5 años', hoy.year - 4),
                  _atajo('Todo (2015 a hoy)', AniosSecop.primero),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('desde$_desde'),
                      initialValue: _desde,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: 'Desde (1 de enero de)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        for (final a in AniosSecop.disponibles)
                          DropdownMenuItem(value: a, child: Text('$a')),
                      ],
                      onChanged: (v) => setState(() {
                        _desde = v ?? _desde;
                        if (_corte.year < _desde) {
                          _corte = DateTime(_desde, 12, 31);
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _elegirCorte,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _navy,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.event_rounded, size: 18),
                      label: Text('Corte: ${fechaDia(_corte)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _soloPs,
                onChanged: (v) => setState(() => _soloPs = v),
                title: const Text(
                  'Solo prestación de servicios profesionales y de apoyo a la gestión',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'Numeral 3 del artículo 32 de la Ley 80 de 1993.',
                  style: TextStyle(color: _gris, fontSize: 12),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _verColumnas = !_verColumnas),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'Columnas del reporte (${_columnas.length})',
                        style: const TextStyle(
                          color: _navy,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _verColumnas ? 'Ocultar' : 'Agregar o quitar',
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_verColumnas)
                Text(
                  _columnas.map((c) => c.titulo).join(' · '),
                  style: const TextStyle(color: _gris, fontSize: 12),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in ColumnaReporte.values)
                      FilterChip(
                        label: Text(
                          c.porDiligenciar
                              ? '${c.titulo} (la diligencia la entidad)'
                              : c.titulo,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: _columnas.contains(c),
                        selectedColor: const Color(0xFFDCE6F5),
                        checkmarkColor: _navy,
                        onSelected: (_) => _alternarColumna(c),
                      ),
                  ],
                ),
              _seccion('Archivo'),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    avatar: const Icon(Icons.grid_on_rounded, size: 16),
                    label: const Text('Hoja de cálculo (.xlsx)'),
                    selected: _xlsx,
                    selectedColor: const Color(0xFFDCE6F5),
                    showCheckmark: false,
                    onSelected: (v) => setState(() => _xlsx = v),
                  ),
                  FilterChip(
                    avatar: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                    label: const Text('PDF'),
                    selected: _pdf,
                    selectedColor: const Color(0xFFDCE6F5),
                    showCheckmark: false,
                    onSelected: (v) => setState(() => _pdf = v),
                  ),
                ],
              ),
              if (_pdf)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'El PDF admite hasta $maxFilasPdf contratos; para más, usa la hoja de cálculo.',
                    style: TextStyle(color: _gris, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (k, v) in criterios)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '$k: ',
                                style: const TextStyle(color: _gris),
                              ),
                              TextSpan(
                                text: v,
                                style: const TextStyle(
                                  color: _navy,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          style: const TextStyle(fontSize: 12.6),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: puedeGenerar
              ? () => Navigator.pop(context, _opciones)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: _navy,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Generar'),
        ),
      ],
    );
  }
}

/// Consulta los contratos, completa el historial si las columnas lo piden,
/// arma la hoja de cálculo y/o el PDF y los descarga, con un diálogo de
/// progreso ("Generando documento oficial…").
Future<void> generarReporteContratos(
  BuildContext context, {
  required OpcionesReporte opciones,
  required Future<List<ContratoReporte>> Function(void Function(String))
  obtener,
  required String entidad,
  required String nit,
  required String titulo,
  required List<(String, String)> criterios,
  required List<String> notas,
  required String alcanceArchivo,
}) async {
  final estado = ValueNotifier<String>('Consultando contratos en SECOP II…');
  final navegador = Navigator.of(context, rootNavigator: true);
  final mensajero = ScaffoldMessenger.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: estado,
                builder: (_, t, _) => Text(
                  t,
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String? error;
  final avisos = <String>[];
  var cantidad = 0;
  try {
    final contratos = await obtener((t) => estado.value = t);
    if (contratos.isEmpty) {
      throw const ReporteException(
        'No hay contratos con este criterio en ese periodo.',
      );
    }
    if (contratos.length > maxFilasXlsx) {
      throw ReporteException(
        'Son ${_miles(contratos.length)} contratos. Acota el reporte (menos años o una unidad): '
        'el máximo es ${_miles(maxFilasXlsx)}.',
      );
    }
    var pdf = opciones.pdf;
    if (pdf && contratos.length > maxFilasPdf) {
      if (!opciones.xlsx) {
        throw ReporteException(
          'Son ${_miles(contratos.length)} contratos: el PDF admite hasta ${_miles(maxFilasPdf)}. '
          'Elige la hoja de cálculo (.xlsx) o acota el reporte.',
        );
      }
      pdf = false;
      avisos.add(
        'el PDF no se generó porque son más de ${_miles(maxFilasPdf)} contratos',
      );
    }
    if (opciones.requiereHistorial) {
      await ReporteContratosService.completarHistorial(
        nit: nit,
        contratos: contratos,
        desde: opciones.desde,
        corte: opciones.corte,
        progreso: (t) => estado.value = t,
      );
    }
    if (contratos.any((c) => c.inicioEstimado) &&
        (opciones.columnas.contains(ColumnaReporte.inicio) ||
            opciones.columnas.contains(ColumnaReporte.interrupcion))) {
      final n = contratos.where((c) => c.inicioEstimado).length;
      notas = [
        ...notas,
        'Fecha de inicio "(estimada)": SECOP II aún no registra la fecha de inicio de $n contrato${n == 1 ? '' : 's'} '
            '(por lo general recién firmados, sin acta de inicio). Se calcula como la fecha de terminación '
            'menos los días prorrogados y el plazo pactado.',
      ];
    }
    estado.value =
        'Generando documento oficial… (${_miles(contratos.length)} contratos)';
    // Deja pintar el mensaje antes del trabajo pesado.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final ahora = ReporteContratosPdfService.horaColombia();
    final usuario = AuthService.getActiveUserDisplayName();
    final correo = AuthService.getActiveUserEmail();
    final generadoPor = [
      if (usuario.isNotEmpty) usuario,
      if (correo.isNotEmpty) correo,
    ].join(' · ');
    final anexo = opciones.formato == FormatoReporte.anexoDirectiva018;
    if (opciones.xlsx) {
      final bytes = ReporteXlsxService.generar(
        hoja: anexo ? 'Anexo 1' : 'Contratos',
        encabezado: [
          '$entidad${nit.isEmpty ? '' : ' · NIT $nit'}',
          titulo,
          for (final (k, v) in criterios) '$k: $v',
          'Generado el ${ReporteContratosPdfService.fechaLarga(ahora)} por $generadoPor. '
              'Fuente: SECOP II, Datos Abiertos de Colombia (datos.gov.co).',
        ],
        columnas: opciones.columnas,
        contratos: contratos,
        notas: notas,
        firmaResponsable: anexo,
      );
      if (!ReporteXlsxService.descargar(
        bytes,
        ReporteContratosPdfService.nombreArchivo(
          entidad,
          alcanceArchivo,
          ahora,
          extension: 'xlsx',
        ),
      )) {
        error = 'Tu navegador no permitió descargar el archivo.';
      }
    }
    if (pdf && error == null) {
      final bytes = await ReporteContratosPdfService.generar(
        entidad: entidad,
        nit: nit,
        titulo: titulo,
        criterios: criterios,
        contratos: contratos,
        generadoPor: generadoPor,
        generadoEn: ahora,
        columnas: opciones.columnas,
        notas: notas,
        firmaResponsable: anexo,
      );
      if (!ReporteContratosPdfService.descargar(
        bytes,
        ReporteContratosPdfService.nombreArchivo(
          entidad,
          alcanceArchivo,
          ahora,
        ),
      )) {
        error = 'Tu navegador no permitió descargar el archivo.';
      }
    }
    cantidad = contratos.length;
  } on ReporteException catch (e) {
    error = e.message;
  } catch (_) {
    error = 'No fue posible consultar SECOP II. Revisa tu conexión e intenta de nuevo.';
  }
  navegador.pop();
  estado.dispose();
  mensajero.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      backgroundColor: error == null ? _navy : const Color(0xFFB91C1C),
      content: Text(
        error ??
            'Reporte descargado: ${_miles(cantidad)} contratos'
                '${avisos.isEmpty ? '.' : ' (${avisos.join('; ')}).'}',
      ),
    ),
  );
}

/// Reporte exacto de una unidad de contratación (despacho, centro…), desde
/// Presupuesto por dependencia.
Future<void> exportarReporteUnidad(
  BuildContext context, {
  required String entidad,
  required String nit,
  required UnidadContratacion unidad,
  String? regional,
  int? vigencia,
}) async {
  List<(String, String)> criterios(
    OpcionesReporte o,
    UnidadContratacion? _,
  ) => [
    ('Entidad', entidad),
    if (nit.isNotEmpty) ('NIT', nit),
    if (regional != null) ('Regional', regional),
    ('Unidad de contratación (SECOP II)', unidad.etiqueta),
    ('Periodo (fecha de firma)', periodoTexto(o.desde, o.corte)),
    if (o.soloPrestacionServicios)
      ('Tipo', 'Prestación de servicios profesionales y de apoyo a la gestión'),
  ];
  final o = await showDialog<OpcionesReporte>(
    context: context,
    builder: (_) => DialogoReporte(
      criterios: criterios,
      unidadFija: unidad,
      vigencia: vigencia,
    ),
  );
  if (o == null || !context.mounted) return;
  await generarReporteContratos(
    context,
    opciones: o,
    obtener: (progreso) => ReporteContratosService.contratosDeUnidad(
      nit: nit,
      unidad: unidad,
      desde: o.desde,
      corte: o.corte,
      soloPrestacionServicios: o.soloPrestacionServicios,
      progreso: progreso,
    ),
    entidad: entidad,
    nit: nit,
    titulo: o.formato == FormatoReporte.anexoDirectiva018
        ? 'Anexo 1 · Relación de contratos de prestación de servicios · ${unidad.etiqueta}'
        : 'Relación de contratos · ${unidad.etiqueta}',
    criterios: criterios(o, unidad),
    notas: notasReporte(o: o, unidad: unidad),
    alcanceArchivo: '${unidad.etiqueta} ${o.desde}-${o.corte.year}',
  );
}
