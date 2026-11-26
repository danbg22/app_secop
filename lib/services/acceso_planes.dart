import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'admin_access.dart';
import 'payment_service.dart';
import 'registro_cedula.dart';

class RenovacionPlan {
  const RenovacionPlan(this.estado, this.fecha, this.cancelaDespues);

  final String estado;
  final DateTime? fecha;
  final bool cancelaDespues;
  bool get activa => estado == 'activa';
  bool get pendiente =>
      {'registrando', 'verificando', 'revision'}.contains(estado);

  factory RenovacionPlan.desdeMapa(Map datos) {
    final ms = datos['renovacion'];
    return RenovacionPlan(
      datos['estado'] as String? ?? '',
      ms is int && ms > 0
          ? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)
          : null,
      datos['cancelaDespues'] == true,
    );
  }
}

class EstadoPlanes {
  EstadoPlanes(Map<String, dynamic> datos)
    : _ahoraServidor = datos['ahora'] as int,
      _roles = Set<String>.from(datos['roles'] as List),
      _historicos = Set<String>.from(datos['historicos'] as List),
      _accesosAnteriores = Set<String>.from(
        datos['accesosAnteriores'] as List? ?? const [],
      ),
      _pagadosHasta = Map<String, int>.from(datos['pagadosHasta'] as Map),
      rolInicial = datos['rolInicial'] as String,
      rolPrueba = datos['pruebaRol'] as String?,
      _pruebaHasta = datos['pruebaHasta'] as int,
      _equipoHasta = datos['graciaEquipoHasta'] as int,
      preparando = datos['preparando'] == true,
      renovaciones = {
        if (datos['renovaciones'] case final Map mapa)
          for (final entrada in mapa.entries)
            if (entrada.value is Map)
              entrada.key.toString(): RenovacionPlan.desdeMapa(
                entrada.value as Map,
              ),
      },
      admin = datos['esAdmin'] == true {
    _reloj.start();
  }

  factory EstadoPlanes.desdeFirestore({
    required Map<String, dynamic> perfil,
    required Map<String, dynamic>? acceso,
    required bool cuentaAnterior,
    required DateTime ahora,
  }) {
    int ms(Object? valor) =>
        valor is Timestamp ? valor.millisecondsSinceEpoch : 0;
    final rolInicial = PaymentService.normalizarRolId(
      (acceso?['rolInicial'] ??
              perfil['rolRegistroCedula'] ??
              perfil['rolInicialRegistro'] ??
              perfil['rolSolicitadoRegistro'])
          ?.toString(),
    );
    final activos =
        (perfil['rolesActivos'] as List?)?.whereType<String>() ??
        const <String>[];
    final historicos = <String>{
      if (acceso != null)
        ...(acceso['historicos'] as List? ?? const []).whereType<String>()
      else if (perfil['pagoWompiActivo'] == true)
        ...activos.where(_pagos.contains),
    };
    final conservaConsulta =
        acceso == null && cuentaAnterior && perfil['registroCedulaEn'] == null;
    final fechaRegistro = ms(perfil['registroCedulaEn']);
    final finPrueba = acceso != null
        ? ms(acceso['pruebaHasta'])
        : (fechaRegistro > 0 && _pagos.contains(rolInicial)
              ? fechaRegistro + const Duration(days: 30).inMilliseconds
              : 0);
    final rolPrueba = acceso != null
        ? acceso['pruebaRol'] as String?
        : (finPrueba > 0 ? rolInicial : null);
    final pagados = {
      for (final entrada
          in (acceso?['pagadosHasta'] as Map? ?? const {}).entries)
        entrada.key.toString(): ms(entrada.value),
    };
    return EstadoPlanes({
      'ahora': ahora.millisecondsSinceEpoch,
      'roles': {
        if (conservaConsulta) 'persona',
        ...historicos,
        ...pagados.keys,
        ...activos.where((rol) => !_pagos.contains(rol)),
        ?rolPrueba,
      }.toList(),
      'historicos': historicos.toList(),
      'accesosAnteriores': [if (conservaConsulta) 'persona'],
      'pagadosHasta': pagados,
      'rolInicial': rolInicial,
      'pruebaRol': rolPrueba,
      'pruebaHasta': finPrueba,
      'graciaEquipoHasta': 0,
      'preparando':
          !cuentaAnterior &&
          !RegistroCedula.completado(perfil) &&
          acceso == null,
    });
  }

