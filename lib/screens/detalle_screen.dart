import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/contract_document_service.dart';
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
  final ScrollController _chatScrollController = ScrollController();

  final List<Map<String, dynamic>> _mensajes = [];
  bool _isTyping = false;
  bool _esFavorito = false;
  bool _isSidebarCollapsed = false;
  bool _contextExpanded = true;
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 2);
    _cargarEstadoFavorito();
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

  String _obtenerUrlSecop() {
    final rawUrl = widget.contrato['urlproceso'];
    if (rawUrl is Map && rawUrl['url'] != null) {
      return rawUrl['url'].toString();
    }
    return 'https://www.colombiacompra.gov.co/secop-ii';
  }

  Future<void> _abrirEnlaceSecop() async {
    final uri = Uri.tryParse(_obtenerUrlSecop());
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  Widget _buildDocumentosTabContent() {
    final expectedDocs =
        ContractDocumentService.getExpectedDocumentsForContract(widget.contrato);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTabsBar(insideSummaryCard: false),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(26),
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
              // Encabezado principal del área de documentos
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
                      Icons.folder_shared_rounded,
                      color: _azulPrimario,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Expediente Documental del Contrato',
                          style: TextStyle(
                            color: _azulOscuro,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Proceso oficial: $_procesoContrato   |   Ref: $_referenciaContrato',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Nota de Transparencia Ciudadana
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF475569),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Aviso de transparencia: La API abierta nacional (datos.gov.co) almacena únicamente la información de texto del contrato. Los archivos PDF escaneados originales (firmas manuscritas, sellos y anexos técnicos de la entidad) se custodian en el portal transaccional de SECOP II. Selecciona una de las dos opciones para acceder:',
                        style: TextStyle(
                          color: Colors.blueGrey.shade700,
                          fontSize: 12.8,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ENFOQUE DUAL: Botón 1 (Acceso Oficial) vs Botón 2 (Resumen Inteligente)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 860;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildOpcionOficialCard()),
                        const SizedBox(width: 20),
                        Expanded(child: _buildOpcionResumenCard()),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildOpcionOficialCard(),
                        const SizedBox(height: 18),
                        _buildOpcionResumenCard(),
                      ],
                    );
                  }
                },
              ),

              const SizedBox(height: 32),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 24),

              // Sección Informativa: Checklist de Documentos Esperados según Ley
              _buildDocumentosEsperadosSection(expectedDocs),
            ],
          ),
        ),
      ],
    );
  }

  /// TARJETA Y BOTÓN 1: El Acceso Oficial (Opción A)
  Widget _buildOpcionOficialCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _azulOscuro.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag superior de opción oficial
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 13, color: Color(0xFF059669)),
                    SizedBox(width: 5),
                    Text(
                      'OPCIÓN A · FUENTE OFICIAL DEL ESTADO',
                      style: TextStyle(
                        color: Color(0xFF047857),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Título y explicación clara
          const Text(
            'Documentos oficiales en SECOP',
            style: TextStyle(
              color: _azulOscuro,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Abre directamente el expediente en el portal transaccional de Colombia Compra Eficiente (community.secop.gov.co) donde reposan los archivos escaneados originales subidos por la entidad pública.',
            style: TextStyle(
              color: Color(0xFF475569),
              fontSize: 13,
              height: 1.42,
            ),
          ),
          const SizedBox(height: 16),

          // Características de lo que encontrará
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBulletPoint(
                  Icons.picture_as_pdf_outlined,
                  'PDFs originales escaneados con firmas y sellos institucionales.',
                ),
                const SizedBox(height: 8),
                _buildBulletPoint(
                  Icons.layers_outlined,
                  'Estudios previos completos, CDP original, pliegos definitivos y pólizas.',
                ),
                const SizedBox(height: 8),
                _buildBulletPoint(
                  Icons.download_for_offline_outlined,
                  'Descarga directa e inmediata desde los servidores del Gobierno.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // BOTÓN 1: "Documentos oficiales en SECOP"
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () =>
                  ContractDocumentService.abrirDocumentosOficialesSecop(
                context,
                widget.contrato,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: const Text(
                'Documentos oficiales en SECOP',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F2747),
                foregroundColor: Colors.white,
                elevation: 0,
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

  /// TARJETA Y BOTÓN 2: El Resumen Inteligente (Opción B)
  Widget _buildOpcionResumenCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag superior de opción generada por IA
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 13, color: Color(0xFFD97706)),
                    SizedBox(width: 5),
                    Text(
                      'OPCIÓN B · RESUMEN INTELIGENTE IA',
                      style: TextStyle(
                        color: Color(0xFFB45309),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Título y explicación clara
          const Text(
            'Generar resumen de contrato y documentos',
            style: TextStyle(
              color: _azulOscuro,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Genera al instante un reporte conciso estructurado a partir de los datos abiertos de texto: monto, objeto, proceso, entidad, contratista y el checklist legal de documentos que deben existir.',
            style: TextStyle(
              color: Color(0xFF475569),
              fontSize: 13,
              height: 1.42,
            ),
          ),
          const SizedBox(height: 16),

          // Características de lo que encontrará
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFEF3C7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBulletPoint(
                  Icons.monetization_on_outlined,
                  'Monto ($_valorFormateado), objeto, número de proceso y partes.',
                ),
                const SizedBox(height: 8),
                _buildBulletPoint(
                  Icons.checklist_rtl_rounded,
                  'Checklist legal de documentos esperados según la modalidad.',
                ),
                const SizedBox(height: 8),
                _buildBulletPoint(
                  Icons.security_outlined,
                  'Transparente: Mini resumen sintético, no simula ser el original.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // BOTÓN 2: "Generar resumen de contrato y documentos" + Acción secundaria "Ver en navegador"
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        ContractDocumentService.descargarResumenInteligente(
                      context,
                      widget.contrato,
                    ),
                    icon: const Icon(Icons.download_rounded, size: 17),
                    label: const Text(
                      'Generar resumen (PDF)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      ContractDocumentService.abrirResumenEnNavegador(
                    context,
                    widget.contrato,
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text(
                    'Ver PDF',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E3A8A),
                    side: const BorderSide(color: Color(0xFF93C5FD)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _azulOscuro),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Sección informativa inferior con el Checklist de Documentos Esperados
  Widget _buildDocumentosEsperadosSection(List<ExpectedDocumentItem> expectedDocs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.checklist_rounded,
              color: _azulOscuro,
              size: 22,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Documentos que componen el expediente de este contrato',
                style: TextStyle(
                  color: _azulOscuro,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Modalidad: $_modalidadContrato',
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Conforme a la Ley 80 de 1993, Ley 1150 de 2007 y Decreto 1082 de 2015, este proceso debe contar con los siguientes archivos en la plataforma oficial:',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 18),

        // Lista de documentos esperados
        for (var i = 0; i < expectedDocs.length; i++)
          _buildExpectedDocRow(expectedDocs[i]),
      ],
    );
  }

  Widget _buildExpectedDocRow(ExpectedDocumentItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: _azulPrimario, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: _azulOscuro,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Text(
                        'Requerido por Ley',
                        style: TextStyle(
                          color: Color(0xFF047857),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.legalReference} · ${item.description}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: () =>
                ContractDocumentService.abrirDocumentosOficialesSecop(
              context,
              widget.contrato,
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 14),
            label: const Text('Descargar en SECOP II'),
            style: TextButton.styleFrom(
              foregroundColor: _azulPrimario,
              textStyle: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
                        _buildDocumentosTabContent()
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