import 'package:flutter/material.dart';

import '../services/etapas_proceso.dart';
import '../services/procesos_secop_service.dart';
import '../tema/cristal.dart';

/// Línea de tiempo de un proceso: la línea dorada avanza hasta la etapa en
/// la que va. Si el proceso se canceló o quedó desierto, se detiene en rojo
/// donde ocurrió.
class LineaTiempoProceso extends StatelessWidget {
  const LineaTiempoProceso(this.proceso, {super.key, this.compacta = false});

  final ProcesoSecop proceso;

  /// Versión de una línea para las tarjetas de la lista.
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final etapas = EtapasProceso.de(proceso);
    final sinAnimar = MediaQuery.of(context).disableAnimations;
    final avance = etapas.nombres.length == 1
        ? 1.0
        : etapas.actual / (etapas.nombres.length - 1);
    final detenido = etapas.interrumpido != null;
    final colorAvance = detenido ? Cristal.rojo : Cristal.dorado;
    final etiqueta = detenido
        ? '${etapas.interrumpido} en ${etapas.nombres[etapas.actual].toLowerCase()}'
        : 'Etapa ${etapas.actual + 1} de ${etapas.nombres.length} · ${etapas.nombres[etapas.actual]}';

    return Semantics(
      label: 'Línea de tiempo del proceso: $etiqueta',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: sinAnimar ? avance : 0, end: avance),
        duration: sinAnimar ? Duration.zero : const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, valor, _) => compacta
            // La barra se llena por etapas: en la 1 de 3 va un tercio.
            ? _compacta(
                etiqueta,
                (etapas.actual + 1) /
                    etapas.nombres.length *
                    (avance == 0 ? 1 : valor / avance),
                colorAvance,
              )
            : _completa(etapas, valor, colorAvance),
      ),
    );
  }

  Widget _compacta(String etiqueta, double valor, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          height: 4,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: Cristal.vidrioFuerte)),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: valor.clamp(1 / 3 * 0.25, 1.0),
                heightFactor: 1,
                child: ColoredBox(color: color),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        etiqueta,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Cristal.textoMedio,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _completa(EtapasProceso etapas, double valor, Color color) {
    final n = etapas.nombres.length;
    const punto = 16.0;
    return LayoutBuilder(
      builder: (context, c) {
        final paso = c.maxWidth / n;
        final inicio = paso / 2;
        final largo = c.maxWidth - paso;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: punto,
              child: Stack(
                children: [
                  Positioned(
                    left: inicio,
                    width: largo,
                    top: punto / 2 - 1.5,
                    height: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Cristal.vidrioFuerte,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Positioned(
                    left: inicio,
                    width: largo * valor,
                    top: punto / 2 - 1.5,
                    height: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  for (var i = 0; i < n; i++)
                    Positioned(
                      left: inicio + paso * i - punto / 2,
                      top: 0,
                      width: punto,
                      height: punto,
                      child: _Punto(
                        estado: i < etapas.actual
                            ? _EstadoPunto.recorrido
                            : i == etapas.actual
                            ? (etapas.interrumpido != null
                                  ? _EstadoPunto.detenido
                                  : _EstadoPunto.actual)
                            : _EstadoPunto.pendiente,
                        // El punto se enciende cuando la línea lo alcanza.
                        alcanzado: n == 1 || valor >= i / (n - 1) - 0.001,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Si los nombres no caben debajo de cada punto (celular), se
            // muestra solo la etapa actual, sin partir las palabras.
            if (paso < 84)
              Text(
                '${etapas.nombres[etapas.actual]} · etapa ${etapas.actual + 1} de $n',
                style: TextStyle(
                  color: Cristal.texto,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < n; i++)
                    Expanded(
                      child: Text(
                        etapas.nombres[i],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          color: i == etapas.actual
                              ? Cristal.texto
                              : i < etapas.actual
                              ? Cristal.textoMedio
                              : Cristal.textoSuave,
                          fontSize: 12.5,
                          fontWeight: i == etapas.actual
                              ? FontWeight.w800
                              : FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                    ),
                ],
              ),
            if (etapas.interrumpido != null) ...[
              const SizedBox(height: 10),
              Text(
                'El proceso quedó ${etapas.interrumpido!.toLowerCase()} en la etapa de ${etapas.nombres[etapas.actual].toLowerCase()}.',
                style: TextStyle(color: Cristal.rojo, fontSize: 13),
              ),
            ],
          ],
        );
      },
    );
  }
}

enum _EstadoPunto { recorrido, actual, detenido, pendiente }

class _Punto extends StatelessWidget {
  const _Punto({required this.estado, required this.alcanzado});

  final _EstadoPunto estado;
  final bool alcanzado;

  @override
  Widget build(BuildContext context) {
    final encendido = alcanzado && estado != _EstadoPunto.pendiente;
    final color = estado == _EstadoPunto.detenido
        ? Cristal.rojo
        : Cristal.dorado;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: encendido
            ? (estado == _EstadoPunto.recorrido ? color : Cristal.flotante)
            : Cristal.flotante,
        border: Border.all(
          color: encendido ? color : Cristal.bordeFuerte,
          width:
              estado == _EstadoPunto.actual || estado == _EstadoPunto.detenido
              ? 3.5
              : 1.5,
        ),
      ),
    );
  }
}
