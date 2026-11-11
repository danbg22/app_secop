import 'package:flutter/material.dart';

export 'fondo_cristal.dart';
export 'foto_ambiente.dart';
export 'panel_cristal.dart';
export 'tema_cristal.dart';
export 'transiciones_liquidas.dart';

/// Fichas del lenguaje visual "Liquid Glass" de Contrata Legal: fondo
/// oscuro mate, paneles de vidrio translúcido y los colores de la marca
/// (azul y dorado) en su variante brillante.
///
/// Todo color de la interfaz sale de aquí. La jerarquía del texto se hace
/// con opacidad sobre blanco, no con grises sólidos.
abstract final class Cristal {
  // ---------------------------------------------------------------------
  // Fondo
  // ---------------------------------------------------------------------

  /// Fondo mate de toda la aplicación: el azul marino de la marca llevado
  /// casi a negro.
  static const Color fondo = Color(0xFF07101F);

  /// Tinta oscura para escribir sobre rellenos claros (dorado, ámbar).
  static const Color tinta = Color(0xFF0A1424);

  /// Superficie de lo que flota sobre el contenido (diálogos, menús,
  /// avisos): casi opaca para que el texto se lea sobre cualquier cosa.
  static const Color flotante = Color(0xF20E1A2E);

  /// Velo que oscurece la pantalla detrás de un diálogo.
  static const Color velo = Color(0x8A030812);

  /// Etiqueta emergente pequeña (burbuja del menú contraído, ayudas).
  static const Color burbuja = Color(0xF51A2A45);

  /// Vidrio oscuro para paneles que van sobre una foto: junto con el
  /// desenfoque mantiene el texto legible sobre zonas claras.
  static const Color vidrioOscuro = Color(0x7A07101F);

  /// El mismo, bajo el cursor.
  static const Color vidrioOscuroEncima = Color(0x7A16284A);

  // ---------------------------------------------------------------------
  // Texto: blanco por opacidad
  // ---------------------------------------------------------------------

  /// Títulos, cifras y valores (100 %).
  static const Color texto = Color(0xFFFFFFFF);

  /// Texto de lectura (87 %).
  static const Color textoCuerpo = Color(0xDEFFFFFF);

  /// Texto de apoyo (70 %).
  static const Color textoMedio = Color(0xB3FFFFFF);

  /// Subtítulos y metadatos (60 %).
  static const Color textoSuave = Color(0x99FFFFFF);

  /// Detalles pequeños e íconos en reposo (50 %).
  static const Color textoTenue = Color(0x80FFFFFF);

  /// Deshabilitado y marcadores de posición (40 %).
  static const Color textoApagado = Color(0x66FFFFFF);

  // ---------------------------------------------------------------------
  // Vidrio
  // ---------------------------------------------------------------------

  /// Relleno interior, el más tenue (4 %).
  static const Color vidrioSuave = Color(0x0AFFFFFF);

  /// Relleno de los campos de texto (5 %).
  static const Color campo = Color(0x0DFFFFFF);

  /// Relleno de una tarjeta o panel (6 %).
  static const Color vidrio = Color(0x0FFFFFFF);

  /// Tarjeta bajo el cursor, pistas y rellenos destacados (10 %).
  static const Color vidrioFuerte = Color(0x1AFFFFFF);

  /// Elemento seleccionado o presionado (16 %).
  static const Color vidrioIntenso = Color(0x29FFFFFF);

  /// Borde de 1 px que delinea el vidrio (8 %).
  static const Color borde = Color(0x14FFFFFF);

  /// Borde de campos y de vidrio bajo el cursor (18 %).
  static const Color bordeFuerte = Color(0x2EFFFFFF);

  /// Sombra de lo que flota. Las tarjetas de vidrio no llevan sombra.
  static const Color sombra = Color(0x47000000);

  // ---------------------------------------------------------------------
  // Marca
  // ---------------------------------------------------------------------

  /// Azul de la marca, saturado: relleno de la acción principal.
  static const Color acento = Color(0xFF2F6BFF);

  /// Azul para texto, enlaces, íconos y trazos de foco.
  static const Color acentoClaro = Color(0xFF60A5FA);

  /// Vidrio teñido de azul: bandas y bloques que antes eran azul marino.
  static const Color acentoVidrio = Color(0x382F6BFF);

  static const Color acentoBorde = Color(0x6660A5FA);

  /// Dorado de la marca: dónde estás (navegación, pestaña activa) y lo
  /// destacado.
  static const Color dorado = Color(0xFFFFC53D);

  static const Color doradoVidrio = Color(0x2EFFC53D);

  static const Color doradoBorde = Color(0x66FFC53D);

  /// Fondo del avatar cuando la persona no tiene foto.
  static const Color avatar = Color(0xFFB81D4E);

  // ---------------------------------------------------------------------
  // Estados (siempre con su palabra o ícono)
  // ---------------------------------------------------------------------

  static const Color verde = Color(0xFF4ADE80);
  static const Color verdeVidrio = Color(0x2422C55E);
  static const Color verdeBorde = Color(0x664ADE80);

  static const Color ambar = Color(0xFFF59E0B);
  static const Color ambarVidrio = Color(0x24F59E0B);
  static const Color ambarBorde = Color(0x66F59E0B);

  static const Color rojo = Color(0xFFF87171);
  static const Color rojoVidrio = Color(0x26EF4444);
  static const Color rojoBorde = Color(0x66F87171);

  static const Color azulVidrio = Color(0x263B82F6);

  // ---------------------------------------------------------------------
  // Forma y movimiento
  // ---------------------------------------------------------------------

  static const double radioPanel = 24;
  static const double radioTarjeta = 20;
  static const double radioAviso = 16;
  static const double radioCampo = 14;
  static const double radioFicha = 12;

  /// Desenfoque del vidrio (sigma).
  static const double desenfoque = 20;

  /// Microinteracciones: cursor encima, selección.
  static const Duration micro = Duration(milliseconds: 300);
  static const Curve curvaMicro = Curves.easeInOut;

  /// Cambio de vista o de ruta.
  static const Duration cambio = Duration(milliseconds: 360);

  /// Variante brillante de un color (de marca, de un rol, de una
  /// categoría) para usarlo como acento sobre el fondo oscuro: le sube la
  /// luminosidad y la saturación sin cambiarle el tono.
  static Color brillante(Color color) {
    final hsl = HSLColor.fromColor(color);
    if (hsl.saturation < 0.08) return color;
    return hsl
        .withLightness(hsl.lightness < 0.66 ? 0.66 : hsl.lightness)
        .withSaturation(hsl.saturation < 0.72 ? 0.72 : hsl.saturation)
        .toColor();
  }

  /// Color del texto o del ícono que va encima de un relleno sólido
  /// [fondo]: tinta oscura si el relleno es claro o brillante (dorado,
  /// celeste, verde), blanco si es oscuro.
  static Color sobre(Color fondo) =>
      fondo.computeLuminance() > 0.3 ? tinta : texto;

  /// Decoración de vidrio para un `Container`: relleno translúcido, borde
  /// de 1 px y esquinas amplias.
  static BoxDecoration vidrioDeco({
    double radio = radioTarjeta,
    Color color = vidrio,
    Color colorBorde = borde,
    double anchoBorde = 1,
  }) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radio),
    border: Border.all(color: colorBorde, width: anchoBorde),
  );
}
