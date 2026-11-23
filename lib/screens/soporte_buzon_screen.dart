import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/pqrs_bandeja_service.dart';
import '../tema/cristal.dart';
import '../widgets/pqrs_help_dialog.dart';

String? _fechaLocal(DateTime? fecha) => fecha == null
    ? null
    : DateFormat('dd/MM/yyyy HH:mm').format(fecha.toLocal());

class BandejaSoporteSection extends StatefulWidget {
  const BandejaSoporteSection({super.key});

  @override
  State<BandejaSoporteSection> createState() => _BandejaSoporteSectionState();
}

class _BandejaSoporteSectionState extends State<BandejaSoporteSection> {
  static const _tamanoPagina = 30;
  int _limite = _tamanoPagina;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _mensajes;

  void _consultar() {
    _mensajes = PqrsBandejaService.consultaAdministrativa(_limite).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isActiveUserAdmin) return const SizedBox.shrink();
    _mensajes ??= PqrsBandejaService.consultaAdministrativa(_limite)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _mensajes,
      builder: (context, snapshot) {
        final datos = snapshot.data;
        final mensajes = datos == null
            ? const <SolicitudBuzon>[]
            : PqrsBandejaService.agrupar(datos.docs);
        return _ListaBuzon(
          titulo: 'Mensajes de soporte',
          subtitulo:
              'Consulta y responde las solicitudes enviadas desde Ayuda.',
          mensajes: mensajes,
          cargando: snapshot.connectionState == ConnectionState.waiting,
          error: snapshot.hasError,
          vacio: 'Todavía no hay solicitudes de soporte.',
          onAbrir: (ticket) => mostrarDialogoCristal<void>(
            context: context,
            builder: (_) =>
                _DetalleSolicitud(ticket: ticket, administrar: true),
          ),
          pie: datos != null && datos.docs.length >= _limite
              ? OutlinedButton.icon(
                  onPressed: snapshot.connectionState == ConnectionState.waiting
                      ? null
                      : () => setState(() {
                          _limite += _tamanoPagina;
                          _consultar();
                        }),
                  icon: const Icon(Icons.expand_more_rounded),
                  label: const Text('Cargar más solicitudes'),
                )
              : null,
          onReintentar: () => setState(_consultar),
        );
      },
    );
  }
}

class MisMensajesSoporteScreen extends StatelessWidget {
  const MisMensajesSoporteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final uid = snapshot.data?.uid;
        if (uid == null) return const SizedBox.shrink();
        return _MisMensajesSoporte(uid: uid, key: ValueKey(uid));
      },
    );
  }
}

class _MisMensajesSoporte extends StatefulWidget {
  const _MisMensajesSoporte({super.key, required this.uid});

  final String uid;

  @override
  State<_MisMensajesSoporte> createState() => _MisMensajesSoporteState();
}

class _MisMensajesSoporteState extends State<_MisMensajesSoporte> {
  late Stream<List<SolicitudBuzon>> _mensajes =
      PqrsBandejaService.misSolicitudes(widget.uid);

