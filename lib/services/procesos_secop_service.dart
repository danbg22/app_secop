import '../utils/nit.dart';
import '../data/colombia_entities_database.dart';
import 'datos_abiertos.dart';

/// Estados por los que se puede filtrar un proceso de SECOP II.
enum FiltroEstadoProceso {
  todos('Todos'),
  abiertos('Abiertos'),
  borrador('Borrador o en aprobación'),
  evaluacion('En evaluación'),
  adjudicados('Adjudicados'),
  cancelados('Cancelados o suspendidos'),
  desiertos('Desiertos');

  const FiltroEstadoProceso(this.etiqueta);
  final String etiqueta;

  /// Condición de SoQL sobre p6dx-8zbt (null = sin filtro).
  String? get condicion => switch (this) {
    todos => null,
    abiertos => "estado_de_apertura_del_proceso = 'Abierto' AND adjudicado = 'No' AND estado_del_procedimiento in ('Publicado','Abierto')",
    borrador =>
      "estado_del_procedimiento in ('Borrador','En aprobación','Aprobado')",
    evaluacion => "estado_del_procedimiento='Evaluación'",
    adjudicados => "adjudicado='Si'",
    cancelados => "estado_del_procedimiento in ('Cancelado','Suspendido')",
    desiertos =>
      "estado_del_procedimiento in ('Desierto','Declarado Desierto','Declarado desierto') OR "
          "estado_resumen in ('Desierto','Declarado Desierto','Declarado desierto')",
  };
}

