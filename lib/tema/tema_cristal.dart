import 'package:flutter/material.dart';

import 'cristal.dart';

/// Superficie opaca equivalente al vidrio flotante, para los componentes
/// de Material que no admiten transparencia (menús desplegables,
/// selector de fecha).
Color get _superficie =>
    Cristal.esClaro ? const Color(0xFFFFFFFF) : const Color(0xFF0E1A2E);
Color get _superficieAlta =>
    Cristal.esClaro ? const Color(0xFFF3F6FB) : const Color(0xFF14233B);

/// Blanco sobre el oscuro, azul marino sobre el claro, con [alfa] (0-255):
/// los velos de botones y la barra de desplazamiento.
Color _tinte(int alfa) => Cristal.esClaro
    ? Color.fromARGB(alfa, 0x0B, 0x14, 0x26)
    : Color.fromARGB(alfa, 0xFF, 0xFF, 0xFF);

/// El cursor no pinta una capa. Se conserva la indicación de foco y pulsación.
final WidgetStateProperty<Color?> _capaBoton = WidgetStateProperty.resolveWith((
  estados,
) {
  if (estados.contains(WidgetState.disabled)) return Colors.transparent;
  if (estados.contains(WidgetState.pressed)) return _tinte(0x29);
  if (estados.contains(WidgetState.focused)) return _tinte(0x24);
  return Colors.transparent;
});

OutlineInputBorder _bordeCampo(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(Cristal.radioCampo),
  borderSide: BorderSide(color: color),
);

