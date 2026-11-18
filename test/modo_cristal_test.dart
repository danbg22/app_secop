import 'package:app_secop/tema/cristal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un widget constante que lee el color en su build: es el caso que no se
/// reconstruiría solo al cambiar de modo.
class _Muestra extends StatelessWidget {
  const _Muestra();

  @override
  Widget build(BuildContext context) =>
      Text('Hola', style: TextStyle(color: Cristal.texto));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Cristal.modo.value = ModoCristal.oscuro;
  });
  tearDown(() => Cristal.modo.value = ModoCristal.oscuro);

  Color colorDe(WidgetTester t) =>
      t.widget<Text>(find.text('Hola')).style!.color!;

  testWidgets('al cambiar de modo se repinta todo, también lo constante', (
    t,
  ) async {
    await t.pumpWidget(
      ModoCristalScope(
        builder: (_) => MaterialApp(
          theme: temaCristal(),
          themeAnimationDuration: Duration.zero,
          home: const Scaffold(body: _Muestra()),
        ),
      ),
    );
    expect(colorDe(t), PaletaCristal.oscura.texto);
    expect(Theme.of(t.element(find.text('Hola'))).brightness, Brightness.dark);

    await Cristal.cambiarModo(ModoCristal.claro);
    await t.pump();
    expect(colorDe(t), PaletaCristal.clara.texto);
    expect(Theme.of(t.element(find.text('Hola'))).brightness, Brightness.light);

    await Cristal.cambiarModo(ModoCristal.oscuro);
    await t.pump();
    expect(colorDe(t), PaletaCristal.oscura.texto);
  });

  test('el modo elegido se recuerda en el navegador', () async {
    await Cristal.cambiarModo(ModoCristal.claro);
    Cristal.modo.value = ModoCristal.oscuro;
    await Cristal.cargarModo();
    expect(Cristal.modo.value, ModoCristal.claro);
  });

  test('legible: igual en oscuro, más profundo en claro', () {
    const turquesa = Color(0xFF2DD4BF);
    expect(Cristal.legible(turquesa), turquesa);
    Cristal.modo.value = ModoCristal.claro;
    final claro = Cristal.legible(turquesa);
    expect(claro.computeLuminance(), lessThan(turquesa.computeLuminance()));
    expect(
      HSLColor.fromColor(claro).hue,
      closeTo(HSLColor.fromColor(turquesa).hue, 1),
    );
  });

  test('el texto de cada modo contrasta con su fondo (al menos 7:1)', () {
    double contraste(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
    }

    for (final p in [PaletaCristal.oscura, PaletaCristal.clara]) {
      expect(contraste(p.texto, p.fondo), greaterThan(7));
    }
  });
}
