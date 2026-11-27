import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/security_service.dart';
import '../services/transparencia_entidad_service.dart';
import '../utils/estado_vista.dart';
import '../utils/nit.dart';
import 'campo_busqueda.dart';

class TransparenciaEntidad extends StatefulWidget {
  const TransparenciaEntidad({super.key, required this.nit});

  final String nit;

  @override
  State<TransparenciaEntidad> createState() => _TransparenciaEntidadState();
}

class _TransparenciaEntidadState extends State<TransparenciaEntidad> {
  final _entrada = TextEditingController();
  final _cop = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );
  late Future<({List<Map<String, dynamic>> filas, bool hayMas})> _contratos;
  late Future<List<Map<String, dynamic>>> _personal;
  String _texto = '';
  int _pagina = 0;

  String get _clave => 'transparencia-${widget.nit}';
  bool get _esEmdupar => Nit.formasNumericas(widget.nit).contains('892300548');

  @override
  void initState() {
    super.initState();
    final vista = EstadoVista.leer(_clave);
    if (vista['texto'] case final String texto) _texto = texto;
    if (vista['pagina'] case final int pagina when pagina >= 0) {
      _pagina = pagina;
    }
    _entrada.text = _texto;
    _contratos = _consultarContratos();
    _personal = TransparenciaEntidadService.personal(widget.nit);
  }

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  Future<({List<Map<String, dynamic>> filas, bool hayMas})>
  _consultarContratos() => TransparenciaEntidadService.contratos(
    widget.nit,
    pagina: _pagina,
    texto: _texto,
  );

  void _ir(int pagina, {String? texto}) {
    setState(() {
      _pagina = pagina;
      _texto = texto ?? _texto;
      _contratos = _consultarContratos();
    });
    EstadoVista.guardar(_clave, {'texto': _texto, 'pagina': _pagina});
  }

  Uri? _url(Object? valor) {
    final dato = valor is Map ? valor['url'] : valor;
    return dato is String ? SecurityService.validateOfficialGovUrl(dato) : null;
  }

  Widget _enlace(String nombre, String url) => TextButton.icon(
    onPressed: () => launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
    icon: const Icon(Icons.open_in_new_rounded, size: 16),
    label: Text(nombre),
  );

  Widget _panel(String titulo, List<Widget> contenido) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ...contenido,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (Nit.formasNumericas(widget.nit).isEmpty) {
      return const Text(
        'La consulta de estas fuentes requiere un NIT de la entidad.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_esEmdupar)
          _panel('Publicaciones oficiales de Emdupar', [
            Wrap(
              children: [
                _enlace(
                  'Contratación y relaciones por vigencia',
                  'https://www.emdupar.gov.co/Gestion/Contratacion',
                ),
                _enlace(
                  'Portal de transparencia',
                  'https://www.emdupar.gov.co/Transparencia',
                ),
                _enlace(
                  'Directorio institucional 2024 (PDF)',
                  'https://www.emdupar.gov.co/images/images/DIRECTORIO_INSTITUCIONAL_2024.pdf',
                ),
              ],
            ),
          ]),
        _panel('Contratación consolidada', [
          const Text(
            'Archivo de Datos Abiertos consultado por NIT. Un contrato puede tener varias filas publicadas.',
          ),
          const SizedBox(height: 12),
          CampoBusqueda(
            controller: _entrada,
            onSubmitted: (_) => _ir(0, texto: _entrada.text.trim()),
            decoration: InputDecoration(
              hintText: 'Buscar contrato, proceso, proveedor u objeto',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Buscar en el archivo',
                onPressed: () => _ir(0, texto: _entrada.text.trim()),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder(
            future: _contratos,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              final pagina = snapshot.data;
              if (pagina == null) {
                return _reintentar(
                  'No se pudo consultar el archivo de contratación.',
                  () => _ir(_pagina),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (pagina.filas.isEmpty)
                    const Text(
                      'No hay registros publicados para esta búsqueda.',
                    ),
                  for (final fila in pagina.filas) ...[
                    _filaContrato(fila),
                    const Divider(height: 1),
                  ],
                  if (_pagina > 0 || pagina.hayMas)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IconButton(
                            tooltip: 'Página anterior',
                            onPressed: _pagina > 0
                                ? () => _ir(_pagina - 1)
                                : null,
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Text('Página ${_pagina + 1}'),
                          IconButton(
                            tooltip: 'Página siguiente',
                            onPressed: pagina.hayMas
                                ? () => _ir(_pagina + 1)
                                : null,
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _enlace(
              'Fuente en Datos Abiertos',
              'https://www.datos.gov.co/d/fapy-smq9',
            ),
          ),
        ]),
        _panel('Personal reportado en SIGEP II', [
          const Text(
            'Cifras agregadas del último periodo publicado. Para consultar nombres y cargos, abre el directorio oficial.',
          ),
          const SizedBox(height: 10),
          FutureBuilder(
            future: _personal,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              final personal = snapshot.data;
              if (personal == null) {
                return _reintentar(
                  'No se pudo consultar SIGEP II.',
                  () => setState(
                    () => _personal = TransparenciaEntidadService.personal(
                      widget.nit,
                    ),
                  ),
                );
              }
              if (personal.isEmpty) {
                return const Text(
                  'Sin cifras agregadas publicadas para este NIT.',
                );
              }
              final primero = personal.first;
              final anio = int.tryParse('${primero['a_o']}');
              final mes = int.tryParse('${primero['mes']}');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (anio != null && mes != null && mes >= 1 && mes <= 12)
                    Text(
                      'Periodo reportado: ${mes.toString().padLeft(2, '0')}/$anio',
                    ),
                  for (final fila in personal) _filaPersonal(fila),
                ],
              );
            },
          ),
          Wrap(
            children: [
              _enlace(
                'Directorio de servidores públicos',
                'https://www.funcionpublica.gov.co/web/sigep2/directorio',
              ),
              _enlace(
                'Fuente en Datos Abiertos',
                'https://www.datos.gov.co/d/h8rs-jxum',
              ),
            ],
          ),
        ]),
      ],
    );
  }

  Widget _filaContrato(Map<String, dynamic> fila) {
    String campo(String clave) => '${fila[clave] ?? ''}'.trim();
    final fecha = DateTime.tryParse(campo('fecha_de_firma_del_contrato'));
    final valor = num.tryParse(campo('valor_contrato'));
    final enlace = _url(fila['url_contrato']);
    final resumen = [
      campo('nom_raz_social_contratista'),
      if (fecha != null) DateFormat('dd/MM/yyyy', 'en').format(fecha),
      if (valor != null) '${_cop.format(valor)} COP',
      campo('estado_del_proceso'),
      campo('modalidad_de_contrataci_n'),
    ].where((c) => c.isNotEmpty).join(' · ');
    final referencias = {
      campo('numero_de_proceso'),
      campo('numero_del_contrato'),
    }..remove('');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        referencias.isEmpty
            ? 'Registro de contratación'
            : referencias.join(' · '),
      ),
      subtitle: Text(
        [
          resumen,
          campo('objeto_a_contratar'),
        ].where((c) => c.isNotEmpty).join('\n'),
      ),
      trailing: enlace == null
          ? null
          : IconButton(
              tooltip: 'Abrir publicación oficial',
              onPressed: () => launchUrl(enlace, webOnlyWindowName: '_blank'),
              icon: const Icon(Icons.open_in_new_rounded),
            ),
    );
  }

  Widget _filaPersonal(Map<String, dynamic> fila) {
    final personas = [
      'genero_hombre',
      'genero_mujer',
      'genero_no_binario',
    ].fold(0, (total, campo) => total + (int.tryParse('${fila[campo]}') ?? 0));
    final salario = num.tryParse('${fila['salario_mensual_promedio']}');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        '$personas personas reportadas · ${fila['tipo_de_vinculaci_n'] ?? 'Vinculación sin especificar'}',
      ),
      subtitle: salario == null
          ? null
          : Text(
              'Salario mensual promedio reportado: ${_cop.format(salario)} COP',
            ),
    );
  }

  Widget _reintentar(String mensaje, VoidCallback reintentar) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(mensaje),
      TextButton(onPressed: reintentar, child: const Text('Reintentar')),
    ],
  );
}
