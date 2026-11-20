/// Banderas de control: señales para revisar en los datos abiertos de SECOP
/// II. No son pruebas de irregularidad; dicen qué mirar y con qué norma.
library;

/// Periodo de la Ley de Garantías (Ley 996 de 2005, art. 33): durante los
/// cuatro meses anteriores a la elección presidencial y hasta la segunda
/// vuelta, ninguna entidad puede contratar directamente, salvo defensa y
/// seguridad, crédito público, emergencias, reconstrucción por desastres o
/// atentados, y las entidades sanitarias y hospitalarias.
class PeriodoGarantias {
  const PeriodoGarantias({
    required this.desde,
    required this.hasta,
    required this.eleccion,
  });

  final DateTime desde;
  final DateTime hasta;
  final String eleccion;

  bool contiene(DateTime fecha) {
    final d = DateTime(fecha.year, fecha.month, fecha.day);
    return !d.isBefore(desde) && !d.isAfter(hasta);
  }
}

class BanderasControl {
  BanderasControl._();

  /// Elecciones presidenciales cubiertas por SECOP II (desde 2015): cuatro
  /// meses antes de la primera vuelta y hasta la segunda vuelta.
  static final List<PeriodoGarantias> leyDeGarantias = [
    PeriodoGarantias(
      desde: DateTime(2018, 1, 27),
      hasta: DateTime(2018, 6, 17),
      eleccion: 'presidenciales de 2018',
    ),
    PeriodoGarantias(
      desde: DateTime(2022, 1, 29),
      hasta: DateTime(2022, 6, 19),
      eleccion: 'presidenciales de 2022',
    ),
    PeriodoGarantias(
      desde: DateTime(2026, 1, 31),
      hasta: DateTime(2026, 6, 21),
      eleccion: 'presidenciales de 2026',
    ),
  ];

  static DateTime? fecha(Object? valor) {
    final t = '${valor ?? ''}'.trim();
    if (t.isEmpty) return null;
    return DateTime.tryParse(t.split('T').first);
  }

  static bool esContratacionDirecta(Map<dynamic, dynamic> c) =>
      '${c['modalidad_de_contratacion'] ?? ''}'.toLowerCase().contains(
        'directa',
      );

  /// Periodo de Ley de Garantías en que se firmó el contrato por
  /// contratación directa, o null si no aplica.
  static PeriodoGarantias? enLeyDeGarantias(Map<dynamic, dynamic> c) {
    if (!esContratacionDirecta(c)) return null;
    final firma = fecha(c['fecha_de_firma']);
    if (firma == null) return null;
    for (final p in leyDeGarantias) {
      if (p.contiene(firma)) return p;
    }
    return null;
  }

  static bool esPrestacionDeServicios(Map<dynamic, dynamic> c) =>
      '${c['tipo_de_contrato'] ?? ''}'.toLowerCase().contains(
        'prestación de servicios',
      ) ||
      '${c['tipo_de_contrato'] ?? ''}'.toLowerCase().contains(
        'prestacion de servicios',
      );

  /// Pares de contratos de prestación de servicios del mismo contratista
  /// cuyas fechas de ejecución se cruzan al menos [diasMinimos] días (un
  /// cruce de pocos días suele ser el empalme entre un contrato y el que
  /// lo reemplaza). Tener varios no es ilegal por sí mismo, pero sirve para
  /// revisar que el contratista pueda cumplirlos todos.
  static List<CruceContratos> cruces(
    List<Map<dynamic, dynamic>> contratos, {
    int diasMinimos = 15,
  }) {
    final ps = [
      for (final c in contratos)
        if (esPrestacionDeServicios(c) &&
            fecha(c['fecha_de_inicio_del_contrato']) != null &&
            fecha(c['fecha_de_fin_del_contrato']) != null)
          c,
    ];
    final res = <CruceContratos>[];
    for (var i = 0; i < ps.length; i++) {
      for (var j = i + 1; j < ps.length; j++) {
        final a = ps[i], b = ps[j];
        if (_mismo(a, b)) continue;
        final ai = fecha(a['fecha_de_inicio_del_contrato'])!;
        final af = fecha(a['fecha_de_fin_del_contrato'])!;
        final bi = fecha(b['fecha_de_inicio_del_contrato'])!;
        final bf = fecha(b['fecha_de_fin_del_contrato'])!;
        final desde = ai.isAfter(bi) ? ai : bi;
        final hasta = af.isBefore(bf) ? af : bf;
        final dias = hasta.difference(desde).inDays + 1;
        if (dias >= diasMinimos) {
          res.add(
            CruceContratos(a: a, b: b, desde: desde, hasta: hasta, dias: dias),
          );
        }
      }
    }
    res.sort((x, y) => y.dias.compareTo(x.dias));
    return res;
  }

  /// El mismo contrato repetido (SECOP I y II, o la misma fila dos veces).
  static bool _mismo(Map<dynamic, dynamic> a, Map<dynamic, dynamic> b) {
    final ia = '${a['id_contrato'] ?? a['referencia_del_contrato'] ?? ''}';
    final ib = '${b['id_contrato'] ?? b['referencia_del_contrato'] ?? ''}';
    return ia.isNotEmpty && ia == ib;
  }
}

class CruceContratos {
  const CruceContratos({
    required this.a,
    required this.b,
    required this.desde,
    required this.hasta,
    required this.dias,
  });

  final Map<dynamic, dynamic> a;
  final Map<dynamic, dynamic> b;
  final DateTime desde;
  final DateTime hasta;
  final int dias;
}

String fechaDiaMesAnio(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
