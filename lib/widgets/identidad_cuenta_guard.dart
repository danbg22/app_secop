import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/acceso_planes.dart';
import '../services/auth_service.dart';
import '../services/security_service.dart';
import 'ayuda_plataforma.dart';

class IdentidadCuentaGuard extends StatelessWidget {
  const IdentidadCuentaGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null
        ? const SizedBox.shrink()
        : _VincularCedula(key: ValueKey(uid), child: child);
  }
}

class _VincularCedula extends StatefulWidget {
  const _VincularCedula({super.key, required this.child});

  final Widget child;

  @override
  State<_VincularCedula> createState() => _VincularCedulaState();
}

class _VincularCedulaState extends State<_VincularCedula> {
  final _cedula = TextEditingController();
  bool _ocupado = true;
  bool _vinculada = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _consultar();
  }

  Future<void> _consultar([String? cedula]) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      final vinculada = await AccesoPlanes.vincularCedula(cedula);
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
      setState(() => _vinculada = vinculada);
      if (vinculada) await AccesoPlanes.refrescar();
    } catch (e) {
      final servicioNoDisponible =
          e is AccesoPlanesException && e.servicioNoDisponible;
      if (servicioNoDisponible &&
          uid != null &&
          FirebaseAuth.instance.currentUser?.uid == uid) {
        final accesoConfirmado =
            AuthService.isActiveUserAdmin ||
            await _tieneCedulaConfirmada(uid, cedula);
        if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
        if (accesoConfirmado) {
          setState(() => _vinculada = true);
          return;
        }
      }
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
      setState(() {
        _error = e is AccesoPlanesException
            ? e.mensaje
            : 'No se pudo verificar la cédula. Intenta nuevamente.';
      });
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<bool> _tieneCedulaConfirmada(String uid, String? cedula) async {
    try {
      final db = FirebaseFirestore.instance;
      const servidor = GetOptions(source: Source.server);
      final perfil = (await db.collection('usuarios').doc(uid).get(servidor))
          .data();
      String? canonico(Object? valor) {
        if (valor is! String ||
            !RegExp(r'^[\d. -]{5,32}$').hasMatch(valor.trim())) {
          return null;
        }
        final digitos = valor.replaceAll(RegExp(r'\D'), '');
        return RegExp(r'^\d{5,20}$').hasMatch(digitos) ? digitos : null;
      }

      final documento =
          canonico(perfil?['documentoNormalizado']) ??
          canonico(perfil?['documento']);
      if (documento == null || (cedula != null && cedula != documento)) {
        return false;
      }
      final hash = SecurityService.hashCredentialUniquenessIndex(
        type: 'doc',
        normalizedValue: documento,
      );
      final indice =
          (await db.collection('indices_unicidad').doc(hash).get(servidor))
              .data();
      return indice?['uid'] == uid && indice?['tipo'] == 'doc';
    } on FirebaseException {
      return false;
    }
  }

  void _guardar() {
    if (_ocupado) return;
    final valor = _cedula.text.trim();
    if (valor.length < 5) {
      setState(() => _error = 'Ingresa una cédula de 5 a 20 dígitos.');
      return;
    }
    setState(() {
      _error = null;
      _ocupado = true;
    });
    _consultar(valor);
  }

  @override
  void dispose() {
    _cedula.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_vinculada) return widget.child;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 440,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.badge_outlined, size: 32),
                      const SizedBox(height: 12),
                      Text(
                        'Vincula tu cédula',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Necesitamos tu número de cédula para vincularlo a tu cuenta y evitar registros duplicados.',
                      ),
                      const SizedBox(height: 16),
                      if (_ocupado) const LinearProgressIndicator(),
                      TextField(
                        controller: _cedula,
                        enabled: !_ocupado,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(20),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Número de cédula',
                          errorText: _error,
                          errorMaxLines: 4,
                        ),
                        onSubmitted: (_) => _guardar(),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _ocupado ? null : _guardar,
                        child: const Text('Vincular cédula'),
                      ),
                      Wrap(
                        children: [
                          TextButton(
                            onPressed: () => AyudaPlataforma.mostrar(context),
                            child: const Text('Ayuda'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await AuthService.signOut();
                              if (context.mounted) {
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/portada',
                                  (_) => false,
                                );
                              }
                            },
                            child: const Text('Cerrar sesión'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
