import 'dart:io';

import 'package:app_secop/tema/cristal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Carga Inter y los íconos de Material para que las capturas se lean.
/// Debe llamarse en setUpAll (fuera del reloj falso de testWidgets).
Future<void> cargarFuentes() async {
  ByteData bytes(String ruta) =>
      ByteData.view(File(ruta).readAsBytesSync().buffer);
  final inter = FontLoader('Inter');
  for (final p in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    inter.addFont(Future.value(bytes('assets/fonts/inter/Inter-$p.ttf')));
  }
  await inter.load();
  // El ejecutable es .../bin/cache/artifacts/engine/linux-x64/flutter_tester.
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.path != dir.parent.path &&
      !Directory('${dir.path}/material_fonts').existsSync()) {
    dir = dir.parent;
  }
  final iconos = File('${dir.path}/material_fonts/MaterialIcons-Regular.otf');
  if (iconos.existsSync()) {
    final f = FontLoader('MaterialIcons')
      ..addFont(Future.value(bytes(iconos.path)));
    await f.load();
  }
  // El texto sin familia propia (p. ej. el de los desplegables) sale en la
  // web con Roboto; en las pruebas saldría como bloques. Se carga Roboto
  // con los nombres que el motor busca por defecto en Linux.
  for (final familia in ['Roboto', 'Ubuntu', 'Cantarell', 'DejaVu Sans', 'Liberation Sans', 'Arial', 'sans-serif']) {
    final f = FontLoader(familia);
    var alguna = false;
    for (final peso in ['Regular', 'Medium', 'Bold', 'Black']) {
      final archivo = File('${dir.path}/material_fonts/Roboto-$peso.ttf');
      if (archivo.existsSync()) {
        f.addFont(Future.value(bytes(archivo.path)));
        alguna = true;
      }
    }
    if (alguna) await f.load();
  }
}

/// La app tal como se arma en main.dart: tema Cristal y fondo de manchas.
Widget appCristal(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: temaCristal(),
  builder: (context, child) => FondoCristal(child: child!),
  home: home,
);

/// Fija el tamaño de la ventana de la captura.
void ventana(WidgetTester tester, double ancho, double alto) {
  tester.view.physicalSize = Size(ancho, alto);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Decodifica las imágenes ya montadas (en las pruebas no se cargan solas).
Future<void> cargarImagenes(WidgetTester tester) async {
  final elementos = find.byType(Image).evaluate().toList();
  final fotos = find.byType(FotoAmbiente).evaluate().toList();
  await tester.runAsync(() async {
    for (final e in elementos) {
      final w = e.widget as Image;
      try {
        await precacheImage(w.image, e).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
    for (final e in fotos) {
      final w = e.widget as FotoAmbiente;
      try {
        await precacheImage(w.proveedor, e).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
  });
  await tester.pump();
}

/// Deja correr tiempo real (consultas a Datos Abiertos) y luego repinta.
Future<void> esperarRed(WidgetTester tester, int segundos) async {
  for (var i = 0; i < segundos * 2; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Toma la captura. Las excepciones que no son del diseño (servicios que
/// no existen en las pruebas) se anotan y no la impiden.
Future<void> capturar(WidgetTester tester, String nombre) async {
  await cargarImagenes(tester);
  await tester.pump(const Duration(milliseconds: 500));
  for (Object? e = tester.takeException(); e != null; e = tester.takeException()) {
    final linea = e.toString().split('\n').first;
    // ignore: avoid_print
    print('[$nombre] ${linea.length > 160 ? linea.substring(0, 160) : linea}');
  }
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('capturas/$nombre.png'),
  );
}
