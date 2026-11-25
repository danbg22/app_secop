import 'datos_abiertos.dart';
import 'procesos_secop_service.dart';

/// Novedades que la entidad publica durante un proceso: adendas, informes de
/// evaluación, respuestas a observaciones, adjudicación, etc.
///
/// Los mensajes y observaciones de SECOP II ("Observaciones y Mensajes") no
/// están en Datos Abiertos: se ven solo en la página del proceso. Aquí se
/// reúne lo que sí se publica: los documentos clave (por su nombre y fecha de
/// carga) y la lista de proponentes.
enum TipoNovedad {
  desierto('Declaratoria de desierto'),
  revocatoria('Revocatoria o cancelación'),
  suspension('Suspensión'),
  adjudicacion('Adjudicación'),
  evaluacion('Informe de evaluación'),
  observaciones('Respuesta a observaciones'),
  adenda('Adenda'),
  modificacion('Modificación'),
  oferentes('Cierre y lista de oferentes'),
  apertura('Apertura'),
  convocatoria('Aviso de convocatoria');

  const TipoNovedad(this.titulo);
  final String titulo;
}

class NovedadProceso {
  const NovedadProceso({
    required this.tipo,
    required this.archivo,
    this.fecha,
    this.url,
  });

  final TipoNovedad tipo;
  final String archivo;
  final DateTime? fecha;
  final String? url;
}

class ProponenteProceso {
  const ProponenteProceso({required this.nombre, this.nit = '', this.fecha});

  final String nombre;
  final String nit;
  final DateTime? fecha;
}

class NovedadesProceso {
  const NovedadesProceso({required this.novedades, required this.proponentes});

  final List<NovedadProceso> novedades;
  final List<ProponenteProceso> proponentes;

  bool get vacio => novedades.isEmpty && proponentes.isEmpty;
}

class NovedadesProcesoService {
  NovedadesProcesoService._();

  static const _proponentes = 'hgi6-6wh3';

  /// Documentos publicados, un conjunto por año de carga.
  static const Map<int, String> _archivosPorAnio = {
    2021: 'f8va-cf4m', // Hasta 2021
    2022: 'kgcd-kt7i',
    2023: '3skv-9na7',
    2024: 'nbae-kzan',
    2025: 'h4m3-b4e2',
    2026: 'dmgg-8hin',
  };

  static final _idValido = RegExp(r'^CO1\.[A-Z]+\.\d+$');