enum PeriodoProcesos {
  mes('Último mes', 31),
  trimestre('3 meses', 92),
  anio('1 año', 366),
  todo('Todo el historial', 0);

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
  String get idFase => _t('id_del_proceso');
  String get idCompartido => portafolio.isNotEmpty ? portafolio : idFase;

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
    if (estadoSecop.toLowerCase().contains('desiert') ||
        _t('estado_resumen').toLowerCase().contains('desiert')) {
      return 'Declarado desierto';
    }
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
      case 'Evaluación':
        return 'En evaluación';
    }
    final f = fase.toLowerCase();
    // SECOP a veces deja "abierto" un proceso cuyo plazo ya pasó.
    final cierre = cierreOfertas;
    final vencido =
        cierre != null &&
        DateTime.utc(
          cierre.year,
          cierre.month,
          cierre.day,
          cierre.hour,
          cierre.minute,
          cierre.second,
        ).isBefore(ProcesosSecopService._ahoraEnColombia());
    if (abierto && vencido && !f.contains('observaci')) {
      return 'Plazo de ofertas vencido';
    }
    if (abierto) {
      if (f.contains('observaci')) return 'Recibe observaciones';
      if (f.contains('manifestaci')) return 'Recibe manifestaciones de interés';
      return cierre == null && f.isEmpty
          ? 'Abierto en SECOP'
          : 'Recibe ofertas';
    }
    return 'Ofertas cerradas, sin adjudicar';
  }

  /// Tipo de estado, para el color: abierto, preparación, evaluación,
  /// adjudicado o terminado sin adjudicar.
  TipoEstadoProceso get tipo {
    final e = estado;
    if (e == 'Adjudicado' || e == 'Seleccionado') {
      return TipoEstadoProceso.adjudicado;
    }
    if (e.startsWith('Recibe') || e == 'Abierto en SECOP') {
      return TipoEstadoProceso.abierto;
    }
    if (e == 'Borrador' ||
        e.startsWith('En aprobación') ||
        e.startsWith('Aprobado')) {
      return TipoEstadoProceso.preparacion;
    }
    if (e == 'Cancelado' || e == 'Suspendido' || e == 'Declarado desierto') {
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

enum CampoBusquedaProceso {
  general('Todo'),
  referencia('Número de proceso'),
  entidad('Entidad o NIT');

  const CampoBusquedaProceso(this.etiqueta);
  final String etiqueta;
}

class CursorProcesos {
  const CursorProcesos({this.offset = 0, this.sinFecha = false});

  final int offset;
  final bool sinFecha;
}

class PaginaProcesos {
  const PaginaProcesos(this.procesos, this.siguiente);

  final List<ProcesoSecop> procesos;
  final CursorProcesos? siguiente;
}

/// Búsqueda de procesos de contratación de SECOP II en cualquier estado
/// (p6dx-8zbt), no solo los que ya terminaron en contrato.
class ProcesosSecopService {
  ProcesosSecopService._();

  static const String _procesos = 'p6dx-8zbt';

  static const _orden = 'fecha_de_publicacion_del DESC NULLS LAST, :id DESC';
  static const _tamanoPagina = 24;

  // Las fechas flotantes de SECOP se publican en hora local de Colombia.
  static DateTime _ahoraEnColombia() =>
      DateTime.now().toUtc().subtract(const Duration(hours: 5));

  static String _literal(String s) => "'${s.replaceAll("'", "''")}'";

  static final _idValido = RegExp(r'^[A-Z0-9]+\.[A-Z]+\.[0-9]+$');

  static bool idCompartible(String id) =>
      id.length <= 64 && _idValido.hasMatch(id);

  static String _campoId(String id) =>
      id.contains('.BDOS.') ? 'id_del_portafolio' : 'id_del_proceso';

  static Future<ProcesoSecop?> porId(
    String id, {
    bool soloEncabezado = false,
  }) async {
    if (!idCompartible(id)) return null;
    final filas = await DatosAbiertos.filas(_procesos, {
      if (soloEncabezado)
        r'$select':
            'referencia_del_proceso,nombre_del_procedimiento,entidad,'
            'estado_del_procedimiento,adjudicado',
      r'$where': '${_campoId(id)} = ${_literal(id)}',
      r'$order': _orden,
      r'$limit': '1',
    }, cache: soloEncabezado ? null : DatosAbiertos.ttlPorDefecto);
    return filas.isEmpty ? null : ProcesoSecop(filas.first);
  }

  static Future<List<ProcesoSecop>> fasesDe(ProcesoSecop proceso) async {
    if (proceso.portafolio.isEmpty) return [proceso];
    final filas = await DatosAbiertos.filas(_procesos, {
      r'$where': "id_del_portafolio = ${_literal(proceso.portafolio)}",
      r'$order': 'fecha_de_publicacion_del ASC NULLS LAST, :id ASC',
    });
    return filas.isEmpty ? [proceso] : filas.map(ProcesoSecop.new).toList();
  }

  static Future<PaginaProcesos> buscarPagina({
    String texto = '',
    CampoBusquedaProceso campo = CampoBusquedaProceso.general,
    FiltroEstadoProceso estado = FiltroEstadoProceso.todos,
    PeriodoProcesos periodo = PeriodoProcesos.todo,
    CursorProcesos desde = const CursorProcesos(),
    String nitEntidad = '',
    String departamento = '',
    String entidad = '',
  }) async {
    const fecha = 'fecha_de_publicacion_del';
    final consulta = texto.trim();
    final id = consulta.toUpperCase();
    final tokens = _norm(consulta)
        .split(RegExp(r'[^a-z0-9ñ]+'))
        .where((token) => token.isNotEmpty)
        .toList();
    final codigoEscrito =
        RegExp(r'[0-9]').hasMatch(consulta) &&
        RegExp(
          r'^[a-zñ0-9]+(?:[ /_.-]+[a-zñ0-9]+)+$',
          caseSensitive: false,
        ).hasMatch(_norm(consulta));
    final buscaReferencia =
        campo == CampoBusquedaProceso.referencia ||
        (campo == CampoBusquedaProceso.general &&
            codigoEscrito &&
            RegExp(r'[-_./]').hasMatch(consulta));
    final sinConectores = buscaReferencia
        ? const <String>[]
        : palabras(consulta);
    final palabrasConsulta = (sinConectores.isEmpty ? tokens : sinConectores)
        .toSet();
    final soloNumero = RegExp(r'^[\d .-]+$').hasMatch(consulta);
    final nit = consulta.replaceAll(RegExp(r'[^0-9]'), '');
    final buscaNit = soloNumero && nit.length >= 8;
    final columnas = switch (buscaReferencia
        ? CampoBusquedaProceso.referencia
        : campo) {
      CampoBusquedaProceso.entidad => ['entidad'],
      CampoBusquedaProceso.referencia => ['referencia_del_proceso'],
      CampoBusquedaProceso.general => [
        'referencia_del_proceso',
        'entidad',
        'nombre_del_procedimiento',
        'descripci_n_del_procedimiento',
      ],
    };
    final entidadCatalogo = campo == CampoBusquedaProceso.referencia
        ? null
        : ColombiaEntitiesDatabase.entidadExacta(consulta);
    final nits = entidadCatalogo != null
        ? Nit.formasNumericas(entidadCatalogo.nit)
        : buscaNit && campo != CampoBusquedaProceso.referencia
        ? Nit.formasNumericas(nit)
        : const <String>[];
    final nitCond = nits.isNotEmpty
        ? 'nit_entidad in (${nits.map(_literal).join(',')})'
        : null;
    final idCond = campo != CampoBusquedaProceso.entidad && idCompartible(id)
        ? '${_campoId(id)} = ${_literal(id)}'
        : null;
    final referenciaCompleta = buscaReferencia && codigoEscrito;
    final porPalabras = referenciaCompleta
        ? "upper(referencia_del_proceso) LIKE '${tokens.map(_patron).join('%')}%'"
        : [
            for (final palabra in palabrasConsulta)
              '(${columnas.map((c) => "upper($c) LIKE '%${_patron(palabra)}%'").join(' OR ')})',
          ].join(' AND ');
    // El índice de texto evita escanear millones de descripciones. Los
    // códigos completos se comparan directamente para conservar separadores
    // y segmentos de un carácter que el índice puede interpretar por separado.
    final busquedaIndexada =
        idCond == null &&
        nits.isEmpty &&
        !referenciaCompleta &&
        palabrasConsulta.isNotEmpty;
    final termino = [
      ?idCond,
      ?nitCond,
      if (entidadCatalogo == null &&
          porPalabras.isNotEmpty &&
          !(buscaNit && campo == CampoBusquedaProceso.entidad) &&
          idCond == null)
        '($porPalabras)',
    ].join(' OR ');
    if (consulta.isNotEmpty && termino.isEmpty) {
      return const PaginaProcesos([], null);
    }
    final ahora = _ahoraEnColombia();
    final minuto = DateTime.utc(
      ahora.year,
      ahora.month,
      ahora.day,
      ahora.hour,
      ahora.minute,
    );
    final condicion = estado.condicion;
    final entidadBuscada = entidad.trim();
    final nitBuscado =
        ColombiaEntitiesDatabase.entidadExacta(entidadBuscada)?.nit ??
        (RegExp(r'^\d[\d .-]{7,13}$').hasMatch(entidadBuscada)
            ? entidadBuscada
            : '');
    final alcance = Nit.formasNumericas(
      nitEntidad.isNotEmpty ? nitEntidad : nitBuscado,
    );
    final where = [
      if (alcance.isNotEmpty)
        'nit_entidad in (${alcance.map(_literal).join(',')})',
      if (alcance.isEmpty)
        for (final palabra in palabras(entidadBuscada))
          "upper(entidad) LIKE '%${_patron(palabra)}%'",
      if (departamento.trim().isNotEmpty)
        'departamento_entidad = ${_literal(departamento.trim())}',
      if (termino.isNotEmpty) '($termino)',
      if (condicion != null) '($condicion)',
      if (estado == FiltroEstadoProceso.abiertos)
        "(fecha_de_recepcion_de >= '${_sinZona(minuto)}' OR "
            "fecha_de_recepcion_de is null OR upper(fase) LIKE '%OBSERVACI%')",
      if (periodo.dias > 0)
        "$fecha >= '${_sinZona(ahora.subtract(Duration(days: periodo.dias)))}'",
    ];

    // Separar las fechas vacías permite que Socrata use el índice de
    // publicación. Se recorren después de los procesos con fecha.
    Future<List<Map<String, dynamic>>> consultar(
      CursorProcesos cursor,
      int limite,
    ) => DatosAbiertos.filas(_procesos, {
      if (busquedaIndexada) r'$q': palabrasConsulta.join(' '),
      r'$where': [
        ...where,
        if (cursor.sinFecha)
          '$fecha is null'
        else if (periodo == PeriodoProcesos.todo)
          '$fecha is not null',
      ].join(' AND '),
      r'$order': cursor.sinFecha ? ':id DESC' : '$fecha DESC, :id DESC',
      r'$limit': '$limite',
      r'$offset': '${cursor.offset}',
    }, timeout: const Duration(seconds: 20));

    final filas = await consultar(desde, _tamanoPagina + 1);
    CursorProcesos? siguiente;
    if (filas.length > _tamanoPagina) {
      siguiente = CursorProcesos(
        offset: desde.offset + _tamanoPagina,
        sinFecha: desde.sinFecha,
      );
    } else if (periodo == PeriodoProcesos.todo && !desde.sinFecha) {
      final conFecha = filas.length;
      final sinFecha = await consultar(
        const CursorProcesos(sinFecha: true),
        _tamanoPagina + 1 - conFecha,
      );
      filas.addAll(sinFecha);
      if (filas.length > _tamanoPagina) {
        siguiente = CursorProcesos(
          offset: _tamanoPagina - conFecha,
          sinFecha: true,
        );
      }
    }

    final visibles = filas.take(_tamanoPagina).where((fila) {
      if (idCond != null) return true;
      final nitFila = '${fila['nit_entidad'] ?? ''}'.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      if (nits.contains(nitFila)) return true;
      if (entidadCatalogo != null ||
          (buscaNit && campo == CampoBusquedaProceso.entidad)) {
        return false;
      }
      if (referenciaCompleta) {
        final partes = _norm('${fila['referencia_del_proceso'] ?? ''}')
            .split(RegExp(r'[^a-z0-9ñ]+'));
        return partes.length >= tokens.length &&
            tokens.indexed.every(
              (token) => token.$1 == tokens.length - 1
                  ? partes[token.$1].startsWith(token.$2)
                  : partes[token.$1] == token.$2,
            );
      }
      final contenido = _norm(columnas.map((c) => fila[c] ?? '').join(' '));
      return palabrasConsulta.every(contenido.contains);
    }).toList();

    final candidatos = agrupar(visibles);
    final procesos = estado != FiltroEstadoProceso.todos || consulta.isNotEmpty
        ? await _confirmarEstado(candidatos, estado)
        : candidatos;
    return PaginaProcesos(procesos, siguiente);
  }

  static String _sinZona(DateTime fecha) =>
      fecha.toIso8601String().replaceFirst('Z', '');

  // SoQL no tiene una función para quitar tildes. El primer filtro es
  // inclusivo y la comprobación local conserva las coincidencias reales.
  static String _patron(String palabra) =>
      palabra.toUpperCase().replaceAll(RegExp(r'[AEIOU]'), '_');

  static Future<List<ProcesoSecop>> _confirmarEstado(
    List<ProcesoSecop> candidatos,
    FiltroEstadoProceso estado,
  ) async {
    final ids = candidatos
        .map((p) => p.portafolio)
        .where((id) => id.isNotEmpty)
        .toSet();
    final fases = <Map<String, dynamic>>[];
    if (ids.isNotEmpty) {
      const lote = 200;
      var desde = 0;
      while (true) {
        final filas = await DatosAbiertos.filas(_procesos, {
          r'$where': 'id_del_portafolio in (${ids.map(_literal).join(',')})',
          r'$order': _orden,
          r'$limit': '$lote',
          r'$offset': '$desde',
        });
        fases.addAll(filas);
        if (filas.length < lote) break;
        desde += lote;
      }
    }
    final recientes = {for (final p in agrupar(fases)) p.portafolio: p};
    return candidatos
        .map((p) => recientes[p.portafolio] ?? p)
        .where((p) => _coincideEstado(p, estado))
        .toList();
  }

  static bool _coincideEstado(ProcesoSecop p, FiltroEstadoProceso estado) =>
      switch (estado) {
        FiltroEstadoProceso.todos => true,
        FiltroEstadoProceso.abiertos => p.tipo == TipoEstadoProceso.abierto,
        FiltroEstadoProceso.borrador => p.tipo == TipoEstadoProceso.preparacion,
        FiltroEstadoProceso.evaluacion => p.estado == 'En evaluación',
        FiltroEstadoProceso.adjudicados => p.adjudicado,
        FiltroEstadoProceso.cancelados =>
          p.estado == 'Cancelado' || p.estado == 'Suspendido',
        FiltroEstadoProceso.desiertos => p.estado == 'Declarado desierto',
      };

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
      final p = ProcesoSecop(f);
      final clave = p.idCompartido.isEmpty
          ? 'fila-${porProceso.length}'
          : p.idCompartido;
      porProceso.putIfAbsent(clave, () => []).add(f);
    }
    final res = <ProcesoSecop>[];
    for (final grupo in porProceso.values) {
      grupo.sort((a, b) {
        final fecha = '${b['fecha_de_publicacion_del'] ?? ''}'.compareTo(
          '${a['fecha_de_publicacion_del'] ?? ''}',
        );
        return fecha != 0
            ? fecha
            : '${b[':id'] ?? b['id_del_proceso'] ?? ''}'.compareTo(
                '${a[':id'] ?? a['id_del_proceso'] ?? ''}',
              );
      });
      res.add(ProcesoSecop(grupo.first, fases: grupo.length));
    }
    res.sort(
      (a, b) => (b.publicado ?? DateTime(2000)).compareTo(
        a.publicado ?? DateTime(2000),
      ),
    );
    return res;
  }
}
