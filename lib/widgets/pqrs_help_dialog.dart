import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/pqrs_service.dart';

/// Modal / BottomSheet SaaS para radicación directa de Peticiones, Quejas,
/// Reclamos, Sugerencias o Soporte (PQRS) desde la propia aplicación,
/// almacenando los registros en la nube (Firestore / Google Sheets en Drive)
/// sin abrir clientes de correo externos (`mailto:`).
class PqrsHelpDialog extends StatefulWidget {
  const PqrsHelpDialog({super.key, this.isBottomSheet = false});

  final bool isBottomSheet;

  /// Abre automáticamente un BottomSheet en pantallas móviles (< 600px) o un
  /// Dialog centrado en pantallas de escritorio/tablet.
  static Future<void> show(BuildContext context) async {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    if (isMobile) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
          ),
          child: const PqrsHelpDialog(isBottomSheet: true),
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: const PqrsHelpDialog(),
          ),
        ),
      );
    }
  }

  @override
  State<PqrsHelpDialog> createState() => _PqrsHelpDialogState();
}

class _PqrsHelpDialogState extends State<PqrsHelpDialog> {
  static const Color _navy = Color(0xFF0B224C);
  static const Color _gold = Color(0xFFF5B82E);
  static final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static const List<String> _tiposPqrs = <String>[
    'Soporte técnico',
    'Petición',
    'Queja o reclamo',
    'Sugerencia',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _correoController;
  final _asuntoController = TextEditingController();
  final _mensajeController = TextEditingController();

  String _tipoSolicitud = 'Soporte técnico';
  bool _isSending = false;
  bool _mostrarHistorial = false;
  PqrsRecord? _ultimoRadicado;
  List<PqrsRecord> _historial = const <PqrsRecord>[];

  @override
  void initState() {
    super.initState();
    _correoController = TextEditingController(
      text: AuthService.getActiveUserEmail(),
    );
    _cargarHistorial();
  }

  @override
  void dispose() {
    _correoController.dispose();
    _asuntoController.dispose();
    _mensajeController.dispose();
    super.dispose();
  }

  Future<void> _cargarHistorial() async {
    final registros = await PqrsService.obtenerHistorialLocal();
    if (!mounted) return;
    setState(() => _historial = registros);
  }

  Future<void> _enviarPqrs() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);
    try {
      final radicadoRecord = await PqrsService.enviarSolicitud(
        tipoSolicitud: _tipoSolicitud,
        asunto: _asuntoController.text.trim(),
        mensaje: _mensajeController.text.trim(),
        correoContacto: _correoController.text.trim(),
      );

      final registros = await PqrsService.obtenerHistorialLocal();
      if (!mounted) return;

      setState(() {
        _isSending = false;
        _ultimoRadicado = radicadoRecord;
        _historial = registros;
        _asuntoController.clear();
        _mensajeController.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFDC2626),
          content: Text(
            'Ocurrió un inconveniente al enviar tu solicitud. Inténtalo nuevamente.',
          ),
        ),
      );
    }
  }

  void _exportarCsv() {
    final descargado = PqrsService.exportarHistorialCsv(_historial);
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              descargado ? const Color(0xFF15803D) : const Color(0xFF0B224C),
          content: Text(
            descargado
                ? 'Archivo CSV descargado (listo para Google Drive o Excel).'
                : 'La descarga directa de CSV está disponible en la versión Web.',
          ),
        ),
      );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: icon == null,
      prefixIcon: icon != null ? Icon(icon, size: 19, color: _navy) : null,
      labelStyle: const TextStyle(
        color: Color(0xFF475569),
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _navy, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4D6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _gold.withValues(alpha: 0.55),
            ),
          ),
          child: const Icon(
            Icons.support_agent_rounded,
            color: _navy,
            size: 23,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Centro de Ayuda y PQRS',
                style: TextStyle(
                  color: _navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _mostrarHistorial
                    ? 'Solicitudes radicadas desde tu dispositivo.'
                    : 'Envíanos tu consulta, queja, reclamo o solicitud de soporte.',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12.8,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (_historial.isNotEmpty && _ultimoRadicado == null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton.icon(
              onPressed: () =>
                  setState(() => _mostrarHistorial = !_mostrarHistorial),
              style: TextButton.styleFrom(
                foregroundColor: _navy,
                backgroundColor: const Color(0xFFEEF3FA),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: Icon(
                _mostrarHistorial
                    ? Icons.add_comment_outlined
                    : Icons.history_rounded,
                size: 15,
              ),
              label: Text(
                _mostrarHistorial
                    ? 'Nuevo'
                    : 'Radicados (${_historial.length})',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        IconButton(
          tooltip: 'Cerrar',
          visualDensity: VisualDensity.compact,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.close_rounded,
            color: Color(0xFF64748B),
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmacionRadicado(PqrsRecord record) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF15803D),
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '¡Solicitud enviada exitosamente!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _navy,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Tu formulario quedó registrado directamente en nuestro repositorio sin necesidad de usar tu correo externo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 12.6,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Radicado: ',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SelectableText(
                      record.radicado,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: record.radicado));
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                            content: Text('Número de radicado copiado.'),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 15,
                          color: _navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${record.tipoSolicitud} · ${record.asunto}',
                style: const TextStyle(
                  color: _navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (record.correoContacto.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Correo de respuesta: ${record.correoContacto}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() => _ultimoRadicado = null),
              style: TextButton.styleFrom(
                foregroundColor: _navy,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Enviar otra solicitud',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: const Text(
                'Entendido',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHistorialView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _historial.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = _historial[index];
              final fechaCorta = item.fechaIso.length >= 10
                  ? item.fechaIso.substring(0, 10)
                  : item.fechaIso;
              return Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.radicado,
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.estado,
                            style: const TextStyle(
                              color: Color(0xFF166534),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.tipoSolicitud} · $fechaCorta',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.asunto,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: _exportarCsv,
              style: OutlinedButton.styleFrom(
                foregroundColor: _navy,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              icon: const Icon(Icons.table_view_rounded, size: 17),
              label: const Text(
                'Exportar CSV (Drive / Excel)',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _mostrarHistorial = false),
              style: TextButton.styleFrom(foregroundColor: _navy),
              child: const Text(
                'Volver al formulario',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormulario() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tipo in _tiposPqrs)
                ChoiceChip(
                  label: Text(tipo),
                  selected: _tipoSolicitud == tipo,
                  onSelected: (_) => setState(() => _tipoSolicitud = tipo),
                  selectedColor: _navy,
                  backgroundColor: const Color(0xFFF1F5F9),
                  checkmarkColor: _gold,
                  labelStyle: TextStyle(
                    color: _tipoSolicitud == tipo ? Colors.white : _navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: _tipoSolicitud == tipo
                          ? _navy
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _correoController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 13.8, color: _navy),
            decoration: _inputDecoration(
              label: 'Correo de contacto para respuesta',
              hint: 'tucorreo@ejemplo.com',
              icon: Icons.alternate_email_rounded,
            ),
            validator: (value) {
              final clean = value?.trim() ?? '';
              if (clean.isEmpty || !_emailRegex.hasMatch(clean)) {
                return 'Ingresa un correo válido para recibir respuesta.';
              }
              return null;
            },
          ),
          const SizedBox(height: 13),
          TextFormField(
            controller: _asuntoController,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 13.8, color: _navy),
            decoration: _inputDecoration(
              label: 'Asunto',
              hint: 'Ej. Duda sobre proceso contractual o reporte técnico',
              icon: Icons.subject_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().length < 4) {
                return 'Por favor escribe un asunto claro (mínimo 4 caracteres).';
              }
              return null;
            },
          ),
          const SizedBox(height: 13),
          TextFormField(
            controller: _mensajeController,
            maxLines: 4,
            minLines: 4,
            style: const TextStyle(fontSize: 13.8, color: _navy),
            decoration: _inputDecoration(
              label: 'Mensaje o descripción detallada',
              hint:
                  'Describe aquí tu solicitud, queja o sugerencia para que nuestro equipo te responda...',
            ),
            validator: (value) {
              if (value == null || value.trim().length < 10) {
                return 'Describe tu solicitud con al menos 10 caracteres.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.cloud_done_outlined,
                  size: 17,
                  color: Color(0xFF15803D),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Envío directo desde la plataforma: tu solicitud queda radicada automáticamente sin abrir tu correo.',
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 11.7,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed:
                    _isSending ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _isSending ? null : _enviarPqrs,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                icon: _isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 17),
                label: Text(
                  _isSending ? 'Enviando...' : 'Enviar solicitud',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isBottomSheet
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE6D6)),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isBottomSheet)
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            _buildHeader(),
            if (_ultimoRadicado != null)
              _buildConfirmacionRadicado(_ultimoRadicado!)
            else if (_mostrarHistorial)
              _buildHistorialView()
            else
              _buildFormulario(),
          ],
        ),
      ),
    );
  }
}
