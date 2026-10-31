import 'package:app_secop/widgets/copiloto_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _render(WidgetTester tester, String data) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CopilotoMarkdown(data, style: const TextStyle(fontSize: 13)),
        ),
      ),
    );

/// Texto plano de todos los RichText renderizados.
List<String> _textos(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText())
    .toList();

void main() {
  testWidgets('quita los marcadores y pone en negrita los datos clave',
      (tester) async {
    await _render(tester, 'Valor total: **\$120.000.000 COP**.');
    expect(_textos(tester), contains('Valor total: \$120.000.000 COP.'));

    final rich = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere((r) => r.text.toPlainText().startsWith('Valor'));
    final negrita = <String>[];
    rich.text.visitChildren((span) {
      if (span is TextSpan &&
          span.style?.fontWeight == FontWeight.w800 &&
          span.text != null) {
        negrita.add(span.text!);
      }
      return true;
    });
    expect(negrita, ['\$120.000.000 COP']);
  });

  testWidgets('renderiza viñetas, listas numeradas y títulos sin marcadores',
      (tester) async {
    await _render(
      tester,
      '### Riesgos\n'
      '- Plazo **vencido**\n'
      '* Sin informes\n'
      '  - Subpunto\n'
      '1. Revisar pólizas\n'
      '2) Verificar pagos',
    );
    final textos = _textos(tester);
    expect(textos, containsAll(<String>[
      'Riesgos',
      '•',
      'Plazo vencido',
      'Sin informes',
      '◦',
      'Subpunto',
      '1.',
      'Revisar pólizas',
      '2.',
      'Verificar pagos',
    ]));
    expect(textos.any((t) => t.contains('**') || t.contains('###')), isFalse);
  });

  testWidgets('no confunde multiplicaciones ni asteriscos sueltos con cursiva',
      (tester) async {
    await _render(tester, 'Cálculo: 2 * 3 * 4 meses');
    expect(_textos(tester), contains('Cálculo: 2 * 3 * 4 meses'));
  });
}
