import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utils/app_instalable.dart' as plataforma;

/// Instalación de Contrata Legal como app (desde el navegador) y aviso de
/// versión nueva. La app instalada carga siempre la web publicada, así que
/// cada publicación le llega a todos; el aviso solo invita a recargar a
/// quien ya la tenía abierta.
class AppInstalable {
  AppInstalable._();

  /// Hay un botón de instalar que mostrar (o instrucciones, en iPhone).
  static final ValueNotifier<bool> disponible = ValueNotifier(false);

  /// Se publicó una versión distinta de la que está abierta.
  static final ValueNotifier<bool> hayVersionNueva = ValueNotifier(false);

  static const intervalo = Duration(minutes: 10);

  static bool _iniciado = false;
  static String? _huellaAbierta;
  static Timer? _reloj;

  static bool get esIphone => plataforma.esIphoneOIpad();

  static void iniciar() {
    if (!kIsWeb || _iniciado) return;
    _iniciado = true;
    _actualizarDisponible();
    plataforma.alCambiarInstalable(_actualizarDisponible);
    unawaited(comprobarVersion());
    _reloj = Timer.periodic(intervalo, (_) => unawaited(comprobarVersion()));
  }

  static void _actualizarDisponible() {
    disponible.value =
        !plataforma.abiertaComoApp() &&
        (plataforma.navegadorOfreceInstalar() || plataforma.esIphoneOIpad());
  }

  /// Devuelve true si el usuario aceptó instalar.
  static Future<bool> instalar() async {
    final ok = await plataforma.pedirInstalacion();
    _actualizarDisponible();
    return ok;
  }

  static Future<void> comprobarVersion() async {
    if (hayVersionNueva.value) return;
    final huella = await plataforma.huellaVersionPublicada();
    if (huella == null) return;
    if (_huellaAbierta == null) {
      _huellaAbierta = huella;
      return;
    }
    if (huella != _huellaAbierta) {
      hayVersionNueva.value = true;
      _reloj?.cancel();
    }
  }

  static void recargar() => plataforma.recargarApp();
}
