import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'fondo_cristal.dart';
export 'foto_ambiente.dart';
export 'interruptor_modo.dart';
export 'panel_cristal.dart';
export 'tema_cristal.dart';
export 'transiciones_liquidas.dart';

/// Modo de color de la app. El oscuro es el original; el claro usa los
/// mismos tonos de la marca para que pasar de uno a otro se sienta como la
/// misma app.
enum ModoCristal { oscuro, claro }

/// Los colores de un modo. Cada ficha tiene el mismo papel en los dos: en
/// el oscuro la jerarquía es blanco por opacidad sobre azul marino; en el
/// claro, azul marino por opacidad sobre un gris azulado muy claro, con
/// tarjetas blancas translúcidas. El azul, el dorado y los estados se
/// oscurecen en el claro para que se lean sobre blanco.
class PaletaCristal {
  const PaletaCristal({
    required this.fondo,
    required this.tinta,
    required this.flotante,
    required this.velo,
    required this.burbuja,
    required this.vidrioOscuro,
    required this.vidrioOscuroEncima,
    required this.texto,
    required this.textoCuerpo,
    required this.textoMedio,
    required this.textoSuave,
    required this.textoTenue,
    required this.textoApagado,
    required this.vidrioSuave,
    required this.campo,
    required this.vidrio,
    required this.vidrioFuerte,
    required this.vidrioIntenso,
    required this.borde,
    required this.bordeFuerte,
    required this.sombra,
    required this.acento,
    required this.acentoClaro,
    required this.acentoVidrio,
    required this.acentoBorde,
    required this.dorado,
    required this.doradoVidrio,
    required this.doradoBorde,
    required this.avatar,
    required this.verde,
    required this.verdeVidrio,
    required this.verdeBorde,
    required this.ambar,
    required this.ambarVidrio,
    required this.ambarBorde,
    required this.rojo,
    required this.rojoVidrio,
    required this.rojoBorde,
    required this.azulVidrio,
  });

  final Color fondo;
  final Color tinta;
  final Color flotante;
  final Color velo;
  final Color burbuja;
  final Color vidrioOscuro;
  final Color vidrioOscuroEncima;
  final Color texto;
  final Color textoCuerpo;
  final Color textoMedio;
  final Color textoSuave;
  final Color textoTenue;
  final Color textoApagado;
  final Color vidrioSuave;
  final Color campo;
  final Color vidrio;
  final Color vidrioFuerte;
  final Color vidrioIntenso;
  final Color borde;
  final Color bordeFuerte;
  final Color sombra;
  final Color acento;
  final Color acentoClaro;
  final Color acentoVidrio;
  final Color acentoBorde;
  final Color dorado;
  final Color doradoVidrio;
  final Color doradoBorde;
  final Color avatar;
  final Color verde;
  final Color verdeVidrio;
  final Color verdeBorde;
  final Color ambar;
  final Color ambarVidrio;
  final Color ambarBorde;
  final Color rojo;
  final Color rojoVidrio;
  final Color rojoBorde;
  final Color azulVidrio;

