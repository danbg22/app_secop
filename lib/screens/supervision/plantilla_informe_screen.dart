import 'package:flutter/material.dart';

import '../../services/supervision_service.dart';
import '../gestion_contractual/estilo_contractual.dart';
import 'componentes_supervision.dart';

/// Plantilla de informes de la entidad: lo que cambia entre una alcaldía y
/// una gobernación (encabezado, quincenales, etapas, documentos y orden del
/// PDF). Cada contrato guarda una copia al configurarse.
class PlantillaInformeScreen extends StatefulWidget {
  const PlantillaInformeScreen({super.key, required this.entidad});
  final String entidad;

  @override
  State<PlantillaInformeScreen> createState() => _PlantillaInformeScreenState();
}

class _PlantillaInformeScreenState extends State<PlantillaInformeScreen> {
  PlantillaInforme? _p;
  final _encabezado = TextEditingController();
  final _declaracion = TextEditingController();
  final _tarifa = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    SupervisionService.plantillaDelEquipo(entidad: widget.entidad).then((p) {
      if (!mounted) return;
      setState(() {
        _p = p;
        _encabezado.text = p.encabezado.join('\n');
        _declaracion.text = p.declaracion;
        _tarifa.text = p.tarifaEstampillaPct.toString().replaceAll('.', ',');
      });
    });
  }

  @override
  void dispose() {
    _encabezado.dispose();
    _declaracion.dispose();
    _tarifa.dispose();
    super.dispose();
  }

  void _set(PlantillaInforme p) => setState(() => _p = p);

  List<T> _mover<T>(List<T> l, int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= l.length) return l;
    final c = [...l];
    final x = c.removeAt(i);
    c.insert(j, x);
    return c;
  }

  Future<void> _guardar() async {
    final p = _p!;
    setState(() => _guardando = true);
    try {
      await SupervisionService.guardarPlantilla(
        p.copyWith(
          encabezado: _encabezado.text
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList(),
          declaracion: _declaracion.text.trim().isEmpty
              ? PlantillaInforme.textoDeclaracionPorDefecto
              : _declaracion.text.trim(),
          tarifaEstampillaPct:
              double.tryParse(_tarifa.text.replaceAll(',', '.')) ??
              p.tarifaEstampillaPct,
        ),
      );
      if (!mounted) return;
      mensajeSupervision(
        context,
        'Plantilla guardada. Se aplica a los contratos que configures desde ahora.',
      );
      Navigator.pop(context, true);
    } on SupervisionException catch (e) {
      if (mounted) mensajeSupervision(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _editarEtapa(int? i) async {
    final p = _p!;
    final e = i == null ? null : p.etapas[i];
    final nombre = TextEditingController(text: e?.nombre ?? '');
    final cert = TextEditingController(text: e?.certificacion ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(e == null ? 'Nueva etapa' : 'Editar etapa'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombre,
                decoration: decoracionCampo(
                  'Nombre',
                  ayuda: 'Ej.: Enlace, Jefe de sectorial, Apoyo jurídico',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cert,
                minLines: 3,
                maxLines: 6,
                decoration: decoracionCampo(
                  'Texto que certifica (opcional)',
                  ayuda: 'Si lo escribes, sale como bloque de certificación en el informe y se completa al aprobar.',
                ),
              ),
            ],
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
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true || nombre.text.trim().isEmpty) return;
    final nueva =
        (e ??
                EtapaAprobacion(
                  id: 'e${DateTime.now().microsecondsSinceEpoch}',
                  nombre: '',
                ))
            .copyWith(
              nombre: nombre.text.trim(),
              certificacion: cert.text.trim(),
            );
    _set(
      p.copyWith(
        etapas: i == null ? [...p.etapas, nueva] : ([...p.etapas]..[i] = nueva),
      ),
    );
  }

  Future<void> _editarDocumento(int? i) async {
    final p = _p!;
    var d = i == null
        ? DocumentoPlantilla(
            id: 'd${DateTime.now().microsecondsSinceEpoch}',
            nombre: '',
          )
        : p.documentos[i];
    final nombre = TextEditingController(text: d.nombre);
    final desc = TextEditingController(text: d.descripcion);
    final nota = TextEditingController(text: d.nota);
    final generable = DocumentosSistema.todos.contains(d.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(i == null ? 'Nuevo documento' : 'Editar documento'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nombre,
                    decoration: decoracionCampo('Nombre'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: desc,
                    minLines: 1,
                    maxLines: 3,
                    decoration: decoracionCampo(
                      'Descripción para el contratista',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nota,
                    decoration: decoracionCampo(
                      'Advertencia (opcional)',
                      ayuda:
                          'Ej.: Debe estar firmada y sellada por Contabilidad.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Se pide',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<ReglaDocumento>(
                    segments: [
                      for (final r in ReglaDocumento.values)
                        ButtonSegment(value: r, label: Text(r.etiqueta)),
                    ],
                    selected: {d.regla},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) =>
                        setD(() => d = d.copyWith(regla: v.first)),
                  ),
                  const SizedBox(height: 14),
                  if (generable)
                    const Text(
                      'La app sabe generar este documento con los datos del informe.',
                      style: TextStyle(
                        color: Color(0xFF15803D),
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Row(
                      children: [
                        const Text(
                          'Archivos máximos',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: d.maxArchivos,
                          items: [
                            for (final n in [1, 2, 3, 5])
                              DropdownMenuItem(value: n, child: Text('$n')),
                          ],
                          onChanged: (v) =>
                              setD(() => d = d.copyWith(maxArchivos: v)),
                        ),
                      ],
                    ),
                ],
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
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || nombre.text.trim().isEmpty) return;
    d = d.copyWith(
      nombre: nombre.text.trim(),
      descripcion: desc.text.trim(),
      nota: nota.text.trim(),
      origen: generable ? OrigenDocumento.sistema : OrigenDocumento.contratista,
    );
    _set(
      p.copyWith(
        documentos: i == null
            ? [...p.documentos, d]
            : ([...p.documentos]..[i] = d),
      ),
    );
  }

  Widget _flechas(VoidCallback? arriba, VoidCallback? abajo) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Subir',
        onPressed: arriba,
        icon: const Icon(Icons.arrow_upward_rounded, size: 18),
      ),
      IconButton(
        tooltip: 'Bajar',
        onPressed: abajo,
        icon: const Icon(Icons.arrow_downward_rounded, size: 18),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return PantallaContractual(
      anchoMaximo: 920,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PildoraVolver(
            etiqueta: 'Volver',
            onTap: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Plantilla de informes de la entidad',
          style: EstiloContractual.titulo,
        ),
        const SizedBox(height: 6),
        const Text(
          'Lo que esta entidad pide en cada informe. Se aplica a los contratos que configures desde ahora; '
          'los ya configurados conservan su copia hasta que los edites.',
          style: EstiloContractual.subtitulo,
        ),
        const SizedBox(height: 20),
        if (p == null)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          TarjetaSupervision(
            titulo: 'Encabezado y opciones',
            icono: Icons.article_outlined,
            children: [
              TextField(
                controller: _encabezado,
                minLines: 2,
                maxLines: 4,
                decoration: decoracionCampo(
                  'Encabezado del informe',
                  ayuda: 'Una línea por renglón. Ej.: ALCALDÍA DE VALLEDUPAR / SECRETARÍA DE HACIENDA',
                ),
              ),
              Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: p.quincenalHabilitado,
                      onChanged: (v) =>
                          _set(p.copyWith(quincenalHabilitado: v)),
                      title: const Text('Permitir informes quincenales'),
                      subtitle: const Text(
                        'Si está apagado, todos los contratos reportan mensualmente.',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: p.estampillaDepartamental,
                      onChanged: (v) =>
                          _set(p.copyWith(estampillaDepartamental: v)),
                      title: const Text(
                        'Pedir el pago de la estampilla departamental en el primer informe',
                      ),
                    ),
                  ],
                ),
              ),
              if (p.estampillaDepartamental)
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _tarifa,
                    decoration: decoracionCampo('Tarifa de la estampilla (%)'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TarjetaSupervision(
            titulo: 'Cadena de aprobación',
            subtitulo: 'Etapas por las que pasa cada informe, en orden. Los responsables se asignan en cada contrato.',
            icono: Icons.alt_route_rounded,
            accion: TextButton.icon(
              onPressed: p.etapas.length >= 5 ? null : () => _editarEtapa(null),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Agregar etapa'),
              style: TextButton.styleFrom(
                foregroundColor: EstiloContractual.navy,
              ),
            ),
            children: [
              for (final (i, e) in p.etapas.indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: EstiloContractual.navy,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  title: Text(
                    e.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: e.certificacion.isEmpty
                      ? null
                      : const Text('Certifica en el informe'),
                  onTap: () => _editarEtapa(i),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _flechas(
                        i == 0
                            ? null
                            : () => _set(
                                p.copyWith(etapas: _mover(p.etapas, i, -1)),
                              ),
                        i == p.etapas.length - 1
                            ? null
                            : () => _set(
                                p.copyWith(etapas: _mover(p.etapas, i, 1)),
                              ),
                      ),
                      IconButton(
                        tooltip: 'Quitar',
                        onPressed: p.etapas.length == 1
                            ? null
                            : () => _set(
                                p.copyWith(etapas: [...p.etapas]..removeAt(i)),
                              ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 19,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TarjetaSupervision(
            titulo: 'Documentos de cada informe',
            subtitulo: 'En este orden van en el formulario y en el PDF. "Lo arma la app" no lo adjunta el contratista.',
            icono: Icons.folder_copy_outlined,
            accion: TextButton.icon(
              onPressed: () => _editarDocumento(null),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Agregar documento'),
              style: TextButton.styleFrom(
                foregroundColor: EstiloContractual.navy,
              ),
            ),
            children: [
              for (final (i, d) in p.documentos.indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    d.nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: Text(
                    '${d.regla.etiqueta} · ${d.origen.etiqueta}${d.maxArchivos > 1 ? ' · hasta ${d.maxArchivos}' : ''}',
                  ),
                  onTap: () => _editarDocumento(i),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _flechas(
                        i == 0
                            ? null
                            : () => _set(
                                p.copyWith(
                                  documentos: _mover(p.documentos, i, -1),
                                ),
                              ),
                        i == p.documentos.length - 1
                            ? null
                            : () => _set(
                                p.copyWith(
                                  documentos: _mover(p.documentos, i, 1),
                                ),
                              ),
                      ),
                      IconButton(
                        tooltip: 'Quitar',
                        onPressed: () => _set(
                          p.copyWith(
                            documentos: [...p.documentos]..removeAt(i),
                          ),
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 19,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TarjetaSupervision(
            titulo: 'Orden del informe en PDF',
            icono: Icons.reorder_rounded,
            children: [
              for (final (i, s) in p.secciones.indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(PlantillaInforme.etiquetasSecciones[s] ?? s),
                  trailing: _flechas(
                    i == 0
                        ? null
                        : () => _set(
                            p.copyWith(secciones: _mover(p.secciones, i, -1)),
                          ),
                    i == p.secciones.length - 1
                        ? null
                        : () => _set(
                            p.copyWith(secciones: _mover(p.secciones, i, 1)),
                          ),
                  ),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: _declaracion,
                minLines: 3,
                maxLines: 6,
                decoration: decoracionCampo('Declaración bajo juramento'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              style: EstiloContractual.botonPrincipal(),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text(
                'Guardar plantilla',
                style: EstiloContractual.etiquetaBoton,
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ],
    );
  }
}
