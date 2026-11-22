import '../utils/nit.dart';
import 'datos_abiertos.dart';

/// Estados por los que se puede filtrar un proceso de SECOP II.
enum FiltroEstadoProceso {
  todos('Todos'),
  abiertos('Abiertos'),
  borrador('Borrador o en aprobación'),
  evaluacion('En evaluación'),
  adjudicados('Adjudicados'),
  cancelados('Cancelados o suspendidos');

  const FiltroEstadoProceso(this.etiqueta);
  final String etiqueta;

  /// Condición de SoQL sobre p6dx-8zbt (null = sin filtro).
  String? get condicion => switch (this) {
    todos => null,
    abiertos => "estado_de_apertura_del_proceso='Abierto' AND adjudicado='No' AND estado_del_procedimiento not in ('Cancelado','Borrador','Suspendido')",
    borrador =>
      "estado_del_procedimiento in ('Borrador','En aprobación','Aprobado')",
    evaluacion => "estado_del_procedimiento='Evaluación'",
    adjudicados => "adjudicado='Si'",
    cancelados => "estado_del_procedimiento in ('Cancelado','Suspendido')",
  };
}

enum PeriodoProcesos {
  mes('Último mes', 31),
  trimestre('3 meses', 92),
  anio('1 año', 366),
  todo('Desde 2015', 0);

  const PeriodoProcesos(this.etiqueta, this.dias);
  final String etiqueta;
  final int dias;
}

/// Un proceso de contratación de SECOP II en su fase más reciente.
///
/// SECOP II publica una fila por fase (observaciones, manifestación de
/// interés, presentación de oferta…), todas con el mismo `id_del_portafolio`;
/// aquí se muestra la última.
class ProcesoSecop {
  const ProcesoSecop(this.fila, {this.fases = 1});

  final Map<String, dynamic> fila;

  /// Fases del proceso encontradas en Datos Abiertos.
  final int fases;

  String _t(String k) {
    final v = '${fila[k] ?? ''}'.trim();
    return v.toLowerCase() == 'no definido' ? '' : v;
  }

  String get portafolio => _t('id_del_portafolio');

  /// Referencia sin la fase pegada al final ("SAMC_005_2026 (Presentación
  /// de oferta)" → "SAMC_005_2026").
  String get referencia => _sinFase(_t('referencia_del_proceso'));
  String get nombre => _sinFase(_t('nombre_del_procedimiento'));
  String get descripcion => _t('descripci_n_del_procedimiento');
  String get entidad => _t('entidad');
  String get nitEntidad => _t('nit_entidad');
  String get departamento => _t('departamento_entidad');
  String get modalidad => _t('modalidad_de_contratacion');
  String get fase => _t('fase');
  String get estadoSecop => _t('estado_del_procedimiento');
  bool get abierto => _t('estado_de_apertura_del_proceso') == 'Abierto';
  bool get adjudicado => _t('adjudicado').toLowerCase() == 'si';
  String get proveedor => _t('nombre_del_proveedor');
  double get precioBase => double.tryParse(_t('precio_base')) ?? 0;
  double get valorAdjudicado =>
      double.tryParse(_t('valor_total_adjudicacion')) ?? 0;
  DateTime? get publicado => DateTime.tryParse(_t('fecha_de_publicacion_del'));
  DateTime? get cierreOfertas => DateTime.tryParse(_t('fecha_de_recepcion_de'));

  String get url {
    final u = fila['urlproceso'];
    if (u is Map) return '${u['url'] ?? ''}';
    return '${u ?? ''}';
  }

  /// Estado en palabras de quien no conoce SECOP II.
  String get estado {
    if (adjudicado) return 'Adjudicado';
    switch (estadoSecop) {
      case 'Borrador':
        return 'Borrador';
      case 'En aprobación':
        return 'En aprobación';
      case 'Aprobado':
        return 'Aprobado, sin publicar';
      case 'Cancelado':
        return 'Cancelado';
      case 'Suspendido':
        return 'Suspendido';
      case 'Seleccionado':
        return 'Seleccionado';
    }
    final f = fase.toLowerCase();
    // SECOP a veces deja "abierto" un proceso cuyo plazo ya pasó.
    final vencido =
        cierreOfertas != null && cierreOfertas!.isBefore(DateTime.now());
    if (abierto && vencido && !f.contains('observaci')) {
      return 'Plazo de ofertas vencido';
    }
    if (abierto) {
      if (f.contains('observaci')) return 'Recibe observaciones';
      if (f.contains('manifestaci')) return 'Recibe manifestaciones de interés';
      return 'Recibe ofertas';
    }
    if (estadoSecop == 'Evaluación') return 'En evaluación';
    return 'Ofertas cerradas, sin adjudicar';
  }

  /// Tipo de estado, para el color: abierto, preparación, evaluación,
  /// adjudicado o terminado sin adjudicar.
  TipoEstadoProceso get tipo {
    final e = estado;
    if (e == 'Adjudicado' || e == 'Seleccionado') {
      return TipoEstadoProceso.adjudicado;
    }
    if (e.startsWith('Recibe')) return TipoEstadoProceso.abierto;
    if (e == 'Borrador' ||
        e.startsWith('En aprobación') ||
        e.startsWith('Aprobado')) {
      return TipoEstadoProceso.preparacion;
    }
    if (e == 'Cancelado' || e == 'Suspendido') {
      return TipoEstadoProceso.cancelado;
    }
    return TipoEstadoProceso.evaluacion;
  }

