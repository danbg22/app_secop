import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../utils/nit.dart';
import 'consent_service.dart';
import 'datos_abiertos.dart';

enum TipoSeguido {
  entidad('Entidad'),
  contratista('Contratista');

  const TipoSeguido(this.etiqueta);
  final String etiqueta;

  static TipoSeguido desde(String? v) =>
      v == 'contratista' ? TipoSeguido.contratista : TipoSeguido.entidad;
}

/// Entidad o contratista que la persona sigue.
///
/// Cuenta los contratos de SECOP II firmados desde [desdeIso]: los nuevos
/// son los que aparecieron desde la última vez que los vio ([vistos]). Por
/// contar y no comparar fechas, también aparecen los que la entidad publica
/// tarde con una fecha de firma anterior (siempre que sea desde [desdeIso]).
class Seguido {
  const Seguido({
    required this.tipo,
    required this.clave,
    required this.nombre,
    required this.desdeIso,
    required this.vistos,
    this.creadoEnIso = '',
  });

  final TipoSeguido tipo;

  /// NIT (entidad) o documento del contratista, solo dígitos.
  final String clave;
  final String nombre;

  /// Fecha (aaaa-mm-dd) desde la que se cuentan los contratos.
  final String desdeIso;

  /// Contratos que había la última vez que la persona los vio.
  final int vistos;
  final String creadoEnIso;

  String get id => '${tipo.name}:$clave';

  Seguido conVistos(int n) => Seguido(
    tipo: tipo,
    clave: clave,
    nombre: nombre,
    desdeIso: desdeIso,
    vistos: n,
    creadoEnIso: creadoEnIso,
  );

  Map<String, dynamic> toMap() => {
    'tipo': tipo.name,
    'clave': clave,
    'nombre': nombre,
    'desde': desdeIso,
    'vistos': vistos,
    'creado': creadoEnIso,
  };

  factory Seguido.fromMap(Map<String, dynamic> m) => Seguido(
    tipo: TipoSeguido.desde(m['tipo']?.toString()),
    clave: '${m['clave'] ?? ''}',
    nombre: '${m['nombre'] ?? ''}',
    desdeIso: '${m['desde'] ?? ''}',
    vistos: (m['vistos'] as num?)?.toInt() ?? 0,
    creadoEnIso: '${m['creado'] ?? ''}',
  );

  /// Filtro de SoQL de sus contratos en SECOP II (jbjy-vk9h).
  String get filtroSecop {
    final base = switch (tipo) {
      // nit_entidad es numérico: sin comillas, con y sin DV.
      TipoSeguido.entidad =>
        'nit_entidad in (${Nit.formasNumericas(clave).join(',')})',
      // documento_proveedor es texto: con y sin DV (y con guion).
      TipoSeguido.contratista =>
        "documento_proveedor in (${Nit.formas(clave).map((f) => "'$f'").join(',')})",
    };
    return "$base AND fecha_de_firma >= '${desdeIso}T00:00:00.000'";
  }
}

/// Alertas sin servidor: lo que la persona sigue se guarda en su cuenta
/// (`usuarios/{uid}.seguimiento`) y, al abrir la app, se cuentan sus
/// contratos en SECOP II para ver cuántos son nuevos.
class SeguimientoService {
  SeguimientoService._();

  static const String _campo = 'seguimiento';
  static const int maximo = 40;

  /// Días hacia atrás desde los que se cuentan los contratos al empezar a
  /// seguir (los publicados tarde con una firma reciente también cuentan).
  static const int diasAtras = 60;

  static const String _contratos = 'jbjy-vk9h';

  /// Cambia cada vez que cambia lo seguido o sus novedades.
  static final ValueNotifier<int> cambios = ValueNotifier<int>(0);

  static List<Seguido> _seguidos = const [];
  static final Map<String, int> _actuales = {};
  static bool _revisando = false;
  static String _uid = '';
  static StreamSubscription<User?>? _sesion;

  static List<Seguido> get seguidos => List.unmodifiable(_seguidos);
  static bool get revisando => _revisando;

  /// Contratos nuevos de [s] desde la última vez que los vio (null si aún no
  /// se ha revisado en esta sesión).
  static int? nuevos(Seguido s) {
    final actual = _actuales[s.id];
    if (actual == null) return null;
    return actual > s.vistos ? actual - s.vistos : 0;
  }

  static int get totalNuevos =>
      _seguidos.fold<int>(0, (t, s) => t + (nuevos(s) ?? 0));

  static bool sigue(TipoSeguido tipo, String clave) {
    final c = _limpia(clave);
    return _seguidos.any((s) => s.tipo == tipo && s.clave == c);
  }

  static String _limpia(String clave) {
    final d = clave.replaceAll(RegExp(r'[^0-9]'), '');
    // NIT con DV pegado → sin DV. Solo para NIT (empiezan por 8 o 9): una
    // cédula de 10 dígitos no se recorta.
    if (d.length == 10 && (d.startsWith('8') || d.startsWith('9'))) {
      final base = d.substring(0, 9);
      if ('${Nit.digitoVerificacion(base)}' == d.substring(9)) return base;
    }
    return d;
  }

  static DocumentReference<Map<String, dynamic>>? get _ref {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection(ConsentService.coleccionUsuarios)
        .doc(uid);
  }

