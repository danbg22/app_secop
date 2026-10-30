/// Vigencias consultables en Datos Abiertos SECOP (I y II), calculadas a
/// partir del año en curso para que no queden desactualizadas.
class AniosSecop {
  static const int primero = 2015;

  static int get actual => DateTime.now().year;

  /// Años desde el actual hasta [primero], en orden descendente.
  static List<int> get disponibles => [
        for (var anio = actual; anio >= primero; anio--) anio,
      ];
}
