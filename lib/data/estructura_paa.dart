import '../services/paa_service.dart';
import '../utils/texto_profesional.dart';
import 'colombia_entities_database.dart';
import 'estructura_sena.dart';

/// Ordena las cuentas que publican PAA de una entidad como la entidad está
/// organizada: el nivel central (o la Dirección General) y sus regionales o
/// territoriales, con un nombre uniforme para cada una.
class NodoPaa {
  const NodoPaa({required this.nombre, required this.cuenta});

  /// Nombre uniforme ("Centro Biotecnológico del Caribe", "Nivel central").
  final String nombre;
  final CuentaPaa cuenta;
}

class GrupoPaa {
  const GrupoPaa({
    required this.titulo,
    required this.nodos,
    this.esCentral = false,
  });

  final String titulo;
  final List<NodoPaa> nodos;
  final bool esCentral;

  /// Valor previsto con los totales ya calculados (null mientras faltan).
  double? total(Map<String, ({int compras, double total})>? totales) {
    if (totales == null) return null;
    // Mientras falte alguna cuenta con compras, el total no está completo.
    if (nodos.any((n) => !totales.containsKey(n.cuenta.plan.encabezadoId))) {
      return null;
    }
    return nodos.fold<double>(
      0,
      (s, n) => s + (totales[n.cuenta.plan.encabezadoId]?.total ?? 0),
    );
  }
}

/// Entidades cuyas seccionales tienen NIT propio en SECOP II (las
/// direcciones territoriales de MinTrabajo, por ejemplo): se reúnen por el
/// nombre de sus cuentas.
class FamiliaPaa {
  const FamiliaPaa(this.id, this.nombre, this.patrones);

  final String id;
  final String nombre;

  /// Frases en mayúsculas y sin tildes que aparecen en el nombre de la cuenta.
  final List<String> patrones;
}

const List<FamiliaPaa> familiasPaa = [
  FamiliaPaa('mintrabajo', 'Ministerio del Trabajo', [
    'MINISTERIO DEL TRABAJO',
    'MINISTERIO DE TRABAJO',
    'MINTRABAJO',
  ]),
  FamiliaPaa('rama_judicial', 'Rama Judicial', [
    'RAMA JUDICIAL',
    'ADMINISTRACION JUDICIAL',
  ]),
  FamiliaPaa('inpec', 'Instituto Nacional Penitenciario y Carcelario - INPEC', [
    'INPEC',
    'ESTABLECIMIENTO PENITENCIARIO',
    'COMPLEJO PENITENCIARIO',
  ]),
  FamiliaPaa('policia', 'Policía Nacional', [
    'POLICIA NACIONAL',
    'DEPARTAMENTO DE POLICIA',
    'POLICIA METROPOLITANA',
  ]),
  FamiliaPaa('icbf', 'Instituto Colombiano de Bienestar Familiar - ICBF', [
    'ICBF',
    'BIENESTAR FAMILIAR',
  ]),
];

class EstructuraPaa {
  EstructuraPaa._();

  /// Familia a la que pertenece una cuenta por su nombre, si alguna.
  static FamiliaPaa? familiaDe(String nombreCuenta) {
    final n = ' ${EstructuraSena.normalizar(nombreCuenta)} ';
    for (final f in familiasPaa) {
      if (f.patrones.any((p) => n.contains(' $p '))) return f;
    }
    return null;
  }

  /// Nombre de la entidad cabeza por su NIT ("Servicio Nacional de
  /// Aprendizaje - SENA", "Ministerio del Trabajo").
  static String nombreEntidad(String nit, List<CuentaPaa> cuentas) {
    final limpio = nit.replaceAll(RegExp(r'[^0-9]'), '');
    final catalogo = [
      for (final e in ColombiaEntitiesDatabase.allEntities)
        if (e.nit.replaceAll(RegExp(r'[^0-9]'), '') == limpio) e,
    ]..sort((a, b) => a.name.length.compareTo(b.name.length));
    if (catalogo.isNotEmpty) return catalogo.first.name;
    if (cuentas.isEmpty) return 'Entidad $nit';
    // El nombre más corto suele ser el de la cabeza ("MINTRABAJO NIVEL CENTRAL").
    final nombres = cuentas.map((c) => c.plan.nombreEntidad).toList()
      ..sort((a, b) => a.length.compareTo(b.length));
    return nombreCuenta(nombres.first);
  }