  void _abrir(SolicitudBuzon ticket) {
    if (ticket.sinLeer) {
      unawaited(PqrsBandejaService.marcarLeida(ticket).catchError((_) {}));
    }
    mostrarDialogoCristal<void>(
      context: context,
      builder: (_) => _DetalleSolicitud(ticket: ticket),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Mis solicitudes'),
        actions: [
          IconButton(
            tooltip: 'Enviar una solicitud',
            onPressed: () => PqrsHelpDialog.show(context),
            icon: const Icon(Icons.add_comment_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<SolicitudBuzon>>(
          stream: _mensajes,
          builder: (context, snapshot) => _ListaBuzon(
            titulo: 'Soporte',
            subtitulo: 'Consulta tus radicados y las respuestas del equipo.',
            mensajes: [
              ...?snapshot.data?.where((ticket) => ticket.sinLeer),
              ...?snapshot.data?.where((ticket) => !ticket.sinLeer),
            ],
            personal: true,
            cargando: snapshot.connectionState == ConnectionState.waiting,
            error: snapshot.hasError,
            vacio: 'Aún no has enviado solicitudes de soporte.',
            onAbrir: _abrir,
            onReintentar: () => setState(() {
              _mensajes = PqrsBandejaService.misSolicitudes(widget.uid);
            }),
            pie: FilledButton.icon(
              onPressed: () => PqrsHelpDialog.show(context),
              icon: const Icon(Icons.add_comment_outlined, size: 17),
              label: const Text('Nueva solicitud'),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListaBuzon extends StatelessWidget {
  const _ListaBuzon({
    required this.titulo,
    required this.subtitulo,
    required this.mensajes,
    required this.cargando,
    required this.error,
    required this.vacio,
    required this.onAbrir,
    required this.onReintentar,
    this.pie,
    this.personal = false,
  });

  final String titulo;
  final String subtitulo;
  final List<SolicitudBuzon> mensajes;
  final bool cargando;
  final bool error;
  final String vacio;
  final ValueChanged<SolicitudBuzon> onAbrir;
  final VoidCallback onReintentar;
  final Widget? pie;
  final bool personal;

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final margen = ancho > 1200 ? (ancho - 1200) / 2 + 20 : 18.0;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(margen, 20, margen, 24),
      itemCount: mensajes.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Cristal.vidrio,
              border: Border.all(color: Cristal.borde),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 32, height: 3, color: Cristal.dorado),
                const SizedBox(height: 10),
                Text(titulo, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 5),
                Text(subtitulo, style: TextStyle(color: Cristal.textoMedio)),
              ],
            ),
          );
        }
        if (index == mensajes.length + 1) {
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                if (cargando)
                  const CircularProgressIndicator(
                    semanticsLabel: 'Cargando solicitudes',
                  )
                else if (error) ...[
                  const Text('No pudimos consultar el buzón.'),
                  TextButton(
                    onPressed: onReintentar,
                    child: const Text('Reintentar'),
                  ),
                ] else if (mensajes.isEmpty) ...[
                  Text(vacio, style: TextStyle(color: Cristal.textoMedio)),
                  const SizedBox(height: 12),
                ],
                if (pie != null && !error) pie!,
              ],
            ),
          );
        }
        final mensaje = mensajes[index - 1];
        final nueva = personal && mensaje.sinLeer;
        final estado = nueva
            ? 'Respuesta nueva'
            : (mensaje.tieneRespuesta ? 'Respondida' : 'Pendiente');
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                mensaje.tieneRespuesta
                    ? Icons.mark_email_read_outlined
                    : Icons.mail_outline_rounded,
                color: nueva ? Cristal.dorado : Cristal.acentoClaro,
              ),
              title: Text(
                mensaje.solicitud.asunto,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                [
                  mensaje.radicado,
                  estado,
                  ?_fechaLocal(mensaje.respondida ?? mensaje.creada),
                ].join(' · '),
                style: TextStyle(
                  color: nueva ? Cristal.dorado : Cristal.textoMedio,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onAbrir(mensaje),
            ),
          ),
        );
      },
    );
  }
}

class _DetalleSolicitud extends StatefulWidget {
  const _DetalleSolicitud({required this.ticket, this.administrar = false});

  final SolicitudBuzon ticket;
  final bool administrar;

  @override
  State<_DetalleSolicitud> createState() => _DetalleSolicitudState();
}

class _DetalleSolicitudState extends State<_DetalleSolicitud> {
  final _respuesta = TextEditingController();
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _respuesta.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    final texto = _respuesta.text.trim();
    if (texto.length < 3) {
      setState(
        () => _error = 'Escribe una respuesta de al menos 3 caracteres.',
      );
      return;
    }
    setState(() {
      _error = null;
      _enviando = true;
    });
    try {
      await PqrsBandejaService.responder(widget.ticket, texto);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Respuesta guardada en el radicado.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = e is StateError
            ? e.message
            : 'No pudimos guardar la respuesta. Reintenta.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final solicitud = ticket.solicitud;
    final responder = widget.administrar && !ticket.tieneRespuesta;
    return AlertDialog(
      title: Text(solicitud.asunto),
      scrollable: true,
      content: SizedBox(
        width: 540,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${ticket.radicado} · ${solicitud.tipoSolicitud}',
              style: TextStyle(color: Cristal.textoMedio),
            ),
            if (widget.administrar) ...[
              const SizedBox(height: 10),
              Text(
                [
                  solicitud.nombreUsuario,
                  if (solicitud.correoContacto.isNotEmpty)
                    solicitud.correoContacto,
                ].join(' · '),
              ),
            ],
            const SizedBox(height: 14),
            SelectableText(solicitud.mensaje),
            if (ticket.tieneRespuesta) ...[
              const SizedBox(height: 16),
              const Divider(),
              Text(
                'Respuesta de soporte',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_fechaLocal(ticket.respondida) case final fecha?)
                Text(fecha, style: TextStyle(color: Cristal.textoMedio)),
              const SizedBox(height: 6),
              SelectableText(ticket.respuesta),
            ] else if (responder) ...[
              const SizedBox(height: 18),
              if (ticket.uid.isEmpty) ...[
                Text(
                  'Este radicado histórico no está asociado a una cuenta. La respuesta quedará guardada en el buzón.',
                  style: TextStyle(color: Cristal.textoMedio),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _respuesta,
                minLines: 3,
                maxLines: 7,
                maxLength: 3000,
                enabled: !_enviando,
                decoration: InputDecoration(
                  labelText: 'Respuesta',
                  errorText: _error,
                ),
              ),
            ] else ...[
              const SizedBox(height: 14),
              Text(
                'Pendiente de respuesta',
                style: TextStyle(color: Cristal.textoMedio),
              ),
            ],
            if (_enviando) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        if (responder)
          FilledButton(
            onPressed: _enviando ? null : _enviar,
            child: const Text('Responder'),
          ),
      ],
    );
  }
}
