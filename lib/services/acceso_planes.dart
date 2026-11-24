import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
      _pagadosHasta = Map<String, int>.from(datos['pagadosHasta'] as Map),
      rolInicial = datos['rolInicial'] as String,
      rolPrueba = datos['pruebaRol'] as String?,
      _pruebaHasta = datos['pruebaHasta'] as int,
      _equipoHasta = datos['graciaEquipoHasta'] as int,
      preparando = datos['preparando'] == true,
      renovacionDisponible = datos['renovacionDisponible'] == true,
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

  final _reloj = Stopwatch();
  final int _ahoraServidor;
  final Set<String> _roles;
  final Set<String> _historicos;
  final Map<String, int> _pagadosHasta;
  final int _pruebaHasta;
  final int _equipoHasta;
  final String rolInicial;
  final String? rolPrueba;
  final bool preparando;
  final bool admin;
  final bool renovacionDisponible;
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

  bool tieneSuscripcionVigente(String rol) =>
      _historicos.contains(rol) || (_pagadosHasta[rol] ?? 0) > _ahora;

  static const _pagos = {'persona', 'equipo_juridico', 'supervisor_contratos'};

  Set<String> get roles {
    final ahora = _ahora;
    bool propio(String rol) =>
        admin ||
        _historicos.contains(rol) ||
        (_pagadosHasta[rol] ?? 0) > ahora ||
        (rol == rolPrueba && _pruebaHasta > ahora);
    final puedeUsarGratis = !_pagos.contains(rolInicial) || _roles.any(propio);
    return _roles.where((rol) {
      if (!_pagos.contains(rol)) return puedeUsarGratis;
      return propio(rol) || (rol == 'equipo_juridico' && _equipoHasta > ahora);
    }).toSet();
  }

  Duration get proximaRevision {
    final ahora = _ahora;
    var restante = const Duration(minutes: 1).inMilliseconds;
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

  bool get servicioNoDisponible =>
      codigo == 'SERVICE_UNAVAILABLE' || codigo == 'UNAVAILABLE';
}

abstract final class AccesoPlanes {
  static final cambios = ValueNotifier<int>(0);
  static const _endpoint = String.fromEnvironment(
    'ACCESO_PLAN_URL',
    defaultValue: 'https://us-central1-secop-ia.cloudfunctions.net/accesoPlan',
  );
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
        _hayError = false;
        _revisando = false;
        _enCurso = null;
        _timer?.cancel();
        _notificar();
      }
      if (user != null) unawaited(refrescar());
    });
  }

  static Future<void> refrescar() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != _uid) return Future.value();
    final anterior = _enCurso;
    if (anterior != null) return anterior;
    final trabajo = _obtenerEstado(user, _sesion);
    _enCurso = trabajo;
    return trabajo;
  }

  static Future<void> _obtenerEstado(User user, int sesion) async {
    _timer?.cancel();
    _revisando = true;
    _notificar();
    try {
      final datos = await _consultar(user, {'accion': 'estado'});
      if (_sesion != sesion) return;
      _estado = EstadoPlanes(datos);
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
            ? const Duration(seconds: 8)
            : estado.proximaRevision;
        _timer = Timer(proxima, () => unawaited(refrescar()));
      }
    }
  }

  static Future<Map<String, dynamic>> _consultar(
    User user,
    Map<String, String> datos, {
    Uri? endpoint,
  }) async {
    final token = await user.getIdToken().timeout(const Duration(seconds: 10));
    final respuesta = await http
        .post(
          endpoint ?? Uri.parse(_endpoint),
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

  static Future<bool> vincularCedula([String? cedula]) async {
    final base = Uri.parse(_endpoint);
    final datos = await _consultar(
      _usuario(),
      {'cedula': ?cedula},
      endpoint: base.replace(
        pathSegments: [
          ...base.pathSegments.take(base.pathSegments.length - 1),
          'identidadCuenta',
        ],
      ),
    );
    return datos['vinculada'] == true;
  }

  static Future<Uri> iniciarPago(String rol) async {
    final datos = await _consultar(_usuario(), {
      'accion': 'iniciarPago',
      'rol': rol,
    });
    final url = Uri.tryParse(datos['url'] as String? ?? '');
    final hostFunciones = Uri.parse(_endpoint).host;
    final esRenovacion =
        datos['recurrente'] == true &&
        url?.host == hostFunciones &&
        url?.pathSegments.lastOrNull == 'checkoutRenovacion';
    if (url == null ||
        url.scheme != 'https' ||
        (!esRenovacion && url.host != 'checkout.wompi.co')) {
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
