/// Decide cómo mostrar un archivo que subió otra persona sin confiar en el
/// tipo que ella declaró.
///
/// Un archivo abierto en una pestaña (`blob:`) corre con el mismo origen que
/// la app: si fuera HTML o SVG, su código tendría acceso a la sesión de quien
/// lo abre. Por eso solo se abren PDF e imágenes comunes, y solo si su
/// contenido real lo confirma (firma de los primeros bytes). Todo lo demás se
/// descarga como binario genérico.
library;

/// Tipos que la app abre en una pestaña.
const Set<String> tiposVisualizables = {
  'application/pdf',
  'image/png',
  'image/jpeg',
  'image/gif',
  'image/webp',
};

bool _empiezaCon(List<int> bytes, List<int> firma, [int desde = 0]) {
  if (bytes.length < desde + firma.length) return false;
  for (var i = 0; i < firma.length; i++) {
    if (bytes[desde + i] != firma[i]) return false;
  }
  return true;
}

/// Tipo real según el contenido, solo para los tipos visualizables; `null`
/// si el contenido no es un PDF ni una imagen común.
String? tipoVisualizablePorContenido(List<int> bytes) {
  if (_empiezaCon(bytes, const [0x25, 0x50, 0x44, 0x46, 0x2D])) {
    return 'application/pdf'; // %PDF-
  }
  if (_empiezaCon(bytes, const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ])) {
    return 'image/png';
  }
  if (_empiezaCon(bytes, const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (_empiezaCon(bytes, const [0x47, 0x49, 0x46, 0x38])) return 'image/gif';
  if (_empiezaCon(bytes, const [0x52, 0x49, 0x46, 0x46]) &&
      _empiezaCon(bytes, const [0x57, 0x45, 0x42, 0x50], 8)) {
    return 'image/webp';
  }
  return null;
}

/// Tipo con el que se entrega una descarga: los tipos que el navegador
/// podría ejecutar (HTML, SVG, XML, JavaScript) se cambian por un binario
/// genérico.
String tipoDescargaSeguro(String declarado) {
  final tipo = declarado.split(';').first.trim().toLowerCase();
  const activos = ['html', 'svg', 'xml', 'javascript', 'ecmascript'];
  if (tipo.isEmpty || activos.any(tipo.contains)) {
    return 'application/octet-stream';
  }
  return declarado;
}