  static String _compacto(String texto) => texto
      .toLowerCase()
      .replaceAll(RegExp('[áà]'), 'a')
      .replaceAll(RegExp('[éè]'), 'e')
      .replaceAll(RegExp('[íì]'), 'i')
      .replaceAll(RegExp('[óò]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u')
      .replaceAll(RegExp('[^a-z0-9ñ]'), '');

  /// Tipo de novedad según el nombre del archivo, o `null` si es un documento
  /// ordinario (estudios previos, formatos, anexos…). El orden importa: un
  /// "informe de evaluación y adjudicación" cuenta como adjudicación.
  static TipoNovedad? clasificar(String nombreArchivo) {
    final n = _compacto(nombreArchivo);
    bool tiene(String s) => n.contains(s);
    if (tiene('desiert')) return TipoNovedad.desierto;
    if (tiene('revocatori') ||
        tiene('revocael') ||
        tiene('cancelaciondelproceso')) {
      return TipoNovedad.revocatoria;
    }
    if (tiene('suspension') || tiene('suspende')) return TipoNovedad.suspension;
    if (tiene('adjudica')) return TipoNovedad.adjudicacion;
    if (tiene('informedeevaluacion') ||
        tiene('evaluacionpreliminar') ||
        tiene('evaluaciondefinitiva') ||
        tiene('informeevaluacion') ||
        tiene('verificacionderequisitos') ||
        tiene('informedeverificacion')) {
      return TipoNovedad.evaluacion;
    }
    if (tiene('respuesta') && tiene('observacion')) {
      return TipoNovedad.observaciones;
    }
    if (tiene('adenda')) return TipoNovedad.adenda;
    if (tiene('modificacion') && (tiene('cronograma') || tiene('pliego'))) {
      return TipoNovedad.modificacion;
    }
    if (tiene('actadecierre') ||
        tiene('listadeoferentes') ||
        tiene('listadeproponentes') ||
        tiene('recepciondeofertas')) {
      return TipoNovedad.oferentes;
    }
    if (tiene('resoluciondeapertura') ||
        tiene('actodeapertura') ||
        (tiene('apertura') && tiene('resolucion'))) {
      return TipoNovedad.apertura;
    }
    if (tiene('avisodeconvocatoria')) return TipoNovedad.convocatoria;
    return null;
  }

  /// Datos Abiertos publica la fecha de carga sin hora, corrida 5 horas
  /// (medianoche UTC vista desde Colombia): llega como las 19:00 del día
  /// anterior. Se devuelve al día real.
  static DateTime? _fechaCarga(String texto) {
    final f = DateTime.tryParse(texto);
    if (f == null) return null;
    if (f.hour == 19 && f.minute == 0 && f.second == 0) {
      return DateTime(f.year, f.month, f.day + 1);
    }
    return f;
  }

  /// Deja una novedad por archivo (SECOP II repite el mismo archivo en cada
  /// fase) y las ordena de la más reciente a la más antigua.
  static List<NovedadProceso> depurar(Iterable<Map<String, dynamic>> filas) {
    final porArchivo = <String, NovedadProceso>{};
    for (final f in filas) {
      final nombre = '${f['nombre_archivo'] ?? ''}'.trim();
      final tipo = clasificar(nombre);
      if (tipo == null) continue;
      final enlace = f['url_descarga_documento'];
      final url = enlace is Map ? '${enlace['url'] ?? ''}' : '${enlace ?? ''}';
      final clave = _compacto(nombre);
      final propia = url.startsWith('https://') ? url : null;
      final fecha = _fechaCarga('${f['fecha_carga'] ?? ''}');
      final previa = porArchivo[clave];
      // Se queda la carga más reciente; si empatan, la que trae enlace.
      if (previa != null) {
        final antes = previa.fecha ?? DateTime(0);
        final ahora = fecha ?? DateTime(0);
        if (ahora.isBefore(antes) ||
            (ahora == antes && (previa.url != null || propia == null))) {
          continue;
        }
      }
      porArchivo[clave] = NovedadProceso(
        tipo: tipo,
        archivo: nombre,
        fecha: fecha,
        url: propia,
      );
    }
    return porArchivo.values.toList()..sort(
      (a, b) => (b.fecha ?? DateTime(0)).compareTo(a.fecha ?? DateTime(0)),
    );
  }

  static List<ProponenteProceso> proponentesUnicos(
    Iterable<Map<String, dynamic>> filas,
  ) {
    final vistos = <String, ProponenteProceso>{};
    for (final f in filas) {
      final nombre = '${f['proveedor'] ?? ''}'.trim();
      if (nombre.isEmpty) continue;
      var nit = '${f['nit_proveedor'] ?? ''}'.trim();
      if (!RegExp(r'\d{5,}').hasMatch(nit)) nit = '';
      vistos.putIfAbsent(
        _compacto(nombre),
        () => ProponenteProceso(
          nombre: nombre,
          nit: nit,
          fecha: DateTime.tryParse('${f['fecha_publicaci_n'] ?? ''}'),
        ),
      );
    }
    return vistos.values.toList()..sort((a, b) => a.nombre.compareTo(b.nombre));
  }

  static String _lista(Iterable<String> ids) =>
      ids.map((id) => "'$id'").join(', ');

  static List<String> _datasetsDesde(DateTime? publicado) {
    final actual = DateTime.now().year;
    final desde = (publicado?.year ?? actual - 1).clamp(2021, actual);
    return {
      for (var a = desde; a <= actual; a++)
        _archivosPorAnio[a.clamp(2021, 2026)]!,
    }.toList();
  }

  /// Consulta las novedades y los proponentes del proceso. Cada fuente se
  /// consulta por separado: si una falla, se muestra la otra. Solo lanza un
  /// error si fallan las dos.
  static Future<NovedadesProceso> consultar(
    ProcesoSecop proceso,
    List<ProcesoSecop> fases,
  ) async {
    final portafolio = proceso.portafolio;
    final ids = {
      for (final f in [proceso, ...fases]) '${f.fila['id_del_proceso'] ?? ''}',
    }.where(_idValido.hasMatch).toList();

    Future<List<NovedadProceso>?> documentos() async {
      if (!_idValido.hasMatch(portafolio)) return const [];
      try {
        final respuestas = await Future.wait([
          for (final ds in _datasetsDesde(proceso.publicado))
            DatosAbiertos.filas(ds, {
              r'$select': 'nombre_archivo, fecha_carga, url_descarga_documento',
              r'$where': "proceso = '$portafolio'",
              r'$limit': '1000',
            }, timeout: const Duration(seconds: 15)),
        ]);
        return depurar(respuestas.expand((r) => r));
      } catch (_) {
        return null;
      }
    }

    Future<List<ProponenteProceso>?> proponentes() async {
      if (ids.isEmpty) return const [];
      try {
        final filas = await DatosAbiertos.filas(_proponentes, {
          r'$select': 'proveedor, nit_proveedor, fecha_publicaci_n',
          r'$where': 'id_procedimiento in (${_lista(ids)})',
          r'$limit': '500',
        }, timeout: const Duration(seconds: 15));
        return proponentesUnicos(filas);
      } catch (_) {
        return null;
      }
    }

    final (novedades, oferentes) = await (documentos(), proponentes()).wait;
    if (novedades == null && oferentes == null) {
      throw StateError('No respondió Datos Abiertos');
    }
    return NovedadesProceso(
      novedades: novedades ?? const [],
      proponentes: oferentes ?? const [],
    );
  }
}
