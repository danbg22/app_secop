import 'package:app_secop/utils/dias_habiles_colombia.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Pascua de años conocidos', () {
    expect(DiasHabilesColombia.pascua(2024), DateTime(2024, 3, 31));
    expect(DiasHabilesColombia.pascua(2025), DateTime(2025, 4, 20));
    expect(DiasHabilesColombia.pascua(2026), DateTime(2026, 4, 5));
  });

  test('festivos de Colombia 2025 (calendario oficial)', () {
    final f = DiasHabilesColombia.festivos(2025);
    // San Pedro y Sagrado Corazón coinciden el lunes 30 de junio: 17 fechas.
    expect(f, hasLength(17));
    expect(
      f,
      containsAll([
        DateTime(2025, 1, 1),
        DateTime(2025, 1, 6),
        DateTime(2025, 3, 24), // San José, trasladado
        DateTime(2025, 4, 17), // Jueves Santo
        DateTime(2025, 4, 18), // Viernes Santo
        DateTime(2025, 5, 1),
        DateTime(2025, 6, 2), // Ascensión
        DateTime(2025, 6, 23), // Corpus Christi
        DateTime(2025, 6, 30), // Sagrado Corazón y San Pedro (ambos lunes 30)
        DateTime(2025, 7, 20),
        DateTime(2025, 8, 7),
        DateTime(2025, 8, 18), // Asunción
        DateTime(2025, 10, 13), // Día de la Raza
        DateTime(2025, 11, 3), // Todos los Santos
        DateTime(2025, 11, 17), // Independencia de Cartagena
        DateTime(2025, 12, 8),
        DateTime(2025, 12, 25),
      ]),
    );
  });

  test('suma días hábiles saltando fines de semana y festivos', () {
    // Viernes 31 oct 2025 + 1 hábil = lunes 3 nov es festivo -> martes 4 nov.
    expect(DiasHabilesColombia.sumar(DateTime(2025, 10, 31), 1), DateTime(2025, 11, 4));
    // 10 días hábiles desde lunes 1 dic 2025 (festivo 8 dic).
    expect(DiasHabilesColombia.sumar(DateTime(2025, 12, 1), 10), DateTime(2025, 12, 16));
    expect(DiasHabilesColombia.sumar(DateTime(2025, 12, 16), -10), DateTime(2025, 12, 1));
  });

  test('cuenta días hábiles entre fechas', () {
    expect(DiasHabilesColombia.entre(DateTime(2025, 12, 1), DateTime(2025, 12, 16)), 10);
    expect(DiasHabilesColombia.entre(DateTime(2025, 12, 16), DateTime(2025, 12, 1)), -10);
    expect(DiasHabilesColombia.esHabil(DateTime(2025, 12, 8)), isFalse);
    expect(DiasHabilesColombia.esHabil(DateTime(2025, 12, 9)), isTrue);
  });
}