  final _reloj = Stopwatch();
  final int _ahoraServidor;
  final Set<String> _roles;
  final Set<String> _historicos;
  final Set<String> _accesosAnteriores;
  final Map<String, int> _pagadosHasta;
  final int _pruebaHasta;
  final int _equipoHasta;
  final String rolInicial;
  final String? rolPrueba;
  final bool preparando;
  final bool admin;
  final Map<String, RenovacionPlan> renovaciones;

  int get _ahora => _ahoraServidor + _reloj.elapsedMilliseconds;
  int get _restantePrueba => _pruebaHasta - _ahora;
  bool get enPrueba => !admin && rolPrueba != null && _restantePrueba > 0;
  bool get bloqueoConfirmado => _roles.isEmpty && !preparando;
  bool get pruebaVencida => rolPrueba != null && _restantePrueba <= 0;
  int get diasPrueba =>
      enPrueba ? (_restantePrueba / Duration.millisecondsPerDay).ceil() : 0;

  DateTime get fechaFinPrueba =>
      DateTime.fromMillisecondsSinceEpoch(_pruebaHasta, isUtc: true);

  bool tienePagoMensual(String rol) => (_pagadosHasta[rol] ?? 0) > _ahora;

  DateTime? finPagoMensual(String rol) {
    final ms = _pagadosHasta[rol] ?? 0;
    return ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true) : null;
  }

  String? get planPorRenovar {
    if (admin) return null;
    final ahora = _ahora;
    var limite = ahora + const Duration(days: 7).inMilliseconds;
    String? plan;
    for (final pago in _pagadosHasta.entries) {
      final renovacion = renovaciones[pago.key];
      if (pago.value <= ahora ||
          pago.value > limite ||
          _historicos.contains(pago.key) ||
          renovacion?.activa == true ||
          renovacion?.pendiente == true) {
        continue;
      }
      plan = pago.key;
      limite = pago.value;
    }
    return plan;
  }

  bool tieneSuscripcionVigente(String rol) =>
      _historicos.contains(rol) || (_pagadosHasta[rol] ?? 0) > _ahora;

  static const _pagos = {'persona', 'equipo_juridico', 'supervisor_contratos'};

  Set<String> get roles {
    final ahora = _ahora;
    bool propio(String rol) =>
        admin ||
        _accesosAnteriores.contains(rol) ||
        _historicos.contains(rol) ||
        (_pagadosHasta[rol] ?? 0) > ahora ||
        (rol == rolPrueba && _pruebaHasta > ahora);
    final puedeUsarGratis = !_pagos.contains(rolInicial) || _roles.any(propio);
    return _roles.where((rol) {
      if (!_pagos.contains(rol)) return puedeUsarGratis;
      return propio(rol) || (rol == 'equipo_juridico' && _equipoHasta > ahora);
    }).toSet();
  }

  Duration proximaRevision(Duration intervalo) {
    final ahora = _ahora;
    var restante = intervalo.inMilliseconds;
    for (final fin in [
      if (rolPrueba != null) _pruebaHasta,
      _equipoHasta,
      ..._pagadosHasta.values,
    ]) {
      final diferencia = fin - ahora;
      if (diferencia > 0 && diferencia < restante) restante = diferencia;
    }
    return Duration(milliseconds: restante + 25);
  }
}

class AccesoPlanesException implements Exception {
  const AccesoPlanesException(this.mensaje, {this.codigo});
  final String mensaje;
  final String? codigo;
}

