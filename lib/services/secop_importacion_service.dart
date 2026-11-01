import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Importación y sincronización de procesos que ya existen en SECOP II, con
/// datos de Datos Abiertos:
/// - Procesos: `p6dx-8zbt` (fase, estado, fechas, adjudicación).
/// - Documentos publicados: conjuntos "Archivos Descarga" por año.

class DocumentoSecop {
  const DocumentoSecop({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.fechaIso,
    required this.extension,
    required this.tamanoBytes,
    required this.url,
  });

  final String id;
  final String nombre;
  final String descripcion;
  final String fechaIso;
  final String extension;
  final int tamanoBytes;
  final String url;

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'descripcion': descripcion,
    'fechaIso': fechaIso,
    'extension': extension,
    'tamanoBytes': tamanoBytes,
    'url': url,
  };

  factory DocumentoSecop.fromMap(Map<String, dynamic> m) => DocumentoSecop(
    id: '${m['id'] ?? ''}',
    nombre: '${m['nombre'] ?? ''}',
    descripcion: '${m['descripcion'] ?? ''}',
    fechaIso: '${m['fechaIso'] ?? ''}',
    extension: '${m['extension'] ?? ''}',
    tamanoBytes: (m['tamanoBytes'] as num?)?.toInt() ?? 0,
    url: '${m['url'] ?? ''}',
  );
}

/// Fotografía del proceso en SECOP II en el momento de la sincronización.
class ProcesoSecop {
  const ProcesoSecop({
    required this.idProceso,
    required this.idPortafolio,
    required this.referencia,
    required this.nombre,
    required this.descripcion,
    required this.entidad,
    required this.nit,
    required this.departamento,
    required this.unidad,
    required this.modalidad,
    required this.tipoContrato,
    required this.fase,
    required this.estado,
    required this.precioBase,
    required this.duracion,
    required this.adjudicado,
    required this.proveedor,
    required this.valorAdjudicado,
    required this.ofertas,
    required this.manifestaciones,
    required this.fechas,
    required this.url,
    this.documentos = const [],
  });

  final String idProceso;
  final String idPortafolio;
  final String referencia;
  final String nombre;
  final String descripcion;
  final String entidad;
  final String nit;
  final String departamento;
  final String unidad;
  final String modalidad;
  final String tipoContrato;
  final String fase;
  final String estado;
  final int precioBase;
  final String duracion;
  final bool adjudicado;
  final String proveedor;
  final int valorAdjudicado;
  final int ofertas;
  final int manifestaciones;

  /// publicacion, ultimaPublicacion, recepcionOfertas, aperturaOfertas,
  /// adjudicacion (aaaa-mm-dd).
  final Map<String, String> fechas;
  final String url;
  final List<DocumentoSecop> documentos;

  /// Estado legible: el de SECOP II, con la adjudicación si la hay.
  String get estadoVisible {
    if (adjudicado) return 'Adjudicado';
    if (estado.isEmpty) return fase.isEmpty ? 'Sin estado' : fase;
    return estado;
  }

  ProcesoSecop conDocumentos(List<DocumentoSecop> docs) => ProcesoSecop(
    idProceso: idProceso,
    idPortafolio: idPortafolio,
    referencia: referencia,
    nombre: nombre,
    descripcion: descripcion,
    entidad: entidad,
    nit: nit,
    departamento: departamento,
    unidad: unidad,
    modalidad: modalidad,
    tipoContrato: tipoContrato,
    fase: fase,
    estado: estado,
    precioBase: precioBase,
    duracion: duracion,
    adjudicado: adjudicado,
    proveedor: proveedor,
    valorAdjudicado: valorAdjudicado,
    ofertas: ofertas,
    manifestaciones: manifestaciones,
    fechas: fechas,
    url: url,
    documentos: docs,
  );

  Map<String, dynamic> toMap() => {
    'idProceso': idProceso,
    'idPortafolio': idPortafolio,
    'referencia': referencia,
    'nombre': nombre,
    'descripcion': descripcion,
    'entidad': entidad,
    'nit': nit,
    'departamento': departamento,
    'unidad': unidad,
    'modalidad': modalidad,
    'tipoContrato': tipoContrato,
    'fase': fase,
    'estado': estado,
    'precioBase': precioBase,
    'duracion': duracion,
    'adjudicado': adjudicado,
    'proveedor': proveedor,
    'valorAdjudicado': valorAdjudicado,
    'ofertas': ofertas,
    'manifestaciones': manifestaciones,
    'fechas': fechas,
    'url': url,
    'documentos': documentos.map((d) => d.toMap()).toList(),
  };