  /// "MINTRABAJO NIVEL CENTRAL*/" → "Mintrabajo Nivel Central".
  static String nombreCuenta(String raw) => TextoProfesional.titulo(raw);

  static final RegExp _central = RegExp(
    r'\bNIVEL CENTRAL\b|\bSEDE CENTRAL\b|\bDIRECCION GENERAL\b|'
    r'\bSECRETARIA GENERAL\b|\bOFICINA CENTRAL\b|\bDESPACHO DEL MINISTRO\b|'
    r'\bDIRECCION EJECUTIVA\b',
  );

  /// Departamento nombrado en el texto (la clave más larga gana).
  static RegionalSena? _departamentoEn(String texto) {
    RegionalSena? mejor;
    var largo = 0;
    for (final r in regionalesSena) {
      for (final c in [
        ...r.claves,
        if (r.nombre == 'Distrito Capital') 'BOGOTA',
        if (r.nombre == 'Valle') 'VALLE DEL CAUCA',
      ]) {
        if (c.length > largo && ' $texto '.contains(' $c ')) {
          mejor = r;
          largo = c.length;
        }
      }
    }
    return mejor;
  }

  static String _nombreDepartamento(RegionalSena r) => switch (r.nombre) {
    'Distrito Capital' => 'Bogotá D.C.',
    'Valle' => 'Valle del Cauca',
    'San Andrés' => 'San Andrés y Providencia',
    _ => r.nombre,
  };

  static List<GrupoPaa> agrupar(
    String nit,
    List<CuentaPaa> cuentas, {
    FamiliaPaa? familia,
  }) => esNitSena(nit) ? _sena(cuentas) : _general(cuentas, familia);