abstract final class AccesoPlanes {
  static final cambios = ValueNotifier<int>(0);
  static const _endpoint = String.fromEnvironment(
    'ACCESO_PLAN_URL',
    defaultValue: 'https://contratalegal.com/api/planes',
  );
  static const pagosEnLineaDisponibles = bool.fromEnvironment(
    'PAGOS_WOMPI_EN_LINEA',
  );
  static DateTime? _horaServidor;
  static final _relojServidor = Stopwatch();
  static String? _uid;
  static int _sesion = 0;
  static EstadoPlanes? _estado;
  static Future<void>? _enCurso;
  static Timer? _timer;
  static bool _iniciado = false;
  static bool _hayError = false;
  static bool _revisando = false;

  static String? get uid => _uid;
  static EstadoPlanes? get estado =>
      _uid == FirebaseAuth.instance.currentUser?.uid ? _estado : null;
  static bool get hayError => _hayError;
  static bool get revisando => _revisando;

  static void iniciar() {
    if (_iniciado) return;
    _iniciado = true;
    FirebaseAuth.instance.userChanges().listen((user) {
      if (user?.uid != _uid) {
        _uid = user?.uid;
        _sesion++;
        _estado = null;
        _horaServidor = null;
        _relojServidor
          ..stop()
          ..reset();
        _hayError = false;
        _revisando = false;
        _enCurso = null;
        _timer?.cancel();
        _notificar();
      }
      if (user != null) unawaited(refrescar());
    });
  }

  static Future<void> actualizarTrasRegistro() async {
    await refrescar();
    if (estado?.preparando != false) await refrescar();
  }

