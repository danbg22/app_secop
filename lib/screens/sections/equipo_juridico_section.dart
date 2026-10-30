import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../services/juridico_contratacion_service.dart';
import '../../widgets/user_profile_header_action.dart';

class EquipoJuridicoSection extends StatefulWidget {
  const EquipoJuridicoSection({
    super.key,
    this.initialMode = 0,
    required this.onLogout,
  });

  final int initialMode;
  final VoidCallback onLogout;

  @override
  State<EquipoJuridicoSection> createState() => _EquipoJuridicoSectionState();
}

class _EquipoJuridicoSectionState extends State<EquipoJuridicoSection> {
  static const Color _bgCrema = Color(0xFFFFF8EE);
  static const Color _azulOscuro = Color(0xFF1A2B4C);
  static const Color _azulPrimario = Color(0xFF2563EB);
  static const Color _dorado = Color(0xFFF5B82E);
  static const Color _bordeSuave = Color(0xFFE2E8F0);
  static const Color _textoSecundario = Color(0xFF64748B);

  final NumberFormat _monedaFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  final TextEditingController _busquedaController = TextEditingController();
  final TextEditingController _conceptoController = TextEditingController();
  final TextEditingController _observacionesController =
      TextEditingController();

  List<ExpedienteContratoPs> _expedientes = <ExpedienteContratoPs>[];
  bool _cargando = true;
  String _filtroEstado = 'todos'; // todos | revisar | observados | verificados
  String? _tokenDetalleAbierto;

  /// Casillas "Devolver este documento" marcadas en el expediente abierto.
  final Set<String> _idsMarcadosParaDevolver = <String>{};
  List<bool> _checksLocales = <bool>[false, false, false, false, false];
  bool _trazabilidadExpandida = true;
  bool _procesandoAccion = false;
  Timer? _sincronizadorContinuo;

