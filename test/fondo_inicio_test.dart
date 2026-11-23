import 'package:app_secop/screens/sections/fondo_inicio.dart';
import 'package:app_secop/tema/foto_ambiente.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('rota cada 15 minutos sin repetir y se pausa al salir', (
    tester,
  ) async {
    Widget inicio({bool activo = true}) => MaterialApp(
      home: SizedBox.expand(child: FondoInicio(activo: activo, movil: true)),
    );

    String fotoActual() => tester
        .widget<FotoAmbiente>(find.byType(FotoAmbiente))
        .imagen!
        .assetName;

    Future<void> cambiarFoto() async {
      await tester.pump(const Duration(minutes: 15));
      await tester.pump(const Duration(seconds: 2));
    }

    await tester.pumpWidget(inicio());
    final primera = fotoActual();
    await tester.pump(const Duration(minutes: 14, seconds: 59));
    expect(fotoActual(), primera);

    final fotos = {primera};
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));
    expect(fotos.add(fotoActual()), isTrue);
    for (var cambio = 0; cambio < 3; cambio++) {
      await cambiarFoto();
      expect(fotos.add(fotoActual()), isTrue);
    }

    final ultima = fotoActual();
    await cambiarFoto();
    expect(fotoActual(), isNot(ultima));

    final pausada = fotoActual();
    await tester.pumpWidget(inicio(activo: false));
    await cambiarFoto();
    expect(fotoActual(), pausada);
  });
}
