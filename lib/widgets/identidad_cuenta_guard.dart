import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/acceso_planes.dart';
import '../services/auth_service.dart';
import '../services/registro_cedula.dart';
import 'ayuda_plataforma.dart';

class FormularioCedulaRegistro extends StatefulWidget {
  const FormularioCedulaRegistro({super.key, required this.rol});

  final String rol;

  @override
  State<FormularioCedulaRegistro> createState() =>
      _FormularioCedulaRegistroState();
}

class _FormularioCedulaRegistroState extends State<FormularioCedulaRegistro> {
  final _cedula = TextEditingController();
  bool _ocupado = false;
  String? _error;

  Future<void> _guardarCedula(String cedula) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await RegistroCedula.guardar(uid: uid, cedula: cedula, rol: widget.rol);
      await AccesoPlanes.actualizarTrasRegistro();
    } catch (error) {
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
      setState(() {
        _error = error is RegistroCedulaException
            ? error.mensaje
            : 'No pudimos completar tu registro. Intenta nuevamente.';
      });
    } finally {
      if (mounted) setState(() => _ocupado = false);
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
    _guardarCedula(valor);
  }

  @override
  void dispose() {
    _cedula.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                        'Completa tu registro',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ingresa tu cédula para crear una única cuenta en Contrata Legal.',
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
                        child: const Text('Completar registro'),
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
