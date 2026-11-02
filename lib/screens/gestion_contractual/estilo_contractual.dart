import 'package:flutter/material.dart';

/// Lenguaje visual de Gestión contractual: el mismo de la autenticación
/// (fondo crema, tarjetas blancas limpias, botones tipo píldora y azul
/// marino institucional).
class EstiloContractual {
  EstiloContractual._();

  static const Color crema = Color(0xFFFEF9EB);
  static const Color navy = Color(0xFF0E2646);
  static const Color texto = Color(0xFF364F6B);
  static const Color gris = Color(0xFF64748B);
  static const Color borde = Color(0xFFE6ECF5);
  static const Color bordeCalido = Color(0xFFE2DAC8);
  static const Color dorado = Color(0xFFF5C032);

  static BoxDecoration tarjeta({Color? colorBorde}) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: colorBorde ?? borde, width: 1.3),
    boxShadow: [
      BoxShadow(
        color: navy.withValues(alpha: 0.04),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ],
  );

  static ButtonStyle botonPrincipal() => FilledButton.styleFrom(
    backgroundColor: navy,
    foregroundColor: Colors.white,
    disabledBackgroundColor: const Color(0xFFCBD5E1),
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
    shape: const StadiumBorder(),
  );

  static ButtonStyle botonSecundario() => OutlinedButton.styleFrom(
    foregroundColor: navy,
    backgroundColor: Colors.white,
    side: const BorderSide(color: bordeCalido, width: 1.2),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    shape: const StadiumBorder(),
  );

  static const TextStyle etiquetaBoton = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle titulo = TextStyle(
    color: navy,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.12,
  );

  static const TextStyle subtitulo = TextStyle(
    color: texto,
    fontSize: 14.5,
    height: 1.45,
  );

  /// Clave de un dato ("CONTRATO", "VALOR"): la única mayúscula sostenida.
  static const TextStyle seccion = TextStyle(
    color: gris,
    fontSize: 11.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.6,
  );

  /// Título de un grupo dentro de una pantalla, en tipo oración.
  static const TextStyle tituloGrupo = TextStyle(
    color: navy,
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
        foregroundColor: EstiloContractual.navy,
        backgroundColor: Colors.white,
        side: const BorderSide(
          color: EstiloContractual.bordeCalido,
          width: 1.2,
        ),
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
      backgroundColor: EstiloContractual.crema,
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