  @override
  void initState() {
    super.initState();
    JuridicoContratacionService.expedientesVersion.addListener(
      _onServicioActualizado,
    );
    JuridicoContratacionService.activarTiempoRealEquipoJuridico();
    _cargarExpedientes();
    _sincronizadorContinuo = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _cargarExpedientes(silencioso: true),
    );
  }

  @override
  void dispose() {
    _sincronizadorContinuo?.cancel();
    JuridicoContratacionService.expedientesVersion.removeListener(
      _onServicioActualizado,
    );
    _busquedaController.dispose();
    _conceptoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  void _onServicioActualizado() {
    _cargarExpedientes(silencioso: true);
  }

  Future<void> _cargarExpedientes({bool silencioso = false}) async {
    if (!silencioso && _expedientes.isEmpty) {
      setState(() => _cargando = true);
    }
    final lista = await JuridicoContratacionService.listarExpedientes();
    if (!mounted) return;
    setState(() {
      _expedientes = lista;
      _cargando = false;
      if (_tokenDetalleAbierto != null) {
        final actual = _expedienteAbierto;
        if (actual != null) {
          _checksLocales = List<bool>.from(actual.checksVerificacion);
        }
      }
    });
  }

  ExpedienteContratoPs? get _expedienteAbierto {
    if (_tokenDetalleAbierto == null) return null;
    for (final exp in _expedientes) {
      if (exp.tokenInvitado == _tokenDetalleAbierto) return exp;
    }
    return null;
  }

  void _abrirDetalleAspirante(ExpedienteContratoPs exp) {
    setState(() {
      _tokenDetalleAbierto = exp.tokenInvitado;
      _idsMarcadosParaDevolver.clear();
      _checksLocales = List<bool>.from(exp.checksVerificacion);
      _conceptoController.text = exp.conceptoJuridico;
      _observacionesController.clear();
      _trazabilidadExpandida = true;
    });
  }

  void _volverAListaAspirantes() {
    setState(() {
      _tokenDetalleAbierto = null;
      _idsMarcadosParaDevolver.clear();
    });
  }

  List<ExpedienteContratoPs> get _expedientesFiltrados {
    final query = _busquedaController.text.trim().toLowerCase();
    return _expedientes.where((exp) {
      if (_filtroEstado == 'revisar' && exp.totalEnRevision == 0) {
        return false;
      }
      if (_filtroEstado == 'observados' && exp.totalPorSubsanar == 0) {
        return false;
      }
      if (_filtroEstado == 'verificados' &&
          !(exp.avalJuridicoEmitido || exp.todosObligatoriosAprobados)) {
        return false;
      }

      if (query.isEmpty) return true;
      return exp.contratistaNombreEsperado.toLowerCase().contains(query) ||
          exp.contratistaCedulaEsperada.toLowerCase().contains(query) ||
          exp.numeroContrato.toLowerCase().contains(query) ||
          exp.entidadNombre.toLowerCase().contains(query) ||
          exp.objetoContrato.toLowerCase().contains(query);
    }).toList();
  }

  void _mostrarMensaje(String texto, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: esError
              ? const Color(0xFFB91C1C)
              : const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          content: Text(
            texto,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      );
  }

  Future<void> _generarYMostrarLinkContratista(
    ExpedienteContratoPs expediente,
  ) async {
    final link = JuridicoContratacionService.construirLinkInvitadoWeb(
      expediente.tokenInvitado,
    );
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.link_rounded,
                        color: _azulPrimario,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Enlace personalizado del contratista',
                            style: TextStyle(
                              color: _azulOscuro,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Contrato ${expediente.numeroContrato} · ${expediente.contratistaNombreEsperado}',
                            style: const TextStyle(
                              color: _textoSecundario,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, size: 19),
                      color: _textoSecundario,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'El enlace ya fue copiado al portapapeles. Compártelo con el aspirante para que ingrese únicamente con su nombre completo y número de cédula a cargar los documentos de este contrato:',
                  style: TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _bordeSuave),
                  ),
                  child: SelectableText(
                    link,
                    style: const TextStyle(
                      color: _azulOscuro,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'Cerrar',
                        style: TextStyle(color: _textoSecundario),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: link));
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        _mostrarMensaje(
                          'Enlace copiado para ${expediente.contratistaNombreEsperado}.',
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _azulOscuro,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copiar enlace'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarVistaPreviaDocumento(
    ExpedienteContratoPs expediente,
    ApartadoDocumentoContrato apartado,
  ) async {
    final binario = JuridicoContratacionService.obtenerBinarioDocumento(
      expediente: expediente,
      apartado: apartado,
    );
    if (binario == null) {
      _mostrarMensaje('Este documento aún no ha sido cargado.', esError: true);
      return;
    }

    final esImagen =
        binario.mimeType.startsWith('image/') &&
        apartado.archivoBase64 != null &&
        apartado.archivoBase64!.isNotEmpty;

    Uint8List? bytesImagen;
    if (esImagen) {
      try {
        bytesImagen = base64Decode(apartado.archivoBase64!);
      } catch (_) {}
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildFileFormatBadge(apartado.formatoCorto),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            apartado.nombre,
                            style: const TextStyle(
                              color: _azulOscuro,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${binario.fileName}${apartado.tamanoFormateado.isNotEmpty ? " · ${apartado.tamanoFormateado}" : ""} · Versión ${apartado.versionCarga}',
                            style: const TextStyle(
                              color: _textoSecundario,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusDotPill(apartado.estado),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, size: 20),
                      color: _textoSecundario,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (bytesImagen != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: Center(
                        child: Image.memory(bytesImagen, fit: BoxFit.contain),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _bordeSuave),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_user_outlined,
                              size: 18,
                              color: _azulOscuro,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cargado por ${apartado.cargadoPorNombre ?? expediente.contratistaNombreEsperado}',
                                style: const TextStyle(
                                  color: _azulOscuro,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (apartado.fechaCargaIso != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Fecha de cargue: ${JuridicoContratacionService.formatearFechaHumana(apartado.fechaCargaIso)}',
                            style: const TextStyle(
                              color: _textoSecundario,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                        if (apartado.notaContratista != null &&
                            apartado.notaContratista!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Nota del contratista: ${apartado.notaContratista}',
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text(
                          'Puedes abrir el documento completo en una pestaña del navegador para su lectura detallada o descargarlo.',
                          style: TextStyle(
                            color: _textoSecundario,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  children: [
                    if (!apartado.estaAprobado)
                      OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await _aprobarDocumentoIndividual(
                            expediente,
                            apartado,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF15803D),
                          side: const BorderSide(color: Color(0xFF86EFAC)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 17,
                        ),
                        label: const Text('Verificar documento'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () {
                        JuridicoContratacionService.descargarDocumentoIndividual(
                          expediente: expediente,
                          apartado: apartado,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _azulOscuro,
                        side: const BorderSide(color: _bordeSuave),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 17),
                      label: const Text('Descargar'),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        final abierto =
                            JuridicoContratacionService.abrirDocumentoEnPestana(
                              expediente: expediente,
                              apartado: apartado,
                            );
                        if (!abierto) {
                          JuridicoContratacionService.descargarDocumentoIndividual(
                            expediente: expediente,
                            apartado: apartado,
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _azulOscuro,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Abrir documento'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _aprobarDocumentoIndividual(
    ExpedienteContratoPs expediente,
    ApartadoDocumentoContrato apartado,
  ) async {
    try {
      final actualizado =
          await JuridicoContratacionService.aprobarApartadoJuridico(
            tokenInvitado: expediente.tokenInvitado,
            apartadoId: apartado.id,
          );
      _reemplazarExpedienteEnEstado(actualizado);
      _idsMarcadosParaDevolver.remove(apartado.id);
      _mostrarMensaje('Documento "${apartado.nombre}" verificado.');
    } catch (e) {
      _mostrarMensaje(
        e.toString().replaceFirst('Invalid argument(s): ', ''),
        esError: true,
      );
    }
  }

  Future<void> _ejecutarRevisadoYVerificado(
    ExpedienteContratoPs expediente,
  ) async {
    if (_procesandoAccion) return;
    setState(() => _procesandoAccion = true);
    try {
      final actualizado =
          await JuridicoContratacionService.marcarRevisadoYVerificado(
            tokenInvitado: expediente.tokenInvitado,
            checks: _checksLocales,
            conceptoOpcional: _conceptoController.text,
            excluirIdsMarcadosDevolver: _idsMarcadosParaDevolver,
          );
      _reemplazarExpedienteEnEstado(actualizado);
      _mostrarMensaje(
        'Documentos verificados correctamente y registrados en trazabilidad.',
      );
    } catch (e) {
      _mostrarMensaje(
        e.toString().replaceFirst('Invalid argument(s): ', ''),
        esError: true,
      );
    } finally {
      if (mounted) setState(() => _procesandoAccion = false);
    }
  }

  Future<void> _ejecutarDevolucionAlContratista(
    ExpedienteContratoPs expediente,
  ) async {
    if (_procesandoAccion) return;
    if (_idsMarcadosParaDevolver.isEmpty) {
      _mostrarMensaje(
        'Marca la casilla "Devolver este documento" en al menos un soporte de la lista.',
        esError: true,
      );
      return;
    }
    if (_observacionesController.text.trim().length < 4) {
      _mostrarMensaje(
        'Escribe en "Observaciones para el contratista" qué debe corregir y cómo.',
        esError: true,
      );
      return;
    }

    setState(() => _procesandoAccion = true);
    try {
      final res =
          await JuridicoContratacionService.devolverDocumentosSeleccionados(
            tokenInvitado: expediente.tokenInvitado,
            apartadosIds: _idsMarcadosParaDevolver.toList(),
            observaciones: _observacionesController.text,
          );
      final cantidad = _idsMarcadosParaDevolver.length;
      _idsMarcadosParaDevolver.clear();
      _observacionesController.clear();
      _reemplazarExpedienteEnEstado(res.expediente);
      _mostrarMensaje(
        cantidad == 1
            ? 'Documento devuelto al contratista y notificado a ${expediente.contratistaCorreo}.'
            : '$cantidad documentos devueltos al contratista y notificados a ${expediente.contratistaCorreo}.',
      );
    } catch (e) {
      _mostrarMensaje(
        e.toString().replaceFirst('Invalid argument(s): ', ''),
        esError: true,
      );
    } finally {
      if (mounted) setState(() => _procesandoAccion = false);
    }
  }

  Future<void> _ejecutarCorreoRequerimiento(
    ExpedienteContratoPs expediente,
  ) async {
    try {
      final actualizado =
          await JuridicoContratacionService.enviarCorreoRequerimiento(
            tokenInvitado: expediente.tokenInvitado,
            observacionAdicional: _observacionesController.text,
            abrirClienteCorreo: true,
          );
      _reemplazarExpedienteEnEstado(actualizado);
      _mostrarMensaje(
        'Requerimiento registrado en trazabilidad para ${expediente.contratistaCorreo}.',
      );
    } catch (e) {
      _mostrarMensaje(
        e.toString().replaceFirst('Invalid argument(s): ', ''),
        esError: true,
      );
    }
  }

  void _reemplazarExpedienteEnEstado(ExpedienteContratoPs actualizado) {
    if (!mounted) return;
    setState(() {
      final idx = _expedientes.indexWhere(
        (e) => e.tokenInvitado == actualizado.tokenInvitado,
      );
      if (idx >= 0) {
        _expedientes[idx] = actualizado;
      } else {
        _expedientes.insert(0, actualizado);
      }
      _checksLocales = List<bool>.from(actualizado.checksVerificacion);
    });
  }

  Future<void> _abrirModalAgregarDocumento(
    ExpedienteContratoPs expediente,
  ) async {
    final nombreCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool obligatorio = true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Agregar documento requerido',
                    style: TextStyle(
                      color: _azulOscuro,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Se añadirá inmediatamente al contrato ${expediente.numeroContrato}.',
                    style: const TextStyle(
                      color: _textoSecundario,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildModalField(
                    controller: nombreCtrl,
                    label: 'Nombre del documento',
                    hint: 'Ej.: Examen médico ocupacional',
                  ),
                  const SizedBox(height: 12),
                  _buildModalField(
                    controller: descCtrl,
                    label: 'Indicación para el contratista (opcional)',
                    hint: 'Ej.: Vigencia no mayor a tres años en formato PDF',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: obligatorio,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: _azulOscuro,
                    title: const Text(
                      'Documento obligatorio para verificar el contrato',
                      style: TextStyle(fontSize: 13, color: _azulOscuro),
                    ),
                    onChanged: (v) =>
                        setModalState(() => obligatorio = v ?? true),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: _textoSecundario),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          if (nombreCtrl.text.trim().isEmpty) return;
                          final actualizado =
                              await JuridicoContratacionService.agregarApartadoAlExpediente(
                                tokenInvitado: expediente.tokenInvitado,
                                nombreApartado: nombreCtrl.text,
                                descripcionApartado: descCtrl.text,
                                obligatorio: obligatorio,
                              );
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          _reemplazarExpedienteEnEstado(actualizado);
                          _mostrarMensaje('Documento requerido agregado.');
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _azulOscuro,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Agregar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _abrirModalCrearContrato() async {
    final nombreCtrl = TextEditingController();
    final cedulaCtrl = TextEditingController();
    final correoCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final numeroContratoCtrl = TextEditingController();
    final entidadCtrl = TextEditingController(
      text: _expedientes.isNotEmpty
          ? _expedientes.first.entidadNombre
          : 'Alcaldía Municipal',
    );
    final nitCtrl = TextEditingController(
      text: _expedientes.isNotEmpty
          ? _expedientes.first.entidadNit
          : '899.999.061-9',
    );
    final dependenciaCtrl = TextEditingController(
      text: 'Oficina Asesora Jurídica',
    );
    final valorCtrl = TextEditingController();
    final plazoCtrl = TextEditingController(text: '6 meses');
    final objetoCtrl = TextEditingController();
    final docExtraCtrl = TextEditingController();

    final plantillas = JuridicoContratacionService.plantillasEstandarColombia;
    final seleccionadas = List<bool>.generate(
      plantillas.length,
      (i) => plantillas[i].obligatorioPorDefecto,
    );
    final documentosPersonalizados = <String>[];
    String? errorModal;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 740),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Crear contrato de prestación de servicios (OPS)',
                              style: TextStyle(
                                color: _azulOscuro,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Registra los datos del aspirante y los documentos requeridos para generar su enlace único.',
                              style: TextStyle(
                                color: _textoSecundario,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close, color: _textoSecundario),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: _bordeSuave),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Datos del aspirante a contratista',
                          style: TextStyle(
                            color: _azulOscuro,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, c) {
                            final estrecho = c.maxWidth < 480;
                            if (estrecho) {
                              return Column(
                                children: [
                                  _buildModalField(
                                    controller: nombreCtrl,
                                    label: 'Nombre completo del contratista *',
                                    hint: 'Ej.: Laura Sofía Gómez Mendoza',
                                  ),
                                  const SizedBox(height: 10),
                                  _buildModalField(
                                    controller: cedulaCtrl,
                                    label: 'Número de cédula *',
                                    hint: 'Ej.: 1065842910',
                                    keyboardType: TextInputType.number,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildModalField(
                                    controller: correoCtrl,
                                    label: 'Correo electrónico *',
                                    hint: 'contratista@correo.com',
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildModalField(
                                    controller: telefonoCtrl,
                                    label: 'Teléfono (opcional)',
                                    hint: 'Ej.: 3001234567',
                                  ),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: _buildModalField(
                                        controller: nombreCtrl,
                                        label:
                                            'Nombre completo del contratista *',
                                        hint: 'Ej.: Laura Sofía Gómez Mendoza',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: _buildModalField(
                                        controller: cedulaCtrl,
                                        label: 'Número de cédula *',
                                        hint: 'Ej.: 1065842910',
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: _buildModalField(
                                        controller: correoCtrl,
                                        label: 'Correo electrónico *',
                                        hint: 'contratista@correo.com',
                                        keyboardType:
                                            TextInputType.emailAddress,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: _buildModalField(
                                        controller: telefonoCtrl,
                                        label: 'Teléfono (opcional)',
                                        hint: 'Ej.: 3001234567',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Información del contrato (OPS)',
                          style: TextStyle(
                            color: _azulOscuro,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, c) {
                            final estrecho = c.maxWidth < 480;
                            if (estrecho) {
                              return Column(
                                children: [
                                  _buildModalField(
                                    controller: numeroContratoCtrl,
                                    label: 'Número del contrato *',
                                    hint: 'Ej.: OPS-2026-0612',
                                  ),
                                  const SizedBox(height: 10),
                                  _buildModalField(
                                    controller: entidadCtrl,
                                    label: 'Entidad contratante *',
                                    hint: 'Nombre de la entidad pública',
                                  ),
                                  const SizedBox(height: 10),
                                  _buildModalField(
                                    controller: dependenciaCtrl,
                                    label: 'Dependencia o área',
                                    hint: 'Ej.: Secretaría de Hacienda',
                                  ),
                                  const SizedBox(height: 10),
                                  _buildModalField(
                                    controller: valorCtrl,
                                    label: 'Valor del contrato en COP',
                                    hint: 'Ej.: 24000000',
                                    keyboardType: TextInputType.number,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildModalField(
                                    controller: plazoCtrl,
                                    label: 'Plazo de ejecución',
                                    hint: 'Ej.: 6 meses',
                                  ),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _buildModalField(
                                        controller: numeroContratoCtrl,
                                        label: 'Número del contrato *',
                                        hint: 'Ej.: OPS-2026-0612',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: _buildModalField(
                                        controller: entidadCtrl,
                                        label: 'Entidad contratante *',
                                        hint: 'Nombre de la entidad pública',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: _buildModalField(
                                        controller: dependenciaCtrl,
                                        label: 'Dependencia o área',
                                        hint: 'Ej.: Secretaría de Hacienda',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: _buildModalField(
                                        controller: valorCtrl,
                                        label: 'Valor (COP)',
                                        hint: 'Ej.: 24000000',
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: _buildModalField(
                                        controller: plazoCtrl,
                                        label: 'Plazo',
                                        hint: 'Ej.: 6 meses',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildModalField(
                          controller: objetoCtrl,
                          label: 'Objeto del contrato *',
                          hint:
                              'Prestación de servicios profesionales o de apoyo a la gestión para...',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Documentos requeridos al contratista',
                          style: TextStyle(
                            color: _azulOscuro,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _bordeSuave),
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < plantillas.length; i++)
                                CheckboxListTile(
                                  dense: true,
                                  value: seleccionadas[i],
                                  activeColor: _azulOscuro,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: Text(
                                    plantillas[i].nombre,
                                    style: const TextStyle(
                                      color: _azulOscuro,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    plantillas[i].descripcion,
                                    style: const TextStyle(
                                      color: _textoSecundario,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                  onChanged: (v) => setModalState(
                                    () => seleccionadas[i] = v ?? false,
                                  ),
                                ),
                              for (final extra in documentosPersonalizados)
                                ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.check_box_rounded,
                                    color: _azulOscuro,
                                    size: 20,
                                  ),
                                  title: Text(
                                    extra,
                                    style: const TextStyle(
                                      color: _azulOscuro,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.close, size: 17),
                                    onPressed: () => setModalState(
                                      () => documentosPersonalizados.remove(
                                        extra,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildModalField(
                                controller: docExtraCtrl,
                                label: 'Añadir otro documento específico',
                                hint:
                                    'Ej.: Certificación SST o Estampilla departamental',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: OutlinedButton(
                                onPressed: () {
                                  final t = docExtraCtrl.text.trim();
                                  if (t.isEmpty) return;
                                  setModalState(() {
                                    documentosPersonalizados.add(t);
                                    docExtraCtrl.clear();
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _azulOscuro,
                                  side: const BorderSide(color: _bordeSuave),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Añadir'),
                              ),
                            ),
                          ],
                        ),
                        if (errorModal != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            errorModal!,
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: _bordeSuave),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: _textoSecundario),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () async {
                          final apartados = <ApartadoDocumentoContrato>[];
                          for (var i = 0; i < plantillas.length; i++) {
                            if (seleccionadas[i]) {
                              apartados.add(
                                ApartadoDocumentoContrato(
                                  id: 'APT-0${apartados.length + 1}',
                                  nombre: plantillas[i].nombre,
                                  descripcion: plantillas[i].descripcion,
                                  obligatorio: true,
                                ),
                              );
                            }
                          }
                          for (final extra in documentosPersonalizados) {
                            apartados.add(
                              ApartadoDocumentoContrato(
                                id: 'APT-X${apartados.length + 1}',
                                nombre: extra,
                                descripcion:
                                    'Documento requerido para el contrato.',
                                obligatorio: true,
                              ),
                            );
                          }

                          try {
                            final valorNum =
                                int.tryParse(
                                  valorCtrl.text.replaceAll(
                                    RegExp(r'[^0-9]'),
                                    '',
                                  ),
                                ) ??
                                0;
                            final nuevo =
                                await JuridicoContratacionService.crearExpedienteContratoPs(
                                  entidadNombre: entidadCtrl.text,
                                  entidadNit: nitCtrl.text,
                                  dependencia: dependenciaCtrl.text,
                                  numeroContrato: numeroContratoCtrl.text,
                                  objetoContrato: objetoCtrl.text,
                                  valorContratoCop: valorNum,
                                  plazoEjecucion: plazoCtrl.text.trim().isEmpty
                                      ? 'Vigencia 2026'
                                      : plazoCtrl.text,
                                  contratistaNombreEsperado: nombreCtrl.text,
                                  contratistaCedulaEsperada: cedulaCtrl.text,
                                  contratistaCorreo: correoCtrl.text,
                                  contratistaTelefono: telefonoCtrl.text,
                                  apartados: apartados,
                                );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            _reemplazarExpedienteEnEstado(nuevo);
                            await _generarYMostrarLinkContratista(nuevo);
                          } catch (e) {
                            setModalState(() {
                              errorModal = e
                                  .toString()
                                  .replaceFirst('Invalid argument(s): ', '');
                            });
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _azulOscuro,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Crear contrato y generar link'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13.5, color: _azulOscuro),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _bordeSuave),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _bordeSuave),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _azulOscuro, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 768;
    final expedienteDetalle = _expedienteAbierto;

    return ColoredBox(
      color: _bgCrema,
      child: _cargando
          ? const Center(child: CircularProgressIndicator())
          : expedienteDetalle != null
          ? _buildDetalleVerificacionView(expedienteDetalle, width, isMobile)
          : _buildListaAspirantesView(isMobile),
    );
  }

  // ===========================================================================
  // VISTA 1: LISTA MINIMALISTA DE PERFILES DE ASPIRANTES A CONTRATISTA
  // ===========================================================================

  Widget _buildListaAspirantesView(bool isMobile) {
    final filtrados = _expedientesFiltrados;
    final totalPorRevisar = _expedientes
        .where((e) => e.totalEnRevision > 0)
        .length;
    final totalConObs = _expedientes
        .where((e) => e.totalPorSubsanar > 0)
        .length;
    final totalVerificados = _expedientes
        .where((e) => e.avalJuridicoEmitido || e.todosObligatoriosAprobados)
        .length;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 32,
        isMobile ? 18 : 26,
        isMobile ? 16 : 32,
        36,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado limpio y minimalista
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gestión contractual',
                          style: TextStyle(
                            color: _azulOscuro,
                            fontSize: isMobile ? 23 : 30,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 36,
                          height: 3.5,
                          decoration: BoxDecoration(
                            color: _dorado,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Contratación estatal de prestación de servicios (OPS) · Perfiles de aspirantes y verificación documental',
                          style: TextStyle(
                            color: _textoSecundario,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _abrirModalCrearContrato,
                    style: FilledButton.styleFrom(
                      backgroundColor: _azulOscuro,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 14 : 18,
                        vertical: isMobile ? 11 : 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: Text(
                      isMobile ? 'Crear' : 'Crear contrato',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: 12),
                    UserProfileHeaderAction(onLogout: widget.onLogout),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              // Filtro corto superior
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _bordeSuave),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: isMobile ? double.infinity : 360,
                      child: TextField(
                        controller: _busquedaController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: _azulOscuro,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText:
                              'Buscar por aspirante, cédula o número de contrato...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 19,
                            color: _textoSecundario,
                          ),
                          suffixIcon: _busquedaController.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _busquedaController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close, size: 16),
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildFiltroChip(
                          id: 'todos',
                          label: 'Todos (${_expedientes.length})',
                        ),
                        _buildFiltroChip(
                          id: 'revisar',
                          label: 'Por revisar ($totalPorRevisar)',
                        ),
                        _buildFiltroChip(
                          id: 'observados',
                          label: 'Con observaciones ($totalConObs)',
                        ),
                        _buildFiltroChip(
                          id: 'verificados',
                          label: 'Verificados ($totalVerificados)',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (filtrados.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 42,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _bordeSuave),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.person_search_outlined,
                        size: 40,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No se encontraron aspirantes con el filtro actual.',
                        style: TextStyle(
                          color: _azulOscuro,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Usa el botón "Crear contrato" para registrar un nuevo aspirante a contratista.',
                        style: TextStyle(
                          color: _textoSecundario,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final exp in filtrados)
                  _buildBannerPerfilAspirante(exp, isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltroChip({required String id, required String label}) {
    final activo = _filtroEstado == id;
    return InkWell(
      onTap: () => setState(() => _filtroEstado = id),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: activo ? _azulOscuro : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: activo ? _azulOscuro : _bordeSuave),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: activo ? Colors.white : const Color(0xFF475569),
            fontSize: 12,
            fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Banner minimalista tipo perfil de aspirante a contratista con un único
  /// botón abajo para generar el link personalizado del contrato.
  Widget _buildBannerPerfilAspirante(
    ExpedienteContratoPs exp,
    bool isMobile,
  ) {
    final nombre = exp.contratistaNombreEsperado.isEmpty
        ? 'Aspirante sin nombre'
        : exp.contratistaNombreEsperado;
    final iniciales = _obtenerIniciales(nombre);

    final (Color dotColor, Color pillBg, Color pillText) = () {
      if (exp.avalJuridicoEmitido || exp.todosObligatoriosAprobados) {
        return (
          const Color(0xFF16A34A),
          const Color(0xFFDCFCE7),
          const Color(0xFF166534),
        );
      }
      if (exp.totalPorSubsanar > 0) {
        return (
          const Color(0xFFD97706),
          const Color(0xFFFEF3C7),
          const Color(0xFF92400E),
        );
      }
      if (exp.totalEnRevision > 0) {
        return (
          const Color(0xFF2563EB),
          const Color(0xFFDBEAFE),
          const Color(0xFF1E40AF),
        );
      }
      return (
        const Color(0xFF64748B),
        const Color(0xFFF1F5F9),
        const Color(0xFF475569),
      );
    }();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _bordeSuave),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila superior de identidad del aspirante (texto seleccionable + acceso al detalle)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _abrirDetalleAspirante(exp),
                  borderRadius: BorderRadius.circular(28),
                  child: CircleAvatar(
                    radius: isMobile ? 21 : 24,
                    backgroundColor: _azulOscuro,
                    child: Text(
                      iniciales,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          InkWell(
                            onTap: () => _abrirDetalleAspirante(exp),
                            borderRadius: BorderRadius.circular(6),
                            child: Text(
                              nombre,
                              style: TextStyle(
                                color: _azulOscuro,
                                fontSize: isMobile ? 15.5 : 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: pillBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6.5,
                                  height: 6.5,
                                  decoration: BoxDecoration(
                                    color: dotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  exp.estadoGlobalEtiqueta,
                                  style: TextStyle(
                                    color: pillText,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 14,
                        runSpacing: 4,
                        children: [
                          Text(
                            'CC ${exp.contratistaCedulaEsperada.isEmpty ? "Por registrar" : exp.contratistaCedulaEsperada}',
                            style: const TextStyle(
                              color: _textoSecundario,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            exp.contratistaCorreo,
                            style: const TextStyle(
                              color: _textoSecundario,
                              fontSize: 12.5,
                            ),
                          ),
                          Text(
                            'Contrato ${exp.numeroContrato}',
                            style: const TextStyle(
                              color: _azulOscuro,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (exp.valorContratoCop > 0)
                            Text(
                              '${_monedaFormat.format(exp.valorContratoCop)} · ${exp.plazoEjecucion}',
                              style: const TextStyle(
                                color: _textoSecundario,
                                fontSize: 12.5,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isMobile)
                  Text(
                    '${exp.totalCargados}/${exp.totalApartados} documentos',
                    style: const TextStyle(
                      color: _textoSecundario,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              exp.objetoContrato,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            // Pie del perfil: único botón para generar link + acción para ver el detalle
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _generarYMostrarLinkContratista(exp),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _azulOscuro,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.link_rounded, size: 17),
                  label: const Text(
                    'Generar link para contratista',
                    style: TextStyle(
                      fontSize: 12.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _abrirDetalleAspirante(exp),
                  style: TextButton.styleFrom(
                    foregroundColor: _azulPrimario,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  icon: Text(
                    '${exp.totalAprobados} verificados · Ver expediente',
                    style: const TextStyle(
                      color: _azulPrimario,
                      fontSize: 12.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  label: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: _azulPrimario,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // VISTA 2: DETALLE DE DOCUMENTOS + PANEL DE VERIFICACIÓN Y TRAZABILIDAD
  // ===========================================================================

  Widget _buildDetalleVerificacionView(
    ExpedienteContratoPs exp,
    double screenWidth,
    bool isMobile,
  ) {
    final bool dosColumnas = screenWidth >= 980;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 30,
        isMobile ? 16 : 24,
        isMobile ? 16 : 30,
        40,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1220),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera limpia del perfil del aspirante y su contrato
              _buildCabeceraDetalleAspirante(exp, isMobile),
              const SizedBox(height: 18),

              if (dosColumnas)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _buildListaDocumentosRequeridosCard(exp),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 5,
                      child: _buildColumnaDerechaVerificacionYTrazabilidad(exp),
                    ),
                  ],
                )
              else ...[
                _buildListaDocumentosRequeridosCard(exp),
                const SizedBox(height: 18),
                _buildColumnaDerechaVerificacionYTrazabilidad(exp),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCabeceraDetalleAspirante(
    ExpedienteContratoPs exp,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bordeSuave),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: _volverAListaAspirantes,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _bordeSuave),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back_rounded,
                        size: 17,
                        color: _azulOscuro,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Volver',
                        style: TextStyle(
                          color: _azulOscuro,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6.5,
                        height: 6.5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Sincronización en tiempo real activa',
                        style: TextStyle(
                          color: Color(0xFF166534),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _abrirModalAgregarDocumento(exp),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _azulOscuro,
                      side: const BorderSide(color: _bordeSuave),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: Text(
                      isMobile ? 'Requisito' : 'Agregar requisito',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _generarYMostrarLinkContratista(exp),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _azulOscuro,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.link_rounded, size: 17),
                    label: const Text(
                      'Generar link para contratista',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _azulOscuro,
                child: Text(
                  _obtenerIniciales(exp.contratistaNombreEsperado),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exp.contratistaNombreEsperado,
                      style: TextStyle(
                        color: _azulOscuro,
                        fontSize: isMobile ? 17 : 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        Text(
                          'CC ${exp.contratistaCedulaEsperada}',
                          style: const TextStyle(
                            color: _textoSecundario,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          exp.contratistaCorreo,
                          style: const TextStyle(
                            color: _textoSecundario,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Contrato ${exp.numeroContrato}',
                          style: const TextStyle(
                            color: _azulOscuro,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${exp.entidadNombre} · ${exp.dependencia}',
                          style: const TextStyle(
                            color: _textoSecundario,
                            fontSize: 13,
                          ),
                        ),
                        if (exp.valorContratoCop > 0)
                          Text(
                            '${_monedaFormat.format(exp.valorContratoCop)} (${exp.plazoEjecucion})',
                            style: const TextStyle(
                              color: _textoSecundario,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      exp.objetoContrato,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Columna izquierda: lista minimalista de documentos cargados y pendientes
  /// con botón "Ver" y casilla "Devolver este documento".
  Widget _buildListaDocumentosRequeridosCard(ExpedienteContratoPs exp) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bordeSuave),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Documentos del contrato',
                    style: TextStyle(
                      color: _azulOscuro,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${exp.totalCargados} de ${exp.totalApartados} cargados',
                  style: const TextStyle(
                    color: _textoSecundario,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _bordeSuave),
          for (var i = 0; i < exp.apartados.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _buildFilaDocumentoVerificacion(exp, exp.apartados[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildFilaDocumentoVerificacion(
    ExpedienteContratoPs exp,
    ApartadoDocumentoContrato ap,
  ) {
    final marcadoDevolver = _idsMarcadosParaDevolver.contains(ap.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título del requisito + píldora limpia de estado (`• Cargado`, `• Verificado`, etc.)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                ap.nombre,
                style: const TextStyle(
                  color: _azulOscuro,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _buildStatusDotPill(ap.estado),
            ],
          ),
          const SizedBox(height: 10),

          // Caja limpia del archivo con ícono PDF y botón "Ver"
          if (ap.tieneArchivoCargado)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: marcadoDevolver
                      ? const Color(0xFFF59E0B)
                      : _bordeSuave,
                ),
              ),
              child: Row(
                children: [
                  _buildFileFormatBadge(ap.formatoCorto),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ap.archivoNombre ?? 'Documento cargado',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _azulOscuro,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${ap.formatoCorto}${ap.tamanoFormateado.isNotEmpty ? " · ${ap.tamanoFormateado}" : ""}${ap.versionCarga > 1 ? " · Versión ${ap.versionCarga}" : ""}',
                          style: const TextStyle(
                            color: _textoSecundario,
                            fontSize: 11.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () => _mostrarVistaPreviaDocumento(exp, ap),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _azulOscuro,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      minimumSize: const Size(58, 34),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Ver',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                'Sin archivo cargado aún · ${ap.descripcion}',
                style: const TextStyle(
                  color: _textoSecundario,
                  fontSize: 12.5,
                ),
              ),
            ),

          // Casilla limpia "Devolver este documento" debajo del soporte cargado
          if (ap.tieneArchivoCargado) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                setState(() {
                  if (marcadoDevolver) {
                    _idsMarcadosParaDevolver.remove(ap.id);
                  } else {
                    _idsMarcadosParaDevolver.add(ap.id);
                  }
                });
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: marcadoDevolver,
                        activeColor: const Color(0xFFD97706),
                        side: const BorderSide(color: Color(0xFF94A3B8)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _idsMarcadosParaDevolver.add(ap.id);
                            } else {
                              _idsMarcadosParaDevolver.remove(ap.id);
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Devolver este documento',
                      style: TextStyle(
                        color: marcadoDevolver
                            ? const Color(0xFFB45309)
                            : const Color(0xFF334155),
                        fontSize: 12.8,
                        fontWeight: marcadoDevolver
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (ap.requiereSubsanacion &&
              ap.observacionJuridica != null &&
              ap.observacionJuridica!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Text(
                'Observación enviada al contratista: ${ap.observacionJuridica}',
                style: const TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Columna derecha: Lista de chequeo jurídica + Concepto + Revisado y verificado
  /// + Observaciones para el contratista + Devolver al contratista + Trazabilidad.
  Widget _buildColumnaDerechaVerificacionYTrazabilidad(
    ExpedienteContratoPs exp,
  ) {
    final preguntas = JuridicoContratacionService.checklistVerificacionOps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tarjeta de verificación y devolución
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _bordeSuave),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Verificación jurídica',
                style: TextStyle(
                  color: _azulOscuro,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Revisa los soportes del contratista. Si hay algo por corregir, marca el documento a la izquierda y devuélvelo con observaciones.',
                style: TextStyle(
                  color: _textoSecundario,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),

              // 5 casillas de verificación OPS
              for (var i = 0; i < preguntas.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () {
                      final nuevoValor = !_checksLocales[i];
                      setState(() => _checksLocales[i] = nuevoValor);
                      JuridicoContratacionService.guardarEstadoChecklist(
                        tokenInvitado: exp.tokenInvitado,
                        checks: _checksLocales,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: _checksLocales[i],
                              activeColor: _azulOscuro,
                              side: const BorderSide(color: Color(0xFF94A3B8)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (v) {
                                setState(
                                  () => _checksLocales[i] = v ?? false,
                                );
                                JuridicoContratacionService.guardarEstadoChecklist(
                                  tokenInvitado: exp.tokenInvitado,
                                  checks: _checksLocales,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            preguntas[i],
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 12.8,
                              height: 1.38,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 8),
              const Text(
                'Concepto (opcional)',
                style: TextStyle(
                  color: _azulOscuro,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _conceptoController,
                style: const TextStyle(fontSize: 13.5, color: _azulOscuro),
                decoration: InputDecoration(
                  hintText: 'Ej.: Cumple',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _bordeSuave),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _bordeSuave),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Botón principal: Revisado y verificado
              FilledButton(
                onPressed: _procesandoAccion
                    ? null
                    : () => _ejecutarRevisadoYVerificado(exp),
                style: FilledButton.styleFrom(
                  backgroundColor: _azulPrimario,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Revisado y verificado',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 18),
              const Divider(height: 1, color: _bordeSuave),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Observaciones para el contratista',
                    style: TextStyle(
                      color: _azulOscuro,
                      fontSize: 12.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_idsMarcadosParaDevolver.isNotEmpty)
                    Text(
                      '${_idsMarcadosParaDevolver.length} seleccionado(s)',
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontSize: 11.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _observacionesController,
                maxLines: 3,
                style: const TextStyle(fontSize: 13.5, color: _azulOscuro),
                decoration: InputDecoration(
                  hintText: 'Qué debe corregir y cómo',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _bordeSuave),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _bordeSuave),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: _procesandoAccion
                    ? null
                    : () => _ejecutarDevolucionAlContratista(exp),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB45309),
                  side: const BorderSide(color: Color(0xFFF59E0B)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Devolver al contratista',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Acción limpia de correo de requerimiento + descarga opcional de acta
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _bordeSuave),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                onPressed: () => _ejecutarCorreoRequerimiento(exp),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB91C1C),
                  side: const BorderSide(color: Color(0xFFFECACA)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Enviar correo de requerimiento',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  JuridicoContratacionService.descargarActaVerificacionJuridicaPdf(
                    exp,
                  );
                },
                icon: const Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 16,
                  color: _textoSecundario,
                ),
                label: const Text(
                  'Descargar acta de verificación en PDF',
                  style: TextStyle(
                    color: _textoSecundario,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Tarjeta colapsable de Trazabilidad
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _bordeSuave),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => setState(
                  () => _trazabilidadExpandida = !_trazabilidadExpandida,
                ),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Trazabilidad (${exp.trazabilidad.length} eventos)',
                          style: const TextStyle(
                            color: _azulOscuro,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        _trazabilidadExpandida
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: _textoSecundario,
                      ),
                    ],
                  ),
                ),
              ),
              if (_trazabilidadExpandida) ...[
                const Divider(height: 1, color: _bordeSuave),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                  child: Column(
                    children: [
                      for (var i = 0; i < exp.trazabilidad.length; i++)
                        _buildEventoTrazabilidadItem(
                          exp.trazabilidad[i],
                          esUltimo: i == exp.trazabilidad.length - 1,
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventoTrazabilidadItem(
    EventoTrazabilidadContrato ev, {
    required bool esUltimo,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _azulPrimario,
                  shape: BoxShape.circle,
                ),
              ),
              if (!esUltimo)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: esUltimo ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    JuridicoContratacionService.formatearFechaHumana(
                      ev.fechaIso,
                    ),
                    style: const TextStyle(
                      color: _textoSecundario,
                      fontSize: 11.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: _azulOscuro,
                        fontSize: 13,
                        height: 1.38,
                      ),
                      children: [
                        TextSpan(
                          text: ev.actorNombre,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(text: ' · '),
                        TextSpan(text: ev.titulo),
                      ],
                    ),
                  ),
                  if (ev.detalle.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      ev.detalle,
                      style: const TextStyle(
                        color: _textoSecundario,
                        fontSize: 12.2,
                        height: 1.38,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDotPill(EstadoDocumentoJuridico estado) {
    final (Color dot, Color bg, Color fg) = switch (estado) {
      EstadoDocumentoJuridico.enRevision => (
        const Color(0xFF16A34A),
        const Color(0xFFDCFCE7),
        const Color(0xFF166534),
      ),
      EstadoDocumentoJuridico.subsanadoEnRevision => (
        const Color(0xFF0284C7),
        const Color(0xFFE0F2FE),
        const Color(0xFF075985),
      ),
      EstadoDocumentoJuridico.aprobado => (
        const Color(0xFF059669),
        const Color(0xFFD1FAE5),
        const Color(0xFF065F46),
      ),
      EstadoDocumentoJuridico.devueltoSubsanar => (
        const Color(0xFFD97706),
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
      ),
      EstadoDocumentoJuridico.pendiente => (
        const Color(0xFF94A3B8),
        const Color(0xFFF1F5F9),
        const Color(0xFF475569),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            estado.etiquetaCorta,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileFormatBadge(String formato) {
    final esPdf = formato.toUpperCase() == 'PDF';
    return Container(
      width: 34,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: esPdf ? const Color(0xFFFEE2E2) : const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        formato,
        style: TextStyle(
          color: esPdf ? const Color(0xFFB91C1C) : const Color(0xFF0369A1),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _obtenerIniciales(String nombre) {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return 'CT';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
  }
}
