import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../services/juridico_contratacion_service.dart';
import '../../services/supervision_service.dart';
import '../gestion_contractual/estilo_contractual.dart';
import 'componentes_supervision.dart';

class RegistroSupervision extends StatefulWidget {
  const RegistroSupervision({
    super.key,
    required this.esSupervisor,
    this.alGuardar,
    this.contrato,
    this.perfil,
  });
  final ExpedienteContratoPs? contrato;
  final Map<String, dynamic>? perfil;
  final bool esSupervisor;
  final VoidCallback? alGuardar;

  @override
  State<RegistroSupervision> createState() => _RegistroSupervisionState();
}

class _RegistroSupervisionState extends State<RegistroSupervision> {
  final _form = GlobalKey<FormState>();
  final _campos = <String, TextEditingController>{};
  String _vinculacion = 'nombramiento';
  String? _error;
  DateTime? _fecha;
  bool _ocupado = false;
  List<DestinoSupervision>? _resultados;
  DestinoSupervision? _destino;

  TextEditingController _campo(String id) =>
      _campos.putIfAbsent(id, TextEditingController.new);
  String _valor(String id) => _campo(id).text.trim();

  @override
  void initState() {
    super.initState();
    final perfil = widget.perfil;
    if (perfil != null) {
      _fecha = DateTime.tryParse(perfil['fecha']);
      _vinculacion = perfil['vinculacion'];
      const campos = {
        'nit': 'entidadNit',
        'entidad': 'entidadNombre',
        'dependencia': 'dependencia',
        'referencia': 'referencia',
        'cargoObjeto': 'cargoObjeto',
        'nombre': 'juridicoNombre',
        'email': 'juridicoEmail',
        'duracion': 'plazoEjecucion',
        'formaPago': 'formaPago',
        'rp': 'rp',
        'cdp': 'cdp',
      };
      for (final campo in campos.entries) {
        _campo(campo.key).text = perfil[campo.value] ?? '';
      }
      if (perfil['valorContratoCop'] is int) {
        _campo('valor').text = milesCop(perfil['valorContratoCop']);
      }
    }
    final e = widget.contrato;
    if (e == null) return;
    _fecha = DateTime.tryParse(e.aprobacionSecop);
    for (final campo in {
      'objeto': e.objetoContrato,
      'duracion': e.plazoEjecucion,
      'valor': milesCop(e.valorContratoCop),
      'formaPago': e.formaPago,
      'rp': e.rp,
      'cdp': e.cdp,
    }.entries) {
      _campo(campo.key).text = campo.value;
    }
  }

