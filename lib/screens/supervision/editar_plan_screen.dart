import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/equipo_juridico_service.dart';
import '../../services/juridico_contratacion_service.dart';
import '../../services/supervision_service.dart';
import '../gestion_contractual/estilo_contractual.dart';
import 'componentes_supervision.dart';

/// Configuración de la supervisión de un contrato: supervisor, vigencia,
/// honorarios, riesgo ARL y obligaciones que se reportan cada mes.
class EditarPlanScreen extends StatefulWidget {
  const EditarPlanScreen({super.key, required this.expediente, this.plan});

  final ExpedienteContratoPs expediente;
  final PlanSupervision? plan;

  @override
  State<EditarPlanScreen> createState() => _EditarPlanScreenState();
}

class _EditarPlanScreenState extends State<EditarPlanScreen> {
  late final TextEditingController _supervisor;
  late final TextEditingController _correo;
  late final TextEditingController _valor;
  late DateTime _inicio;
  late DateTime _fin;
  late int _riesgo;
  late List<TextEditingController> _obligaciones;
  late List<String> _ids;

  static String _nuevoId() => 'o${DateTime.now().microsecondsSinceEpoch}';
  List<MiembroEquipo> _equipo = const [];
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    final hoy = DateTime.now();
    _inicio = p?.fechaInicio ?? DateTime(hoy.year, hoy.month, 1);
    _fin = p?.fechaFin ?? DateTime(hoy.year, 12, 31);
    _riesgo = p?.claseRiesgo ?? 1;
    _supervisor = TextEditingController(text: p?.supervisorNombre ?? '');
    _correo = TextEditingController(text: p?.supervisorEmail ?? '');
    final meses =
        (_fin.year - _inicio.year) * 12 + _fin.month - _inicio.month + 1;
    final sugerido = widget.expediente.valorContratoCop > 0 && meses > 0
        ? (widget.expediente.valorContratoCop / meses).round()
        : 0;
    _valor = TextEditingController(
      text: '${p?.valorMensualCop ?? (sugerido > 0 ? sugerido : '')}',
    );
    final previas = p?.obligaciones ?? const <ObligacionContractual>[];
    _obligaciones = [
      for (final o in previas) TextEditingController(text: o.texto),
    ];
    _ids = [for (final o in previas) o.id];
    if (_obligaciones.isEmpty) {
      _obligaciones.add(TextEditingController());
      _ids.add(_nuevoId());
    }
    _cargarEquipo();
  }

  Future<void> _cargarEquipo() async {
    if (!EquipoJuridicoService.esMaster) return;
    try {
      final lista = await EquipoJuridicoService.listarMiembros();
      if (mounted) setState(() => _equipo = lista);
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in [_supervisor, _correo, _valor, ..._obligaciones]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirFecha(bool inicio) async {
    final f = await showDatePicker(
      context: context,
      initialDate: inicio ? _inicio : _fin,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: inicio ? 'Fecha de inicio' : 'Fecha de terminación',
    );
    if (f != null) setState(() => inicio ? _inicio = f : _fin = f);
  }

  /// Pega varias obligaciones a la vez (una por línea).
  Future<void> _pegarVarias() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Pegar obligaciones'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: c,
            maxLines: 12,
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
    final obligaciones = [
      for (final (i, c) in _obligaciones.indexed)
        if (c.text.trim().isNotEmpty)
          ObligacionContractual(id: _ids[i], texto: c.text.trim()),
    ];
    if (_supervisor.text.trim().isEmpty || !_correo.text.contains('@')) {
      mensajeSupervision(
        context,
        'Indica el nombre y el correo del supervisor.',
        error: true,
      );
      return;
    }
    final valor = int.tryParse(_valor.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
    if (valor <= 0) {
      mensajeSupervision(
        context,
        'Indica el valor mensual de los honorarios.',
        error: true,
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      await SupervisionService.guardarPlan(
        widget.expediente,
        PlanSupervision(
          supervisorNombre: _supervisor.text,
          supervisorEmail: _correo.text,
          fechaInicio: _inicio,
          fechaFin: _fin,
          valorMensualCop: valor,
          claseRiesgo: _riesgo,
          obligaciones: obligaciones,
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

  String _f(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
    final valor = int.tryParse(_valor.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
    final aporte = AporteEsperado.calcular(
      valorMensualCop: valor,
      claseRiesgo: _riesgo,
      anio: _inicio.year,
    );
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

    return PantallaContractual(
      anchoMaximo: 900,
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
          'Contrato ${widget.expediente.numeroContrato} · ${widget.expediente.contratistaNombreEsperado}',
          style: EstiloContractual.subtitulo,
        ),
        const SizedBox(height: 20),
        TarjetaSupervision(
          titulo: 'Supervisor',
          subtitulo:
              'Quien aprueba cada informe y firma el certificado de cumplimiento. '
              'Debe ingresar a Contrata Legal con este correo.',
          icono: Icons.verified_user_outlined,
          children: [
            if (_equipo.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in _equipo.where((m) => m.estado == 'activo'))
                    ActionChip(
                      avatar: const Icon(
                        Icons.person_outline_rounded,
                        size: 16,
                      ),
                      label: Text(m.nombre),
                      onPressed: () => setState(() {
                        _supervisor.text = m.nombre;
                        _correo.text = m.email;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            par(
              TextField(
                controller: _supervisor,
                decoration: decoracionCampo('Nombre del supervisor'),
              ),
              TextField(
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                decoration: decoracionCampo('Correo del supervisor'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TarjetaSupervision(
          titulo: 'Ejecución y honorarios',
          subtitulo: 'Con estos datos la app arma los meses del contrato y calcula los aportes mínimos.',
          icono: Icons.event_note_rounded,
          children: [
            par(
              OutlinedButton.icon(
                onPressed: () => _elegirFecha(true),
                style: EstiloContractual.botonSecundario(),
                icon: const Icon(Icons.event_rounded, size: 18),
                label: Text(
                  'Inicio: ${_f(_inicio)}',
                  style: EstiloContractual.etiquetaBoton,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _elegirFecha(false),
                style: EstiloContractual.botonSecundario(),
                icon: const Icon(Icons.event_available_rounded, size: 18),
                label: Text(
                  'Terminación: ${_f(_fin)}',
                  style: EstiloContractual.etiquetaBoton,
                ),
              ),
            ),
            const SizedBox(height: 14),
            par(
              TextField(
                controller: _valor,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: decoracionCampo(
                  'Honorarios mensuales',
                  prefijo: '\$ ',
                ),
              ),
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
            if (valor > 0) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Wrap(
                  spacing: 26,
                  runSpacing: 10,
                  children: [
                    DatoSupervision('IBC mínimo', formatoCop(aporte.ibc)),
                    DatoSupervision('Salud 12,5 %', formatoCop(aporte.salud)),
                    DatoSupervision('Pensión 16 %', formatoCop(aporte.pension)),
                    DatoSupervision(
                      'ARL',
                      aporte.arlLaPagaLaEntidad
                          ? 'La paga la entidad'
                          : formatoCop(aporte.arl),
                    ),
                    DatoSupervision(
                      'Aporte mensual del contratista',
                      formatoCop(aporte.totalContratista),
                      color: const Color(0xFF0369A1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'IBC: 40 % de los honorarios, mínimo 1 SMMLV (${formatoCop(aporte.smmlv)} en ${_inicio.year}).',
                style: const TextStyle(
                  color: EstiloContractual.gris,
                  fontSize: 11.8,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        TarjetaSupervision(
          titulo: 'Obligaciones del contrato',
          subtitulo: 'El contratista describe cada mes qué hizo para cumplir cada una, y el supervisor lo verifica.',
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
                        maxLines: 4,
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
        const SizedBox(height: 30),
      ],
    );
  }
}
