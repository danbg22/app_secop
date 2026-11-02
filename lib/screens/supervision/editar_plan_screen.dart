import 'package:flutter/material.dart';

import '../../services/equipo_juridico_service.dart';
import '../../services/juridico_contratacion_service.dart';
import '../../services/supervision_service.dart';
import '../gestion_contractual/estilo_contractual.dart';
import 'componentes_supervision.dart';
import 'plantilla_informe_screen.dart';

/// Configuración de la supervisión de un contrato: periodos, presupuesto,
/// obligaciones y quién aprueba cada etapa del informe.
class EditarPlanScreen extends StatefulWidget {
  const EditarPlanScreen({super.key, required this.expediente, this.plan});

  final ExpedienteContratoPs expediente;
  final PlanSupervision? plan;

  @override
  State<EditarPlanScreen> createState() => _EditarPlanScreenState();
}

class _EditarPlanScreenState extends State<EditarPlanScreen> {
  ExpedienteContratoPs get _exp => widget.expediente;

  PlantillaInforme? _plantilla;
  late DateTime _inicio;
  late DateTime _fin;
  late Periodicidad _periodicidad;
  late int _riesgo;
  final Map<String, TextEditingController> _c = {};
  late List<TextEditingController> _obligaciones;
  late List<String> _ids;
  List<MiembroEquipo> _equipo = const [];
  bool _guardando = false;
  String? _fechaCdp;
  String? _fechaRp;

  static String _nuevoId() => 'o${DateTime.now().microsecondsSinceEpoch}';