  /// Quita del nombre de la cuenta el de la entidad, que ya está en el
  /// título: "Ministerio del Trabajo Dirección Territorial del Amazonas" →
  /// "Dirección Territorial del Amazonas".
  static String _sinEntidad(String nombre, FamiliaPaa? familia) {
    if (familia == null) return nombre;
    const vocales = {
      'A': '[AÁ]',
      'E': '[EÉ]',
      'I': '[IÍ]',
      'O': '[OÓ]',
      'U': '[UÚ]',
    };
    var t = nombre;
    for (final p in familia.patrones) {
      final patron = p
          .split('')
          .map((c) => vocales[c] ?? RegExp.escape(c))
          .join();
      t = t.replaceAll(RegExp(patron, caseSensitive: false), ' ');
    }
    t = t
        .replaceAll(RegExp(r'\(\s*\)'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s\-–,.]+|[\s\-–,.]+$'), '')
        .replaceAll(RegExp(r'^(de|del)\s+', caseSensitive: false), '')
        .trim();
    if (t.isEmpty) return nombre;
    return t[0].toUpperCase() + t.substring(1);
  }

  /// "SENA REGIONAL ANTIOQUIA Grupo Administrativo Complejo Itagüí" →
  /// "Grupo administrativo Complejo Itagüí".
  static String _grupoSena(String raw) {
    final m = RegExp(
      r'GRUPO (DE APOYO |MIXTO DE APOYO )?ADMINISTRATIVO( MIXTO)?(.*)$',
      caseSensitive: false,
    ).firstMatch(raw);
    final resto = (m?.group(3) ?? '')
        .replaceAll(RegExp(r'[*/+?]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return resto.isEmpty
        ? 'Grupo de Apoyo Administrativo Mixto'
        : 'Grupo Administrativo ${TextoProfesional.titulo(resto)}';
  }

  static List<GrupoPaa> _sena(List<CuentaPaa> cuentas) {
    final nacional = <NodoPaa>[];
    final porRegional = <RegionalSena, List<NodoPaa>>{};
    final otras = <NodoPaa>[];
    for (final c in cuentas) {
      final u = EstructuraSena.ubicar(
        cuenta: c.plan.nombreEntidad,
        unidad: '',
        departamento: c.plan.departamento,
      );
      switch (u.nivel) {
        case NivelSena.nacional:
          nacional.add(NodoPaa(nombre: u.nodo, cuenta: c));
        case NivelSena.otra:
          otras.add(
            NodoPaa(nombre: nombreCuenta(c.plan.nombreEntidad), cuenta: c),
          );
        case NivelSena.centro:
          porRegional
              .putIfAbsent(u.regional!, () => [])
              .add(NodoPaa(nombre: u.nodo, cuenta: c));
        default:
          porRegional
              .putIfAbsent(u.regional!, () => [])
              .add(
                NodoPaa(
                  nombre: 'Grupo de Apoyo Administrativo Mixto (despacho y centros)',
                  cuenta: c,
                ),
              );
      }
    }
    // Dos grupos administrativos en la misma regional: se distinguen por la
    // cuenta (Antioquia tiene el mixto, el de Itagüí y el de Medellín).
    for (final nodos in porRegional.values) {
      final genericos = nodos
          .where(
            (n) => n.nombre.startsWith('Grupo de Apoyo Administrativo Mixto'),
          )
          .toList();
      if (genericos.length > 1) {
        for (final n in genericos) {
          nodos[nodos.indexOf(n)] = NodoPaa(
            nombre: _grupoSena(n.cuenta.plan.nombreEntidad),
            cuenta: n.cuenta,
          );
        }
      }
    }
    return [
      if (nacional.isNotEmpty)
        GrupoPaa(titulo: 'Dirección General', nodos: nacional, esCentral: true),
      for (final r in regionalesSena)
        if (porRegional[r] case final nodos?)
          GrupoPaa(
            titulo: 'Regional ${r.nombre}',
            nodos: nodos..sort((a, b) => a.nombre.compareTo(b.nombre)),
          ),
      if (otras.isNotEmpty) GrupoPaa(titulo: 'Otras cuentas', nodos: otras),
    ];
  }

  static List<GrupoPaa> _general(List<CuentaPaa> cuentas, FamiliaPaa? familia) {
    final central = <NodoPaa>[];
    final porDepto = <RegionalSena, List<NodoPaa>>{};
    final otras = <NodoPaa>[];
    for (final c in cuentas) {
      final n = EstructuraSena.normalizar(c.plan.nombreEntidad);
      final nombre = _sinEntidad(nombreCuenta(c.plan.nombreEntidad), familia);
      if (cuentas.length == 1 || _central.hasMatch(n)) {
        central.add(NodoPaa(nombre: nombre, cuenta: c));
        continue;
      }
      final depto =
          _departamentoEn(n) ??
          _departamentoEn(EstructuraSena.normalizar(c.plan.departamento));
      if (depto == null) {
        otras.add(NodoPaa(nombre: nombre, cuenta: c));
      } else {
        porDepto
            .putIfAbsent(depto, () => [])
            .add(NodoPaa(nombre: nombre, cuenta: c));
      }
    }
    // Con una sola cuenta central basta con "Nivel central"; con varias
    // (Rama Judicial) cada una conserva su nombre.
    if (central.length == 1 && cuentas.length > 1) {
      central[0] = NodoPaa(nombre: 'Nivel central', cuenta: central[0].cuenta);
    }
    return [
      if (central.isNotEmpty)
        GrupoPaa(
          titulo: cuentas.length == 1 ? 'Plan de la entidad' : 'Nivel central',
          nodos: central,
          esCentral: true,
        ),
      for (final r in regionalesSena)
        if (porDepto[r] case final nodos?)
          GrupoPaa(titulo: _nombreDepartamento(r), nodos: nodos),
      if (otras.isNotEmpty) GrupoPaa(titulo: 'Otras cuentas', nodos: otras),
    ];
  }
}