  /// Sigue la sesión: al entrar carga lo seguido y revisa las novedades.
  static void iniciar() {
    _sesion ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      final uid = user?.uid ?? '';
      if (uid == _uid) return;
      _uid = uid;
      _seguidos = const [];
      _actuales.clear();
      cambios.value++;
      if (uid.isNotEmpty) unawaited(cargarYRevisar());
    });
  }

  static Future<void> cargarYRevisar() async {
    await _cargar();
    await revisar();
  }

  static Future<void> _cargar() async {
    final ref = _ref;
    if (ref == null) return;
    try {
      final data = (await ref.get().timeout(const Duration(seconds: 10)))
          .data();
      _seguidos = [
        for (final e in (data?[_campo] as List? ?? const []))
          if (e is Map) Seguido.fromMap(Map<String, dynamic>.from(e)),
      ];
      cambios.value++;
    } catch (e) {
      debugPrint('SeguimientoService._cargar: $e');
    }
  }

  static Future<void> _guardar() async {
    final ref = _ref;
    if (ref == null) {
      throw StateError('Inicia sesión para seguir entidades y contratistas.');
    }
    await ref
        .set({
          _campo: [for (final s in _seguidos) s.toMap()],
        }, SetOptions(merge: true))
        .timeout(const Duration(seconds: 10));
  }

  /// Cuántos contratos tiene [s] en SECOP II desde su fecha de inicio.
  static Future<int?> _contar(Seguido s) async {
    try {
      final filas = await DatosAbiertos.filas(
        _contratos,
        {r'$select': 'count(*) as n', r'$where': s.filtroSecop},
        fresco: true,
        cache: null,
      );
      if (filas.isEmpty) return 0;
      return int.tryParse('${filas.first['n'] ?? 0}') ?? 0;
    } catch (e) {
      debugPrint('SeguimientoService._contar ${s.id}: $e');
      return null;
    }
  }

  /// Revisa las novedades de todo lo seguido.
  static Future<void> revisar() async {
    if (_revisando || _seguidos.isEmpty) return;
    _revisando = true;
    cambios.value++;
    try {
      final resultados = await Future.wait(_seguidos.map(_contar));
      for (var i = 0; i < _seguidos.length; i++) {
        final n = resultados[i];
        if (n != null) _actuales[_seguidos[i].id] = n;
      }
    } finally {
      _revisando = false;
      cambios.value++;
    }
  }

  static Future<void> seguir({
    required TipoSeguido tipo,
    required String clave,
    required String nombre,
  }) async {
    final c = _limpia(clave);
    if (c.length < 5) {
      throw StateError('No se encontró el NIT o el documento para seguir.');
    }
    if (sigue(tipo, c)) return;
    if (_seguidos.length >= maximo) {
      throw StateError(
        'Puedes seguir hasta $maximo entidades y contratistas. Deja de seguir alguno para agregar otro.',
      );
    }
    final hoy = DateTime.now();
    final desde = hoy.subtract(const Duration(days: diasAtras));
    final base = Seguido(
      tipo: tipo,
      clave: c,
      nombre: nombre.trim(),
      desdeIso:
          '${desde.year}-${desde.month.toString().padLeft(2, '0')}-${desde.day.toString().padLeft(2, '0')}',
      vistos: 0,
      creadoEnIso: hoy.toUtc().toIso8601String(),
    );
    // Lo que ya existe al empezar a seguir no es novedad.
    final actual = await _contar(base) ?? 0;
    final nuevo = base.conVistos(actual);
    _seguidos = [nuevo, ..._seguidos];
    _actuales[nuevo.id] = actual;
    cambios.value++;
    try {
      await _guardar();
    } catch (_) {
      _seguidos = _seguidos.where((s) => s.id != nuevo.id).toList();
      cambios.value++;
      rethrow;
    }
  }

  static Future<void> dejarDeSeguir(TipoSeguido tipo, String clave) async {
    final c = _limpia(clave);
    final antes = _seguidos;
    _seguidos = _seguidos
        .where((s) => !(s.tipo == tipo && s.clave == c))
        .toList();
    cambios.value++;
    try {
      await _guardar();
    } catch (_) {
      _seguidos = antes;
      cambios.value++;
      rethrow;
    }
  }

  /// Las novedades de [s] quedan vistas.
  static Future<void> marcarVisto(Seguido s) async {
    final actual = _actuales[s.id];
    if (actual == null) return;
    _seguidos = [
      for (final x in _seguidos) x.id == s.id ? x.conVistos(actual) : x,
    ];
    cambios.value++;
    await _guardar();
  }

  @visibleForTesting
  static void fijarParaPrueba(
    List<Seguido> seguidos,
    Map<String, int> actuales,
  ) {
    _seguidos = seguidos;
    _actuales
      ..clear()
      ..addAll(actuales);
    cambios.value++;
  }

  /// Los contratos más recientes de [s] (los nuevos están entre ellos).
  static Future<List<Map<String, dynamic>>> recientes(
    Seguido s, {
    int cuantos = 10,
  }) => DatosAbiertos.filas(_contratos, {
    r'$where': s.filtroSecop,
    r'$order': 'fecha_de_firma DESC',
    r'$limit': '$cuantos',
  });
}
