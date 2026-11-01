import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/modalidades_contratacion.dart';
import '../../services/procesos_contratacion_service.dart';
import '../../services/secop_importacion_service.dart';
import 'crear_proceso_screen.dart';
import 'estado_secop.dart';
import 'estilo_contractual.dart';
import 'proceso_detalle_screen.dart';
import 'selector_modalidad_screen.dart';

/// Importa un proceso que ya existe en SECOP II: se busca por ID o enlace,
/// se revisa lo que reporta SECOP II y se guarda en el equipo.
class ImportarProcesoScreen extends StatefulWidget {
  const ImportarProcesoScreen({super.key});

  @override
  State<ImportarProcesoScreen> createState() => _ImportarProcesoScreenState();
}

class _ImportarProcesoScreenState extends State<ImportarProcesoScreen> {
  final _entrada = TextEditingController();
  bool _buscando = false;
  bool _importando = false;
  bool _noEncontrado = false;
  String? _error;
  ProcesoSecop? _resultado;
  String? _modalidadId;

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _buscando = true;
      _error = null;
      _noEncontrado = false;
      _resultado = null;
    });
    try {
      final r = await SecopImportacionService.buscar(_entrada.text);
      if (!mounted) return;
      setState(() {
        _resultado = r;
        _noEncontrado = r == null;
        _modalidadId = r == null
            ? null
            : SecopImportacionService.modalidadDesdeSecop(r.modalidad);
      });
    } on SecopImportacionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _importar() async {
    final r = _resultado;
    final modalidad = modalidadPorId(_modalidadId ?? '');
    if (r == null || modalidad == null) return;
    setState(() => _importando = true);
    try {
      final p = await ProcesosContratacionService.importarDesdeSecop(
        r,
        modalidad: modalidad,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ProcesoDetalleScreen(procesoId: p.id),
        ),
      );
    } on ProcesoContratacionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'No fue posible guardar el proceso. Revisa tu conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => _importando = false);
    }
  }

  Future<void> _registrarManual() async {
    final modalidad = await Navigator.of(context).push<ModalidadContratacion>(
      MaterialPageRoute(
        builder: (_) =>
            const SelectorModalidadScreen(sinPrestacionServicios: true),
      ),
    );
    if (!mounted || modalidad == null) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CrearProcesoScreen(
          modalidad: modalidad,
          idProcesoSecop:
              SecopImportacionService.extraerIdentificador(_entrada.text) ?? '',
        ),
      ),
    );
  }

  void _abrir(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
    return PantallaContractual(
      anchoMaximo: 980,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PildoraVolver(
            etiqueta: 'Volver',
            onTap: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Importar proceso de SECOP II',
          style: EstiloContractual.titulo,
        ),
        const SizedBox(height: 8),
        const Text(
          'Pega el ID o el enlace público del proceso. La app consulta Datos Abiertos de SECOP II y trae '
          'su estado, fechas, valor y documentos publicados.',
          style: EstiloContractual.subtitulo,
        ),
        const SizedBox(height: 20),
        Container(
          padding: EdgeInsets.all(mobile ? 16 : 22),
          decoration: EstiloContractual.tarjeta(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flex(
                direction: mobile ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: mobile
                    ? CrossAxisAlignment.stretch
                    : CrossAxisAlignment.center,
                children: [
                  Flexible(
                    flex: mobile ? 0 : 1,
                    child: TextField(
                      controller: _entrada,
                      onSubmitted: (_) => _buscar(),
                      decoration: InputDecoration(
                        labelText: 'ID o enlace del proceso',
                        hintText: 'CO1.REQ.1234567 · CO1.NTC.1234567 · https://community.secop.gov.co/…',
                        prefixIcon: const Icon(Icons.link_rounded),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: mobile ? 0 : 12, height: mobile ? 12 : 0),
                  FilledButton.icon(
                    onPressed: _buscando ? null : _buscar,
                    style: EstiloContractual.botonPrincipal(),
                    icon: _buscando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search_rounded, size: 19),
                    label: Text(
                      _buscando ? 'Buscando…' : 'Buscar en SECOP II',
                      style: EstiloContractual.etiquetaBoton,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Datos Abiertos se actualiza una vez al día: un proceso publicado hoy puede aparecer mañana.',
                style: TextStyle(color: EstiloContractual.gris, fontSize: 12),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _Aviso(
            icono: Icons.error_outline_rounded,
            color: const Color(0xFFB91C1C),
            texto: _error!,
          ),
        ],
        if (_noEncontrado) ...[
          const SizedBox(height: 14),
          _Aviso(
            icono: Icons.search_off_rounded,
            color: const Color(0xFFB45309),
            texto:
                'Datos Abiertos aún no reporta este proceso. Si lo acabas de publicar, puedes registrarlo '
                'a mano con su ID y sincronizarlo cuando aparezca.',
            accion: TextButton(
              onPressed: _registrarManual,
              child: const Text('Registrar manualmente'),
            ),
          ),
        ],
        if (_resultado != null) ...[
          const SizedBox(height: 18),
          _vistaPrevia(_resultado!, mobile),
        ],
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _vistaPrevia(ProcesoSecop r, bool mobile) {
    final esPrestacion =
        r.tipoContrato.toLowerCase().contains('prestación de servicios') &&
        SecopImportacionService.modalidadDesdeSecop(r.modalidad) ==
            'contratacion_directa';
    final modalidades = modalidadesContratacion
        .where((m) => m.id != 'prestacion_servicios')
        .toList();
    return Container(
      padding: EdgeInsets.all(mobile ? 16 : 24),
      decoration: EstiloContractual.tarjeta(
        colorBorde: const Color(0xFFBFDBFE),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChipEstadoSecop(secop: r),
              if (r.fase.isNotEmpty && r.fase != r.estado)
                EtiquetaColor(
                  texto: r.fase,
                  color: EstiloContractual.navy,
                  fondo: const Color(0xFFF1F5F9),
                ),
              EtiquetaColor(
                texto: r.idProceso,
                color: EstiloContractual.gris,
                fondo: const Color(0xFFF8FAFC),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            r.nombre.isEmpty ? r.referencia : r.nombre,
            style: const TextStyle(
              color: EstiloContractual.navy,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (r.descripcion.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              r.descripcion,
              style: EstiloContractual.subtitulo.copyWith(fontSize: 13.5),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              _dato('Entidad', r.entidad),
              _dato('Referencia', r.referencia),
              _dato('Modalidad en SECOP II', r.modalidad),
              _dato('Presupuesto oficial', copMillones(r.precioBase)),
              if (r.duracion.isNotEmpty) _dato('Duración', r.duracion),
              if (r.fechas['publicacion'] != null)
                _dato('Publicación', r.fechas['publicacion']!),
              if (r.fechas['recepcionOfertas'] != null)
                _dato('Cierre de ofertas', r.fechas['recepcionOfertas']!),
              if (r.ofertas > 0) _dato('Ofertas recibidas', '${r.ofertas}'),
              if (r.adjudicado)
                _dato(
                  'Adjudicado a',
                  '${r.proveedor} · ${copMillones(r.valorAdjudicado)}',
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'DOCUMENTOS PUBLICADOS (${r.documentos.length})',
            style: EstiloContractual.seccion,
          ),
          const SizedBox(height: 6),
          ListaDocumentosSecop(
            documentos: r.documentos,
            abrir: _abrir,
            visiblesIniciales: 5,
          ),
          const SizedBox(height: 18),
          if (esPrestacion)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _Aviso(
                icono: Icons.info_outline_rounded,
                color: Color(0xFF1D4ED8),
                texto:
                    'Este proceso es de prestación de servicios. Si aún no tienes el expediente del contratista, '
                    'créalo con "Estructurar nuevo proceso" para verificar sus documentos.',
              ),
            ),
          DropdownButtonFormField<String>(
            initialValue: _modalidadId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Modalidad para el seguimiento',
              helperText: 'Detectada a partir de SECOP II. Define el cronograma y los requisitos que se verifican.',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: [
              for (final m in modalidades)
                DropdownMenuItem(value: m.id, child: Text(m.nombre)),
            ],
            onChanged: (v) => setState(() => _modalidadId = v),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              if (r.url.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _abrir(r.url),
                  style: EstiloContractual.botonSecundario(),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text(
                    'Ver en SECOP II',
                    style: EstiloContractual.etiquetaBoton,
                  ),
                ),
              FilledButton.icon(
                onPressed: _importando || _modalidadId == null
                    ? null
                    : _importar,
                style: EstiloContractual.botonPrincipal(),
                icon: _importando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_download_outlined, size: 19),
                label: const Text(
                  'Importar y hacer seguimiento',
                  style: EstiloContractual.etiquetaBoton,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _dato(String etiqueta, String valor) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 300),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          etiqueta.toUpperCase(),
          style: EstiloContractual.seccion.copyWith(fontSize: 10.5),
        ),
        const SizedBox(height: 3),
        Text(
          valor.isEmpty ? '—' : valor,
          style: const TextStyle(
            color: EstiloContractual.navy,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.icono,
    required this.color,
    required this.texto,
    this.accion,
  });
  final IconData icono;
  final Color color;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Icon(icono, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
        ?accion,
      ],
    ),
  );
}
