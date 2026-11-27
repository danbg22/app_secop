import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../services/procesos_secop_service.dart';
import '../tema/cristal.dart';
import 'detalle_proceso_screen.dart';

class ProcesoCompartidoScreen extends StatefulWidget {
  const ProcesoCompartidoScreen({
    super.key,
    required this.id,
    required this.soloEncabezado,
    this.onVistaActiva,
    this.onAutenticar,
  }) : assert(!soloEncabezado || onAutenticar != null);

  final String id;
  final bool soloEncabezado;
  final VoidCallback? onVistaActiva;
  final ValueChanged<String>? onAutenticar;

  @override
  State<ProcesoCompartidoScreen> createState() =>
      _ProcesoCompartidoScreenState();
}

class _ProcesoCompartidoScreenState extends State<ProcesoCompartidoScreen> {
  late Future<ProcesoSecop?> _proceso = _consultar();

  Future<ProcesoSecop?> _consultar() => ProcesosSecopService.porId(
    widget.id,
    soloEncabezado: widget.soloEncabezado,
  );

  @override
  void didUpdateWidget(covariant ProcesoCompartidoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        oldWidget.soloEncabezado != widget.soloEncabezado) {
      _proceso = _consultar();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ModalRoute.isCurrentOf(context) == true) {
      widget.onVistaActiva?.call();
    }

    return FutureBuilder<ProcesoSecop?>(
      future: _proceso,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Cargando proceso',
              ),
            ),
          );
        }
        final proceso = snapshot.data;
        if (proceso == null) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        snapshot.hasError ? 'No pudimos consultar el proceso.' : 'El enlace no corresponde a un proceso disponible.',
                        textAlign: TextAlign.center,
                      ),
                      if (snapshot.hasError)
                        TextButton(
                          onPressed: () =>
                              setState(() => _proceso = _consultar()),
                          child: const Text('Reintentar'),
                        ),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).pushReplacementNamed('/home'),
                        child: const Text('Ir al inicio'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        if (!widget.soloEncabezado) {
          return DetalleProcesoScreen(proceso: proceso);
        }
        return _VistaPreviaProceso(
          proceso: proceso,
          onAutenticar: widget.onAutenticar!,
        );
      },
    );
  }
}

class _VistaPreviaProceso extends StatelessWidget {
  const _VistaPreviaProceso({
    required this.proceso,
    required this.onAutenticar,
  });

  final ProcesoSecop proceso;
  final ValueChanged<String> onAutenticar;

  @override
  Widget build(BuildContext context) {
    final titulo = Theme.of(context).textTheme.headlineMedium?.copyWith(
      color: Cristal.texto,
      fontWeight: FontWeight.w800,
      height: 1.16,
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SelectionContainer.disabled(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Image.asset(
                            Cristal.logo,
                            height: 42,
                            semanticLabel: 'Contrata Legal',
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Spacer(),
                        TextButton(
                          onPressed: () => onAutenticar('/auth'),
                          child: const Text('Ingresa'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Cristal.borde),
                        borderRadius: BorderRadius.circular(24),
                        color: Cristal.vidrio,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  [
                                    'SECOP II',
                                    if (proceso.adjudicado)
                                      'Adjudicado'
                                    else if (proceso.estadoSecop.isNotEmpty)
                                      proceso.estadoSecop,
                                  ].join(' · '),
                                  style: TextStyle(
                                    color: Cristal.acentoClaro,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  proceso.nombre.isNotEmpty
                                      ? proceso.nombre
                                      : 'Proceso de contratación',
                                  style: titulo,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  [
                                    proceso.entidad,
                                    proceso.referencia,
                                  ].where((v) => v.isNotEmpty).join(' · '),
                                  style: TextStyle(color: Cristal.textoMedio),
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: Cristal.borde),
                          const _DetalleDifuminado(),
                          Container(
                            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  color: Cristal.dorado,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Consulta el proceso completo',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Crea una cuenta o inicia sesión para ver los detalles y abrir el proceso en SECOP.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Cristal.textoMedio,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 17),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    FilledButton(
                                      onPressed: () =>
                                          onAutenticar('/registro'),
                                      child: const Text('Regístrate'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () => onAutenticar('/auth'),
                                      child: const Text('Ingresa'),
                                    ),
                                  ],
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
            ),
          ),
        ),
      ),
    );
  }
}

class _DetalleDifuminado extends StatelessWidget {
  const _DetalleDifuminado();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Colors.transparent],
        stops: [.12, .95],
      ).createShader(rect),
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, ancho) in const [.47, .92, .71, .77, .38].indexed)
                FractionallySizedBox(
                  widthFactor: ancho,
                  child: Container(
                    height: i == 0 ? 17 : 9,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Cristal.texto.withValues(
                        alpha: i == 0 ? .45 : .29,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