  Map<String, dynamic> get _datosEconomicos => {
    'valorContratoCop': FormatoMilesCop.leer(_valor('valor')),
    'plazoEjecucion': _valor('duracion'),
    'formaPago': _valor('formaPago'),
    'rp': _valor('rp'),
    'cdp': _valor('cdp'),
  };

  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _buscar() async {
    final nit = RegistroSupervisionService.nitEntidad(_valor('nit'));
    if (nit == null) {
      setState(
        () => _error =
            'Escribe el NIT de la entidad, con o sin dígito de verificación.',
      );
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
      _destino = null;
      _resultados = null;
    });
    try {
      final lista = await RegistroSupervisionService.buscar(nit);
      if (mounted) {
        setState(() {
          _resultados = lista
              .where((d) => d.uid != RegistroSupervisionService.uid)
              .toList();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo consultar el directorio. Vuelve a buscar.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    if (_fecha == null ||
        (!widget.esSupervisor && widget.contrato == null && _destino == null)) {
      setState(
        () => _error = _fecha == null
            ? 'Selecciona la fecha.'
            : 'Busca la entidad y selecciona tu supervisor.',
      );
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      if (widget.contrato != null) {
        final actualizado = await RegistroSupervisionService.corregirContrato(
          widget.contrato!,
          {
            ..._datosEconomicos,
            'objetoContrato': _valor('objeto'),
            'aprobacionSecop': fechaIsoCorta(_fecha!),
          },
        );
        if (mounted) Navigator.pop(context, actualizado);
        return;
      }
      if (widget.esSupervisor) {
        await RegistroSupervisionService.guardarPerfil(
          versionAnterior: widget.perfil == null
              ? null
              : widget.perfil!['version'] ?? 0,
          destino: DestinoSupervision(
            RegistroSupervisionService.uid,
            RegistroSupervisionService.nitEntidad(_valor('nit'))!,
            _valor('entidad'),
            _valor('dependencia'),
            AuthService.getActiveUserDisplayName(),
          ),
          datosContrato: _vinculacion == 'contrato' ? _datosEconomicos : {},
          vinculacion: _vinculacion,
          referencia: _valor('referencia'),
          fecha: fechaIsoCorta(_fecha!),
          cargoObjeto: _valor('cargoObjeto'),
          juridicoNombre: _valor('nombre'),
          juridicoEmail: _valor('email').toLowerCase(),
        );
      } else {
        await RegistroSupervisionService.registrarContrato(
          destino: _destino!,
          numero: _valor('numero'),
          objeto: _valor('objeto'),
          valor: FormatoMilesCop.leer(_valor('valor')),
          aprobacion: fechaIsoCorta(_fecha!),
          duracion: _valor('duracion'),
          formaPago: _valor('formaPago'),
          rp: _valor('rp'),
          cdp: _valor('cdp'),
        );
      }
      if (mounted) widget.alGuardar?.call();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is SupervisionException
              ? e.message
              : 'No fue posible registrar los datos. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Widget _texto(String id, String etiqueta, {String? ayuda, int maximo = 160}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _campo(id),
        decoration: decoracionCampo(etiqueta, ayuda: ayuda),
        keyboardType: switch (id) {
          'email' => TextInputType.emailAddress,
          'valor' => TextInputType.number,
          _ => TextInputType.text,
        },
        inputFormatters: [
          LengthLimitingTextInputFormatter(id == 'valor' ? 18 : maximo),
          if (id == 'valor') const FormatoMilesCop(),
        ],
        onChanged: id == 'nit'
            ? (_) => setState(() {
                _destino = null;
                _resultados = null;
                _error = null;
              })
            : null,
        validator: (v) {
          final t = (v ?? '').trim();
          if (t.isEmpty) return 'Completa este campo.';
          if (id == 'nit' && RegistroSupervisionService.nitEntidad(t) == null) {
            return 'Revisa el NIT y su dígito de verificación.';
          }
          if (id == 'email' &&
              (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t) ||
                  t.toLowerCase() == SupervisionService.emailActual)) {
            return 'Indica el correo de la persona que hará la revisión jurídica.';
          }
          if (id == 'valor' && FormatoMilesCop.leer(t) <= 0) {
            return 'Ingresa un valor mayor que cero.';
          }
          return null;
        },
      ),
    );
  }

  List<Widget> _camposEconomicos() => [
    _texto('valor', 'Valor total del contrato (COP)'),
    _texto('duracion', 'Duración', ayuda: 'Por ejemplo, 6 meses o 120 días.'),
    _texto('formaPago', 'Forma de pago'),
    _texto('rp', 'Número del RP'),
    _texto('cdp', 'Número del CDP'),
  ];

  Widget _elegirFecha(String titulo) => OutlinedButton.icon(
    icon: const Icon(Icons.event_outlined),
    label: Text(
      _fecha == null ? titulo : '$titulo · ${fechaNumerica(_fecha!)}',
    ),
    onPressed: () async {
      final fecha = await showDatePicker(
        context: context,
        initialDate: _fecha ?? DateTime.now(),
        firstDate: DateTime(1950),
        lastDate: DateTime.now(),
      );
      if (mounted && fecha != null) setState(() => _fecha = fecha);
    },
  );

  @override
  Widget build(BuildContext context) {
    final nombramiento = _vinculacion == 'nombramiento';
    return TarjetaSupervision(
      titulo: widget.contrato != null
          ? 'Corregir contrato ${widget.contrato!.numeroContrato}'
          : widget.esSupervisor
          ? (widget.perfil == null
                ? 'Configura tu supervisión'
                : 'Editar perfil de supervisión')
          : 'Registra tu contrato',
      icono: widget.esSupervisor
          ? Icons.fact_check_outlined
          : Icons.description_outlined,
      subtitulo: widget.contrato != null
          ? widget.contrato!.entidadNombre
          : widget.esSupervisor
          ? (widget.perfil == null
                ? 'Tus contratistas te encontrarán por entidad y dependencia.'
                : 'La entidad, la dependencia y Jurídico se aplican a nuevas vinculaciones. Para cambiar quién revisa un contrato activo, edita su plan.')
          : 'Busca la entidad por su NIT y selecciona a la persona que supervisa tu contrato.',
      children: [
        Form(
          key: _form,
          child: AbsorbPointer(
            absorbing: _ocupado,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.contrato == null)
                  _texto(
                    'nit',
                    'NIT de la entidad',
                    ayuda: 'Por ejemplo, 899.999.061 o 899999061-9.',
                  ),
                if (widget.esSupervisor) ...[
                  _texto('entidad', 'Nombre de la entidad'),
                  _texto('dependencia', 'Dependencia'),
                  DropdownButtonFormField<String>(
                    initialValue: _vinculacion,
                    isExpanded: true,
                    decoration: decoracionCampo('Tipo de vinculación'),
                    items: const [
                      DropdownMenuItem(
                        value: 'nombramiento',
                        child: Text('Libre nombramiento y remoción'),
                      ),
                      DropdownMenuItem(
                        value: 'contrato',
                        child: Text('Contratista'),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      _vinculacion = v!;
                      _campo('referencia').clear();
                      _campo('cargoObjeto').clear();
                      _fecha = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  _texto(
                    'referencia',
                    nombramiento
                        ? 'Número del acto de nombramiento'
                        : 'Número de tu contrato',
                  ),
                  _texto(
                    'cargoObjeto',
                    nombramiento ? 'Cargo' : 'Objeto de tu contrato',
                    maximo: 2000,
                  ),
                  _elegirFecha(
                    nombramiento
                        ? 'Fecha de nombramiento'
                        : 'Fecha de aprobación en SECOP',
                  ),
                  if (!nombramiento) ...[
                    const SizedBox(height: 12),
                    ..._camposEconomicos(),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Jurídico de supervisión',
                    style: EstiloContractual.tituloGrupo,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'La persona que designes debe registrarse con el rol gratuito Jurídico y verificar este mismo correo.',
                  ),
                  const SizedBox(height: 12),
                  _texto('nombre', 'Nombre de la persona'),
                  _texto('email', 'Correo de Jurídico'),
                ] else ...[
                  if (widget.contrato == null) ...[
                    OutlinedButton.icon(
                      onPressed: _buscar,
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar supervisores'),
                    ),
                    if (_resultados?.isEmpty == true)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'No encontramos un supervisor para este NIT. Confirma el número y que tu supervisor haya registrado su dependencia.',
                        ),
                      ),
                    if (_resultados?.isNotEmpty == true)
                      DropdownButtonFormField<DestinoSupervision>(
                        key: ObjectKey(_resultados),
                        isExpanded: true,
                        decoration: decoracionCampo(
                          'Entidad, dependencia y supervisor',
                        ),
                        items: [
                          for (final d in _resultados!)
                            DropdownMenuItem(
                              value: d,
                              child: Text(
                                '${d.entidad} · ${d.dependencia} · ${d.supervisor}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => _destino = v),
                      ),
                    if (_destino != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${_destino!.entidad} · ${_destino!.dependencia}\nSupervisor: ${_destino!.supervisor}',
                        ),
                      ),
                    const SizedBox(height: 16),
                    _texto('numero', 'Número del contrato', maximo: 80),
                  ],
                  _texto('objeto', 'Objeto del contrato', maximo: 2000),
                  _elegirFecha('Fecha de aprobación en SECOP'),
                  const SizedBox(height: 12),
                  ..._camposEconomicos(),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                FilledButton(
                  onPressed: _ocupado ? null : _guardar,
                  style: EstiloContractual.botonPrincipal(),
                  child: Text(
                    _ocupado
                        ? 'Un momento…'
                        : widget.contrato != null
                        ? 'Guardar corrección'
                        : widget.esSupervisor
                        ? (widget.perfil == null
                              ? 'Crear supervisión y Jurídico'
                              : 'Guardar perfil')
                        : 'Vincular contrato',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
