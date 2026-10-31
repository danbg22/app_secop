import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../services/equipo_juridico_service.dart';

String _fechaLarga(DateTime f) {
  const meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return '${f.day} de ${meses[f.month - 1]} de ${f.year}';
}

/// Gestión del equipo jurídico: el Master Jurídico (titular de la
/// suscripción) agrega abogados temporales, define sus permisos y vigencia,
/// los suspende o los quita. Mismo lenguaje visual que el registro.
class GestionEquipoScreen extends StatefulWidget {
  const GestionEquipoScreen({super.key});

  @override
  State<GestionEquipoScreen> createState() => _GestionEquipoScreenState();
}

class _GestionEquipoScreenState extends State<GestionEquipoScreen> {
  static const Color _navy = Color(0xFF0E2646);
  static const Color _texto = Color(0xFF364F6B);
  static const Color _crema = Color(0xFFFEF9EB);

  List<MiembroEquipo> _miembros = const [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final miembros = await EquipoJuridicoService.listarMiembros();
      if (!mounted) return;
      setState(() => _miembros = miembros);
    } on EquipoJuridicoException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No fue posible cargar el equipo. Revisa tu conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mensaje(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? const Color(0xFFB91C1C) : _navy,
        ),
      );
  }

  Future<void> _ejecutar(Future<void> Function() accion, String exito) async {
    try {
      await accion();
      _mensaje(exito);
      await _cargar();
    } on EquipoJuridicoException catch (e) {
      _mensaje(e.message, error: true);
    } catch (_) {
      _mensaje('No fue posible completar la acción.', error: true);
    }
  }

  Future<void> _abrirFormulario({MiembroEquipo? existente}) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _FormularioMiembro(existente: existente),
    );
    if (guardado == true) await _cargar();
  }

  Future<void> _confirmarQuitar(MiembroEquipo m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar del equipo'),
        content: Text(
          '${m.nombre} perderá de inmediato el acceso a los expedientes del '
          'equipo. Los expedientes que creó se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
            ),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _ejecutar(
        () => EquipoJuridicoService.quitarMiembro(m),
        '${m.nombre} ya no hace parte del equipo.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 680;
    final usados = _miembros.length;
    final lleno = usados >= EquipoJuridicoService.cupoMaximo;

    return Scaffold(
      backgroundColor: _crema,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? 16 : 40,
            vertical: mobile ? 14 : 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _PildoraVolver(onTap: () => Navigator.pop(context)),
                  ),
                  SizedBox(height: mobile ? 18 : 26),
                  Text(
                    'Mi equipo jurídico',
                    style: TextStyle(
                      color: _navy,
                      fontSize: mobile ? 26 : 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Agrega a los abogados de tu equipo como usuarios temporales. '
                    'Cada uno define su propia contraseña desde el correo que le '
                    'enviamos, trabaja sobre los expedientes del equipo con los '
                    'permisos que le asignes y pierde el acceso al vencer su vigencia.',
                    style: TextStyle(
                      color: _texto,
                      fontSize: 14.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      _CupoIndicador(
                        usados: usados,
                        maximo: EquipoJuridicoService.cupoMaximo,
                      ),
                      FilledButton.icon(
                        onPressed: _cargando || lleno
                            ? null
                            : () => _abrirFormulario(),
                        icon: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 19,
                        ),
                        label: Text(
                          lleno ? 'Cupos completos' : 'Agregar abogado',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _navy,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 16,
                          ),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_cargando)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    _TarjetaVacia(
                      icono: Icons.error_outline_rounded,
                      titulo: 'No pudimos cargar tu equipo',
                      detalle: _error!,
                      accion: TextButton(
                        onPressed: _cargar,
                        child: const Text('Reintentar'),
                      ),
                    )
                  else if (_miembros.isEmpty)
                    const _TarjetaVacia(
                      icono: Icons.groups_2_outlined,
                      titulo: 'Aún no tienes abogados en tu equipo',
                      detalle:
                          'Agrega a tu primer abogado con su correo institucional '
                          'o personal. Le llegará un enlace para crear su contraseña.',
                    )
                  else
                    for (final m in _miembros) ...[
                      _TarjetaMiembro(
                        miembro: m,
                        onEditar: () => _abrirFormulario(existente: m),
                        onSuspender: () => _ejecutar(
                          () => EquipoJuridicoService.actualizarMiembro(
                            m.copyWith(
                              estado: m.suspendido ? 'activo' : 'suspendido',
                            ),
                          ),
                          m.suspendido
                              ? '${m.nombre} vuelve a tener acceso.'
                              : 'Acceso de ${m.nombre} suspendido.',
                        ),
                        onReenviar: () => _ejecutar(
                          () => EquipoJuridicoService.reenviarAcceso(m),
                          'Enviamos a ${m.email} un enlace para definir su contraseña.',
                        ),
                        onQuitar: () => _confirmarQuitar(m),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PildoraVolver extends StatelessWidget {
  const _PildoraVolver({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.arrow_back_rounded, size: 19),
      label: const Text(
        'Gestión contractual',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF0E2646),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFE2DAC8), width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _CupoIndicador extends StatelessWidget {
  const _CupoIndicador({required this.usados, required this.maximo});

  final int usados;
  final int maximo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6DFCF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 90,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: maximo == 0 ? 0 : usados / maximo,
                minHeight: 7,
                color: const Color(0xFFF5C032),
                backgroundColor: const Color(0xFFF1F5F9),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$usados de $maximo cupos usados',
            style: const TextStyle(
              color: Color(0xFF0E2646),
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaVacia extends StatelessWidget {
  const _TarjetaVacia({
    required this.icono,
    required this.titulo,
    required this.detalle,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6ECF5), width: 1.3),
      ),
      child: Column(
        children: [
          Icon(icono, size: 40, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF0E2646),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detalle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF364F6B), fontSize: 13.5),
          ),
          ?accion,
        ],
      ),
    );
  }
}

class _TarjetaMiembro extends StatelessWidget {
  const _TarjetaMiembro({
    required this.miembro,
    required this.onEditar,
    required this.onSuspender,
    required this.onReenviar,
    required this.onQuitar,
  });

  final MiembroEquipo miembro;
  final VoidCallback onEditar;
  final VoidCallback onSuspender;
  final VoidCallback onReenviar;
  final VoidCallback onQuitar;

  static const Color _navy = Color(0xFF0E2646);

  @override
  Widget build(BuildContext context) {
    final m = miembro;
    final (estado, colorEstado, fondoEstado) = m.suspendido
        ? ('Suspendido', const Color(0xFFB45309), const Color(0xFFFEF3C7))
        : m.vencido
        ? ('Vencido', const Color(0xFFB91C1C), const Color(0xFFFEE2E2))
        : ('Activo', const Color(0xFF15803D), const Color(0xFFDCFCE7));
    final vence = _fechaLarga(m.vigenteHasta);
    final iniciales = m.nombre
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6ECF5), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFE8F1FC),
            child: Text(
              iniciales,
              style: const TextStyle(
                color: Color(0xFF28559A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      m.nombre,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: fondoEstado,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        estado,
                        style: TextStyle(
                          color: colorEstado,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${m.email} · vence el $vence',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    const _ChipPermiso(texto: 'Ver expedientes', activo: true),
                    for (final p in PermisoEquipo.values)
                      _ChipPermiso(
                        texto: p.etiqueta,
                        activo: m.permisos.contains(p),
                      ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opciones',
            icon: const Icon(Icons.more_vert_rounded, color: _navy),
            onSelected: (v) => switch (v) {
              'editar' => onEditar(),
              'suspender' => onSuspender(),
              'reenviar' => onReenviar(),
              _ => onQuitar(),
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'editar',
                child: Text('Editar permisos y vigencia'),
              ),
              PopupMenuItem(
                value: 'suspender',
                child: Text(
                  m.suspendido ? 'Reactivar acceso' : 'Suspender acceso',
                ),
              ),
              const PopupMenuItem(
                value: 'reenviar',
                child: Text('Reenviar enlace de contraseña'),
              ),
              const PopupMenuItem(
                value: 'quitar',
                child: Text(
                  'Quitar del equipo',
                  style: TextStyle(color: Color(0xFFB91C1C)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipPermiso extends StatelessWidget {
  const _ChipPermiso({required this.texto, required this.activo});

  final String texto;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: activo ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activo ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            activo ? Icons.check_rounded : Icons.block_rounded,
            size: 13,
            color: activo ? const Color(0xFF1D4ED8) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
              color: activo ? const Color(0xFF1E3A8A) : const Color(0xFF94A3B8),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              decoration: activo ? null : TextDecoration.lineThrough,
            ),
          ),
        ],
      ),
    );
  }
}

/// Alta o edición de un abogado: nombre, correo, permisos y vigencia.
class _FormularioMiembro extends StatefulWidget {
  const _FormularioMiembro({this.existente});

  final MiembroEquipo? existente;

  @override
  State<_FormularioMiembro> createState() => _FormularioMiembroState();
}

class _FormularioMiembroState extends State<_FormularioMiembro> {
  static const Color _navy = Color(0xFF0E2646);

  late final TextEditingController _nombre;
  late final TextEditingController _correo;
  late Set<PermisoEquipo> _permisos;
  late DateTime _vigencia;
  bool _guardando = false;
  String? _error;

  bool get _editando => widget.existente != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    _nombre = TextEditingController(text: e?.nombre ?? '');
    _correo = TextEditingController(text: e?.email ?? '');
    _permisos = {...?e?.permisos};
    if (e == null) {
      _permisos = {
        PermisoEquipo.pedirDocumentos,
        PermisoEquipo.verificarDocumentos,
      };
    }
    _vigencia = e?.vigenteHasta ?? EquipoJuridicoService.vigenciaPorDefecto();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _vigencia.isAfter(hoy)
          ? _vigencia
          : hoy.add(const Duration(days: 30)),
      firstDate: hoy.add(const Duration(days: 1)),
      lastDate: hoy.add(
        EquipoJuridicoService.vigenciaMaxima - const Duration(days: 1),
      ),
      helpText: 'Vigencia del acceso',
    );
    if (elegida != null) {
      setState(
        () => _vigencia = DateTime(
          elegida.year,
          elegida.month,
          elegida.day,
          23,
          59,
        ),
      );
    }
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      String mensaje;
      if (_editando) {
        await EquipoJuridicoService.actualizarMiembro(
          widget.existente!.copyWith(
            nombre: _nombre.text.trim(),
            permisos: _permisos,
            vigenteHasta: _vigencia,
          ),
        );
        mensaje = 'Cambios guardados.';
      } else {
        final resultado = await EquipoJuridicoService.agregarMiembro(
          nombre: _nombre.text,
          email: _correo.text,
          permisos: _permisos,
          vigenteHasta: _vigencia,
        );
        mensaje = resultado == ResultadoAltaMiembro.cuentaCreada
            ? 'Abogado agregado. Le enviamos a ${_correo.text.trim()} un enlace para crear su contraseña.'
            : 'Ese correo ya tenía cuenta en Contrata Legal: quedó vinculado al '
                  'equipo y entra con su contraseña actual.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensaje)));
      Navigator.pop(context, true);
    } on EquipoJuridicoException catch (e) {
      setState(() => _error = e.message);
    } on FirebaseException catch (e) {
      setState(
        () => _error = e.code == 'permission-denied'
            ? 'Firestore rechazó la operación (permisos). Verifica que las reglas publicadas sean las del repositorio.'
            : 'No fue posible guardar (${e.code}).',
      );
    } catch (e) {
      setState(() => _error = 'No fue posible guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  InputDecoration _decoracion(String etiqueta, IconData icono) =>
      InputDecoration(
        labelText: etiqueta,
        prefixIcon: Icon(icono, color: _navy, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD8DEE8)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFFEFBF4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _editando ? 'Editar abogado' : 'Agregar abogado al equipo',
                style: const TextStyle(
                  color: _navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                decoration: _decoracion(
                  'Nombre completo',
                  Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _correo,
                enabled: !_editando,
                keyboardType: TextInputType.emailAddress,
                decoration: _decoracion(
                  'Correo electrónico',
                  Icons.mail_outline_rounded,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'PERMISOS',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Todos los abogados pueden ver los expedientes del equipo.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
              ),
              for (final p in PermisoEquipo.values)
                CheckboxListTile(
                  value: _permisos.contains(p),
                  onChanged: (v) => setState(
                    () => v == true ? _permisos.add(p) : _permisos.remove(p),
                  ),
                  title: Text(
                    p.etiqueta,
                    style: const TextStyle(fontSize: 14, color: _navy),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: _navy,
                ),
              const SizedBox(height: 10),
              const Text(
                'VIGENCIA DEL ACCESO',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _elegirFecha,
                icon: const Icon(Icons.event_rounded, size: 18),
                label: Text('Hasta el ${_fechaLarga(_vigencia)}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _navy,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  side: const BorderSide(color: Color(0xFFD8DEE8)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _guardando
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    style: FilledButton.styleFrom(
                      backgroundColor: _navy,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _editando
                                ? 'Guardar cambios'
                                : 'Agregar y enviar acceso',
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
}
