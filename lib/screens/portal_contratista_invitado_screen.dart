import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/juridico_contratacion_service.dart';
import '../utils/document_file_picker.dart';

class PortalContratistaInvitadoScreen extends StatefulWidget {
  const PortalContratistaInvitadoScreen({
    super.key,
    required this.token,
  });

  final String token;

  @override
  State<PortalContratistaInvitadoScreen> createState() =>
      _PortalContratistaInvitadoScreenState();
}

class _PortalContratistaInvitadoScreenState
    extends State<PortalContratistaInvitadoScreen> {
  static const Color _bgCrema = Color(0xFFFFF8EE);
  static const Color _azulOscuro = Color(0xFF1A2B4C);
  static const Color _azulPrimario = Color(0xFF2563EB);
  static const Color _bordeSuave = Color(0xFFE2E8F0);
  static const Color _textoSecundario = Color(0xFF64748B);

  final NumberFormat _monedaFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _cedulaController = TextEditingController();

  ExpedienteContratoPs? _expediente;
  bool _cargando = true;
  bool _accesoValidado = false;
  bool _validandoIngreso = false;
  String? _apartadoSubiendoId;
  String? _mensajeErrorIngreso;
  bool _trazabilidadAbierta = true;
  Timer? _sincronizadorContinuo;

  String _contratistaNombreActivo = '';
  String _contratistaCedulaActiva = '';

  String get _tokenEfectivo {
    final limpio = widget.token.trim();
    if (limpio.isNotEmpty) return limpio;
    return JuridicoContratacionService.extraerTokenInvitadoDeUri(Uri.base);
  }

  @override
  void initState() {
    super.initState();
    JuridicoContratacionService.expedientesVersion.addListener(
      _sincronizarCambios,
    );
    JuridicoContratacionService.activarTiempoRealContratista(_tokenEfectivo);
    _cargarContratoInicial();
    _sincronizadorContinuo = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _sincronizarCambios(),
    );
  }

  @override
  void dispose() {
    _sincronizadorContinuo?.cancel();
    JuridicoContratacionService.expedientesVersion.removeListener(
      _sincronizarCambios,
    );
    _nombreController.dispose();
    _cedulaController.dispose();
    super.dispose();
  }

  Future<void> _sincronizarCambios() async {
    // Llamado por el aviso de cambios del servicio: no se relee el
    // almacenamiento para no disparar otra notificación.
    final actualizado =
        await JuridicoContratacionService.obtenerExpedientePorTokenInvitado(
          _tokenEfectivo,
          releerAlmacenamiento: false,
        );
    if (!mounted || actualizado == null) return;
    setState(() => _expediente = actualizado);
  }

  Future<void> _cargarContratoInicial() async {
    final exp =
        await JuridicoContratacionService.obtenerExpedientePorTokenInvitado(
          _tokenEfectivo,
        );
    if (!mounted) return;
    setState(() {
      _expediente = exp;
      _cargando = false;
    });
  }

  Future<void> _ingresarAlContrato() async {
    final exp = _expediente;
    if (exp == null || _validandoIngreso) return;

    setState(() {
      _validandoIngreso = true;
      _mensajeErrorIngreso = null;
    });

    try {
      final validado =
          await JuridicoContratacionService.validarEIngresarContratistaInvitado(
            tokenInvitado: exp.tokenInvitado,
            nombreCompleto: _nombreController.text,
            cedula: _cedulaController.text,
          );
      if (!mounted) return;
      setState(() {
        _expediente = validado;
        _contratistaNombreActivo = _nombreController.text.trim();
        _contratistaCedulaActiva = _cedulaController.text.trim();
        _accesoValidado = true;
        _validandoIngreso = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _validandoIngreso = false;
        _mensajeErrorIngreso = e
            .toString()
            .replaceFirst('Invalid argument(s): ', '');
      });
    }
  }

  Future<void> _seleccionarYSubirArchivo(
    ExpedienteContratoPs exp,
    ApartadoDocumentoContrato apartado,
  ) async {
    if (_apartadoSubiendoId != null) return;

    final picked = await pickContractDocumentFile();
    if (picked == null || !mounted) return;

    if (!picked.isValid) {
      _mostrarMensaje(
        picked.errorMessage ?? 'El archivo seleccionado no es válido.',
        esError: true,
      );
      return;
    }

    setState(() => _apartadoSubiendoId = apartado.id);
    try {
      final actualizado =
          await JuridicoContratacionService.subirDocumentoContratistaInvitado(
            tokenInvitado: exp.tokenInvitado,
            apartadoId: apartado.id,
            archivo: picked,
            contratistaNombre: _contratistaNombreActivo,
            contratistaCedula: _contratistaCedulaActiva,
          );
      if (!mounted) return;
      setState(() {
        _expediente = actualizado;
        _apartadoSubiendoId = null;
      });
      _mostrarMensaje('Documento "${apartado.nombre}" cargado correctamente.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _apartadoSubiendoId = null);
      _mostrarMensaje(
        e.toString()
            .replaceFirst('Invalid argument(s): ', '')
            .replaceFirst('Bad state: ', ''),
        esError: true,
      );
    }
  }

  void _verDocumentoCargado(
    ExpedienteContratoPs exp,
    ApartadoDocumentoContrato apartado,
  ) {
    final abierto = JuridicoContratacionService.abrirDocumentoEnPestana(
      expediente: exp,
      apartado: apartado,
    );
    if (!abierto) {
      JuridicoContratacionService.descargarDocumentoIndividual(
        expediente: exp,
        apartado: apartado,
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return SelectionArea(
      child: Scaffold(
        backgroundColor: _bgCrema,
        body: SafeArea(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _expediente == null
              ? _buildEnlaceNoValido()
              : !_accesoValidado
              ? _buildPantallaIngresoContratista(_expediente!, isMobile)
              : _buildExpedienteContratistaView(_expediente!, isMobile),
        ),
      ),
    );
  }

  Widget _buildEnlaceNoValido() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _bordeSuave),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 46,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(height: 18),
              const Text(
                'Enlace de contrato no encontrado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _azulOscuro,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Verifica que hayas copiado completo el enlace enviado por el equipo jurídico de la entidad contratante.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textoSecundario,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Paso 1: Ingreso limpio y rápido mostrando arriba el número y objeto del contrato
  /// y solicitando únicamente nombre completo y número de cédula.
  Widget _buildPantallaIngresoContratista(
    ExpedienteContratoPs exp,
    bool isMobile,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 24,
          vertical: 28,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 22 : 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _bordeSuave),
              boxShadow: [
                BoxShadow(
                  color: _azulOscuro.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 50,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(height: 20),

                // Resumen superior del contrato al que está ingresando
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _bordeSuave),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exp.entidadNombre,
                        style: const TextStyle(
                          color: _textoSecundario,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Contrato ${exp.numeroContrato}',
                        style: const TextStyle(
                          color: _azulOscuro,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
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
                const SizedBox(height: 22),

                const Text(
                  'Ingreso del contratista',
                  style: TextStyle(
                    color: _azulOscuro,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ingresa tu nombre completo y número de cédula para cargar o subsanar los documentos de este contrato.',
                  style: TextStyle(
                    color: _textoSecundario,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),

                const Text(
                  'Nombre completo',
                  style: TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 12.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nombreController,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontSize: 14, color: _azulOscuro),
                  decoration: InputDecoration(
                    hintText: 'Ej.: ${exp.contratistaNombreEsperado}',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13.5,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
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
                      borderSide: const BorderSide(
                        color: _azulOscuro,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                const Text(
                  'Número de cédula',
                  style: TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 12.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _cedulaController,
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _ingresarAlContrato(),
                  style: const TextStyle(fontSize: 14, color: _azulOscuro),
                  decoration: InputDecoration(
                    hintText: 'Ingresa tu número de documento sin puntos',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13.5,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
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
                      borderSide: const BorderSide(
                        color: _azulOscuro,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),

                if (_mensajeErrorIngreso != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Text(
                      _mensajeErrorIngreso!,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                FilledButton(
                  onPressed: _validandoIngreso ? null : _ingresarAlContrato,
                  style: FilledButton.styleFrom(
                    backgroundColor: _azulOscuro,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  child: const Text(
                    'Ingresar al contrato',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Paso 2: Vista limpia de cargue y subsanación de documentos del contratista.
  Widget _buildExpedienteContratistaView(
    ExpedienteContratoPs exp,
    bool isMobile,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 28,
        isMobile ? 16 : 24,
        isMobile ? 16 : 28,
        40,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado limpio con logo y perfil del contratista
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 22),
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
                        Image.asset(
                          'assets/images/logo.png',
                          height: 36,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                        const Spacer(),
                        if (!isMobile) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFA7F3D0),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 7,
                                  color: Color(0xFF10B981),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Sincronización en tiempo real',
                                  style: TextStyle(
                                    color: Color(0xFF047857),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _accesoValidado = false);
                          },
                          icon: const Icon(
                            Icons.logout_rounded,
                            size: 16,
                            color: _textoSecundario,
                          ),
                          label: const Text(
                            'Salir',
                            style: TextStyle(
                              color: _textoSecundario,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Contrato ${exp.numeroContrato}',
                          style: TextStyle(
                            color: _azulOscuro,
                            fontSize: isMobile ? 18 : 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${exp.totalCargados} de ${exp.totalApartados} documentos cargados',
                            style: const TextStyle(
                              color: _azulOscuro,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${exp.entidadNombre} · ${exp.dependencia}${exp.valorContratoCop > 0 ? " · ${_monedaFormat.format(exp.valorContratoCop)} (${exp.plazoEjecucion})" : ""}',
                      style: const TextStyle(
                        color: _textoSecundario,
                        fontSize: 13,
                      ),
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
                    const SizedBox(height: 10),
                    Text(
                      'Contratista: $_contratistaNombreActivo · CC $_contratistaCedulaActiva',
                      style: const TextStyle(
                        color: _azulOscuro,
                        fontSize: 12.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Aviso claro cuando hay documentos devueltos con observaciones
              if (exp.totalPorSubsanar > 0) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFFB45309),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          exp.totalPorSubsanar == 1
                              ? 'Tienes 1 documento devuelto por el equipo jurídico. Revisa la observación indicada abajo y sube el archivo corregido.'
                              : 'Tienes ${exp.totalPorSubsanar} documentos devueltos por el equipo jurídico. Revisa las observaciones indicadas abajo y sube los archivos corregidos.',
                          style: const TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Lista limpia de documentos requeridos
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _bordeSuave),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
                      child: Text(
                        'Documentos requeridos',
                        style: TextStyle(
                          color: _azulOscuro,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: _bordeSuave),
                    for (var i = 0; i < exp.apartados.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      _buildFilaDocumentoContratista(
                        exp,
                        exp.apartados[i],
                        isMobile,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Trazabilidad limpia colapsable
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _bordeSuave),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => setState(
                        () => _trazabilidadAbierta = !_trazabilidadAbierta,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Trazabilidad (${exp.trazabilidad.length} eventos)',
                                style: const TextStyle(
                                  color: _azulOscuro,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Icon(
                              _trazabilidadAbierta
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: _textoSecundario,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_trazabilidadAbierta) ...[
                      const Divider(height: 1, color: _bordeSuave),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                        child: Column(
                          children: [
                            for (final ev in exp.trazabilidad)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 5),
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: _azulPrimario,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            JuridicoContratacionService.formatearFechaHumana(
                                              ev.fechaIso,
                                            ),
                                            style: const TextStyle(
                                              color: _textoSecundario,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${ev.actorNombre} · ${ev.titulo}',
                                            style: const TextStyle(
                                              color: _azulOscuro,
                                              fontSize: 12.8,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (ev.detalle.trim().isNotEmpty)
                                            Text(
                                              ev.detalle,
                                              style: const TextStyle(
                                                color: _textoSecundario,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilaDocumentoContratista(
    ExpedienteContratoPs exp,
    ApartadoDocumentoContrato ap,
    bool isMobile,
  ) {
    final subiendoEste = _apartadoSubiendoId == ap.id;

    final (Color dot, Color bg, Color fg) = switch (ap.estado) {
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.5,
                  vertical: 3,
                ),
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
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      ap.estado.etiquetaCorta,
                      style: TextStyle(
                        color: fg,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (ap.descripcion.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              ap.descripcion,
              style: const TextStyle(color: _textoSecundario, fontSize: 12.3),
            ),
          ],

          // Si fue devuelto, mostrar con total claridad qué debe corregir
          if (ap.requiereSubsanacion &&
              ap.observacionJuridica != null &&
              ap.observacionJuridica!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Text(
                'Observación para corregir: ${ap.observacionJuridica}',
                style: const TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.38,
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: ap.requiereSubsanacion
                    ? const Color(0xFFF59E0B)
                    : _bordeSuave,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ap.tieneArchivoCargado
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ap.tieneArchivoCargado ? ap.formatoCorto : 'PDF',
                    style: TextStyle(
                      color: ap.tieneArchivoCargado
                          ? const Color(0xFFB91C1C)
                          : _textoSecundario,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ap.tieneArchivoCargado
                            ? (ap.archivoNombre ?? 'Documento cargado')
                            : 'Ningún archivo cargado aún',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ap.tieneArchivoCargado
                              ? _azulOscuro
                              : _textoSecundario,
                          fontSize: 13.2,
                          fontWeight: ap.tieneArchivoCargado
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (ap.tieneArchivoCargado)
                        Text(
                          '${ap.formatoCorto}${ap.tamanoFormateado.isNotEmpty ? " · ${ap.tamanoFormateado}" : ""}',
                          style: const TextStyle(
                            color: _textoSecundario,
                            fontSize: 11.8,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (ap.tieneArchivoCargado) ...[
                  OutlinedButton(
                    onPressed: () => _verDocumentoCargado(exp, ap),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _azulOscuro,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      minimumSize: const Size(54, 34),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
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
                  const SizedBox(width: 8),
                ],
                if (!ap.estaAprobado)
                  FilledButton(
                    onPressed: subiendoEste
                        ? null
                        : () => _seleccionarYSubirArchivo(exp, ap),
                    style: FilledButton.styleFrom(
                      backgroundColor: ap.requiereSubsanacion
                          ? const Color(0xFFD97706)
                          : _azulOscuro,
                      minimumSize: const Size(80, 34),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      subiendoEste
                          ? 'Subiendo...'
                          : ap.requiereSubsanacion
                          ? 'Subir corrección'
                          : ap.tieneArchivoCargado
                          ? 'Cambiar'
                          : 'Subir',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
