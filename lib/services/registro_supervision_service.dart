part of 'supervision_service.dart';

enum PerfilSupervision {
  supervisor('Supervisor', 'supervisor_contratos'),
  contratista('Contratista', 'contratista'),
  juridico('Jurídico', 'juridico_supervision');

  const PerfilSupervision(this.nombre, this.rol);
  final String nombre;
  final String rol;
}

/// Entrada del directorio: el NIT identifica a la entidad y el UID al
/// supervisor, incluso si hay dos personas en una misma dependencia.
class DestinoSupervision {
  const DestinoSupervision(
    this.uid,
    this.nit,
    this.entidad,
    this.dependencia,
    this.supervisor,
  );

  final String uid, nit, entidad, dependencia, supervisor;

  Map<String, dynamic> toMap() => {
    'entidadNit': nit,
    'entidadNombre': entidad,
    'dependencia': dependencia,
    'supervisorNombre': supervisor,
  };

  factory DestinoSupervision.fromMap(String uid, Map<String, dynamic> datos) =>
      DestinoSupervision(
        uid,
        datos['entidadNit'],
        datos['entidadNombre'],
        datos['dependencia'],
        datos['supervisorNombre'],
      );
}

class RegistroSupervisionService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String get uid => FirebaseAuth.instance.currentUser!.uid;
  static DocumentReference<Map<String, dynamic>> get _perfil =>
      _db.collection('perfiles_supervision').doc(uid);

  static String? nitEntidad(String valor) {
    if (!RegExp(r'^[0-9.\s-]+$').hasMatch(valor.trim())) return null;
    final formas = Nit.formasNumericas(valor);
    return formas.isNotEmpty && formas.first.length == 9 ? formas.first : null;
  }

  static Stream<Map<String, dynamic>?> perfil() =>
      _perfil.snapshots().map((s) => s.data());

  static Stream<List<String>> designacionesJuridicas() => _db
      .collection('juridicos_supervision')
      .where('email', isEqualTo: SupervisionService.emailActual)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            '${d['entidadNombre']} · ${d['dependencia']} · ${d['supervisorNombre']}',
        ],
      );

  static CollectionReference<Map<String, dynamic>> _directorio(String nit) =>
      _db
          .collection('directorio_supervision')
          .doc(nit)
          .collection('supervisores');

  static Future<List<DestinoSupervision>> buscar(String nit) async {
    final q = await _directorio(nit)
        .get(const GetOptions(source: Source.server));
    return [for (final d in q.docs) DestinoSupervision.fromMap(d.id, d.data())]
      ..sort(
        (a, b) => '${a.dependencia} ${a.supervisor}'.compareTo(
          '${b.dependencia} ${b.supervisor}',
        ),
      );
  }

  static Future<void> guardarPerfil({
    int? versionAnterior,
    required DestinoSupervision destino,
    required String vinculacion,
    required String referencia,
    required String fecha,
    required String cargoObjeto,
    required Map<String, dynamic> datosContrato,
    required String juridicoNombre,
    required String juridicoEmail,
  }) => SupervisionService._guardar(
    () => _db.runTransaction((tx) async {
      final perfilRef = _perfil;
      final actual = (await tx.get(perfilRef)).data();
      if (actual != null && versionAnterior == null) return;
      if (versionAnterior != null &&
          versionAnterior != (actual?['version'] ?? 0)) {
        throw const SupervisionException(
          'El perfil cambió. Vuelve a abrirlo para editar la última versión.',
        );
      }
      final plantillaRef = SupervisionService._refPlantilla(uid);
      final previa = (await tx.get(plantillaRef)).data();
      final plantilla = previa == null
          ? PlantillaInforme.porDefecto(destino.entidad)
          : PlantillaInforme.fromMap(previa);
      final inicial = plantilla.copyWith(
        etapas: [
          for (final etapa in plantilla.etapas)
            if (etapa.id == 'supervisor' && etapa.responsableEmail.isEmpty)
              etapa.copyWith(
                responsableNombre: destino.supervisor,
                responsableEmail: SupervisionService.emailActual,
              )
            else if (etapa.id == 'juridico' &&
                (actual == null ||
                    etapa.esResponsable(actual['juridicoEmail'])))
              etapa.copyWith(
                responsableNombre: juridicoNombre,
                responsableEmail: juridicoEmail,
              )
            else
              etapa,
          if (actual == null &&
              plantilla.etapas.length < 5 &&
              !plantilla.etapas.any(
                (e) => e.esResponsable(juridicoEmail) || e.id == 'juridico',
              ))
            EtapaAprobacion(
              id: 'juridico',
              nombre: 'Revisión jurídica',
              responsableNombre: juridicoNombre,
              responsableEmail: juridicoEmail,
            ),
        ],
      );
      if (actual != null && actual['entidadNit'] != destino.nit) {
        tx.delete(_directorio(actual['entidadNit']).doc(uid));
      }
      tx.set(perfilRef, {
        'version': (versionAnterior ?? 0) + 1,
        'juridicoEmail': juridicoEmail,
        'juridicoNombre': juridicoNombre,
        ...destino.toMap(),
        'vinculacion': vinculacion,
        'referencia': referencia,
        'fecha': fecha,
        'cargoObjeto': cargoObjeto,
        if (vinculacion == 'contrato') ...datosContrato,
      });
      tx.set(_directorio(destino.nit).doc(uid), destino.toMap());
      tx.set(_db.collection('juridicos_supervision').doc(uid), {
        ...destino.toMap(),
        'nombre': juridicoNombre,
        'email': juridicoEmail,
      });
      tx.set(plantillaRef, inicial.toMap());
    }),
  );

  static String idContrato(String contratista, String nit, String numero) =>
      'sc_${SecurityService.sha256Hex(jsonEncode([contratista, nit, numero.trim().toUpperCase()]))}';

  static Future<void> registrarContrato({
    required DestinoSupervision destino,
    required String numero,
    required String objeto,
    required String aprobacion,
    required int valor,
    required String duracion,
    required String formaPago,
    required String rp,
    required String cdp,
  }) async {
    final usuario = await AuthService.getActiveUserProfile();
    final token = idContrato(uid, destino.nit, numero);
    final ref = SupervisionService._expediente(token);
    await SupervisionService._guardar(
      () => _db.runTransaction((tx) async {
        if ((await tx.get(ref)).exists) {
          throw const SupervisionException(
            'Ya registraste ese número de contrato para esta entidad.',
          );
        }
        tx.set(ref, {
          ...destino.toMap(),
          'id': token,
          'tokenInvitado': token,
          'contratistaUid': uid,
          'supervisorUid': destino.uid,
          'revisoresEmails': <String>[],
          'contratistaNombreEsperado': AuthService.getActiveUserDisplayName(),
          'contratistaCedulaEsperada': usuario['documento'] ?? '',
          'contratistaCorreo': SupervisionService.emailActual,
          'numeroContrato': numero,
          'objetoContrato': objeto,
          'aprobacionSecop': aprobacion,
          'valorContratoCop': valor,
          'plazoEjecucion': duracion,
          'formaPago': formaPago,
          'rp': rp,
          'cdp': cdp,
        });
      }),
    );
  }

  static Future<ExpedienteContratoPs> corregirContrato(
    ExpedienteContratoPs exp,
    Map<String, dynamic> cambios,
  ) async {
    if (!SupervisionService.esSupervisor(exp)) {
      throw const SupervisionException(
        'Solo el supervisor puede corregir los datos del contrato.',
      );
    }
    final ref = SupervisionService._expediente(exp.id);
    return SupervisionService._guardar(
      () => _db.runTransaction((tx) async {
        final actual = (await tx.get(ref)).data();
        if (actual == null) {
          throw const SupervisionException(
            'El contrato ya no está disponible.',
          );
        }
        final anterior = exp.toMap();
        if (cambios.keys.any((campo) => actual[campo] != anterior[campo])) {
          throw const SupervisionException(
            'Los datos cambiaron. Vuelve a abrir el contrato para ver la última versión.',
          );
        }
        tx.update(ref, cambios);
        return ExpedienteContratoPs.fromMap({...actual, ...cambios});
      }),
    );
  }

  static Stream<List<ExpedienteContratoPs>> contratos(
    PerfilSupervision perfil,
  ) {
    final col = _db.collection('contratos_supervision');
    final q = switch (perfil) {
      PerfilSupervision.supervisor => col.where(
        'supervisorUid',
        isEqualTo: uid,
      ),
      PerfilSupervision.contratista => col.where(
        'contratistaUid',
        isEqualTo: uid,
      ),
      PerfilSupervision.juridico => col.where(
        'revisoresEmails',
        arrayContains: SupervisionService.emailActual,
      ),
    };
    return q.snapshots().map(
      (s) =>
          [for (final doc in s.docs) _desdeContrato(doc, perfil)]
            ..sort((a, b) => a.numeroContrato.compareTo(b.numeroContrato)),
    );
  }

  static ExpedienteContratoPs _desdeContrato(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    PerfilSupervision perfil,
  ) {
    final d = doc.data();
    final exp = ExpedienteContratoPs.fromMap(d);
    if (perfil != PerfilSupervision.contratista) {
      SupervisionService._asignacionesConocidas[doc.id] =
          AsignacionSupervision.fromMap({
            ...d,
            'token': doc.id,
            if (perfil == PerfilSupervision.supervisor)
              'supervisorEmail': SupervisionService.emailActual,
          });
    }
    return exp;
  }
}
