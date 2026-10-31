import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'pdf_unificado_types.dart';

const bool unionPdfDisponible = true;

const String _rutaScript = 'js/expediente_impresion.js';

extension type _ItemJs._(JSObject _) implements JSObject {
  external factory _ItemJs({
    String titulo,
    String tipo,
    JSUint8Array bytes,
    String sha256,
    String? nota,
  });
}

extension type _ResultadoJs._(JSObject _) implements JSObject {
  external JSUint8Array? get bytes;
  external String? get error;
}

@JS('contrataLegalPdf.unirExpediente')
external JSPromise<_ResultadoJs> _unirExpediente(
  JSArray<_ItemJs> items,
  String tituloDocumento,
);

@JS('contrataLegalPdf')
external JSObject? get _moduloCargado;

Future<void>? _carga;

/// Carga `web/js/expediente_impresion.js` una sola vez, al primer uso.
Future<void> _asegurarScript() {
  if (_moduloCargado != null) return Future<void>.value();
  return _carga ??=
      () async {
        final script = web.HTMLScriptElement()
          ..src = _rutaScript
          ..async = true;
        final cargado = script.onLoad.first;
        final fallo = script.onError.first.then<void>((_) {
          throw const PdfUnificadoException(
            'No fue posible cargar el generador de PDF. Revisa tu conexión.',
          );
        });
        web.document.head!.append(script);
        await Future.any(<Future<void>>[cargado, fallo]);
      }().catchError((Object e) {
        _carga = null;
        throw e;
      });
}

Future<Uint8List> unirDocumentosEnPdf(
  List<DocumentoParaUnir> documentos, {
  required String tituloDocumento,
}) async {
  await _asegurarScript();
  final items = <_ItemJs>[
    for (final d in documentos)
      _ItemJs(
        titulo: d.titulo,
        tipo: d.tipo.name,
        bytes: d.bytes.toJS,
        sha256: d.sha256Esperado,
        nota: d.nota,
      ),
  ];
  final resultado = await _unirExpediente(items.toJS, tituloDocumento).toDart;
  final bytes = resultado.bytes;
  if (bytes == null) {
    throw PdfUnificadoException(
      resultado.error ?? 'No fue posible generar el PDF unificado.',
    );
  }
  return bytes.toDart;
}
