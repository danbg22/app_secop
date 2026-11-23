import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';
import 'consent_service.dart';
import 'pqrs_service.dart';

class SolicitudBuzon {
  SolicitudBuzon(QueryDocumentSnapshot<Map<String, dynamic>> doc)
    : _ref = doc.reference,
      radicado = doc.id,
      solicitud = PqrsRecord.fromMap({...doc.data(), 'radicado': doc.id}),
      uid = (doc.data()['uid'] ?? '').toString(),
      creada = doc.data()['fecha_creacion'] is Timestamp
          ? (doc.data()['fecha_creacion'] as Timestamp).toDate()
          : DateTime.tryParse(
              (doc.data()['fecha_cliente_iso'] ?? '').toString(),
            ),
      _datos = doc.data();

  final DocumentReference<Map<String, dynamic>> _ref;
  final Map<String, dynamic> _datos;
  final String radicado;
  final PqrsRecord solicitud;
  final String uid;
  final DateTime? creada;

  String get respuesta => (_respuestaDatos?['texto'] ?? '').toString();
  Map? get _respuestaDatos =>
      _datos['respuesta'] is Map ? _datos['respuesta'] as Map : null;
  Timestamp? get _fechaRespuesta => _respuestaDatos?['enviada_en'] is Timestamp
      ? _respuestaDatos!['enviada_en'] as Timestamp
      : null;
  DateTime? get respondida => _fechaRespuesta?.toDate();
  bool get tieneRespuesta => respuesta.isNotEmpty;
  bool get sinLeer =>
      tieneRespuesta &&
      _fechaRespuesta != null &&
      _datos['respuesta_leida_en'] != _fechaRespuesta;
  bool get _esGlobal => _ref.parent.parent == null;

  String get _clave => '$uid|$radicado';
}

abstract final class PqrsBandejaService {
  static CollectionReference<Map<String, dynamic>> get _global =>
      FirebaseFirestore.instance.collection(PqrsService.coleccionGlobalPqrs);

  static Stream<({List<SolicitudBuzon> mensajes, bool hayMas, bool soloGlobal})>
  consultaAdministrativa(int limite, User admin) async* {
    final grupo = FirebaseFirestore.instance.collectionGroup(
      PqrsService.coleccionGlobalPqrs,
    );
    final ordenada = grupo.orderBy('fecha_creacion', descending: true);
    try {
      await for (final lote in _escucharAdmin(
        ordenada.limit(limite + 1),
        limite,
      )) {
        yield lote;
      }
      return;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' &&
          FirebaseAuth.instance.currentUser?.uid == admin.uid) {
        await admin.getIdToken(true).timeout(const Duration(seconds: 8));
      } else if (e.code != 'failed-precondition') {
        rethrow;
      }
    }
    try {
      // Incluye radicados históricos aunque el índice todavía se esté creando.
      await for (final lote in _escucharAdmin(grupo, limite)) {
        yield lote;
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied' && e.code != 'failed-precondition') {
        rethrow;
      }
      yield* _escucharAdmin(
        _global.orderBy('fecha_creacion', descending: true).limit(limite + 1),
        limite,
        soloGlobal: true,
      );
    }
  }

  static Stream<({List<SolicitudBuzon> mensajes, bool hayMas, bool soloGlobal})>
  _escucharAdmin(
    Query<Map<String, dynamic>> consulta,
    int limite, {
    bool soloGlobal = false,
  }) async* {
    // Una respuesta del caché no confirma permisos ni disponibilidad.
    var confirmada = false;
    final lecturas = consulta
        .snapshots(includeMetadataChanges: true)
        .where((datos) => !datos.metadata.isFromCache)
        .timeout(
          const Duration(seconds: 12),
          onTimeout: (salida) {
            if (confirmada) return;
            salida.addError(TimeoutException('No se confirmó el buzón.'));
            salida.close();
          },
        );
    await for (final datos in lecturas) {
      confirmada = true;
      final mensajes = agrupar(datos.docs);
      yield (
        mensajes: mensajes.take(limite).toList(),
        hayMas: datos.docs.length > limite,
        soloGlobal: soloGlobal,
      );
    }
  }

  static List<SolicitudBuzon> agrupar(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final porRadicado = <String, SolicitudBuzon>{};
    for (final d in docs) {
      final item = SolicitudBuzon(d);
      final anterior = porRadicado[item._clave];
      if (anterior == null ||
          (!anterior.tieneRespuesta && item.tieneRespuesta) ||
          (anterior.tieneRespuesta == item.tieneRespuesta && item._esGlobal)) {
        porRadicado[item._clave] = item;
      }
    }
    return porRadicado.values.toList()..sort(
      (a, b) => (b.creada?.millisecondsSinceEpoch ?? 0).compareTo(
        a.creada?.millisecondsSinceEpoch ?? 0,
      ),
    );
  }

  static Stream<List<SolicitudBuzon>> misSolicitudes(String uid) =>
      Stream.multi((destino) {
        final espejo = FirebaseFirestore.instance
            .collection(ConsentService.coleccionUsuarios)
            .doc(uid)
            .collection(PqrsService.subcoleccionUsuarioPqrs);
        final fuentes = <Query<Map<String, dynamic>>>[
          _global.where('uid', isEqualTo: uid),
          espejo,
        ];
        final documentos =
            <int, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
        final escuchas = <StreamSubscription>[];

        for (final (i, fuente) in fuentes.indexed) {
          escuchas.add(
            fuente.snapshots().listen((snap) {
              documentos[i] = snap.docs;
              if (documentos.length == fuentes.length) {
                destino.add(agrupar(documentos.values.expand((d) => d)));
              }
            }, onError: destino.addError),
          );
        }
        destino.onCancel = () =>
            Future.wait(escuchas.map((sub) => sub.cancel()));
      });

  static Future<void> responder(SolicitudBuzon ticket, String respuesta) async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null || !AuthService.isActiveUserAdmin) {
      throw StateError('Esta acción requiere una cuenta administradora.');
    }
    final texto = respuesta.trim();
    if (texto.length < 3 || texto.length > 3000) {
      throw ArgumentError('La respuesta debe tener entre 3 y 3000 caracteres.');
    }

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final global = _global.doc(ticket.radicado);
      final canonica = await tx.get(global);
      final usaGlobal =
          canonica.exists && canonica.data()?['uid'] == ticket.uid;
      final original = usaGlobal ? canonica : await tx.get(ticket._ref);
      if (!original.exists || original.data()?['uid'] != ticket.uid) {
        throw StateError('El radicado ya no está disponible.');
      }
      if (original.data()?['respuesta'] != null) {
        throw StateError('El radicado ya fue respondido.');
      }
      tx.update(original.reference, {
        'estado': 'Respondido',
        'respuesta': {
          'texto': texto,
          'enviada_en': FieldValue.serverTimestamp(),
          'autor_uid': usuario.uid,
        },
      });
    });
  }

  static Future<void> marcarLeida(SolicitudBuzon mensaje) async {
    final fecha = mensaje._fechaRespuesta;
    if (!mensaje.sinLeer ||
        fecha == null ||
        FirebaseAuth.instance.currentUser?.uid != mensaje.uid) {
      return;
    }
    await mensaje._ref.update({'respuesta_leida_en': fecha});
  }
}
