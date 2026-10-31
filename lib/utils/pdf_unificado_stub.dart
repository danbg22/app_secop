import 'dart:typed_data';

import 'pdf_unificado_types.dart';

const bool unionPdfDisponible = false;

Future<Uint8List> unirDocumentosEnPdf(
  List<DocumentoParaUnir> documentos, {
  required String tituloDocumento,
}) async {
  throw const PdfUnificadoException(
    'El PDF unificado solo está disponible en la versión web.',
  );
}