  factory ProcesoSecop.fromMap(Map<String, dynamic> m) => ProcesoSecop(
    idProceso: '${m['idProceso'] ?? ''}',
    idPortafolio: '${m['idPortafolio'] ?? ''}',
    referencia: '${m['referencia'] ?? ''}',
    nombre: '${m['nombre'] ?? ''}',
    descripcion: '${m['descripcion'] ?? ''}',
    entidad: '${m['entidad'] ?? ''}',
    nit: '${m['nit'] ?? ''}',
    departamento: '${m['departamento'] ?? ''}',
    unidad: '${m['unidad'] ?? ''}',
    modalidad: '${m['modalidad'] ?? ''}',
    tipoContrato: '${m['tipoContrato'] ?? ''}',
    fase: '${m['fase'] ?? ''}',
    estado: '${m['estado'] ?? ''}',
    precioBase: (m['precioBase'] as num?)?.toInt() ?? 0,
    duracion: '${m['duracion'] ?? ''}',
    adjudicado: m['adjudicado'] == true,
    proveedor: '${m['proveedor'] ?? ''}',
    valorAdjudicado: (m['valorAdjudicado'] as num?)?.toInt() ?? 0,
    ofertas: (m['ofertas'] as num?)?.toInt() ?? 0,
    manifestaciones: (m['manifestaciones'] as num?)?.toInt() ?? 0,
    fechas: {
      for (final e in (m['fechas'] as Map? ?? const {}).entries)
        '${e.key}': '${e.value}',
    },
    url: '${m['url'] ?? ''}',
    documentos: [
      for (final d in (m['documentos'] as List? ?? const []))
        if (d is Map) DocumentoSecop.fromMap(Map<String, dynamic>.from(d)),
    ],
  );
}