  static String _sinFase(String t) {
    // Quita los paréntesis de fase que SECOP II agrega al final, uno o varios.
    var r = t;
    final fase = RegExp(
      r'\s*\((Presentación de oferta|Presentación de observaciones|Manifestación de interés[^)]*|Fase de[^)]*|Selección de ofertas[^)]*)\)\s*$',
      caseSensitive: false,
    );
    while (fase.hasMatch(r)) {
      r = r.replaceFirst(fase, '');
    }
    return r.trim();
  }
}

enum TipoEstadoProceso {
  abierto,
  preparacion,
  evaluacion,
  adjudicado,
  cancelado,
}

/// Búsqueda de procesos de contratación de SECOP II en cualquier estado
/// (p6dx-8zbt), no solo los que ya terminaron en contrato.
class ProcesosSecopService {
  ProcesosSecopService._();

  static const String _procesos = 'p6dx-8zbt';

  static String _norm(String t) => t
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u');

  /// Palabras con contenido de [texto] (sin conectores).
  static List<String> palabras(String texto) {
    const conectores = {
      'de',
      'del',
      'la',
      'las',
      'el',
      'los',
      'y',
      'e',
      'en',
      'para',
      'por',
      'con',
      'a',
      'al',
    };
    return _norm(texto)
        .split(RegExp(r'[^a-z0-9ñ]+'))
        .where((p) => p.length > 1 && !conectores.contains(p))
        .toList();
  }

  /// La fila nombra todas las [buscadas] en su referencia, nombre,
  /// descripción o entidad.
  static bool contiene(Map<String, dynamic> fila, List<String> buscadas) {
    if (buscadas.isEmpty) return true;
    final texto = _norm(
      '${fila['referencia_del_proceso'] ?? ''} ${fila['nombre_del_procedimiento'] ?? ''} '
      '${fila['descripci_n_del_procedimiento'] ?? ''} ${fila['entidad'] ?? ''}',
    );
    return buscadas.every(texto.contains);
  }

  /// Una tarjeta por proceso: la fase más reciente de cada portafolio,
  /// ordenadas de la más reciente a la más antigua.
  static List<ProcesoSecop> agrupar(List<Map<String, dynamic>> filas) {
    final porProceso = <String, List<Map<String, dynamic>>>{};
    for (final f in filas) {
      final clave = '${f['id_del_portafolio'] ?? f['id_del_proceso'] ?? ''}';
      porProceso.putIfAbsent(clave, () => []).add(f);
    }
    final res = <ProcesoSecop>[];
    for (final grupo in porProceso.values) {
      grupo.sort(
        (a, b) => '${b['fecha_de_publicacion_del'] ?? ''}'.compareTo(
          '${a['fecha_de_publicacion_del'] ?? ''}',
        ),
      );
      res.add(ProcesoSecop(grupo.first, fases: grupo.length));
    }
    res.sort(
      (a, b) => (b.publicado ?? DateTime(2000)).compareTo(
        a.publicado ?? DateTime(2000),
      ),
    );
    return res;
  }

  /// Busca procesos. [texto] usa la búsqueda de texto completo de Datos
  /// Abiertos (rápida) y luego se exige que estén todas las palabras.
  /// [entidad] es un NIT o parte del nombre de la entidad.
  static Future<List<ProcesoSecop>> buscar({
    String texto = '',
    String entidad = '',
    FiltroEstadoProceso estado = FiltroEstadoProceso.todos,
    PeriodoProcesos periodo = PeriodoProcesos.anio,
  }) async {
    final where = <String>[];
    if (periodo.dias > 0) {
      final desde = DateTime.now().subtract(Duration(days: periodo.dias));
      where.add(
        "fecha_de_publicacion_del >= '${desde.toIso8601String().split('T').first}T00:00:00.000'",
      );
    }
    final cond = estado.condicion;
    if (cond != null) where.add(cond);

    final ent = entidad.trim();
    final digitos = ent.replaceAll(RegExp(r'[^0-9]'), '');
    final palabrasEntidad = <String>[];
    if (digitos.length >= 8 &&
        digitos.length == ent.replaceAll(RegExp(r'[\s.\-]'), '').length) {
      where.add(
        "nit_entidad in (${Nit.formasNumericas(digitos).map((f) => "'$f'").join(',')})",
      );
    } else if (ent.isNotEmpty) {
      palabrasEntidad.addAll(palabras(ent));
    }

    final buscadas = palabras(texto);
    final params = <String, String>{
      r'$limit': '600',
      if (where.isNotEmpty) r'$where': where.join(' AND '),
    };
    final q = [...buscadas, ...palabrasEntidad].join(' ');
    if (q.isNotEmpty) {
      params[r'$q'] = q;
    } else {
      // Sin texto, los más recientes primero.
      params[r'$order'] = 'fecha_de_publicacion_del DESC';
      params[r'$limit'] = '300';
    }
    final filas = await DatosAbiertos.filas(
      _procesos,
      params,
      timeout: const Duration(seconds: 15),
    );
    final filtradas = [
      for (final f in filas)
        if (contiene(f, buscadas) &&
            (palabrasEntidad.isEmpty ||
                palabrasEntidad.every(_norm('${f['entidad'] ?? ''}').contains)))
          f,
    ];
    final procesos = agrupar(filtradas);
    // "Abiertos": solo los que de verdad siguen recibiendo (la fase más
    // reciente abierta y con el plazo vigente).
    if (estado == FiltroEstadoProceso.abiertos) {
      return procesos
          .where((p) => p.tipo == TipoEstadoProceso.abierto)
          .toList();
    }
    return procesos;
  }
}
