import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/secop_document_intelligence_service.dart';
import '../utils/secop_launcher.dart';
import '../widgets/collapsible_side_menu.dart';
import '../widgets/dashboard_top_bar.dart';
import '../widgets/user_profile_header_action.dart';
import 'home_screen.dart';
import 'perfil_contratista_screen.dart';
import 'resultados_busqueda_screen.dart';

class DetalleContratoScreen extends StatefulWidget {
  final dynamic contrato;
  final int initialTab;

  const DetalleContratoScreen({
    super.key,
    required this.contrato,
    this.initialTab = 0,
  });

  @override
  State<DetalleContratoScreen> createState() => _DetalleContratoScreenState();
}

class _DetalleContratoScreenState extends State<DetalleContratoScreen> {
  static const _claveContratosFavoritos = 'contratos_favoritos';
  static const Color _azulOscuro = Color(0xFF1A2B4C);
  static const Color _azulPrimario = Color(0xFF1D4ED8);
  static const Color _amarillo = Color(0xFFF5B82E);

  final NumberFormat _formatoDecimal = NumberFormat.decimalPattern('es_CO');
  final TextEditingController _topSearchController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();
  final TextEditingController _docFilterController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  final List<Map<String, dynamic>> _mensajes = [];
  bool _isTyping = false;
  bool _esFavorito = false;
  bool _isSidebarCollapsed = false;
  bool _contextExpanded = true;
  bool _isExtractingDocs = false;
  String _extractingStepText = 'Conectando con el expediente en SECOP II...';
  SecopExtractionResult? _docExtractionResult;
  String _docSearchQuery = '';
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 2);
    _cargarEstadoFavorito();
    _cargarDocumentosCacheados();
    final desc = _descripcionContrato.toUpperCase();
    _mensajes.add({
      'sender': 'ai',
      'text':
          'Hola, soy tu Copiloto IA. Estoy analizando el contrato:\n"$desc".\n\n¿Qué deseas saber sobre este contrato?',
    });
  }

  @override
  void dispose() {
    _topSearchController.dispose();
    _chatController.dispose();
    _docFilterController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  String get _descripcionContrato {
    final raw = (widget.contrato['descripcion_del_proceso'] ??
            widget.contrato['objeto_del_contrato'] ??
            'Contrato estatal SECOP II')
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return raw.isEmpty ? 'Contrato estatal SECOP II' : raw;
  }

  String get _entidadContrato {
    final raw = (widget.contrato['nombre_entidad'] ?? 'Entidad Pública')
        .toString()
        .trim();
    return raw.isEmpty ? 'Entidad Pública' : raw;
  }

  String get _contratistaContrato {
    final raw = (widget.contrato['proveedor_adjudicado'] ?? 'No disponible')
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return raw.isEmpty ? 'No disponible' : raw;
  }

  String get _modalidadContrato {
    final raw =
        (widget.contrato['modalidad_de_contratacion'] ?? 'Contratación directa')
            .toString()
            .trim();
    return raw.isEmpty ? 'Contratación directa' : raw;
  }

  String get _estadoContrato {
    final raw = (widget.contrato['estado_contrato'] ?? 'Aprobado')
        .toString()
        .trim();
    return raw.isEmpty ? 'Aprobado' : raw;
  }

  String get _procesoContrato {
    final raw = (widget.contrato['proceso_de_compra'] ??
            widget.contrato['id_contrato'] ??
            widget.contrato['referencia_del_contrato'] ??
            'Proceso SECOP II')
        .toString()
        .trim();
    return raw.isEmpty ? 'Proceso SECOP II' : raw;
  }

  String get _referenciaContrato {
    final raw = (widget.contrato['referencia_del_contrato'] ??
            widget.contrato['id_contrato'] ??
            _procesoContrato)
        .toString()
        .trim();
    return raw.isEmpty ? _procesoContrato : raw;
  }

  String get _fechaFirmaIso {
    final raw = (widget.contrato['fecha_de_firma'] ??
            widget.contrato['fecha_de_inicio_del_contrato'] ??
            '2026-10-09')
        .toString();
    return raw.split('T').first;
  }

  String get _fechaFirmaCorta {
    final iso = _fechaFirmaIso;
    final parts = iso.split('-');
    if (parts.length == 3) {
      const months = [
        'ene',
        'feb',
        'mar',
        'abr',
        'may',
        'jun',
        'jul',
        'ago',
        'sep',
        'oct',
        'nov',
        'dic',
      ];
      final m = int.tryParse(parts[1]) ?? 1;
      final monthName = months[(m - 1).clamp(0, 11)];
      return '${parts[2]} $monthName ${parts[0]}';
    }
    return iso;
  }

  double get _valorNumerico {
    return double.tryParse(
          widget.contrato['valor_del_contrato']?.toString() ?? '0',
        ) ??
        0;
  }

  String get _valorFormateado {
    return '\$ ${_formatoDecimal.format(_valorNumerico.round())}';
  }

  String _toTitleCase(String text) {
    const smallWords = {
      'de',
      'del',
      'la',
      'las',
      'el',
      'los',
      'y',
      'e',
      'en',
      'para',
      'por',
      'con',
      'a',
      'al',
    };
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    final out = <String>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.isEmpty) continue;
      if (i > 0 && smallWords.contains(w)) {
        out.add(w);
      } else {
        out.add(w[0].toUpperCase() + w.substring(1));
      }
    }
    return out.join(' ');
  }

  String _idContrato(dynamic contrato) {
    if (contrato is! Map) return '';
    final proceso = contrato['proceso_de_compra']?.toString() ??
        contrato['id_contrato']?.toString() ??
        contrato['referencia_del_contrato']?.toString();
    if (proceso != null && proceso.isNotEmpty) return proceso;
    return '${contrato['nombre_entidad'] ?? ''}'
        '${contrato['descripcion_del_proceso'] ?? ''}';
  }

  Future<void> _cargarEstadoFavorito() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritos = prefs.getStringList(_claveContratosFavoritos) ?? [];
    final idContrato = _idContrato(widget.contrato);
    final estaGuardado = favoritos.any((favorito) {
      try {
        final contrato = json.decode(favorito);
        return contrato is Map && _idContrato(contrato) == idContrato;
      } catch (_) {
        return false;
      }
    });

    if (!mounted) return;
    setState(() => _esFavorito = estaGuardado);
  }

  Future<void> _alternarFavorito() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritos = prefs.getStringList(_claveContratosFavoritos) ?? [];
    final idContrato = _idContrato(widget.contrato);
    final indice = favoritos.indexWhere((favorito) {
      try {
        final contrato = json.decode(favorito);
        return contrato is Map && _idContrato(contrato) == idContrato;
      } catch (_) {
        return false;
      }
    });
    final guardado = indice == -1;

    if (guardado) {
      favoritos.add(json.encode(widget.contrato));
    } else {
      favoritos.removeAt(indice);
    }
    await prefs.setStringList(_claveContratosFavoritos, favoritos);

    if (!mounted) return;
    setState(() => _esFavorito = guardado);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          guardado
              ? 'Contrato guardado en favoritos'
              : 'Contrato eliminado de favoritos',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _compartirContrato() async {
    final url = _obtenerUrlSecop();
    await Clipboard.setData(
      ClipboardData(
        text:
            '$_descripcionContrato - $_entidadContrato ($_valorFormateado)\n$url',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enlace e información del contrato copiados al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String? _extraerUrlProcesoReal() {
    if (widget.contrato is! Map) return null;
    final rawUrl = widget.contrato['urlproceso'];
    String candidate = '';

    if (rawUrl is Map && rawUrl['url'] != null) {
      candidate = rawUrl['url'].toString().trim();
    } else if (rawUrl is String) {
      final trimmed = rawUrl.trim();
      if (trimmed.startsWith('{')) {
        try {
          final decoded = json.decode(trimmed);
          if (decoded is Map && decoded['url'] != null) {
            candidate = decoded['url'].toString().trim();
          }
        } catch (_) {}
      } else {
        candidate = trimmed;
      }
    }

    if (candidate.isNotEmpty) {
      if (candidate.startsWith('http://') || candidate.startsWith('https://')) {
        return candidate;
      }
      if (candidate.startsWith('community.secop.gov.co') ||
          candidate.startsWith('www.')) {
        return 'https://$candidate';
      }
    }

    final proceso =
        (widget.contrato['proceso_de_compra'] ?? '').toString().trim();
    if (proceso.isNotEmpty && proceso.toUpperCase() != 'NO DEFINIDO') {
      return 'https://community.secop.gov.co/Public/Tendering/OpportunityDetail/Index?noticeUID=${Uri.encodeComponent(proceso)}';
    }

    return null;
  }

  String _obtenerUrlSecop() {
    if (_docExtractionResult != null &&
        _docExtractionResult!.resolvedSecopUrl.isNotEmpty) {
      return _docExtractionResult!.resolvedSecopUrl;
    }
    final extracted = _extraerUrlProcesoReal();
    if (extracted != null) {
      return SecopDocumentIntelligenceService.construirUrlVistaDocumental(
        extracted,
      );
    }
    return 'https://www.colombiacompra.gov.co/secop-ii';
  }

  Future<void> _cargarDocumentosCacheados() async {
    final cached = await SecopDocumentIntelligenceService.obtenerCacheSiExiste(
      widget.contrato,
    );
    if (!mounted || cached == null) return;
    setState(() {
      _docExtractionResult = cached;
    });
  }

  Future<void> _ejecutarExtraccionDocumentos({bool forceRefresh = false}) async {
    if (_isExtractingDocs) return;
    setState(() {
      _isExtractingDocs = true;
      _docSearchQuery = '';
      _docFilterController.clear();
      _extractingStepText =
          'Conectando con la sección Documentación de SECOP II...';
    });

    final result =
        await SecopDocumentIntelligenceService.extraerDocumentosContrato(
      widget.contrato,
      forceRefresh: forceRefresh,
      onProgress: (stepMsg) {
        if (!mounted) return;
        setState(() => _extractingStepText = stepMsg);
      },
    );

    if (!mounted) return;
    setState(() {
      _isExtractingDocs = false;
      _docExtractionResult = result;
    });
  }

  Future<void> _extraerDesdePortapapeles() async {
    try {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      final rawText = clip?.text?.trim() ?? '';
      if (rawText.length < 15) {
        if (!mounted) return;
        await _mostrarDialogoPegarSecop();
        return;
      }

      setState(() {
        _isExtractingDocs = true;
        _extractingStepText =
            'Extrayendo nombres reales de documentos desde el texto copiado...';
      });

      final result =
          await SecopDocumentIntelligenceService.procesarTextoCopiadoDeSecop(
        contrato: widget.contrato,
        rawCopiedText: rawText,
      );

      if (!mounted) return;
      setState(() {
        _isExtractingDocs = false;
        _docExtractionResult = result;
      });

      if (result.status != SecopExtractionStatus.success) {
        await _mostrarDialogoPegarSecop();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isExtractingDocs = false);
      await _mostrarDialogoPegarSecop();
    }
  }

  Future<void> _mostrarDialogoPegarSecop() async {
    final pasteController = TextEditingController();
    final textoPegado = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: _azulPrimario, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Extraer lista de documentos',
                  style: TextStyle(
                    color: _azulOscuro,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'En la ventana abierta del SECOP presiona Ctrl+A y luego Ctrl+C, y pega el contenido aquí abajo (Ctrl+V). Nuestra inteligencia filtrará únicamente los nombres reales de la sección Documentación:',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: pasteController,
                  maxLines: 6,
                  autofocus: true,
                  style: const TextStyle(fontSize: 12.5, color: _azulOscuro),
                  decoration: InputDecoration(
                    hintText:
                        'Pega aquí (Ctrl+V) el texto copiado de la página del proceso en SECOP...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12.5,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: _azulPrimario,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(pasteController.text),
              icon: const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: _amarillo,
              ),
              label: const Text(
                'Extraer nombres',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _azulOscuro,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        );
      },
    );
    pasteController.dispose();

    if (textoPegado == null || textoPegado.trim().isEmpty || !mounted) return;

    setState(() {
      _isExtractingDocs = true;
      _extractingStepText =
          'Filtrando los nombres reales de los documentos...';
    });

    final result =
        await SecopDocumentIntelligenceService.procesarTextoCopiadoDeSecop(
      contrato: widget.contrato,
      rawCopiedText: textoPegado,
    );

    if (!mounted) return;
    setState(() {
      _isExtractingDocs = false;
      _docExtractionResult = result;
    });
  }

  Future<void> _abrirEnlaceSecop() async {
    final targetUrl = _obtenerUrlSecop();
    final uri = Uri.tryParse(targetUrl);

    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se encontró una dirección válida de SECOP para este contrato.',
          ),
          backgroundColor: Color(0xFFB91C1C),
        ),
      );
      return;
    }

    try {
      bool launched = false;

      if (kIsWeb) {
        // En Web se abre una ventana superpuesta centrada (o pestaña controlada)
        // para que el usuario resuelva el reCAPTCHA del SECOP, consulte y
        // descargue el listado real de documentos, y regrese cerrando la vista.
        launched = openControlledSecopPopup(uri.toString());
        if (!launched) {
          launched = await launchUrl(
            uri,
            mode: LaunchMode.inAppBrowserView,
            webOnlyWindowName: 'secop_expediente_oficial',
          );
        }
      } else {
        // En plataformas móviles/nativas se utiliza vista integrada In-App.
        launched = await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );
        if (!launched) {
          launched = await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
            webViewConfiguration: const WebViewConfiguration(
              enableJavaScript: true,
              enableDomStorage: true,
            ),
          );
        }
        if (!launched) {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      if (mounted && launched && kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: _azulOscuro,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: const Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: _amarillo,
                  size: 19,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Vista oficial del SECOP abierta. Completa el reCAPTCHA para ver o descargar los anexos y cierra la ventana para volver.',
                    style: TextStyle(fontSize: 12.5, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No fue posible abrir el visor oficial del SECOP en este momento.',
          ),
          backgroundColor: Color(0xFFB91C1C),
        ),
      );
    }
  }

  void _abrirPerfilContratista() {
    final rawContractor =
        widget.contrato['proveedor_adjudicado']?.toString().trim() ??
            _contratistaContrato;
    if (rawContractor.isEmpty || rawContractor == 'No disponible') return;
    final docProveedor =
        widget.contrato['documento_proveedor']?.toString().trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PerfilContratistaScreen(
          nombreContratista: _contratistaContrato,
          nombreBuscado: rawContractor,
          documentoProveedor: docProveedor,
          nit: docProveedor,
        ),
      ),
    );
  }

  void _onSidebarItemSelected(int index) {
    if (index == 2 && Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomeScreen(initialIndex: index)),
      (route) => false,
    );
  }

  Future<void> _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('usuarioActivo');
    await prefs.remove('userEmail');
  }

  void _handleTopSearch(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResultadosBusquedaScreen(query: q)),
    );
  }

  Future<void> _enviarMensaje(String texto) async {
    final cleanText = texto.trim();
    if (cleanText.isEmpty) return;

    setState(() {
      _mensajes.add({'sender': 'user', 'text': cleanText});
      _isTyping = true;
      _chatController.clear();
    });

    _bajarScrollChat();

    try {
      const String apiKey = String.fromEnvironment('GEMINI_API_KEY');
      if (apiKey.isEmpty) {
        throw Exception('GEMINI_API_KEY no configurada');
      }
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );

      final String contextoContrato = '''
Eres el "Copiloto IA", un asesor legal experto en contratación pública de Colombia (SECOP II).
El usuario te hará preguntas sobre un contrato. Tu regla principal es NUNCA repetir textualmente la información como una lista robótica. Analízala, explícala en lenguaje claro y aporta valor ciudadano y jurídico.

DATOS DEL CONTRATO:
- Entidad: $_entidadContrato
- Objeto: $_descripcionContrato
- Valor: $_valorFormateado COP
- Adjudicatario: $_contratistaContrato
- Modalidad: $_modalidadContrato
- Estado actual: $_estadoContrato
- Fecha de firma: $_fechaFirmaIso

PREGUNTA DEL USUARIO: $cleanText
''';

      final response = await model
          .generateContent([Content.text(contextoContrato)])
          .timeout(const Duration(seconds: 18));

      if (!mounted) return;
      setState(() {
        _isTyping = false;
        final respuestaLimpia = response.text?.replaceAll('**', '').trim() ??
            _generarRespuestaLocalInteligente(cleanText);
        _mensajes.add({'sender': 'ai', 'text': respuestaLimpia});
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _mensajes.add({
          'sender': 'ai',
          'text': _generarRespuestaLocalInteligente(cleanText),
        });
      });
    }

    _bajarScrollChat();
  }

  String _generarRespuestaLocalInteligente(String pregunta) {
    final q = pregunta.toLowerCase();
    if (q.contains('resum') || q.contains('objeto') || q.contains('trata')) {
      return 'Este contrato fue suscrito por $_entidadContrato con el propósito de ejecutar: "$_descripcionContrato".\n\nEn términos prácticos, busca atender una necesidad operativa e institucional mediante la modalidad de $_modalidadContrato, con un presupuesto oficial de $_valorFormateado y estado actual $_estadoContrato.';
    }
    if (q.contains('presupuesto') ||
        q.contains('cuánto') ||
        q.contains('cuanto') ||
        q.contains('valor') ||
        q.contains('modalidad')) {
      return 'El valor total adjudicado es de $_valorFormateado COP y se tramitó bajo la modalidad de $_modalidadContrato.\n\nDe acuerdo con el Estatuto General de Contratación de la Administración Pública (Ley 80 de 1993 y Ley 1150 de 2007), esta modalidad exige justificación previa de la necesidad e idoneidad en los estudios previos publicados en SECOP II.';
    }
    if (q.contains('contratista') || q.contains('quién') || q.contains('quien')) {
      return 'El contratista adjudicatario es $_contratistaContrato, con fecha de firma registrada el $_fechaFirmaCorta ante $_entidadContrato.\n\nPuedes hacer clic sobre el nombre del contratista en la ficha técnica para abrir su Perfil Unificado y auditar todos sus contratos históricos en SECOP II y su estado en SIGEP.';
    }
    if (q.contains('riesgo') || q.contains('alerta')) {
      return 'Análisis preventivo del contrato ($_valorFormateado):\n\n1. Modalidad ($_modalidadContrato): Verifica en los Estudios Previos la justificación de idoneidad y la tabla de honorarios o precios de mercado de la entidad.\n2. Seguimiento de ejecución: El contrato figura como "$_estadoContrato" desde su firma el $_fechaFirmaCorta. Es recomendable revisar los informes de supervisión en el expediente oficial de SECOP II.';
    }
    if (q.contains('pliego') || q.contains('criterio')) {
      return 'En un proceso de $_modalidadContrato adelantado por $_entidadContrato, los documentos rectores definen las obligaciones específicas del contratista ($_contratistaContrato), el plazo de ejecución, la forma de pago y los requisitos habilitantes jurídicos, técnicos y financieros.';
    }
    return 'Sobre este proceso de $_entidadContrato ($_valorFormateado, modalidad $_modalidadContrato): el contrato tiene por objeto "$_descripcionContrato", adjudicado a $_contratistaContrato y firmado el $_fechaFirmaCorta en estado $_estadoContrato.';
  }

  void _bajarScrollChat() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildHeaderRow({
    required bool showTopRightActions,
    bool isMobile = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          onTap: () => Navigator.maybePop(context),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: isMobile ? 36 : 40,
            height: isMobile ? 36 : 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _azulOscuro.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back,
              color: _azulOscuro,
              size: isMobile ? 17 : 19,
            ),
          ),
        ),
        SizedBox(width: isMobile ? 12 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detalle del contrato',
                style: TextStyle(
                  color: _azulOscuro,
                  fontSize: isMobile ? 22 : 32,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: _amarillo,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
        if (showTopRightActions) ...[
          _buildActionIconButton(
            icon: _esFavorito
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            iconColor: _esFavorito ? Colors.amber.shade700 : _azulOscuro,
            tooltip: _esFavorito
                ? 'Eliminar de favoritos'
                : 'Guardar en favoritos',
            onTap: _alternarFavorito,
            elevatedWhite: true,
          ),
          const SizedBox(width: 10),
          _buildActionIconButton(
            icon: Icons.share_outlined,
            iconColor: _azulOscuro,
            tooltip: 'Compartir contrato',
            onTap: _compartirContrato,
            elevatedWhite: true,
          ),
        ],
      ],
    );
  }

  Widget _buildActionIconButton({
    required IconData icon,
    required Color iconColor,
    required String tooltip,
    required VoidCallback onTap,
    bool elevatedWhite = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: elevatedWhite ? 42 : 38,
          height: elevatedWhite ? 42 : 38,
          decoration: BoxDecoration(
            color: elevatedWhite ? Colors.white : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: elevatedWhite
                ? [
                    BoxShadow(
                      color: _azulOscuro.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Icon(icon, color: iconColor, size: 19),
        ),
      ),
    );
  }

  Widget _buildTabsBar({required bool insideSummaryCard}) {
    Widget tabItem({
      required int index,
      required IconData icon,
      required String label,
      bool showSparkle = false,
    }) {
      final bool isSelected = _selectedTab == index;
      final Color activeColor =
          insideSummaryCard ? _azulOscuro : _azulPrimario;
      final Color inactiveColor = const Color(0xFF475569);

      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _selectedTab = index),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 17,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? activeColor : inactiveColor,
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    if (showSparkle) ...[
                      const SizedBox(width: 4),
                      const Text('✨', style: TextStyle(fontSize: 13)),
                    ],
                  ],
                ),
              ),
              Container(
                height: 3,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isSelected ? _amarillo : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Row(
        children: [
          tabItem(
            index: 0,
            icon: Icons.description_outlined,
            label: 'Resumen',
          ),
          tabItem(
            index: 1,
            icon: Icons.insert_drive_file_outlined,
            label: 'Documentos',
          ),
          tabItem(
            index: 2,
            icon: Icons.auto_awesome_outlined,
            label: 'Copiloto IA',
            showSparkle: true,
          ),
        ],
      ),
    );
  }

  Widget _buildResumenTabContent({bool isMobile = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _azulOscuro.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _estadoContrato,
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _buildActionIconButton(
                icon: _esFavorito
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                iconColor: _esFavorito ? Colors.amber.shade700 : _azulOscuro,
                tooltip: _esFavorito
                    ? 'Eliminar de favoritos'
                    : 'Guardar en favoritos',
                onTap: _alternarFavorito,
              ),
              const SizedBox(width: 8),
              _buildActionIconButton(
                icon: Icons.share_outlined,
                iconColor: _azulOscuro,
                tooltip: 'Compartir contrato',
                onTap: _compartirContrato,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _descripcionContrato.toUpperCase(),
            style: TextStyle(
              color: _azulOscuro,
              fontSize: isMobile ? 16.5 : 19.5,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _valorFormateado,
            style: TextStyle(
              color: const Color(0xFF15803D),
              fontSize: isMobile ? 24 : 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          _buildTabsBar(insideSummaryCard: true),
          const SizedBox(height: 22),
          if (isMobile) ...[
            _buildResumenInfoBox(
              icon: Icons.account_balance_outlined,
              iconColor: const Color(0xFF2563EB),
              iconBg: const Color(0xFFE8F1FF),
              label: 'Entidad contratante',
              value: _entidadContrato.toUpperCase(),
            ),
            const SizedBox(height: 10),
            _buildResumenInfoBox(
              icon: Icons.person_outline,
              iconColor: const Color(0xFF16A34A),
              iconBg: const Color(0xFFE6F6EC),
              label: 'Contratista',
              value: _contratistaContrato.toUpperCase(),
              isLink: true,
              onTap: _abrirPerfilContratista,
            ),
            const SizedBox(height: 10),
            _buildResumenInfoBox(
              icon: Icons.gavel_rounded,
              iconColor: const Color(0xFFE5A000),
              iconBg: const Color(0xFFFEF5D8),
              label: 'Modalidad',
              value: _modalidadContrato,
            ),
            const SizedBox(height: 10),
            _buildResumenInfoBox(
              icon: Icons.calendar_today_outlined,
              iconColor: const Color(0xFF4F46E5),
              iconBg: const Color(0xFFEDE9FE),
              label: 'Fecha de firma',
              value: _fechaFirmaIso,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildResumenInfoBox(
                    icon: Icons.account_balance_outlined,
                    iconColor: const Color(0xFF2563EB),
                    iconBg: const Color(0xFFE8F1FF),
                    label: 'Entidad contratante',
                    value: _entidadContrato.toUpperCase(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildResumenInfoBox(
                    icon: Icons.person_outline,
                    iconColor: const Color(0xFF16A34A),
                    iconBg: const Color(0xFFE6F6EC),
                    label: 'Contratista',
                    value: _contratistaContrato.toUpperCase(),
                    isLink: true,
                    onTap: _abrirPerfilContratista,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildResumenInfoBox(
                    icon: Icons.gavel_rounded,
                    iconColor: const Color(0xFFE5A000),
                    iconBg: const Color(0xFFFEF5D8),
                    label: 'Modalidad',
                    value: _modalidadContrato,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildResumenInfoBox(
                    icon: Icons.calendar_today_outlined,
                    iconColor: const Color(0xFF4F46E5),
                    iconBg: const Color(0xFFEDE9FE),
                    label: 'Fecha de firma',
                    value: _fechaFirmaIso,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _abrirEnlaceSecop,
              icon: const Icon(
                Icons.open_in_new,
                size: 17,
                color: _azulOscuro,
              ),
              label: const Text(
                'Ver expediente original en SECOP',
                style: TextStyle(
                  color: _azulOscuro,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFF8FAFC),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenInfoBox({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
    bool isLink = false,
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEF2F6)),
        boxShadow: [
          BoxShadow(
            color: _azulOscuro.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 23),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isLink ? _azulPrimario : _azulOscuro,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    decoration: isLink ? TextDecoration.underline : null,
                    decorationColor: _azulPrimario,
                  ),
                ),
              ],
            ),
          ),
          if (isLink) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.open_in_new,
              size: 17,
              color: _azulPrimario,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: content,
      );
    }
    return content;
  }

  Widget _buildDocumentosTabContent({bool isMobile = false}) {
    final referenciaDetalle = _referenciaContrato != _procesoContrato
        ? '$_procesoContrato · Ref: $_referenciaContrato'
        : _procesoContrato;

    Widget innerContent;
    if (_isExtractingDocs) {
      innerContent = _buildDocumentosLoadingState(isMobile: isMobile);
    } else if (_docExtractionResult == null) {
      innerContent = _buildDocumentosInitialState(
        isMobile: isMobile,
        referenciaDetalle: referenciaDetalle,
      );
    } else if (_docExtractionResult!.status == SecopExtractionStatus.success &&
        _docExtractionResult!.documents.isNotEmpty) {
      innerContent = _buildDocumentosExtractedListState(
        isMobile: isMobile,
        referenciaDetalle: referenciaDetalle,
        result: _docExtractionResult!,
      );
    } else if (_docExtractionResult!.status ==
        SecopExtractionStatus.emptyOfficialList) {
      innerContent = _buildDocumentosEmptyOfficialState(
        isMobile: isMobile,
        message: _docExtractionResult!.errorMessage,
      );
    } else {
      innerContent = _buildDocumentosCaptchaFallbackState(
        isMobile: isMobile,
        message: _docExtractionResult!.errorMessage,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTabsBar(insideSummaryCard: false),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 18 : 32,
            vertical: isMobile ? 26 : 36,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _azulOscuro.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: innerContent,
        ),
      ],
    );
  }

  Widget _buildDocumentosInitialState({
    required bool isMobile,
    required String referenciaDetalle,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFEFF6FF),
                        border: Border.all(
                          color: const Color(0xFFDBEAFE),
                          width: 1.5,
                        ),
                      ),
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _azulOscuro,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: _azulOscuro.withValues(alpha: 0.18),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.find_in_page_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _amarillo,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: _azulOscuro.withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: _azulOscuro,
                          size: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 13,
                      color: _azulPrimario,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'INTELIGENCIA DOCUMENTAL · SECOP II',
                      style: TextStyle(
                        color: _azulPrimario,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Conoce qué documentos tiene este contrato',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _azulOscuro,
                  fontSize: isMobile ? 20 : 23,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Escanea en tiempo real la sección "Documentación" de este expediente en SECOP II para extraer y listar aquí los nombres exactos de los anexos publicados antes de ir a descargarlos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF475569),
                  fontSize: isMobile ? 14 : 15,
                  fontWeight: FontWeight.w500,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      size: 16,
                      color: _azulPrimario,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Proceso vinculado: $referenciaDetalle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _ejecutarExtraccionDocumentos(forceRefresh: false),
                  icon: const Icon(
                    Icons.auto_awesome_rounded,
                    color: _amarillo,
                    size: 20,
                  ),
                  label: Text(
                    'Extraer listado de documentos del SECOP',
                    style: TextStyle(
                      fontSize: isMobile ? 13.5 : 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _azulOscuro,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: _azulOscuro.withValues(alpha: 0.25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _abrirEnlaceSecop,
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: const Text(
                  'O abrir directamente la sección en SECOP II',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentosLoadingState({required bool isMobile}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 28 : 44),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 68,
                height: 68,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _azulPrimario,
                        ),
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: _azulOscuro,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Analizando sección Documentación en SECOP II',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _azulOscuro,
                  fontSize: isMobile ? 17 : 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _extractingStepText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Extrayendo únicamente los nombres reales de los anexos cargados por la entidad...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentosExtractedListState({
    required bool isMobile,
    required String referenciaDetalle,
    required SecopExtractionResult result,
  }) {
    final allDocs = result.documents;
    final queryNorm = SecopDocumentIntelligenceService.normalizarTexto(
      _docSearchQuery.trim(),
    );
    final filteredDocs = queryNorm.isEmpty
        ? allDocs
        : allDocs.where((d) {
            final nameNorm =
                SecopDocumentIntelligenceService.normalizarTexto(d.name);
            final catNorm =
                SecopDocumentIntelligenceService.normalizarTexto(d.category);
            return nameNorm.contains(queryNorm) || catNorm.contains(queryNorm);
          }).toList();

    final countBadgeText = allDocs.length == 1
        ? '1 documento detectado'
        : '${allDocs.length} documentos detectados';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Encabezado con contador real y botón de actualizar
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.fact_check_outlined,
                color: _azulPrimario,
                size: 24,
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
                      Text(
                        'Documentos encontrados en SECOP II',
                        style: TextStyle(
                          color: _azulOscuro,
                          fontSize: isMobile ? 17.5 : 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 13,
                              color: Color(0xFF059669),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              countBadgeText,
                              style: const TextStyle(
                                color: Color(0xFF047857),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sección "Documentación" · Proceso: $referenciaDetalle',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: 'Volver a consultar SECOP II',
              child: isMobile
                  ? OutlinedButton(
                      onPressed: () =>
                          _ejecutarExtraccionDocumentos(forceRefresh: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _azulOscuro,
                        minimumSize: const Size(40, 40),
                        padding: EdgeInsets.zero,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Icon(Icons.refresh_rounded, size: 18),
                    )
                  : OutlinedButton.icon(
                      onPressed: () =>
                          _ejecutarExtraccionDocumentos(forceRefresh: true),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Actualizar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _azulOscuro,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Resumen ejecutivo inteligente de lo que encontrará el usuario
        if (result.summaryText.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: _azulPrimario,
                  size: 19,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.summaryText,
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Buscador rápido dentro de la lista cuando hay 6 o más anexos
        if (allDocs.length >= 6) ...[
          TextField(
            controller: _docFilterController,
            onChanged: (v) => setState(() => _docSearchQuery = v),
            style: const TextStyle(fontSize: 13, color: _azulOscuro),
            decoration: InputDecoration(
              hintText:
                  'Filtrar documentos por nombre o categoría (ej. Estudios previos, CDP, Adenda)...',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 19,
                color: Color(0xFF64748B),
              ),
              suffixIcon: _docSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _docFilterController.clear();
                        setState(() => _docSearchQuery = '');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: _azulPrimario, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Listado limpio de los nombres reales extraídos de SECOP
        if (filteredDocs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Ningún documento coincide con "$_docSearchQuery".',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13.5,
                ),
              ),
            ),
          )
        else
          for (var i = 0; i < filteredDocs.length; i++)
            _buildExtractedDocumentItemCard(
              index: i + 1,
              doc: filteredDocs[i],
              isMobile: isMobile,
            ),

        const SizedBox(height: 18),

        // Pie de acción para ir a descargar los archivos reales en SECOP II
        Container(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '¿Ya identificaste los documentos que necesitas? Abre el expediente oficial para descargarlos directamente desde SECOP II.',
                      style: TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _abrirEnlaceSecop,
                        icon: const Icon(
                          Icons.open_in_browser_rounded,
                          color: _amarillo,
                          size: 19,
                        ),
                        label: const Text(
                          'Ir a SECOP para descargar documentos',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _azulOscuro,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(
                        Icons.cloud_download_outlined,
                        color: _azulOscuro,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¿Listo para descargar los archivos originales?',
                            style: TextStyle(
                              color: _azulOscuro,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Ya sabes exactamente qué anexos contiene este proceso. Abre la vista oficial de SECOP II para descargar los PDFs.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _abrirEnlaceSecop,
                        icon: const Icon(
                          Icons.open_in_browser_rounded,
                          color: _amarillo,
                          size: 19,
                        ),
                        label: const Text(
                          'Ir a SECOP a descargar',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _azulOscuro,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildExtractedDocumentItemCard({
    required int index,
    required SecopExtractedDocument doc,
    required bool isMobile,
  }) {
    final ext = doc.extension.toUpperCase();
    Color badgeBg;
    Color badgeText;
    IconData fileIcon;

    if (ext == 'PDF') {
      badgeBg = const Color(0xFFFEF2F2);
      badgeText = const Color(0xFFDC2626);
      fileIcon = Icons.picture_as_pdf_rounded;
    } else if (ext == 'XLSX' || ext == 'XLS' || ext == 'CSV') {
      badgeBg = const Color(0xFFECFDF5);
      badgeText = const Color(0xFF059669);
      fileIcon = Icons.table_chart_rounded;
    } else if (ext == 'ZIP' || ext == 'RAR' || ext == '7Z') {
      badgeBg = const Color(0xFFFFFBEB);
      badgeText = const Color(0xFFD97706);
      fileIcon = Icons.folder_zip_rounded;
    } else {
      badgeBg = const Color(0xFFEFF6FF);
      badgeText = _azulPrimario;
      fileIcon = Icons.description_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            alignment: Alignment.centerLeft,
            child: Text(
              '${index.toString().padLeft(2, '0')}.',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(fileIcon, color: badgeText, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  doc.name,
                  style: const TextStyle(
                    color: _azulOscuro,
                    fontSize: 13.8,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        ext,
                        style: TextStyle(
                          color: badgeText,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        doc.category,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 12),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 14,
                  color: Color(0xFF059669),
                ),
                SizedBox(width: 5),
                Text(
                  'En SECOP II',
                  style: TextStyle(
                    color: Color(0xFF059669),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentosEmptyOfficialState({
    required bool isMobile,
    String? message,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inbox_outlined,
                  color: Color(0xFF64748B),
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Sin documentos listados en esta sección',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _azulOscuro,
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message ??
                    'Se consultó la sección Documentación de este expediente en SECOP II y no se encontraron anexos publicados.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        _ejecutarExtraccionDocumentos(forceRefresh: true),
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: const Text('Volver a consultar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _azulOscuro,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _abrirEnlaceSecop,
                    icon: const Icon(
                      Icons.open_in_browser_rounded,
                      size: 17,
                      color: _amarillo,
                    ),
                    label: const Text('Verificar en SECOP II'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _azulOscuro,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentosCaptchaFallbackState({
    required bool isMobile,
    String? message,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 22),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 590),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Icon(
                  Icons.security_rounded,
                  color: Color(0xFFD97706),
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'SECOP solicitó validación anti-bots (reCAPTCHA)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _azulOscuro,
                  fontSize: isMobile ? 18 : 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message ??
                    'El firewall de Colombia Compra Eficiente bloqueó temporalmente la lectura automática de este contrato.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extracción asistida en 2 clics (queda guardada en la app):',
                      style: TextStyle(
                        color: _azulOscuro,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Abre la vista del proceso en SECOP (resuelve el reCAPTCHA si aparece) y presiona Ctrl+A y Ctrl+C.\n'
                      '2. Haz clic en "Extraer lista desde portapapeles" para filtrar y mostrar aquí solo los nombres de los documentos.',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _abrirEnlaceSecop,
                    icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                    label: const Text(
                      '1. Abrir sección en SECOP',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _azulOscuro,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _extraerDesdePortapapeles,
                    icon: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: _amarillo,
                    ),
                    label: const Text(
                      '2. Extraer lista desde portapapeles',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _azulOscuro,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () =>
                    _ejecutarExtraccionDocumentos(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text(
                  'Reintentar lectura automática directa',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _azulPrimario,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCopilotoTabContent({bool isMobile = false}) {
    final chatColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTabsBar(insideSummaryCard: false),
        const SizedBox(height: 12),
        Container(
          constraints: BoxConstraints(minHeight: isMobile ? 460 : 540),
          padding: EdgeInsets.fromLTRB(isMobile ? 14 : 24, 20, isMobile ? 14 : 24, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _azulOscuro.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 410),
                child: SingleChildScrollView(
                  controller: _chatScrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Primer mensaje de bienvenida del Copiloto IA
                      _buildAiMessageBubble(_mensajes.first['text'] as String),
                      const SizedBox(height: 16),
                      // Tarjetas rápidas de preguntas iniciales
                      Padding(
                        padding: EdgeInsets.only(left: isMobile ? 0 : 54),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildQuickPromptCard(
                              icon: Icons.description_outlined,
                              iconColor: const Color(0xFF2563EB),
                              text: 'Resume el objeto\nde este contrato',
                              textColor: _azulOscuro,
                              prompt: 'Resume el objeto de este contrato',
                            ),
                            _buildQuickPromptCard(
                              icon: Icons.monetization_on_outlined,
                              iconColor: const Color(0xFFD97706),
                              text:
                                  '¿Cuánto es el presupuesto\ny en qué modalidad se hizo?',
                              textColor: _azulPrimario,
                              prompt:
                                  '¿Cuánto es el presupuesto y en qué modalidad se hizo?',
                            ),
                            _buildQuickPromptCard(
                              icon: Icons.domain_outlined,
                              iconColor: const Color(0xFF2563EB),
                              text:
                                  '¿Quién fue el contratista\ny cuál es su historial?',
                              textColor: _azulOscuro,
                              prompt:
                                  '¿Quién fue el contratista y cuál es su historial?',
                            ),
                            _buildQuickPromptCard(
                              icon: Icons.bar_chart_rounded,
                              iconColor: const Color(0xFF7C3AED),
                              text:
                                  'Dame un análisis de riesgos\nen este contrato',
                              textColor: _azulPrimario,
                              prompt:
                                  'Dame un análisis de riesgos en este contrato',
                            ),
                          ],
                        ),
                      ),
                      if (_mensajes.length > 1) ...[
                        const SizedBox(height: 18),
                        for (var i = 1; i < _mensajes.length; i++) ...[
                          if (_mensajes[i]['sender'] == 'user')
                            _buildUserMessageBubble(
                              _mensajes[i]['text'] as String,
                            )
                          else
                            _buildAiMessageBubble(
                              _mensajes[i]['text'] as String,
                            ),
                          const SizedBox(height: 14),
                        ],
                      ],
                      if (_isTyping)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildAiMessageBubble(
                            'Analizando pliegos y datos de SECOP II...',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Column(
                children: [
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F1FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: _azulPrimario,
                            size: 15,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            onSubmitted: _enviarMensaje,
                            style: const TextStyle(
                              color: _azulOscuro,
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(
                              hintText:
                                  'Pregúntale a la IA sobre este contrato...',
                              hintStyle: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () =>
                              _enviarMensaje(_chatController.text),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: _azulOscuro,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'La información generada por la IA puede contener imprecisiones. Verifica siempre en el SECOP.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          chatColumn,
          const SizedBox(height: 16),
          _buildContextoSidebarCard(),
          const SizedBox(height: 14),
          _buildSugerenciasSidebarCard(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: chatColumn),
        const SizedBox(width: 18),
        SizedBox(
          width: 285,
          child: Column(
            children: [
              _buildContextoSidebarCard(),
              const SizedBox(height: 14),
              _buildSugerenciasSidebarCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiMessageBubble(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Color(0xFFE8F1FF),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.auto_awesome,
            color: _azulPrimario,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: _azulOscuro,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserMessageBubble(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: _azulOscuro,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickPromptCard({
    required IconData icon,
    required Color iconColor,
    required String text,
    required Color textColor,
    required String prompt,
  }) {
    return InkWell(
      onTap: () => _enviarMensaje(prompt),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: iconColor),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextoSidebarCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _azulOscuro.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _contextExpanded = !_contextExpanded),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F1FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Contexto del contrato',
                    style: TextStyle(
                      color: _azulOscuro,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(
                  _contextExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: _azulOscuro,
                ),
              ],
            ),
          ),
          if (_contextExpanded) ...[
            const SizedBox(height: 14),
            _buildContextItem(
              icon: Icons.assignment_outlined,
              iconColor: const Color(0xFF2563EB),
              iconBg: const Color(0xFFE8F1FF),
              label: 'Objeto',
              valueWidget: Text(
                _descripcionContrato.toUpperCase(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _azulOscuro,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
            _buildContextItem(
              icon: Icons.attach_money_rounded,
              iconColor: const Color(0xFF16A34A),
              iconBg: const Color(0xFFE6F6EC),
              label: 'Valor',
              valueWidget: Text(
                _valorFormateado,
                style: const TextStyle(
                  color: _azulOscuro,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _buildContextItem(
              icon: Icons.account_balance_outlined,
              iconColor: const Color(0xFF2563EB),
              iconBg: const Color(0xFFE8F1FF),
              label: 'Entidad contratante',
              valueWidget: Text(
                _toTitleCase(_entidadContrato),
                style: const TextStyle(
                  color: _azulOscuro,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _buildContextItem(
              icon: Icons.person_outline,
              iconColor: const Color(0xFFD97706),
              iconBg: const Color(0xFFFEF5D8),
              label: 'Contratista',
              valueWidget: InkWell(
                onTap: _abrirPerfilContratista,
                child: Text(
                  _toTitleCase(_contratistaContrato),
                  style: const TextStyle(
                    color: _azulOscuro,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            _buildContextItem(
              icon: Icons.gavel_rounded,
              iconColor: const Color(0xFFD97706),
              iconBg: const Color(0xFFFEF5D8),
              label: 'Modalidad',
              valueWidget: Text(
                _modalidadContrato,
                style: const TextStyle(
                  color: _azulOscuro,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _buildContextItem(
              icon: Icons.calendar_today_outlined,
              iconColor: const Color(0xFF2563EB),
              iconBg: const Color(0xFFE8F1FF),
              label: 'Fecha de firma',
              valueWidget: Text(
                _fechaFirmaCorta,
                style: const TextStyle(
                  color: _azulOscuro,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _buildContextItem(
              icon: Icons.check_circle_outline,
              iconColor: const Color(0xFF16A34A),
              iconBg: const Color(0xFFE6F6EC),
              label: 'Estado',
              isLast: true,
              valueWidget: Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _estadoContrato,
                  style: const TextStyle(
                    color: Color(0xFF15803D),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: TextButton.icon(
                onPressed: _abrirEnlaceSecop,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: _azulOscuro,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text(
                  'Ver expediente en SECOP',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContextItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required Widget valueWidget,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 1),
                valueWidget,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSugerenciasSidebarCard() {
    const sugerencias = [
      '¿Qué cubren los pliegos de condiciones?',
      '¿Cuáles fueron los criterios de selección?',
      '¿Qué entidades similares han contratado?',
      '¿Hay riesgos o alertas en este contrato?',
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _azulOscuro.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF5D8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Sugerencias de preguntas',
                  style: TextStyle(
                    color: _azulOscuro,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < sugerencias.length; i++) ...[
            InkWell(
              onTap: () => _enviarMensaje(sugerencias[i]),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        sugerencias[i],
                        style: const TextStyle(
                          color: _azulOscuro,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
            if (i < sugerencias.length - 1)
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final isMobile = screenW < 768;

    final bodyContent = Container(
      color: const Color(0xFFFAF5EA),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double horizontalPad = isMobile
              ? 16.0
              : (constraints.maxWidth > 1220 ? 32.0 : 24.0);
          return SingleChildScrollView(
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 215,
                  child: Image.asset(
                    'assets/images/fondo_valledupar.jpg',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    alignment: const Alignment(0.0, -0.38),
                    errorBuilder: (context, error, stackTrace) =>
                        Container(),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 215,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xFFFAF5EA),
                          const Color(0xFFFAF5EA)
                              .withValues(alpha: 0.92),
                          const Color(0xFFFAF5EA)
                              .withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.36, 0.65],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 145,
                  left: 0,
                  right: 0,
                  height: 70,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFFAF5EA)
                              .withValues(alpha: 0.0),
                          const Color(0xFFFAF5EA),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    isMobile ? 16 : 24,
                    horizontalPad,
                    28,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderRow(
                        showTopRightActions: _selectedTab == 1,
                        isMobile: isMobile,
                      ),
                      SizedBox(height: isMobile ? 16 : 22),
                      if (_selectedTab == 0)
                        _buildResumenTabContent(isMobile: isMobile)
                      else if (_selectedTab == 1)
                        _buildDocumentosTabContent(isMobile: isMobile)
                      else
                        _buildCopilotoTabContent(isMobile: isMobile),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (isMobile) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF8EE),
        drawer: null,
        drawerEnableOpenDragGesture: false,
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFFDF8),
          elevation: 0,
          scrolledUnderElevation: 1,
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: 'Regresar',
            icon: const Icon(Icons.arrow_back, color: _azulOscuro),
            onPressed: () => Navigator.maybePop(context),
          ),
          titleSpacing: 0,
          title: const Text(
            'Detalle del Contrato',
            style: TextStyle(
              color: _azulOscuro,
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            Tooltip(
              message: _esFavorito
                  ? 'Eliminar de favoritos'
                  : 'Guardar en favoritos',
              child: IconButton(
                icon: Icon(
                  _esFavorito
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: _esFavorito ? Colors.amber.shade700 : _azulOscuro,
                ),
                onPressed: _alternarFavorito,
              ),
            ),
            IconButton(
              tooltip: 'Compartir contrato',
              icon: const Icon(Icons.share_outlined, color: _azulOscuro),
              onPressed: _compartirContrato,
            ),
            UserProfileHeaderAction(onLogout: _cerrarSesion),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: const Color(0xFFEDE6D6),
            ),
          ),
        ),
        body: SafeArea(child: bodyContent),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 1, // Contratos tab
          onTap: (bottomIdx) {
            const mobileTabIndices = [0, 2, 3, 4, 7];
            if (bottomIdx >= 0 && bottomIdx < mobileTabIndices.length) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => HomeScreen(
                    initialIndex: mobileTabIndices[bottomIdx],
                  ),
                ),
                (route) => false,
              );
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: _azulOscuro,
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded, color: _amarillo),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.description_outlined),
              activeIcon: Icon(Icons.description_rounded, color: _amarillo),
              label: 'Contratos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_outlined),
              activeIcon: Icon(Icons.account_balance_rounded, color: _amarillo),
              label: 'Entidades',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people_alt_rounded, color: _amarillo),
              label: 'Contratistas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.star_border_rounded),
              activeIcon: Icon(Icons.star_rounded, color: _amarillo),
              label: 'Favoritos',
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EE),
      body: Row(
        children: [
          CollapsibleSideMenu(
            selectedIndex: 2,
            isCollapsed: _isSidebarCollapsed,
            onItemSelected: _onSidebarItemSelected,
            onToggleCollapse: () => setState(
              () => _isSidebarCollapsed = !_isSidebarCollapsed,
            ),
            onLogout: _cerrarSesion,
          ),
          Expanded(
            child: Column(
              children: [
                DashboardTopBar(
                  searchController: _topSearchController,
                  onSearchSubmitted: _handleTopSearch,
                  onLogout: _cerrarSesion,
                ),
                Expanded(child: bodyContent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}