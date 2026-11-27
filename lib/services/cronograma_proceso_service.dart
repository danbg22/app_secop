import '../utils/banderas_control.dart';
import 'datos_abiertos.dart';

/// Una fecha del cronograma de un proceso en SECOP II.
class FechaCronograma {
  const FechaCronograma({
    required this.nombre,
    required this.fecha,
    this.observaciones = false,
  });

  final String nombre;

  /// Hora de Colombia.
  final DateTime fecha;

  /// Plazo relacionado con las observaciones de los interesados.
  final bool observaciones;
}

/// Cronograma de un proceso a partir de "SECOPII - Fechas Cronograma"
/// (f3ev-294c). Trae las fechas, no el texto de las observaciones: ese solo
/// está en la página del proceso en SECOP II.
class CronogramaProcesoService {
  CronogramaProcesoService._();

  static const _dataset = 'f3ev-294c';

  /// Nombre de cada columna cuyo significado es claro. Las demás columnas
  /// del conjunto (fechas "previstas", plazos sin descripción) se omiten
  /// para no mostrar un nombre equivocado.
  static const Map<String, String> _columnas = {
    'publicaci_n_aviso_convocatoria': 'Aviso de convocatoria',
    'publicaci_n_del_aviso_de': 'Aviso de convocatoria',
    'publicaci_n_estudios_previos': 'Publicación de estudios previos',
    'publicaci_n_de_estudios': 'Publicación de estudios previos',
    'publicaci_n_de_la_invitaci': 'Publicación de la invitación',
    'expedici_n_y_publicaci_n': 'Acto de apertura y pliego definitivo',
    'plazo_para_manifestaci_n': 'Manifestación de interés',
    'realizaci_n_del_sorteo': 'Sorteo de interesados',
    'respuesta_a_las_observaciones_1': 'Respuesta a las observaciones',
    'respuesta_a_las_observaciones_3': 'Respuesta a las observaciones',
    'fecha_l_mite_para_responder': 'Límite para responder observaciones',
    'plazo_m_ximo_para_expedir': 'Plazo máximo para expedir adendas',
    'presentaci_n_de_ofertas': 'Cierre: presentación de ofertas',
    'fecha_de_apertura_de_ofertas': 'Apertura de ofertas',
    'fecha_apertura_de_sobres': 'Apertura de ofertas',
    'informe_de_presentaci_n_de': 'Lista de oferentes',
    'publicaci_n_de_la_lista_de': 'Lista de oferentes',
    'publicaci_n_del_informe_de': 'Publicación del informe de evaluación',
    'fecha_audiencia_de_adjudicaci': 'Audiencia de adjudicación',
    'publicaci_n_acto': 'Acto de adjudicación o declaratoria de desierto',
    'fecha_de_aceptaci_n_de_ofertas': 'Aceptación de la oferta',
    'fecha_de_firma_del_contrato': 'Firma del contrato',
    'fecha_entrega_garant_a': 'Entrega de garantías',
    'fecha_aprobaci_n_garant_as': 'Aprobación de garantías',
  };

  static const _observaciones = [
    'presentaci_n_de_observaciones',
    'presentaci_n_de_observaciones_1',
    'presentaci_n_de_observaciones_2',
    'presentaci_n_de_observaciones_3',
  ];

  /// Las fechas del conjunto están en UTC; Colombia es UTC-5 todo el año.
  static DateTime? _hora(Object? valor) {
    final t = '${valor ?? ''}'.trim();
    if (t.isEmpty) return null;
    final f = DateTime.tryParse(
      '${t.replaceFirst(' ', 'T').split('.').first}Z',
    );
    return f?.subtract(const Duration(hours: 5));
  }

