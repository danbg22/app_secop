/// Dependencia de la entidad donde se ejecuta un contrato.
///
/// SECOP no publica la dependencia del contratista: el contrato solo trae la
/// entidad ("ALCALDIA MUNICIPAL DE VALLEDUPAR") y el proceso la "unidad de
/// contratación", que en muchas alcaldías es siempre la Secretaría General
/// (la que tramita todo). La dependencia real casi siempre está escrita en
/// el objeto: "…apoyo jurídico a la SECRETARÍA DE HACIENDA MUNICIPAL…".
class DependenciaContrato {
  DependenciaContrato._();

  static final RegExp _inicio = RegExp(
    r'\b(SUBSECRETAR[IÍ]A|SECRETAR[IÍ]A|OFICINA|DIRECCI[OÓ]N|DESPACHO|'
    r'DEPARTAMENTO ADMINISTRATIVO|GERENCIA|CENTRO)\b',
  );

  /// Donde termina el nombre de la dependencia.
  static final RegExp _corte = RegExp(
    r'[;:,.()"/]|\s-\s|'
    r'\s(DEL|DE LA|DE)\s(MUNICIPIO|DISTRITO|DEPARTAMENTO|ALCALD[IÍ]A|'
    r'GOBERNACI[OÓ]N|ENTIDAD|SENA|REGIONAL)\b|'
    // "en" corta solo antes de artículo: "Oficina de Asuntos en Salud" sí
    // es el nombre; "Secretaría de Gobierno en el desarrollo…" no.
    r'\sEN\s(EL|LA|LOS|LAS|LO|UN|UNA|TODO|TODAS?|TODOS)\b|'
    r'\s(PARA|DURANTE|VIGENCIA|ADSCRIT[AO]|CON|QUE|MEDIANTE|SEG[UÚ]N|'
    r'COMO|A TRAV[EÉ]S|Y/O|BAJO|SOBRE|CONFORME|SEDE)\b',
  );

  /// Palabras que indican que no es una dependencia ("bajo la dirección del
  /// supervisor", "centro de costos").
  static final RegExp _descartar = RegExp(
    r'SUPERVISOR|CONTRATISTA|CONTRATO|COSTOS|ACOPIO|T[EÉ]CNICA$|DE OBRA$',
  );

  static const _menores = {
    'DE',
    'DEL',
    'LA',
    'LAS',
    'LOS',
    'EL',
    'Y',
    'E',
    'EN',
    'A',
    'AL',
    'PARA',
  };

  /// Dependencia del [contrato] (fila de SECOP II o I), o null si el objeto
  /// no la nombra.
  static String? desde(Map<dynamic, dynamic> contrato) {
    final ciudad = '${contrato['ciudad'] ?? ''}';
    for (final campo in const [
      'objeto_del_contrato',
      'descripcion_del_proceso',
      'objeto_a_contratar',
      'detalle_del_objeto_a_contratar',
    ]) {
      final texto = contrato[campo];
      if (texto == null) continue;
      final d = deTexto('$texto', ciudad: ciudad);
      if (d != null) return d;
    }
    return null;
  }

  /// Dependencia nombrada en [texto]. Sin la [ciudad] al final ("Secretaría
  /// Local de Salud de Valledupar" → "Secretaría Local de Salud").
  static String? deTexto(String texto, {String ciudad = ''}) {
    final t = texto.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    for (final m in _inicio.allMatches(t)) {
      // "bajo la dirección de…" no es una dependencia.
      final antes = t.substring(0, m.start).trimRight();
      if (antes.endsWith('BAJO LA') || antes.endsWith('SU')) continue;
      var resto = t.substring(m.start);
      final corte = _corte.firstMatch(resto.substring(m.end - m.start));
      if (corte != null) {
        resto = resto.substring(0, m.end - m.start + corte.start);
      }
      var palabras = resto.trim().split(' ');
      if (palabras.length > 9) palabras = palabras.sublist(0, 9);
      final c = ciudad.trim().toUpperCase();
      if (c.isNotEmpty) {
        final sufijo = ' DE $c';
        final unido = palabras.join(' ');
        if (unido.endsWith(sufijo)) {
          palabras = unido
              .substring(0, unido.length - sufijo.length)
              .split(' ');
        }
      }
      while (palabras.length > 1 && _menores.contains(palabras.last)) {
        palabras.removeLast();
      }
      final nombre = palabras.join(' ');
      // Solo la palabra ("OFICINA", "DIRECCIÓN") no dice cuál dependencia.
      if (palabras.length < 2 || _descartar.hasMatch(nombre)) continue;
      return _titulo(nombre);
    }
    return null;
  }

  static String _titulo(String nombre) {
    final palabras = nombre.toLowerCase().split(' ');
    return [
      for (final (i, p) in palabras.indexed)
        i > 0 && _menores.contains(p.toUpperCase())
            ? p
            : p.isEmpty
            ? p
            : p[0].toUpperCase() + p.substring(1),
    ].join(' ');
  }
}