  /// "Liquid Glass" original: fondo oscuro mate y vidrio blanco translúcido.
  static const oscura = PaletaCristal(
    fondo: Color(0xFF07101F),
    tinta: Color(0xFF0A1424),
    flotante: Color(0xF20E1A2E),
    velo: Color(0x8A030812),
    burbuja: Color(0xF51A2A45),
    vidrioOscuro: Color(0x7A07101F),
    vidrioOscuroEncima: Color(0x7A16284A),
    texto: Color(0xFFFFFFFF),
    textoCuerpo: Color(0xDEFFFFFF),
    textoMedio: Color(0xB3FFFFFF),
    textoSuave: Color(0x99FFFFFF),
    textoTenue: Color(0x80FFFFFF),
    textoApagado: Color(0x66FFFFFF),
    vidrioSuave: Color(0x0AFFFFFF),
    campo: Color(0x0DFFFFFF),
    vidrio: Color(0x0FFFFFFF),
    vidrioFuerte: Color(0x1AFFFFFF),
    vidrioIntenso: Color(0x29FFFFFF),
    borde: Color(0x14FFFFFF),
    bordeFuerte: Color(0x2EFFFFFF),
    sombra: Color(0x47000000),
    acento: Color(0xFF2F6BFF),
    acentoClaro: Color(0xFF60A5FA),
    acentoVidrio: Color(0x382F6BFF),
    acentoBorde: Color(0x6660A5FA),
    dorado: Color(0xFFFFC53D),
    doradoVidrio: Color(0x2EFFC53D),
    doradoBorde: Color(0x66FFC53D),
    avatar: Color(0xFFB81D4E),
    verde: Color(0xFF4ADE80),
    verdeVidrio: Color(0x2422C55E),
    verdeBorde: Color(0x664ADE80),
    ambar: Color(0xFFF59E0B),
    ambarVidrio: Color(0x24F59E0B),
    ambarBorde: Color(0x66F59E0B),
    rojo: Color(0xFFF87171),
    rojoVidrio: Color(0x26EF4444),
    rojoBorde: Color(0x66F87171),
    azulVidrio: Color(0x263B82F6),
  );

  /// Modo claro: el mismo azul marino de la marca como tinta, tarjetas
  /// blancas sobre un fondo gris azulado y la marca en su tono profundo.
  static const clara = PaletaCristal(
    fondo: Color(0xFFEDF1F8),
    tinta: Color(0xFF0A1424),
    flotante: Color(0xF7FFFFFF),
    velo: Color(0x590B1426),
    burbuja: Color(0xF5FFFFFF),
    vidrioOscuro: Color(0xB8FFFFFF),
    vidrioOscuroEncima: Color(0xD9FFFFFF),
    texto: Color(0xFF0B1426),
    textoCuerpo: Color(0xDE0B1426),
    textoMedio: Color(0xB80B1426),
    textoSuave: Color(0xA30B1426),
    textoTenue: Color(0x8A0B1426),
    textoApagado: Color(0x6B0B1426),
    vidrioSuave: Color(0x99FFFFFF),
    campo: Color(0xEBFFFFFF),
    vidrio: Color(0xCCFFFFFF),
    vidrioFuerte: Color(0x140B1426),
    vidrioIntenso: Color(0x240B1426),
    borde: Color(0x1C0B1426),
    bordeFuerte: Color(0x360B1426),
    sombra: Color(0x220B1426),
    acento: Color(0xFF2F6BFF),
    acentoClaro: Color(0xFF1D4ED8),
    acentoVidrio: Color(0x242F6BFF),
    acentoBorde: Color(0x592F6BFF),
    dorado: Color(0xFFB07D0A),
    doradoVidrio: Color(0x33F5B301),
    doradoBorde: Color(0x80D99A06),
    avatar: Color(0xFFB81D4E),
    verde: Color(0xFF15803D),
    verdeVidrio: Color(0x1F22C55E),
    verdeBorde: Color(0x6615803D),
    ambar: Color(0xFFB45309),
    ambarVidrio: Color(0x24F59E0B),
    ambarBorde: Color(0x66B45309),
    rojo: Color(0xFFDC2626),
    rojoVidrio: Color(0x1FEF4444),
    rojoBorde: Color(0x66DC2626),
    azulVidrio: Color(0x1F3B82F6),
  );
}

/// Fichas del lenguaje visual "Liquid Glass" de Contrata Legal, en modo
/// oscuro (fondo mate, vidrio translúcido) o claro (ver [PaletaCristal]).
///
/// Todo color de la interfaz sale de aquí. La jerarquía del texto se hace
/// con opacidad, no con grises sólidos. Los colores dependen del modo
/// activo ([modo]): no se guardan en constantes ni en variables que se
/// calculen una sola vez.
abstract final class Cristal {
  // ---------------------------------------------------------------------
  // Modo
  // ---------------------------------------------------------------------