  /// Une las filas del proceso (SECOP II publica una por fase): para cada
  /// fecha se queda la de la fase publicada más recientemente.
  static List<FechaCronograma> desdeFilas(List<Map<String, dynamic>> filas) {
    final ordenadas = [...filas]
      ..sort(
        (a, b) => '${a['fecha_de_publicaci_n'] ?? ''}'.compareTo(
          '${b['fecha_de_publicaci_n'] ?? ''}',
        ),
      );
    final valores = <String, Object?>{};
    for (final f in ordenadas) {
      for (final e in f.entries) {
        if (e.value != null && '${e.value}'.trim().isNotEmpty) {
          valores[e.key] = e.value;
        }
      }
    }
    final informe = _hora(valores['publicaci_n_del_informe_de']);
    final fechas = <FechaCronograma>[];
    final vistos = <String>{};
    void agregar(String nombre, DateTime? fecha, {bool obs = false}) {
      if (fecha == null) return;
      if (!vistos.add('$nombre|${fecha.millisecondsSinceEpoch}')) return;
      fechas.add(
        FechaCronograma(nombre: nombre, fecha: fecha, observaciones: obs),
      );
    }

    for (final c in _observaciones) {
      final f = _hora(valores[c]);
      if (f == null) continue;
      final alInforme = informe != null && !f.isBefore(informe);
      agregar(
        alInforme
            ? 'Observaciones al informe de evaluación'
            : 'Observaciones a los documentos del proceso',
        f,
        obs: true,
      );
    }
    for (final e in _columnas.entries) {
      agregar(
        e.value,
        _hora(valores[e.key]),
        obs: e.value.contains('observaciones'),
      );
    }
    fechas.sort((a, b) => a.fecha.compareTo(b.fecha));
    return fechas;
  }

  static Future<List<FechaCronograma>> consultar(String portafolio) async {
    if (!RegExp(r'^CO1\.[A-Z]+\.\d+$').hasMatch(portafolio)) return const [];
    final filas = await DatosAbiertos.filas(_dataset, {
      r'$where': "proceso_de_compra = '$portafolio'",
      r'$limit': '20',
    }, timeout: const Duration(seconds: 15));
    return desdeFilas(filas);
  }

  /// Fecha (solo el día) de un valor del conjunto. Algunas columnas vienen
  /// en hora de Colombia y otras en UTC; para comparar días basta el día.
  static DateTime? _dia(Object? valor) {
    final t = '${valor ?? ''}'.trim();
    if (t.length < 10) return null;
    return DateTime.tryParse(t.substring(0, 10));
  }

  static DateTime? _primera(Iterable<DateTime?> fechas) {
    final validas = fechas.whereType<DateTime>().toList()..sort();
    return validas.isEmpty ? null : validas.first;
  }

  /// Publicación y firma prevista de cada proceso (por `proceso_de_compra`),
  /// para no confundir la fecha en que se completó la firma electrónica con
  /// la fecha en que empezó la contratación.
  static Future<Map<String, InicioProceso>> iniciosDeProcesos(
    Iterable<String> portafolios,
  ) async {
    final ids = {
      for (final p in portafolios)
        if (RegExp(r'^CO1\.[A-Z]+\.\d+$').hasMatch(p)) p,
    }.toList();
    final res = <String, InicioProceso>{};
    for (var i = 0; i < ids.length; i += 40) {
      final lote = ids.skip(i).take(40);
      final filas = await DatosAbiertos.filas(_dataset, {
        r'$select':
            'proceso_de_compra, fecha_de_publicaci_n, fecha_de_publicaci_n_del_2, '
            'firma_del_contrato, fecha_de_firma_del_contrato',
        r'$where':
            'proceso_de_compra in (${lote.map((p) => "'$p'").join(',')})',
        r'$limit': '500',
      }, timeout: const Duration(seconds: 20));
      for (final f in filas) {
        final id = '${f['proceso_de_compra'] ?? ''}';
        final previa = res[id];
        res[id] = InicioProceso(
          publicacion: _primera([
            previa?.publicacion,
            _dia(f['fecha_de_publicaci_n']),
            _dia(f['fecha_de_publicaci_n_del_2']),
          ]),
          firmaPrevista: _primera([
            previa?.firmaPrevista,
            _dia(f['firma_del_contrato']),
            _dia(f['fecha_de_firma_del_contrato']),
          ]),
        );
      }
    }
    return res;
  }
}