/// Tema de la aplicación en el modo activo (oscuro o claro), de vidrio,
/// con Inter.
ThemeData temaCristal() {
  final esquema = (Cristal.esClaro ? ColorScheme.light : ColorScheme.dark)(
    primary: Cristal.acento,
    onPrimary: Colors.white,
    primaryContainer: Cristal.acentoVidrio,
    onPrimaryContainer: Cristal.texto,
    secondary: Cristal.dorado,
    onSecondary: Cristal.tinta,
    secondaryContainer: Cristal.doradoVidrio,
    onSecondaryContainer: Cristal.dorado,
    tertiary: Cristal.acentoClaro,
    onTertiary: Cristal.tinta,
    error: Cristal.rojo,
    onError: Cristal.tinta,
    errorContainer: Cristal.rojoVidrio,
    onErrorContainer: Cristal.rojo,
    surface: _superficie,
    onSurface: Cristal.texto,
    onSurfaceVariant: Cristal.textoSuave,
    surfaceContainerLowest: Cristal.fondo,
    surfaceContainerLow: Cristal.vidrioSuave,
    surfaceContainer: Cristal.vidrio,
    surfaceContainerHigh: Cristal.vidrioFuerte,
    surfaceContainerHighest: Cristal.vidrioIntenso,
    surfaceTint: Colors.transparent,
    outline: Cristal.bordeFuerte,
    outlineVariant: Cristal.borde,
    shadow: Colors.black,
    scrim: Cristal.velo,
    inverseSurface: Cristal.esClaro
        ? const Color(0xFF0E1A2E)
        : const Color(0xFFF1F5F9),
    onInverseSurface: Cristal.esClaro ? Cristal.blanco : Cristal.tinta,
    inversePrimary: Color(0xFF1D4ED8),
  );

  final titulo = TextStyle(
    color: Cristal.texto,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );
  final tipografia = Typography.material2021(platform: TargetPlatform.android);
  final textos = (Cristal.esClaro ? tipografia.black : tipografia.white)
      .apply(
        fontFamily: 'Inter',
        bodyColor: Cristal.textoCuerpo,
        displayColor: Cristal.texto,
      )
      .copyWith(
        displayLarge: titulo,
        displayMedium: titulo,
        displaySmall: titulo,
        headlineLarge: titulo,
        headlineMedium: titulo,
        headlineSmall: titulo,
        titleLarge: TextStyle(
          color: Cristal.texto,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(color: Cristal.texto),
        titleSmall: TextStyle(color: Cristal.texto),
        bodySmall: TextStyle(color: Cristal.textoSuave),
        labelSmall: TextStyle(color: Cristal.textoSuave),
      );

  final formaVidrio = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Cristal.radioTarjeta),
    side: BorderSide(color: Cristal.borde),
  );
  final formaFlotante = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Cristal.radioCampo),
    side: BorderSide(color: Cristal.borde),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Cristal.esClaro ? Brightness.light : Brightness.dark,
    fontFamily: 'Inter',
    colorScheme: esquema,
    textTheme: textos,
    primaryColor: Cristal.acento,
    // El fondo lo pinta FondoCristal una sola vez, detrás de las rutas.
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: _superficie,
    cardColor: Cristal.vidrio,
    dividerColor: Cristal.borde,
    disabledColor: Cristal.textoApagado,
    hintColor: Cristal.textoTenue,
    hoverColor: Colors.transparent,
    highlightColor: Cristal.vidrioSuave,
    splashColor: Cristal.vidrioFuerte,
    focusColor: Cristal.vidrioIntenso,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: TransicionLiquida(),
        TargetPlatform.iOS: TransicionLiquida(),
        TargetPlatform.linux: TransicionLiquida(),
        TargetPlatform.macOS: TransicionLiquida(),
        TargetPlatform.windows: TransicionLiquida(),
        TargetPlatform.fuchsia: TransicionLiquida(),
      },
    ),
    iconTheme: IconThemeData(color: Cristal.textoCuerpo),
    primaryIconTheme: IconThemeData(color: Cristal.texto),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Cristal.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: Cristal.texto),
    ),
    cardTheme: CardThemeData(
      color: Cristal.vidrio,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      shape: formaVidrio,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Cristal.flotante,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      barrierColor: Cristal.velo,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Cristal.radioPanel),
        side: BorderSide(color: Cristal.bordeFuerte),
      ),
      // La métrica de bodyMedium, con el texto a plena lectura.
      contentTextStyle: TextStyle(
        fontFamily: 'Inter',
        color: Cristal.textoCuerpo,
        fontSize: 14,
        height: 1.43,
        letterSpacing: 0.25,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Cristal.flotante,
      modalBackgroundColor: Cristal.flotante,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Cristal.velo,
      elevation: 0,
      modalElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Cristal.radioPanel),
        ),
        side: BorderSide(color: Cristal.bordeFuerte),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: _superficieAlta,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black,
      elevation: 12,
      shape: formaFlotante,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(_superficieAlta),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: const WidgetStatePropertyAll(Colors.black),
        elevation: const WidgetStatePropertyAll(12),
        shape: WidgetStatePropertyAll(formaFlotante),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: _superficieAlta,
      elevation: 0,
      contentTextStyle: TextStyle(
        fontFamily: 'Inter',
        color: Cristal.texto,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: Cristal.dorado,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Cristal.radioCampo),
        side: BorderSide(color: Cristal.bordeFuerte),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        color: Cristal.burbuja,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Cristal.bordeFuerte),
      ),
      textStyle: TextStyle(
        fontFamily: 'Inter',
        color: Cristal.texto,
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    dividerTheme: DividerThemeData(color: Cristal.borde, thickness: 1),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: Cristal.campo,
      hoverColor: Cristal.vidrioSuave,
      // Solo la forma por defecto: el color de cada estado sale del
      // esquema (outline, primary, error), también en los campos que
      // traen su propio `border`.
      border: _bordeCampo(Cristal.bordeFuerte),
      labelStyle: TextStyle(color: Cristal.textoSuave),
      floatingLabelStyle: TextStyle(color: Cristal.acentoClaro),
      hintStyle: TextStyle(color: Cristal.textoTenue),
      helperStyle: TextStyle(color: Cristal.textoTenue),
      errorStyle: TextStyle(color: Cristal.rojo),
      prefixIconColor: Cristal.textoSuave,
      suffixIconColor: Cristal.textoSuave,
      helperMaxLines: 3,
      errorMaxLines: 3,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Cristal.acentoClaro,
      selectionColor: Color(0x662F6BFF),
      selectionHandleColor: Cristal.acentoClaro,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.disabled)
              ? Cristal.vidrioFuerte
              : Cristal.acento,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.disabled)
              ? Cristal.textoApagado
              : Colors.white,
        ),
        overlayColor: _capaBoton,
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        animationDuration: Cristal.micro,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.disabled)
              ? Cristal.vidrioSuave
              : Cristal.vidrioFuerte,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.disabled)
              ? Cristal.textoApagado
              : Cristal.texto,
        ),
        overlayColor: _capaBoton,
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        animationDuration: Cristal.micro,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(Cristal.vidrioSuave),
        foregroundColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.disabled)
              ? Cristal.textoApagado
              : Cristal.texto,
        ),
        side: WidgetStateProperty.resolveWith(
          (e) => BorderSide(
            color: e.contains(WidgetState.disabled)
                ? Cristal.borde
                : Cristal.bordeFuerte,
          ),
        ),
        overlayColor: _capaBoton,
        animationDuration: Cristal.micro,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.disabled)
              ? Cristal.textoApagado
              : Cristal.acentoClaro,
        ),
        overlayColor: _capaBoton,
        animationDuration: Cristal.micro,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.disabled)
              ? Cristal.textoApagado
              : Cristal.textoCuerpo,
        ),
        overlayColor: _capaBoton,
        animationDuration: Cristal.micro,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.selected)
              ? Cristal.acentoVidrio
              : Cristal.vidrioSuave,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.selected)
              ? Cristal.texto
              : Cristal.textoSuave,
        ),
        overlayColor: _capaBoton,
        side: WidgetStatePropertyAll(BorderSide(color: Cristal.bordeFuerte)),
        animationDuration: Cristal.micro,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Cristal.vidrio,
      selectedColor: Cristal.acentoVidrio,
      disabledColor: Cristal.vidrioSuave,
      surfaceTintColor: Colors.transparent,
      checkmarkColor: Cristal.acentoClaro,
      deleteIconColor: Cristal.textoSuave,
      side: BorderSide(color: Cristal.borde),
      // La métrica de labelLarge; solo cambia el color según el estado.
      labelStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.43,
        letterSpacing: 0.1,
        color: WidgetStateColor.resolveWith(
          (e) => e.contains(WidgetState.disabled)
              ? Cristal.textoApagado
              : e.contains(WidgetState.selected)
              ? Cristal.texto
              : Cristal.textoCuerpo,
        ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Cristal.radioFicha),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (e) => e.contains(WidgetState.selected)
            ? Cristal.acento
            : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      side: BorderSide(color: Cristal.textoTenue, width: 1.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (e) => e.contains(WidgetState.selected)
            ? Colors.white
            : Cristal.textoSuave,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (e) => e.contains(WidgetState.selected)
            ? Cristal.acento
            : Cristal.vidrioFuerte,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (e) => e.contains(WidgetState.selected)
            ? Colors.transparent
            : Cristal.bordeFuerte,
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (e) => e.contains(WidgetState.selected)
            ? Cristal.acentoClaro
            : Cristal.textoTenue,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: Cristal.acentoClaro,
      linearTrackColor: Cristal.vidrioFuerte,
      circularTrackColor: Colors.transparent,
    ),
    tabBarTheme: TabBarThemeData(
      overlayColor: _capaBoton,
      labelColor: Cristal.texto,
      unselectedLabelColor: Cristal.textoTenue,
      indicatorColor: Cristal.dorado,
      dividerColor: Cristal.borde,
    ),
    listTileTheme: ListTileThemeData(
      textColor: Cristal.textoCuerpo,
      iconColor: Cristal.textoSuave,
      selectedColor: Cristal.texto,
      selectedTileColor: Cristal.vidrioFuerte,
    ),
    expansionTileTheme: ExpansionTileThemeData(
      iconColor: Cristal.textoCuerpo,
      collapsedIconColor: Cristal.textoSuave,
      textColor: Cristal.texto,
      collapsedTextColor: Cristal.textoCuerpo,
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      shape: Border(),
      collapsedShape: Border(),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.transparent,
      elevation: 0,
      selectedItemColor: Cristal.dorado,
      unselectedItemColor: Cristal.textoTenue,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(8),
      radius: const Radius.circular(8),
      thumbColor: WidgetStateProperty.resolveWith(
        (e) =>
            e.contains(WidgetState.hovered) || e.contains(WidgetState.dragged)
            ? _tinte(0x66)
            : _tinte(0x33),
      ),
      trackColor: const WidgetStatePropertyAll(Colors.transparent),
      trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: _superficie,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: _superficieAlta,
      headerForegroundColor: Cristal.texto,
      dividerColor: Cristal.borde,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Cristal.radioPanel),
        side: BorderSide(color: Cristal.bordeFuerte),
      ),
    ),
    badgeTheme: const BadgeThemeData(
      backgroundColor: Color(0xFFEF4444),
      textColor: Colors.white,
    ),
  );
}
