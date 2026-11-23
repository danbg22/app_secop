import 'dart:async';

import 'package:flutter/material.dart';

import '../../tema/foto_ambiente.dart';

class FondoInicio extends StatefulWidget {
  const FondoInicio({super.key, required this.activo, required this.movil});

  final bool activo;
  final bool movil;

  @override
  State<FondoInicio> createState() => _FondoInicioState();
}

class _FondoInicioState extends State<FondoInicio> {
  static const _intervalo = Duration(minutes: 15);
  static const _fotos = [
    (AssetImage('assets/images/inicio/valledupar.jpg'), Alignment(-0.35, -0.1)),
    (AssetImage('assets/images/inicio/cartagena.jpg'), Alignment(-0.5, -0.1)),
    (AssetImage('assets/images/inicio/guatape.jpg'), Alignment(0.72, -0.1)),
    (AssetImage('assets/images/inicio/cano_cristales.jpg'), Alignment.center),
    (AssetImage('assets/images/inicio/cocora.jpg'), Alignment.center),
  ];

  final _pendientes = List.of(_fotos)..shuffle();
  late (AssetImage, Alignment) _actual;
  Timer? _rotacion;
  bool _reducirMovimiento = false;

  @override
  void initState() {
    super.initState();
    _actual = _pendientes.removeLast();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducirMovimiento = MediaQuery.disableAnimationsOf(context);
    _programarRotacion();
  }

  @override
  void didUpdateWidget(FondoInicio oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activo != widget.activo) _programarRotacion();
  }

  void _programarRotacion() {
    _rotacion?.cancel();
    _rotacion = null;
    if (!widget.activo || _reducirMovimiento) return;

    if (_pendientes.isEmpty) {
      _pendientes
        ..addAll(_fotos)
        ..shuffle();
      if (_pendientes.last == _actual) {
        _pendientes.insert(0, _pendientes.removeLast());
      }
    }

    precacheImage(_pendientes.last.$1, context, onError: (_, _) {});
    _rotacion = Timer(_intervalo, () {
      setState(() => _actual = _pendientes.removeLast());
      _programarRotacion();
    });
  }

  @override
  void dispose() {
    _rotacion?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (imagen, alineacion) = _actual;
    return AnimatedSwitcher(
      duration: _reducirMovimiento
          ? Duration.zero
          : const Duration(milliseconds: 1400),
      child: FotoAmbiente(
        key: ValueKey(imagen),
        imagen: imagen,
        alineacion: alineacion,
        opacidad: widget.movil ? 0.48 : 0.56,
        inicio: widget.movil ? 0 : 0.08,
        pleno: widget.movil ? 0.75 : 0.78,
        fundidoSuperior: widget.movil ? 0.27 : 0,
        fundidoInferior: widget.movil ? 0.2 : 0.32,
      ),
    );
  }
}
