import 'package:flutter/material.dart';

import 'cristal.dart';

/// Interruptor "Claro | Oscuro" del modo de color. La elección se recuerda
/// en este navegador ([Cristal.cambiarModo]).
class InterruptorModo extends StatelessWidget {
  const InterruptorModo({super.key, this.compacto = false});

  /// Solo el ícono del modo al que se cambiaría (menú lateral contraído).
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ModoCristal>(
      valueListenable: Cristal.modo,
      builder: (context, modo, _) {
        final claro = modo == ModoCristal.claro;
        if (compacto) {
          return IconButton(
            tooltip: claro ? 'Cambiar a modo oscuro' : 'Cambiar a modo claro',
            onPressed: () => Cristal.cambiarModo(
              claro ? ModoCristal.oscuro : ModoCristal.claro,
            ),
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor: Cristal.vidrio,
              side: BorderSide(color: Cristal.borde),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: Icon(
              claro ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              color: Cristal.texto,
              size: 19,
            ),
          );
        }
        Widget opcion(ModoCristal valor, IconData icono, String texto) {
          final activa = modo == valor;
          return Expanded(
            child: Semantics(
              button: true,
              selected: activa,
              label: 'Modo $texto',
              child: InkWell(
                onTap: activa ? null : () => Cristal.cambiarModo(valor),
                borderRadius: BorderRadius.circular(9),
                hoverDuration: Cristal.micro,
                child: AnimatedContainer(
                  duration: Cristal.micro,
                  curve: Cristal.curvaMicro,
                  height: 32,
                  decoration: BoxDecoration(
                    color: activa ? Cristal.vidrioIntenso : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icono,
                        size: 16,
                        color: activa ? Cristal.texto : Cristal.textoSuave,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        texto,
                        style: TextStyle(
                          color: activa ? Cristal.texto : Cristal.textoSuave,
                          fontSize: 12.5,
                          fontWeight: activa
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Cristal.vidrioSuave,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Cristal.borde),
          ),
          child: Row(
            children: [
              opcion(ModoCristal.claro, Icons.light_mode_outlined, 'Claro'),
              const SizedBox(width: 3),
              opcion(ModoCristal.oscuro, Icons.dark_mode_outlined, 'Oscuro'),
            ],
          ),
        );
      },
    );
  }
}

/// Reconstruye y repinta todo lo que tiene debajo cuando cambia el modo
/// (también los widgets constantes y los pintores que leen los colores de
/// [Cristal]), sin perder rutas, lo escrito ni el desplazamiento. Va por
/// encima de `MaterialApp`, que se construye con [builder] para tomar el
/// tema del modo nuevo.
class ModoCristalScope extends StatefulWidget {
  const ModoCristalScope({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  State<ModoCristalScope> createState() => _ModoCristalScopeState();
}

class _ModoCristalScopeState extends State<ModoCristalScope> {
  @override
  void initState() {
    super.initState();
    Cristal.modo.addListener(_cambioDeModo);
  }

  @override
  void dispose() {
    Cristal.modo.removeListener(_cambioDeModo);
    super.dispose();
  }

  void _cambioDeModo() {
    if (!mounted) return;
    setState(() {});
    void marcar(Element e) {
      e.markNeedsBuild();
      if (e is RenderObjectElement) e.renderObject.markNeedsPaint();
      e.visitChildren(marcar);
    }

    (context as Element).visitChildren(marcar);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
