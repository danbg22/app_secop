import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/pqrs_bandeja_service.dart';
import '../tema/cristal.dart';

class BotonNotificacionesSoporte extends StatefulWidget {
  const BotonNotificacionesSoporte({super.key});

  @override
  State<BotonNotificacionesSoporte> createState() =>
      _BotonNotificacionesSoporteState();
}

class _BotonNotificacionesSoporteState
    extends State<BotonNotificacionesSoporte> {
  late final _usuarios = FirebaseAuth.instance.authStateChanges();
  String? _uid;
  Stream<List<SolicitudBuzon>>? _mensajes;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _usuarios,
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, sesion) {
        final uid = sesion.data?.uid;
        if (_uid != uid) {
          _uid = uid;
          _mensajes = uid == null
              ? null
              : PqrsBandejaService.misSolicitudes(uid);
        }
        if (uid == null) return const SizedBox.shrink();
        return StreamBuilder<List<SolicitudBuzon>>(
          stream: _mensajes,
          key: ValueKey(uid),
          builder: (context, snapshot) {
            final nuevas =
                snapshot.data?.where((mensaje) => mensaje.sinLeer).length ?? 0;
            return IconButton(
              tooltip: nuevas == 0
                  ? 'Notificaciones de soporte'
                  : 'Soporte · $nuevas sin leer',
              icon: Badge(
                isLabelVisible: nuevas > 0,
                label: Text(nuevas > 99 ? '99+' : '$nuevas'),
                child: Icon(
                  nuevas == 0
                      ? Icons.notifications_none_rounded
                      : Icons.notifications_rounded,
                  color: nuevas == 0 ? Cristal.texto : Cristal.dorado,
                ),
              ),
              onPressed: () =>
                  Navigator.of(context).pushNamed('/mis-solicitudes'),
            );
          },
        );
      },
    );
  }
}
