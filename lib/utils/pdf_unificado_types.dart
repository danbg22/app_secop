import 'dart:typed_data';

/// Cómo se incorpora cada archivo al PDF unificado.
enum TipoDocumentoParaUnir {
  /// Sus páginas se copian tal cual.
  pdf,

  /// Se inserta como una página (PNG, JPG, WEBP…).
  imagen,

  /// No se puede convertir en el navegador (Word): solo lleva su separador
  /// con una nota para imprimirlo aparte.
  sinIncrustar;

  /// Detecta el tipo por la firma del archivo y, si no la reconoce, por la
  /// extensión del nombre.
  static TipoDocumentoParaUnir detectar(List<int> bytes, String nombreArchivo) {
    bool empiezaCon(List<int> firma) =>
        bytes.length >= firma.length &&
        List<int>.generate(firma.length, (i) => bytes[i]).join(',') ==
            firma.join(',');

    if (empiezaCon(const [0x25, 0x50, 0x44, 0x46])) return pdf; // %PDF
    if (empiezaCon(const [0x89, 0x50, 0x4E, 0x47]) || // PNG
        empiezaCon(const [0xFF, 0xD8, 0xFF]) || // JPG
        empiezaCon(const [0x47, 0x49, 0x46, 0x38]) || // GIF
        (empiezaCon(const [0x52, 0x49, 0x46, 0x46]) && // RIFF…WEBP
            bytes.length >= 12 &&
            String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP')) {
      return imagen;
    }

    final nombre = nombreArchivo.toLowerCase();
    if (nombre.endsWith('.pdf')) return pdf;
    if (RegExp(r'\.(png|jpe?g|webp|gif)$').hasMatch(nombre)) return imagen;
    return sinIncrustar;
  }
}

class DocumentoParaUnir {
  const DocumentoParaUnir({
    required this.titulo,
    required this.nombreArchivo,
    required this.bytes,
    required this.tipo,
    this.sha256Esperado = '',
  });

  /// Texto de la hoja separadora (p. ej. "Cédula de ciudadanía").
  final String titulo;
  final String nombreArchivo;
  final Uint8List bytes;
  final TipoDocumentoParaUnir tipo;

  /// Huella registrada al cargar el archivo; si no coincide, no se genera
  /// el PDF (el archivo no sería el mismo que se verificó).
  final String sha256Esperado;

  String? get nota => tipo == TipoDocumentoParaUnir.sinIncrustar
      ? 'Archivo "$nombreArchivo": este formato no puede incluirse en el PDF. '
            'Imprímalo desde el archivo original e intercálelo aquí.'
      : null;
}

class PdfUnificadoException implements Exception {
  const PdfUnificadoException(this.message);
  final String message;

  @override
  String toString() => message;
}
