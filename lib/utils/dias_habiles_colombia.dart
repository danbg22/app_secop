/// Días hábiles en Colombia (lunes a viernes, sin festivos), para calcular los
/// plazos de la contratación estatal que el Decreto 1082 de 2015 cuenta en
/// días hábiles.
///
/// Festivos de la Ley 51 de 1983 ("Ley Emiliani"): fijos, trasladables al
/// lunes siguiente y los que dependen de la Pascua.
class DiasHabilesColombia {
  DiasHabilesColombia._();

  static final Map<int, Set<DateTime>> _cache = {};

  static DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Domingo de Pascua (algoritmo anónimo gregoriano).
  static DateTime pascua(int anio) {
    final a = anio % 19;
    final b = anio ~/ 100;
    final c = anio % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final mes = (h + l - 7 * m + 114) ~/ 31;
    final dia = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(anio, mes, dia);
  }

  /// Traslada la fecha al lunes siguiente si no cae en lunes.
  static DateTime _alLunes(DateTime d) =>
      d.add(Duration(days: (DateTime.monday - d.weekday + 7) % 7));

  static Set<DateTime> festivos(int anio) => _cache.putIfAbsent(anio, () {
    final p = pascua(anio);
    return {
      // Fijos
      DateTime(anio, 1, 1),
      DateTime(anio, 5, 1),
      DateTime(anio, 7, 20),
      DateTime(anio, 8, 7),
      DateTime(anio, 12, 8),
      DateTime(anio, 12, 25),
      // Trasladables al lunes
      _alLunes(DateTime(anio, 1, 6)),
      _alLunes(DateTime(anio, 3, 19)),
      _alLunes(DateTime(anio, 6, 29)),
      _alLunes(DateTime(anio, 8, 15)),
      _alLunes(DateTime(anio, 10, 12)),
      _alLunes(DateTime(anio, 11, 1)),
      _alLunes(DateTime(anio, 11, 11)),
      // Según la Pascua
      p.subtract(const Duration(days: 3)), // Jueves Santo
      p.subtract(const Duration(days: 2)), // Viernes Santo
      p.add(const Duration(days: 43)), // Ascensión (lunes)
      p.add(const Duration(days: 64)), // Corpus Christi (lunes)
      p.add(const Duration(days: 71)), // Sagrado Corazón (lunes)
    };
  });

  static bool esHabil(DateTime fecha) {
    final d = _dia(fecha);
    if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
      return false;
    }
    return !festivos(d.year).contains(d);
  }

  /// Fecha que resulta de sumar [dias] hábiles a [desde] (sin contar el día
  /// de inicio). Con [dias] negativo cuenta hacia atrás.
  static DateTime sumar(DateTime desde, int dias) {
    var d = _dia(desde);
    final paso = dias >= 0 ? 1 : -1;
    var restantes = dias.abs();
    while (restantes > 0) {
      d = DateTime(d.year, d.month, d.day + paso);
      if (esHabil(d)) restantes--;
    }
    return d;
  }

  /// Días hábiles entre dos fechas: los que hay después de [desde] y hasta
  /// [hasta] inclusive. Negativo si [hasta] es anterior.
  static int entre(DateTime desde, DateTime hasta) {
    final a = _dia(desde);
    final b = _dia(hasta);
    if (a == b) return 0;
    final signo = b.isAfter(a) ? 1 : -1;
    var conteo = 0;
    var d = a;
    while (d != b) {
      d = DateTime(d.year, d.month, d.day + signo);
      if (esHabil(d)) conteo++;
    }
    return conteo * signo;
  }
}
