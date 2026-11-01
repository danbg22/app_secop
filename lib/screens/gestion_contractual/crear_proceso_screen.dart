import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/modalidades_contratacion.dart';
import '../../services/procesos_contratacion_service.dart';
import 'estilo_contractual.dart';
import 'proceso_detalle_screen.dart';

/// Formulario de creación de un proceso: campos comunes más los propios de
/// la modalidad, con la vista previa de etapas y documentos exigidos.
class CrearProcesoScreen extends StatefulWidget {
  const CrearProcesoScreen({
    super.key,
    required this.modalidad,
    this.idProcesoSecop = '',
  });

  final ModalidadContratacion modalidad;

  /// ID de SECOP II ya conocido (registro manual desde la importación).
  final String idProcesoSecop;

  @override
  State<CrearProcesoScreen> createState() => _CrearProcesoScreenState();
}

class _CrearProcesoScreenState extends State<CrearProcesoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _entidad = TextEditingController();
  final _nit = TextEditingController();
  final _dependencia = TextEditingController();
  final _numero = TextEditingController();
  late final _idSecop = TextEditingController(text: widget.idProcesoSecop);
  final _objeto = TextEditingController();
  final _presupuesto = TextEditingController();
  final _plazo = TextEditingController();
  final Map<String, TextEditingController> _camposTexto = {};
  final Map<String, String> _seleccion = {};
  bool _guardando = false;

  ModalidadContratacion get _m => widget.modalidad;

  @override
  void initState() {
    super.initState();
    for (final c in _m.campos) {
      if (c.tipo != TipoCampo.seleccion) {
        _camposTexto[c.id] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _entidad,
      _nit,
      _dependencia,
      _numero,
      _idSecop,
      _objeto,
      _presupuesto,
      _plazo,
      ..._camposTexto.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _crear() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final proceso = await ProcesosContratacionService.crearProceso(
        modalidad: _m,
        entidadNombre: _entidad.text,
        entidadNit: _nit.text,
        dependencia: _dependencia.text,
        numeroProceso: _numero.text,
        objeto: _objeto.text,
        presupuestoCop:
            int.tryParse(_presupuesto.text.replaceAll(RegExp(r'\D'), '')) ?? 0,
        plazoEjecucion: _plazo.text,
        idProcesoSecop: _idSecop.text,
        campos: {
          for (final e in _camposTexto.entries) e.key: e.value.text,
          ..._seleccion,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ProcesoDetalleScreen(procesoId: proceso.id),
        ),
      );
    } on ProcesoContratacionException catch (e) {
      _mensaje(e.message);
    } catch (_) {
      _mensaje('No fue posible crear el proceso. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
  }

  InputDecoration _decoracion(String etiqueta, {String? ayuda}) =>
      InputDecoration(
        labelText: etiqueta,
        helperText: ayuda,
        helperMaxLines: 2,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD8DEE8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: EstiloContractual.navy,
            width: 1.5,
          ),
        ),
      );

  String? _requerido(String? v) =>
      (v ?? '').trim().isEmpty ? 'Campo obligatorio' : null;

  Widget _campo(CampoModalidad c) {
    if (c.tipo == TipoCampo.seleccion) {
      return DropdownButtonFormField<String>(
        initialValue: _seleccion[c.id],
        isExpanded: true,
        decoration: _decoracion(c.etiqueta, ayuda: c.ayuda),
        items: [
          for (final o in c.opciones)
            DropdownMenuItem(
              value: o,
              child: Text(o, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) => setState(() => _seleccion[c.id] = v ?? ''),
        validator: c.obligatorio ? _requerido : null,
      );
    }
    final numerico = c.tipo == TipoCampo.numero || c.tipo == TipoCampo.moneda;
    return TextFormField(
      controller: _camposTexto[c.id],
      maxLines: c.tipo == TipoCampo.textoLargo ? 3 : 1,
      keyboardType: numerico ? TextInputType.number : TextInputType.text,
      inputFormatters: numerico
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
          : null,
      decoration: _decoracion(c.etiqueta, ayuda: c.ayuda),
      validator: c.obligatorio ? _requerido : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
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

    final formulario = Container(
      padding: const EdgeInsets.all(22),
      decoration: EstiloContractual.tarjeta(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Text(
                'Registra aquí el proceso que la entidad adelanta en SECOP II para que el equipo '
                'jurídico controle plazos, documentos, observaciones y verificación de ofertas. '
                'Publicación, recepción de ofertas y adjudicación se hacen únicamente en SECOP II.',
                style: TextStyle(
                  color: Color(0xFF1E3A8A),
                  fontSize: 12.6,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('DATOS DEL PROCESO', style: EstiloContractual.seccion),
            const SizedBox(height: 14),
            par(
              TextFormField(
                controller: _entidad,
                decoration: _decoracion('Entidad contratante'),
                validator: _requerido,
              ),
              TextFormField(
                controller: _nit,
                keyboardType: TextInputType.number,
                decoration: _decoracion('NIT de la entidad'),
              ),
            ),
            const SizedBox(height: 14),
            par(
              TextFormField(
                controller: _numero,
                decoration: _decoracion(
                  'Número del proceso',
                  ayuda: 'Ej.: LP-001-2026',
                ),
                validator: _requerido,
              ),
              TextFormField(
                controller: _idSecop,
                decoration: _decoracion(
                  'ID del proceso en SECOP II',
                  ayuda: 'Opcional. Ej.: CO1.REQ.1234567. Puedes vincularlo después.',
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _dependencia,
              decoration: _decoracion('Dependencia que contrata'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _objeto,
              maxLines: 3,
              decoration: _decoracion('Objeto del contrato'),
              validator: _requerido,
            ),
            const SizedBox(height: 14),
            par(
              TextFormField(
                controller: _presupuesto,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _decoracion('Presupuesto oficial (COP)'),
                validator: _requerido,
              ),
              TextFormField(
                controller: _plazo,
                decoration: _decoracion(
                  'Plazo de ejecución',
                  ayuda: 'Ej.: 6 meses',
                ),
                validator: _requerido,
              ),
            ),
            if (_m.campos.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text(
                'PROPIO DE ${_m.nombre.toUpperCase()}',
                style: EstiloContractual.seccion,
              ),
              const SizedBox(height: 14),
              for (final c in _m.campos) ...[
                _campo(c),
                const SizedBox(height: 14),
              ],
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _guardando ? null : _crear,
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
                    : const Icon(Icons.arrow_forward_rounded, size: 19),
                label: const Text(
                  'Crear proceso',
                  style: EstiloContractual.etiquetaBoton,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final requisitos = _ResumenRequisitos(modalidad: _m);

    return PantallaContractual(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PildoraVolver(
            etiqueta: 'Modalidades',
            onTap: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _m.color,
                shape: BoxShape.circle,
              ),
              child: Icon(_m.icono, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _m.nombre,
                style: EstiloContractual.titulo.copyWith(
                  fontSize: mobile ? 24 : 30,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _m.fundamento,
          style: const TextStyle(color: EstiloContractual.gris, fontSize: 12.5),
        ),
        const SizedBox(height: 20),
        if (mobile) ...[
          formulario,
          const SizedBox(height: 16),
          requisitos,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: formulario),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: requisitos),
            ],
          ),
      ],
    );
  }
}

/// Lo que exige la ley para la modalidad: etapas, documentos de la entidad
/// a cargo del equipo, requisitos que se verifican en cada oferta y criterio
/// de escogencia.
class _ResumenRequisitos extends StatelessWidget {
  const _ResumenRequisitos({required this.modalidad});

  final ModalidadContratacion modalidad;

  @override
  Widget build(BuildContext context) {
    final m = modalidad;
    Widget lista(String titulo, List<DocumentoRequerido> docs) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: EstiloContractual.seccion),
        const SizedBox(height: 8),
        for (final d in docs)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  d.obligatorio
                      ? Icons.check_circle_outline_rounded
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: d.obligatorio ? m.color : EstiloContractual.gris,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    d.obligatorio ? d.nombre : '${d.nombre} (si aplica)',
                    style: const TextStyle(
                      color: EstiloContractual.navy,
                      fontSize: 12.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: m.fondo.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: m.color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lo que exige esta modalidad',
            style: TextStyle(
              color: EstiloContractual.navy,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (m.criterioEvaluacion != null) ...[
            const SizedBox(height: 6),
            Text(
              'Escogencia: ${m.criterioEvaluacion}',
              style: const TextStyle(
                color: EstiloContractual.texto,
                fontSize: 12.8,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (m.etapas.isNotEmpty) ...[
            const Text('ETAPAS', style: EstiloContractual.seccion),
            const SizedBox(height: 8),
            for (var i = 0; i < m.etapas.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: m.color,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: m.etapas[i].nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (m.etapas[i].plazo != null)
                              TextSpan(text: ' · ${m.etapas[i].plazo}'),
                          ],
                        ),
                        style: const TextStyle(
                          color: EstiloContractual.navy,
                          fontSize: 12.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
          ],
          if (m.documentosOferente.isNotEmpty)
            lista(
              'REQUISITOS A VERIFICAR EN CADA OFERTA',
              m.documentosOferente,
            ),
          if (m.documentosContrato.isNotEmpty)
            lista(
              m.esCompetitiva
                  ? 'LEGALIZACIÓN DEL ADJUDICATARIO'
                  : 'DOCUMENTOS DEL CONTRATISTA A VERIFICAR',
              m.documentosContrato,
            ),
        ],
      ),
    );
  }
}