  static Future<void> refrescar() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != _uid) return Future.value();
    final anterior = _enCurso;
    if (anterior != null) return anterior;
    final sesion = _sesion;
    final trabajo = Future<void>.microtask(() => _obtenerEstado(user, sesion));
    _enCurso = trabajo;
    return trabajo;
  }

  static Future<void> _obtenerEstado(User user, int sesion) async {
    if (_sesion != sesion) return;
    _timer?.cancel();
    _revisando = true;
    _notificar();
    try {
      final nuevo = pagosEnLineaDisponibles
          ? EstadoPlanes(await _consultar(user, {'accion': 'estado'}))
          : await _leerPlanesConReintento(user, sesion);
      if (_sesion != sesion) return;
      _estado = nuevo;
      _hayError = false;
    } catch (_) {
      if (_sesion != sesion) return;
      _hayError = true;
    } finally {
      if (_sesion == sesion) {
        _revisando = false;
        _enCurso = null;
        _notificar();
        final estado = _estado;
        final proxima = (estado == null || estado.preparando)
            ? const Duration(seconds: 20)
            : estado.proximaRevision(
                Duration(minutes: pagosEnLineaDisponibles ? 1 : 5),
              );
        _timer = Timer(proxima, () => unawaited(refrescar()));
      }
    }
  }

  static Future<EstadoPlanes> _leerPlanesConReintento(
    User user,
    int sesion,
  ) async {
    try {
      return await _obtenerEstadoFirestore(user, sesion);
    } catch (error) {
      final transitorio =
          error is TimeoutException ||
          (error is FirebaseException &&
              const {
                'unavailable',
                'deadline-exceeded',
                'aborted',
                'network-request-failed',
              }.contains(error.code));
      if (!transitorio || _sesion != sesion) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (_sesion != sesion) rethrow;
      return _obtenerEstadoFirestore(user, sesion);
    }
  }

  static Future<EstadoPlanes> _obtenerEstadoFirestore(
    User user,
    int sesion,
  ) async {
    final db = FirebaseFirestore.instance;
    const servidor = GetOptions(source: Source.server);
    final uid = user.uid;

    if (AdminAccess.esAdministradorVerificado(
      user.email,
      correoVerificado: user.emailVerified,
    )) {
      return EstadoPlanes({
        'ahora': DateTime.now().millisecondsSinceEpoch,
        'roles': AdminAccess.todosLosRoles,
        'historicos': [],
        'pagadosHasta': <String, int>{},
        'rolInicial': 'persona',
        'pruebaHasta': 0,
        'graciaEquipoHasta': 0,
        'esAdmin': true,
      });
    }

    final registros = await Future.wait([
      db.collection('usuarios').doc(uid).get(servidor),
      db.collection('accesos_planes').doc(uid).get(servidor),
      db.collection('accesos_anteriores').doc(uid).get(servidor),
    ]).timeout(const Duration(seconds: 8));
    final perfil = registros[0].data() ?? <String, dynamic>{};
    final acceso = registros[1].data();
    if (_sesion == sesion &&
        (acceso != null || perfil['registroCedulaEn'] is Timestamp) &&
        _horaServidor == null) {
      final ref = db.collection('relojes_acceso').doc(uid);
      await ref
          .set({'ahora': FieldValue.serverTimestamp()})
          .timeout(const Duration(seconds: 8));
      final tiempo =
          (await ref.get(servidor).timeout(const Duration(seconds: 8)))
                  .data()?['ahora']
              as Timestamp;
      if (_sesion == sesion) {
        _horaServidor = tiempo.toDate();
        _relojServidor
          ..reset()
          ..start();
      }
    }
    return EstadoPlanes.desdeFirestore(
      perfil: perfil,
      acceso: acceso,
      cuentaAnterior: registros[2].data()?['exentoCedula'] == true,
      ahora: _horaServidor?.add(_relojServidor.elapsed) ?? DateTime.now(),
    );
  }

  static Future<Map<String, dynamic>> _consultar(
    User user,
    Map<String, String> datos,
  ) async {
    final token = await user.getIdToken().timeout(const Duration(seconds: 10));
    final respuesta = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'data': datos}),
        )
        .timeout(const Duration(seconds: 45));
    final mapa = _respuestaJson(respuesta.body);
    final resultado = mapa?['result'];
    if (respuesta.statusCode != 200 || resultado is! Map<String, dynamic>) {
      final error = mapa?['error'];
      final codigo = error is Map ? error['status'] : null;
      if (codigo is! String &&
          const {404, 502, 503, 504}.contains(respuesta.statusCode)) {
        throw const AccesoPlanesException(
          'El servicio de verificación no está disponible. Intenta más tarde.',
          codigo: 'SERVICE_UNAVAILABLE',
        );
      }
      final mensaje = error is Map ? error['message'] : null;
      throw AccesoPlanesException(
        mensaje is String && mensaje != 'INTERNAL'
            ? mensaje
            : 'No se pudo verificar la solicitud. Intenta nuevamente.',
        codigo: codigo is String ? codigo : null,
      );
    }
    return resultado;
  }

  static Map<String, dynamic>? _respuestaJson(String cuerpo) {
    try {
      final datos = jsonDecode(cuerpo);
      return datos is Map<String, dynamic> ? datos : null;
    } on FormatException {
      return null;
    }
  }

  static User _usuario() {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      throw const AccesoPlanesException('Inicia sesión para continuar.');
    }
    return usuario;
  }

  static Future<Uri> iniciarPago(String rol) async {
    if (!pagosEnLineaDisponibles) {
      throw const AccesoPlanesException(
        'Contacta a soporte para activar tu plan.',
      );
    }
    final datos = await _consultar(_usuario(), {
      'accion': 'iniciarPago',
      'rol': rol,
    });
    final url = Uri.tryParse(datos['url'] as String? ?? '');
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'checkout.wompi.co' ||
        url.port != 443 ||
        url.userInfo.isNotEmpty ||
        url.path != '/p/' ||
        url.hasFragment) {
      throw const AccesoPlanesException(
        'Wompi no devolvió un enlace de pago válido.',
      );
    }
    return url;
  }

  static Future<RenovacionPlan> cancelarRenovacion(String rol) async {
    final datos = await _consultar(_usuario(), {
      'accion': 'cancelarRenovacion',
      'rol': rol,
    });
    await refrescar();
    return RenovacionPlan.desdeMapa(datos);
  }

  static Future<String> confirmarPago(String id) async {
    final resultado = await _consultar(_usuario(), {
      'accion': 'confirmarPago',
      'id': id,
    });
    if (resultado['status'] == 'APPROVED') {
      await refrescar();
      await refrescar();
    }
    return resultado['status'] as String? ?? 'NOT_FOUND';
  }

  static void _notificar() => cambios.value++;
}
