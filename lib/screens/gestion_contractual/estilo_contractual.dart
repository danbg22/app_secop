import 'package:flutter/material.dart';

import '../../tema/cristal.dart';

/// Estilos compartidos de Gestión contractual sobre el lenguaje de vidrio
/// (lib/tema): tarjetas translúcidas, botones tipo píldora y los títulos
/// del módulo. Los colores salen de [Cristal].
class EstiloContractual {
  EstiloContractual._();

  static BoxDecoration tarjeta({Color? colorBorde}) => BoxDecoration(
    color: Cristal.vidrio,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: colorBorde ?? Cristal.borde, width: 1.3),
  );

  static ButtonStyle botonPrincipal() => FilledButton.styleFrom(
    backgroundColor: Cristal.acento,
    foregroundColor: Cristal.texto,
    disabledBackgroundColor: Cristal.vidrioFuerte,
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
    shape: const StadiumBorder(),
  );

  static ButtonStyle botonSecundario() => OutlinedButton.styleFrom(
    foregroundColor: Cristal.texto,
    backgroundColor: Cristal.vidrio,
    side: const BorderSide(color: Cristal.borde, width: 1.2),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    shape: const StadiumBorder(),
  );

  static const TextStyle etiquetaBoton = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle titulo = TextStyle(
    color: Cristal.texto,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.12,
  );

  static const TextStyle subtitulo = TextStyle(
    color: Cristal.textoMedio,
    fontSize: 14.5,
    height: 1.45,
  );

  /// Clave de un dato ("CONTRATO", "VALOR"): la única mayúscula sostenida.
  static const TextStyle seccion = TextStyle(
    color: Cristal.textoSuave,
    fontSize: 11.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.6,
  );

  /// Título de un grupo dentro de una pantalla, en tipo oración.
  static const TextStyle tituloGrupo = TextStyle(
    color: Cristal.texto,
    fontSize: 15,
    fontWeight: FontWeight.w800,
  );
}

/// Píldora "← Volver" de la barra superior, como en el registro.
class PildoraVolver extends StatelessWidget {
  const PildoraVolver({super.key, required this.etiqueta, required this.onTap});

  final String etiqueta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.arrow_back_rounded, size: 19),
      label: Text(etiqueta, style: EstiloContractual.etiquetaBoton),
      style: OutlinedButton.styleFrom(
        foregroundColor: Cristal.texto,
        backgroundColor: Cristal.vidrio,
        side: const BorderSide(color: Cristal.borde, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

/// Etiqueta de color de una modalidad o estado.
class EtiquetaColor extends StatelessWidget {
  const EtiquetaColor({
    super.key,
    required this.texto,
    required this.color,
    required this.fondo,
    this.icono,
  });

  final String texto;
  final Color color;
  final Color fondo;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Envoltura común de las pantallas de gestión contractual.
class PantallaContractual extends StatelessWidget {
  const PantallaContractual({
    super.key,
    required this.children,
    this.anchoMaximo = 1080,
  });

  final List<Widget> children;
  final double anchoMaximo;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 680;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? 16 : 40,
            vertical: mobile ? 14 : 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: anchoMaximo),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