class SecopImportacionException implements Exception {
  const SecopImportacionException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SecopImportacionService {
  SecopImportacionService._();

  static const String _procesos =
      'https://www.datos.gov.co/resource/p6dx-8zbt.json';
  static const String _urlPublica =
      'https://community.secop.gov.co/Public/Tendering/OpportunityDetail/Index?noticeUID=';

  /// Documentos publicados, un conjunto por año de carga.
  static const Map<int, String> _archivosPorAnio = {
    2026: 'dmgg-8hin',
    2025: 'h4m3-b4e2',
    2024: 'nbae-kzan',
    2023: '3skv-9na7',
    2022: 'kgcd-kt7i',
    2021: 'f8va-cf4m', // Hasta 2021
  };

  static final RegExp _patronId = RegExp(
    r'CO1\.[A-Z]+\.\d+',
    caseSensitive: false,
  );

  /// Saca el identificador de lo que pegue el usuario: el ID solo
  /// (CO1.REQ…, CO1.NTC…, CO1.BDOS…) o el enlace público de SECOP II.
  static String? extraerIdentificador(String entrada) {
    final m = _patronId.firstMatch(entrada.trim());
    return m?.group(0)?.toUpperCase();
  }

  static String _l(String v) => v.replaceAll("'", "''");

  static Future<List<dynamic>> _get(
    String base,
    Map<String, String> params,
  ) async {
    final uri = Uri.parse(base).replace(queryParameters: params);
    for (var intento = 1; ; intento++) {
      try {
        final r = await http.get(uri).timeout(const Duration(seconds: 25));
        if (r.statusCode == 200) {
          return jsonDecode(utf8.decode(r.bodyBytes)) as List<dynamic>;
        }
        if (intento >= 2 || (r.statusCode < 500 && r.statusCode != 429)) {
          throw SecopImportacionException(
            'Datos Abiertos respondió con error ${r.statusCode}. Intenta de nuevo en unos minutos.',
          );
        }
      } on SecopImportacionException {
        rethrow;
      } catch (_) {
        if (intento >= 2) {
          throw const SecopImportacionException(
            'No fue posible conectar con Datos Abiertos. Revisa tu conexión.',
          );
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
  }

  static String _fecha(dynamic v) {
    final t = '${v ?? ''}';
    return t.length >= 10 && DateTime.tryParse(t) != null
        ? t.substring(0, 10)
        : '';
  }

  static ProcesoSecop _desdeFila(Map<String, dynamic> r) {
    String t(String k) {
      final v = '${r[k] ?? ''}'.trim();
      return v == 'No Definido' || v == 'No definido' || v == 'No Adjudicado'
          ? ''
          : v;
    }

    int n(String k) => int.tryParse('${r[k] ?? 0}'.split('.').first) ?? 0;
    final url = r['urlproceso'] is Map
        ? '${(r['urlproceso'] as Map)['url'] ?? ''}'
        : '';
    final adjudicado = t('adjudicado').toLowerCase();
    return ProcesoSecop(
      idProceso: t('id_del_proceso'),
      idPortafolio: t('id_del_portafolio'),
      referencia: t('referencia_del_proceso'),
      nombre: t('nombre_del_procedimiento'),
      descripcion: t('descripci_n_del_procedimiento'),
      entidad: t('entidad'),
      nit: t('nit_entidad'),
      departamento: t('departamento_entidad'),
      unidad: t('nombre_de_la_unidad_de'),
      modalidad: t('modalidad_de_contratacion'),
      tipoContrato: t('tipo_de_contrato'),
      fase: t('fase'),
      estado: t('estado_del_procedimiento'),
      precioBase: n('precio_base'),
      duracion: [
        t('duracion'),
        t('unidad_de_duracion'),
      ].where((e) => e.isNotEmpty).join(' '),
      adjudicado: adjudicado == 'si' || adjudicado == 'sí',
      proveedor: t('nombre_del_proveedor'),
      valorAdjudicado: n('valor_total_adjudicacion'),
      ofertas: n('respuestas_al_procedimiento'),
      manifestaciones: n('proveedores_que_manifestaron'),
      fechas: {
        for (final e in {
          'publicacion': r['fecha_de_publicacion_del'],
          'ultimaPublicacion': r['fecha_de_ultima_publicaci'],
          'recepcionOfertas': r['fecha_de_recepcion_de'],
          'aperturaOfertas': r['fecha_de_apertura_de_respuesta'],
          'adjudicacion': r['fecha_adjudicacion'],
        }.entries)
          if (_fecha(e.value).isNotEmpty) e.key: _fecha(e.value),
      },
      url: url,
    );
  }

  /// Busca el proceso por ID o enlace y trae sus documentos publicados.
  /// Devuelve `null` si Datos Abiertos aún no lo tiene (se actualiza a diario).
  static Future<ProcesoSecop?> buscar(String entrada) async {
    final id = extraerIdentificador(entrada);
    if (id == null) {
      throw const SecopImportacionException(
        'Escribe el ID del proceso (p. ej. CO1.REQ.1234567 o CO1.NTC.1234567) o pega el enlace público de SECOP II.',
      );
    }
    final String where;
    if (id.contains('.REQ.')) {
      where = "id_del_proceso = '${_l(id)}'";
    } else if (id.contains('.BDOS.')) {
      where = "id_del_portafolio = '${_l(id)}'";
    } else if (id.contains('.NTC.')) {
      where = "urlproceso = '${_l('$_urlPublica$id')}'";
    } else {
      where = "urlproceso.url like '%${_l(id)}%'";
    }
    final filas = await _get(_procesos, {
      r'$where': where,
      r'$order': 'fecha_de_ultima_publicaci DESC',
      r'$limit': '1',
    });
    if (filas.isEmpty || filas.first is! Map) return null;
    final proceso = _desdeFila(Map<String, dynamic>.from(filas.first as Map));
    return proceso.conDocumentos(await documentos(proceso));
  }

  /// Documentos publicados del proceso, buscando desde el año de publicación.
  static Future<List<DocumentoSecop>> documentos(ProcesoSecop p) async {
    if (p.idPortafolio.isEmpty) return const [];
    final hoy = DateTime.now().year;
    final desde =
        int.tryParse(
          (p.fechas['publicacion'] ?? p.fechas['ultimaPublicacion'] ?? '')
              .split('-')
              .first,
        ) ??
        hoy - 1;
    final conjuntos = <String>{
      for (var a = desde.clamp(2021, hoy); a <= hoy; a++)
        _archivosPorAnio[a] ?? _archivosPorAnio[2026]!,
    };
    final resultados = await Future.wait([
      for (final c in conjuntos)
        _get('https://www.datos.gov.co/resource/$c.json', {
          r'$where': "proceso = '${_l(p.idPortafolio)}'",
          r'$order': 'fecha_carga',
          r'$limit': '300',
        }).catchError((_) => <dynamic>[]),
    ]);
    final vistos = <String>{};
    final docs = <DocumentoSecop>[];
    for (final fila in resultados.expand((r) => r)) {
      if (fila is! Map) continue;
      final m = Map<String, dynamic>.from(fila);
      final id = '${m['id_documento'] ?? ''}';
      if (id.isEmpty || !vistos.add(id)) continue;
      docs.add(
        DocumentoSecop(
          id: id,
          nombre: '${m['nombre_archivo'] ?? ''}',
          descripcion: '${m['descripci_n'] ?? ''}',
          fechaIso: _fecha(m['fecha_carga']),
          extension: '${m['extensi_n'] ?? ''}'.toLowerCase(),
          tamanoBytes: int.tryParse('${m['tamanno_archivo'] ?? 0}') ?? 0,
          url: m['url_descarga_documento'] is Map
              ? '${(m['url_descarga_documento'] as Map)['url'] ?? ''}'
              : '',
        ),
      );
    }
    docs.sort((a, b) => a.fechaIso.compareTo(b.fechaIso));
    return docs;
  }

  /// Modalidad de Contrata Legal que corresponde a la de SECOP II.
  static String modalidadDesdeSecop(String modalidadSecop) {
    final m = modalidadSecop
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    if (m.contains('licitacion')) return 'licitacion_publica';
    if (m.contains('subasta inversa')) return 'subasta_inversa';
    if (m.contains('seleccion abreviada')) {
      return 'seleccion_abreviada_menor_cuantia';
    }
    if (m.contains('concurso de meritos')) return 'concurso_meritos';
    if (m.contains('minima cuantia')) return 'minima_cuantia';
    if (m.contains('regimen especial')) return 'regimen_especial';
    if (m.contains('directa')) return 'contratacion_directa';
    return 'regimen_especial';
  }

  /// Qué cambió en SECOP II entre dos sincronizaciones.
  static List<String> novedades(ProcesoSecop anterior, ProcesoSecop nuevo) {
    String cop(int v) =>
        '\$${v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';
    final docsAntes = {for (final d in anterior.documentos) d.id};
    final nuevos = nuevo.documentos
        .where((d) => !docsAntes.contains(d.id))
        .toList();
    return [
      if (anterior.estado != nuevo.estado)
        'Estado: ${anterior.estado.isEmpty ? '—' : anterior.estado} → ${nuevo.estado}',
      if (anterior.fase != nuevo.fase && nuevo.fase.isNotEmpty)
        'Fase: ${anterior.fase.isEmpty ? '—' : anterior.fase} → ${nuevo.fase}',
      if (!anterior.adjudicado && nuevo.adjudicado)
        'Adjudicado a ${nuevo.proveedor.isEmpty ? 'un proponente' : nuevo.proveedor}'
            '${nuevo.valorAdjudicado > 0 ? ' por ${cop(nuevo.valorAdjudicado)}' : ''}',
      if (nuevo.ofertas > anterior.ofertas)
        '${nuevo.ofertas - anterior.ofertas} oferta${nuevo.ofertas - anterior.ofertas == 1 ? '' : 's'} nueva${nuevo.ofertas - anterior.ofertas == 1 ? '' : 's'} (total ${nuevo.ofertas})',
      if (nuevos.isNotEmpty)
        nuevos.length == 1
            ? 'Documento nuevo: ${nuevos.first.nombre}'
            : '${nuevos.length} documentos nuevos: ${nuevos.take(3).map((d) => d.nombre).join(', ')}${nuevos.length > 3 ? '…' : ''}',
      for (final k in ['recepcionOfertas', 'adjudicacion'])
        if ((anterior.fechas[k] ?? '') != (nuevo.fechas[k] ?? '') &&
            (nuevo.fechas[k] ?? '').isNotEmpty)
          '${k == 'recepcionOfertas' ? 'Cierre de ofertas' : 'Fecha de adjudicación'}: ${nuevo.fechas[k]}',
    ];
  }
}