  TextEditingController _t(String clave, [String inicial = '']) =>
      _c.putIfAbsent(clave, () => TextEditingController(text: inicial));

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    final hoy = DateTime.now();
    _inicio = p?.fechaInicio ?? DateTime(hoy.year, hoy.month, hoy.day);
    _fin = p?.fechaFin ?? DateTime(hoy.year, 12, 31);
    _periodicidad = p?.periodicidad ?? Periodicidad.mensual;
    _riesgo = p?.claseRiesgo ?? 1;
    _t('supNombre', p?.supervisorNombre ?? '');
    _t('supEmail', p?.supervisorEmail ?? '');
    final meses =
        (_fin.year - _inicio.year) * 12 + _fin.month - _inicio.month + 1;
    final sugerido = _exp.valorContratoCop > 0 && meses > 0
        ? (_exp.valorContratoCop / meses).round()
        : 0;
    _t(
      'valor',
      p != null
          ? milesCop(p.valorPeriodoCop)
          : (sugerido > 0 ? milesCop(sugerido) : ''),
    );
    _t('formaPago', p?.formaPago ?? '');
    _t('sectorial', p?.sectorial ?? _exp.dependencia);
    _t('cdpNum', p?.cdp.numero ?? '');
    _t('cdpValor', (p?.cdp.valorCop ?? 0) > 0 ? milesCop(p!.cdp.valorCop) : '');
    _t('rpNum', p?.rp.numero ?? '');
    _t('rpValor', (p?.rp.valorCop ?? 0) > 0 ? milesCop(p!.rp.valorCop) : '');
    _fechaCdp = p?.cdp.fechaIso;
    _fechaRp = p?.rp.fechaIso;
    final previas = p?.obligaciones ?? const <ObligacionContractual>[];
    _obligaciones = [
      for (final o in previas) TextEditingController(text: o.texto),
    ];
    _ids = [for (final o in previas) o.id];
    if (_obligaciones.isEmpty) {
      _obligaciones.add(TextEditingController());
      _ids.add(_nuevoId());
    }
    if (p != null) {
      _aplicarPlantilla(p.plantilla);
    } else {
      _cargarPlantilla();
    }
    _cargarEquipo();
  }

  void _aplicarPlantilla(PlantillaInforme p) {
    _plantilla = p;
    for (final e in p.etapas) {
      _t('etNombre:${e.id}', e.responsableNombre).text = e.responsableNombre;
      _t('etEmail:${e.id}', e.responsableEmail).text = e.responsableEmail;
    }
    if (!p.quincenalHabilitado) _periodicidad = Periodicidad.mensual;
  }

  Future<void> _cargarPlantilla() async {
    final p = await SupervisionService.plantillaDelEquipo(
      entidad: _exp.entidadNombre,
    );
    if (!mounted) return;
    setState(() {
      // Conserva los responsables que ya estaban escritos para etapas iguales.
      final previos = {
        for (final e in _plantilla?.etapas ?? const <EtapaAprobacion>[])
          e.id: e,
      };
      _aplicarPlantilla(
        p.copyWith(
          etapas: [
            for (final e in p.etapas)
              previos[e.id] == null
                  ? e
                  : e.copyWith(
                      responsableNombre: previos[e.id]!.responsableNombre,
                      responsableEmail: previos[e.id]!.responsableEmail,
                    ),
          ],
        ),
      );
    });
  }

  Future<void> _cargarEquipo() async {
    if (!EquipoJuridicoService.esMaster) return;
    try {
      final lista = await EquipoJuridicoService.listarMiembros();
      if (mounted) {
        setState(
          () => _equipo = lista.where((m) => m.estado == 'activo').toList(),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in [..._c.values, ..._obligaciones]) {
      c.dispose();
    }
    super.dispose();
  }

  int _n(String clave) =>
      int.tryParse(_t(clave).text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  Future<void> _elegirFecha(String cual) async {
    final inicial = switch (cual) {
      'inicio' => _inicio,
      'fin' => _fin,
      'cdp' => DateTime.tryParse(_fechaCdp ?? '') ?? DateTime.now(),
      _ => DateTime.tryParse(_fechaRp ?? '') ?? DateTime.now(),
    };
    final f = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (f == null) return;
    setState(() {
      switch (cual) {
        case 'inicio':
          _inicio = f;
        case 'fin':
          _fin = f;
        case 'cdp':
          _fechaCdp = fechaIsoCorta(f);
        default:
          _fechaRp = fechaIsoCorta(f);
      }
    });
  }

  Future<void> _pegarVarias() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Pegar obligaciones'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: c,
            maxLines: 14,
            decoration: decoracionCampo(
              'Una obligación por línea',
              ayuda: 'Cópialas de la cláusula de obligaciones específicas del contrato.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: EstiloContractual.botonPrincipal(),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final lineas = c.text
        .split('\n')
        .map(
          (l) => l.replaceFirst(RegExp(r'^\s*(\d+[.)-]|[-•*])\s*'), '').trim(),
        )
        .where((l) => l.isNotEmpty);
    setState(() {
      for (var i = _obligaciones.length - 1; i >= 0; i--) {
        if (_obligaciones[i].text.trim().isEmpty) {
          _obligaciones.removeAt(i).dispose();
          _ids.removeAt(i);
        }
      }
      for (final (i, l) in lineas.indexed) {
        _obligaciones.add(TextEditingController(text: l));
        _ids.add('${_nuevoId()}$i');
      }
      if (_obligaciones.isEmpty) {
        _obligaciones.add(TextEditingController());
        _ids.add(_nuevoId());
      }
    });
  }

  Future<void> _guardar() async {
    final plantilla = _plantilla;
    if (plantilla == null) return;
    if (_t('supNombre').text.trim().isEmpty) {
      mensajeSupervision(
        context,
        'Indica el nombre del supervisor.',
        error: true,
      );
      return;
    }
    if (_n('valor') <= 0) {
      mensajeSupervision(
        context,
        'Indica el valor que se cobra en cada periodo.',
        error: true,
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      await SupervisionService.guardarPlan(
        _exp,
        PlanSupervision(
          supervisorNombre: _t('supNombre').text,
          supervisorEmail: _t('supEmail').text,
          fechaInicio: _inicio,
          fechaFin: _fin,
          periodicidad: _periodicidad,
          valorPeriodoCop: _n('valor'),
          formaPago: _t('formaPago').text,
          sectorial: _t('sectorial').text,
          claseRiesgo: _riesgo,
          cdp: DatoPresupuestal(
            numero: _t('cdpNum').text.trim(),
            fechaIso: _fechaCdp ?? '',
            valorCop: _n('cdpValor'),
          ),
          rp: DatoPresupuestal(
            numero: _t('rpNum').text.trim(),
            fechaIso: _fechaRp ?? '',
            valorCop: _n('rpValor'),
          ),
          obligaciones: [
            for (final (i, c) in _obligaciones.indexed)
              if (c.text.trim().isNotEmpty)
                ObligacionContractual(id: _ids[i], texto: c.text.trim()),
          ],
          plantilla: plantilla.copyWith(
            etapas: [
              for (final e in plantilla.etapas)
                e.copyWith(
                  responsableNombre: _t('etNombre:${e.id}').text.trim(),
                  responsableEmail: _t('etEmail:${e.id}').text.trim(),
                ),
            ],
          ),
        ),
      );
      if (!mounted) return;
      mensajeSupervision(context, 'Supervisión guardada.');
      Navigator.pop(context, true);
    } on SupervisionException catch (e) {
      if (mounted) mensajeSupervision(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
    final plantilla = _plantilla;
    Widget par(Widget a, Widget b) => mobile
        ? Column(children: [a, const SizedBox(height: 14), b])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: a),
              const SizedBox(width: 14),
              Expanded(child: b),
            ],
          );
    Widget fecha(String etiqueta, DateTime? f, String cual) =>
        OutlinedButton.icon(
          onPressed: () => _elegirFecha(cual),
          style: EstiloContractual.botonSecundario(),
          icon: const Icon(Icons.event_rounded, size: 18),
          label: Text(
            '$etiqueta: ${f == null ? 'sin fecha' : fechaNumerica(f)}',
            style: EstiloContractual.etiquetaBoton,
          ),
        );
    Widget dinero(String clave, String etiqueta) => TextField(
      controller: _t(clave),
      keyboardType: TextInputType.number,
      inputFormatters: const [FormatoMilesCop()],
      onChanged: (_) => setState(() {}),
      decoration: decoracionCampo(etiqueta, prefijo: '\$ '),
    );

    final valor = _n('valor');
    final aporte = AporteEsperado.calcular(
      valorMensualCop: _periodicidad == Periodicidad.quincenal
          ? valor * 2
          : valor,
      claseRiesgo: _riesgo,
      anio: _inicio.year,
    );
    final periodos = PlanSupervision(
      supervisorNombre: '',
      supervisorEmail: '',
      fechaInicio: _inicio,
      fechaFin: _fin,
      periodicidad: _periodicidad,
      valorPeriodoCop: valor,
      claseRiesgo: _riesgo,
      obligaciones: const [],
      plantilla: plantilla ?? PlantillaInforme.porDefecto(''),
    ).periodos;

    return PantallaContractual(
      anchoMaximo: 920,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PildoraVolver(
            etiqueta: 'Supervisión',
            onTap: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          widget.plan == null ? 'Configurar supervisión' : 'Editar supervisión',
          style: EstiloContractual.titulo,
        ),
        const SizedBox(height: 6),
        Text(
          'Contrato ${_exp.numeroContrato} · ${_exp.contratistaNombreEsperado}',
          style: EstiloContractual.subtitulo,
        ),
        const SizedBox(height: 20),
        if (plantilla == null)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          TarjetaSupervision(
            titulo: 'Periodos de los informes',
            subtitulo: 'El contratista reporta un informe por periodo; cada uno vence su último día.',
            icono: Icons.event_note_rounded,
            children: [
              par(
                fecha('Inicio', _inicio, 'inicio'),
                fecha('Terminación', _fin, 'fin'),
              ),
              const SizedBox(height: 14),
              SegmentedButton<Periodicidad>(
                segments: [
                  const ButtonSegment(
                    value: Periodicidad.mensual,
                    label: Text('Mensual'),
                  ),
                  ButtonSegment(
                    value: Periodicidad.quincenal,
                    label: const Text('Quincenal'),
                    enabled: plantilla.quincenalHabilitado,
                    tooltip: plantilla.quincenalHabilitado ? null : 'La entidad no tiene habilitados los informes quincenales',
                  ),
                ],
                selected: {_periodicidad},
                showSelectedIcon: false,
                onSelectionChanged: (v) =>
                    setState(() => _periodicidad = v.first),
              ),
              const SizedBox(height: 8),
              Text(
                '${periodos.length} informes: el primero del ${fechaLegible(periodos.first.desde, conDia: false)} '
                'al ${fechaLegible(periodos.first.hasta, conDia: false)}.',
                style: const TextStyle(
                  color: EstiloContractual.gris,
                  fontSize: 12.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TarjetaSupervision(
            titulo: 'Valor, presupuesto y aportes',
            icono: Icons.payments_outlined,
            children: [
              par(
                dinero('valor', 'Valor que se cobra por periodo'),
                DropdownButtonFormField<int>(
                  initialValue: _riesgo,
                  isExpanded: true,
                  decoration: decoracionCampo(
                    'Clase de riesgo ARL',
                    ayuda: 'Riesgo I para labores de oficina. En IV y V la ARL la paga la entidad.',
                  ),
                  items: [
                    for (final c in tarifaArlPorClase.entries)
                      DropdownMenuItem(
                        value: c.key,
                        child: Text(
                          'Riesgo ${['I', 'II', 'III', 'IV', 'V'][c.key - 1]} · ${(c.value * 100).toStringAsFixed(3).replaceAll('.', ',')} %',
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _riesgo = v ?? 1),
                ),
              ),
              if (valor > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Aporte mínimo mensual del contratista: ${formatoCop(aporte.totalContratista())} (IBC ${formatoCop(aporte.ibc)}).',
                    style: const TextStyle(
                      color: Color(0xFF0369A1),
                      fontSize: 12.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              TextField(
                controller: _t('formaPago'),
                minLines: 2,
                maxLines: 5,
                decoration: decoracionCampo(
                  'Forma de pago',
                  ayuda: 'Como dice la cláusula del contrato. Sale en el informe de supervisión.',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _t('sectorial'),
                decoration: decoracionCampo('Dependencia o sectorial'),
              ),
              const SizedBox(height: 14),
              par(
                TextField(
                  controller: _t('cdpNum'),
                  decoration: decoracionCampo('CDP N.º'),
                ),
                par(
                  fecha('Fecha CDP', DateTime.tryParse(_fechaCdp ?? ''), 'cdp'),
                  dinero('cdpValor', 'Valor CDP'),
                ),
              ),
              const SizedBox(height: 14),
              par(
                TextField(
                  controller: _t('rpNum'),
                  decoration: decoracionCampo(
                    'RP N.º',
                    ayuda: 'Si aún no existe, déjalo vacío.',
                  ),
                ),
                par(
                  fecha('Fecha RP', DateTime.tryParse(_fechaRp ?? ''), 'rp'),
                  dinero('rpValor', 'Valor RP'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TarjetaSupervision(
            titulo: 'Quién aprueba el informe',
            subtitulo:
                'La cadena de la entidad: cada etapa aprueba o devuelve en este orden. Los responsables deben ser '
                'del equipo y entrar con este correo.',
            icono: Icons.alt_route_rounded,
            accion: TextButton.icon(
              onPressed: () async {
                final cambio = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PlantillaInformeScreen(entidad: _exp.entidadNombre),
                  ),
                );
                if (cambio == true) await _cargarPlantilla();
              },
              icon: const Icon(Icons.tune_rounded, size: 17),
              label: const Text('Plantilla de la entidad'),
              style: TextButton.styleFrom(
                foregroundColor: EstiloContractual.navy,
              ),
            ),
            children: [
              for (final (i, e) in plantilla.etapas.indexed) ...[
                Text(
                  '${i + 1}. ${e.nombre}',
                  style: const TextStyle(
                    color: EstiloContractual.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                if (_equipo.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final m in _equipo)
                        ActionChip(
                          label: Text(
                            m.nombre,
                            style: const TextStyle(fontSize: 12.3),
                          ),
                          onPressed: () => setState(() {
                            _t('etNombre:${e.id}').text = m.nombre;
                            _t('etEmail:${e.id}').text = m.email;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                par(
                  TextField(
                    controller: _t('etNombre:${e.id}'),
                    decoration: decoracionCampo('Nombre del responsable'),
                  ),
                  TextField(
                    controller: _t('etEmail:${e.id}'),
                    keyboardType: TextInputType.emailAddress,
                    decoration: decoracionCampo('Correo del responsable'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Divider(height: 1),
              const SizedBox(height: 14),
              const Text(
                'Supervisor del contrato (firma el informe de supervisión)',
                style: TextStyle(
                  color: EstiloContractual.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              par(
                TextField(
                  controller: _t('supNombre'),
                  decoration: decoracionCampo('Nombre del supervisor'),
                ),
                TextField(
                  controller: _t('supEmail'),
                  decoration: decoracionCampo('Correo (opcional)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TarjetaSupervision(
            titulo: 'Obligaciones del contrato',
            subtitulo: 'El contratista describe en cada informe qué hizo para cumplir cada una.',
            icono: Icons.checklist_rounded,
            accion: TextButton.icon(
              onPressed: _pegarVarias,
              icon: const Icon(Icons.content_paste_rounded, size: 17),
              label: const Text('Pegar varias'),
              style: TextButton.styleFrom(
                foregroundColor: EstiloContractual.navy,
              ),
            ),
            children: [
              for (final (i, c) in _obligaciones.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: EstiloContractual.navy,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: c,
                          minLines: 1,
                          maxLines: 5,
                          decoration: decoracionCampo('Obligación ${i + 1}'),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Quitar',
                        onPressed: _obligaciones.length == 1
                            ? null
                            : () => setState(() {
                                _obligaciones.removeAt(i).dispose();
                                _ids.removeAt(i);
                              }),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: EstiloContractual.gris,
                        ),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _obligaciones.add(TextEditingController());
                    _ids.add(_nuevoId());
                  }),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar obligación'),
                  style: TextButton.styleFrom(
                    foregroundColor: EstiloContractual.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              style: EstiloContractual.botonPrincipal(),
              icon: _guardando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text(
                'Guardar supervisión',
                style: EstiloContractual.etiquetaBoton,
              ),
            ),
          ),
        ],
        const SizedBox(height: 30),
      ],
    );
  }
}