  static final ValueNotifier<ModoCristal> modo = ValueNotifier(
    ModoCristal.oscuro,
  );

  static bool get esClaro => modo.value == ModoCristal.claro;

  static PaletaCristal get paleta =>
      esClaro ? PaletaCristal.clara : PaletaCristal.oscura;

  static const String _claveModo = 'tema_modo_cristal';

  /// Lee el modo que eligió la persona (al abrir la app).
  static Future<void> cargarModo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      modo.value = prefs.getString(_claveModo) == 'claro'
          ? ModoCristal.claro
          : ModoCristal.oscuro;
    } catch (_) {}
  }

  /// Cambia el modo y lo recuerda en este navegador.
  static Future<void> cambiarModo(ModoCristal nuevo) async {
    modo.value = nuevo;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _claveModo,
        nuevo == ModoCristal.claro ? 'claro' : 'oscuro',
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------
  // Fondo
  // ---------------------------------------------------------------------

  /// Fondo mate de toda la aplicación.
  static Color get fondo => paleta.fondo;

  /// Tinta oscura para escribir sobre rellenos claros (dorado, ámbar).
  static Color get tinta => paleta.tinta;

  /// Blanco puro: texto sobre rellenos de color (el botón azul principal).
  static const Color blanco = Color(0xFFFFFFFF);

  /// Logo de Contrata Legal para el fondo del modo activo.
  static String get logo => esClaro
      ? 'assets/images/logo.png'
      : 'assets/images/logo_fondo_oscuro.png';

  /// Superficie de lo que flota sobre el contenido (diálogos, menús,
  /// avisos): casi opaca para que el texto se lea sobre cualquier cosa.
  static Color get flotante => paleta.flotante;

  /// Velo que oscurece la pantalla detrás de un diálogo.
  static Color get velo => paleta.velo;

  /// Etiqueta emergente pequeña (burbuja del menú contraído, ayudas).
  static Color get burbuja => paleta.burbuja;

  /// Vidrio para paneles que van sobre una foto: junto con el desenfoque
  /// mantiene el texto legible (oscuro en el modo oscuro, blanco lechoso en
  /// el claro).
  static Color get vidrioOscuro => paleta.vidrioOscuro;

  /// El mismo, bajo el cursor.
  static Color get vidrioOscuroEncima => paleta.vidrioOscuroEncima;

  // ---------------------------------------------------------------------
  // Texto por opacidad
  // ---------------------------------------------------------------------

  /// Títulos, cifras y valores (100 %).
  static Color get texto => paleta.texto;

  /// Texto de lectura (87 %).
  static Color get textoCuerpo => paleta.textoCuerpo;

  /// Texto de apoyo (70 %).
  static Color get textoMedio => paleta.textoMedio;

  /// Subtítulos y metadatos (60 %).
  static Color get textoSuave => paleta.textoSuave;

  /// Detalles pequeños e íconos en reposo (50 %).
  static Color get textoTenue => paleta.textoTenue;

  /// Deshabilitado y marcadores de posición (40 %).
  static Color get textoApagado => paleta.textoApagado;

  // ---------------------------------------------------------------------
  // Vidrio
  // ---------------------------------------------------------------------

  /// Relleno interior, el más tenue.
  static Color get vidrioSuave => paleta.vidrioSuave;

  /// Relleno de los campos de texto.
  static Color get campo => paleta.campo;

  /// Relleno de una tarjeta o panel.
  static Color get vidrio => paleta.vidrio;

  /// Tarjeta bajo el cursor, pistas y rellenos destacados.
  static Color get vidrioFuerte => paleta.vidrioFuerte;

  /// Elemento seleccionado o presionado.
  static Color get vidrioIntenso => paleta.vidrioIntenso;

  /// Borde de 1 px que delinea el vidrio.
  static Color get borde => paleta.borde;

  /// Borde de campos y de vidrio bajo el cursor.
  static Color get bordeFuerte => paleta.bordeFuerte;

  /// Sombra de lo que flota. Las tarjetas de vidrio no llevan sombra.
  static Color get sombra => paleta.sombra;

  // ---------------------------------------------------------------------
  // Marca
  // ---------------------------------------------------------------------

  /// Azul de la marca, saturado: relleno de la acción principal.
  static Color get acento => paleta.acento;

  /// Azul para texto, enlaces, íconos y trazos de foco.
  static Color get acentoClaro => paleta.acentoClaro;

  /// Vidrio teñido de azul: bandas y bloques que antes eran azul marino.
  static Color get acentoVidrio => paleta.acentoVidrio;

  static Color get acentoBorde => paleta.acentoBorde;

  /// Dorado de la marca: dónde estás (navegación, pestaña activa) y lo
  /// destacado.
  static Color get dorado => paleta.dorado;

  /// Dorado brillante de la marca para rellenos (botones, insignias) con
  /// tinta oscura encima: el mismo en los dos modos.
  static const Color doradoRelleno = Color(0xFFFFC53D);

  static Color get doradoVidrio => paleta.doradoVidrio;

  static Color get doradoBorde => paleta.doradoBorde;

  /// Fondo del avatar cuando la persona no tiene foto.
  static Color get avatar => paleta.avatar;

  // ---------------------------------------------------------------------
  // Estados (siempre con su palabra o ícono)
  // ---------------------------------------------------------------------

  static Color get verde => paleta.verde;
  static Color get verdeVidrio => paleta.verdeVidrio;
  static Color get verdeBorde => paleta.verdeBorde;

  static Color get ambar => paleta.ambar;
  static Color get ambarVidrio => paleta.ambarVidrio;
  static Color get ambarBorde => paleta.ambarBorde;

  static Color get rojo => paleta.rojo;
  static Color get rojoVidrio => paleta.rojoVidrio;
  static Color get rojoBorde => paleta.rojoBorde;

  static Color get azulVidrio => paleta.azulVidrio;

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

  /// Variante de un color (de marca, de un rol, de una categoría) para
  /// usarlo como acento sobre el fondo del modo, sin cambiarle el tono: más
  /// luminosa y saturada sobre el oscuro, más profunda sobre el claro.
  static Color brillante(Color color) {
    final hsl = HSLColor.fromColor(color);
    if (hsl.saturation < 0.08) return color;
    final saturado = hsl.withSaturation(
      hsl.saturation < 0.72 ? 0.72 : hsl.saturation,
    );
    if (esClaro) {
      return saturado
          .withLightness(hsl.lightness > 0.40 ? 0.40 : hsl.lightness)
          .toColor();
    }
    return saturado
        .withLightness(hsl.lightness < 0.66 ? 0.66 : hsl.lightness)
        .toColor();
  }

  /// Un color de acento escrito a mano (de una modalidad, un estado o una
  /// categoría) que se lea sobre el fondo del modo: igual en el oscuro; en
  /// el claro, el mismo tono más profundo.
  static Color legible(Color color) {
    if (!esClaro) return color;
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness <= 0.42 || hsl.saturation < 0.08) return color;
    return hsl.withLightness(0.38).toColor();
  }

  /// Color del texto o del ícono que va encima de un relleno sólido
  /// [fondo]: tinta oscura si el relleno es claro o brillante (dorado,
  /// celeste, verde), blanco si es oscuro.
  static Color sobre(Color fondo) =>
      fondo.computeLuminance() > 0.3 ? tinta : blanco;

  /// Decoración de vidrio para un `Container`: relleno translúcido, borde
  /// de 1 px y esquinas amplias.
  static BoxDecoration vidrioDeco({
    double radio = radioTarjeta,
    Color? color,
    Color? colorBorde,
    double anchoBorde = 1,
  }) => BoxDecoration(
    color: color ?? vidrio,
    borderRadius: BorderRadius.circular(radio),
    border: Border.all(color: colorBorde ?? borde, width: anchoBorde),
  );
}
