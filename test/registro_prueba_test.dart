import 'package:app_secop/screens/escoger_rol_screen.dart';
import 'package:app_secop/screens/registro_screen.dart';
import 'package:app_secop/services/payment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el registro invita a probar y muestra el precio posterior', (
    tester,
  ) async {
    final persona = PaymentService.obtenerConfiguracionRol('persona');
    await tester.pumpWidget(
      const MaterialApp(home: RegistroScreen(rolSeleccionadoId: 'persona')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inicia tu prueba gratuita'), findsOneWidget);
    expect(find.text('30 días gratis'), findsOneWidget);
    expect(find.text('Crea una nueva contraseña'), findsOneWidget);
    expect(
      find.textContaining(persona.precioMensualFormateado),
      findsOneWidget,
    );
    expect(find.textContaining('Continuar al pago'), findsNothing);
  });

  testWidgets('la selección muestra la prueba y el precio por separado', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: EscogerRolScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Inicia tu prueba gratuita'), findsNWidgets(2));
    expect(find.text('30 días gratis'), findsNWidgets(2));
    expect(find.textContaining('Supervisor · 30 días gratis'), findsOneWidget);
  });
}
