import 'package:flutter/material.dart';

import 'cristal.dart';

/// Superficie opaca equivalente al vidrio flotante, para los componentes
/// de Material que no admiten transparencia (menús desplegables,
/// selector de fecha).
const Color _superficie = Color(0xFF0E1A2E);
const Color _superficieAlta = Color(0xFF14233B);

/// Velo que sube de opacidad bajo el cursor, en 0,3 s: la microinteracción
/// común de todos los botones.
Widget _veloBoton(
  BuildContext context,
  Set<WidgetState> estados,
  Widget? child,
) {
  final activo = !estados.contains(WidgetState.disabled);
  final Color velo;
  if (activo && estados.contains(WidgetState.pressed)) {
    velo = const Color(0x29FFFFFF);
  } else if (activo && estados.contains(WidgetState.hovered)) {
    velo = const Color(0x17FFFFFF);
  } else {
    velo = const Color(0x00FFFFFF);
  }
  return AnimatedContainer(
    duration: Cristal.micro,
    curve: Cristal.curvaMicro,
    color: velo,
    child: child,
  );
}

/// Bajo el cursor ya responde el velo; aquí solo el foco del teclado.
final WidgetStateProperty<Color?> _capaBoton = WidgetStateProperty.resolveWith(
  (estados) => estados.contains(WidgetState.focused)
      ? const Color(0x24FFFFFF)
      : Colors.transparent,
);

OutlineInputBorder _bordeCampo(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(Cristal.radioCampo),
  borderSide: BorderSide(color: color),
);

/// Tema de la aplicación: oscuro, de vidrio, con Inter.
ThemeData temaCristal() {
  const esquema = ColorScheme.dark(
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
    inverseSurface: Color(0xFFF1F5F9),
    onInverseSurface: Cristal.tinta,
    inversePrimary: Color(0xFF1D4ED8),
  );

  const titulo = TextStyle(
    color: Cristal.texto,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );
  final textos = Typography.material2021(platform: TargetPlatform.android).white
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
        titleLarge: const TextStyle(
          color: Cristal.texto,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: const TextStyle(color: Cristal.texto),
        titleSmall: const TextStyle(color: Cristal.texto),
        bodySmall: const TextStyle(color: Cristal.textoSuave),
        labelSmall: const TextStyle(color: Cristal.textoSuave),
      );

  final formaVidrio = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Cristal.radioTarjeta),
    side: const BorderSide(color: Cristal.borde),
  );
  final formaFlotante = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Cristal.radioCampo),
    side: const BorderSide(color: Cristal.borde),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
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
    hoverColor: Cristal.vidrio,
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
    iconTheme: const IconThemeData(color: Cristal.textoCuerpo),
    primaryIconTheme: const IconThemeData(color: Cristal.texto),
    appBarTheme: const AppBarTheme(
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
        side: const BorderSide(color: Cristal.bordeFuerte),
      ),
      // La métrica de bodyMedium, con el texto a plena lectura.
      contentTextStyle: const TextStyle(
        fontFamily: 'Inter',
        color: Cristal.textoCuerpo,
        fontSize: 14,
        height: 1.43,
        letterSpacing: 0.25,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
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
        backgroundColor: const WidgetStatePropertyAll(_superficieAlta),
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
      contentTextStyle: const TextStyle(
        fontFamily: 'Inter',
        color: Cristal.texto,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: Cristal.dorado,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Cristal.radioCampo),
        side: const BorderSide(color: Cristal.bordeFuerte),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        color: Cristal.burbuja,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Cristal.bordeFuerte),
      ),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        color: Cristal.texto,
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    dividerTheme: const DividerThemeData(color: Cristal.borde, thickness: 1),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: Cristal.campo,
      hoverColor: Cristal.vidrioSuave,
      // Solo la forma por defecto: el color de cada estado sale del
      // esquema (outline, primary, error), también en los campos que
      // traen su propio `border`.
      border: _bordeCampo(Cristal.bordeFuerte),
      labelStyle: const TextStyle(color: Cristal.textoSuave),
      floatingLabelStyle: const TextStyle(color: Cristal.acentoClaro),
      hintStyle: const TextStyle(color: Cristal.textoTenue),
      helperStyle: const TextStyle(color: Cristal.textoTenue),
      errorStyle: const TextStyle(color: Cristal.rojo),
      prefixIconColor: Cristal.textoSuave,
      suffixIconColor: Cristal.textoSuave,
      helperMaxLines: 3,
      errorMaxLines: 3,
    ),
    textSelectionTheme: const TextSelectionThemeData(
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
        backgroundBuilder: _veloBoton,
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
        backgroundBuilder: _veloBoton,
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        animationDuration: Cristal.micro,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(Cristal.vidrioSuave),
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
        backgroundBuilder: _veloBoton,
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
        backgroundBuilder: _veloBoton,
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
        backgroundBuilder: _veloBoton,
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
        side: const WidgetStatePropertyAll(
          BorderSide(color: Cristal.bordeFuerte),
        ),
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
      side: const BorderSide(color: Cristal.borde),
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
      side: const BorderSide(color: Cristal.textoTenue, width: 1.6),
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
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Cristal.acentoClaro,
      linearTrackColor: Cristal.vidrioFuerte,
      circularTrackColor: Colors.transparent,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Cristal.texto,
      unselectedLabelColor: Cristal.textoTenue,
      indicatorColor: Cristal.dorado,
      dividerColor: Cristal.borde,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: Cristal.textoCuerpo,
      iconColor: Cristal.textoSuave,
      selectedColor: Cristal.texto,
      selectedTileColor: Cristal.vidrioFuerte,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: Cristal.textoCuerpo,
      collapsedIconColor: Cristal.textoSuave,
      textColor: Cristal.texto,
      collapsedTextColor: Cristal.textoCuerpo,
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      shape: Border(),
      collapsedShape: Border(),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
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
            ? const Color(0x66FFFFFF)
            : const Color(0x33FFFFFF),
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
        side: const BorderSide(color: Cristal.bordeFuerte),
      ),
    ),
    badgeTheme: const BadgeThemeData(
      backgroundColor: Color(0xFFEF4444),
      textColor: Colors.white,
    ),
  );
}
