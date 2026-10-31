import 'package:app_secop/services/juridico_contratacion_service.dart';
import 'package:app_secop/utils/pdf_unificado_types.dart';
import 'package:flutter_test/flutter_test.dart';

ApartadoDocumentoContrato _doc(
  String id,
  EstadoDocumentoJuridico estado, {
  bool obligatorio = true,
}) => ApartadoDocumentoContrato(
  id: id,
  nombre: id,
  descripcion: '',
  obligatorio: obligatorio,
  estado: estado,
  archivoNombre: estado == EstadoDocumentoJuridico.pendiente ? null : '$id.pdf',
);

ExpedienteContratoPs _expediente(List<ApartadoDocumentoContrato> apartados) =>
    ExpedienteContratoPs.fromMap({
      'id': 'x',
      'apartados': [for (final a in apartados) a.toMap()],
    });

void main() {
  const aprobado = EstadoDocumentoJuridico.aprobado;

  group('listoParaPdfUnificado', () {
    test('se habilita cuando todos los documentos están verificados', () {
      final exp = _expediente([
        _doc('cedula', aprobado),
        _doc('rut', aprobado),
      ]);
      expect(exp.listoParaPdfUnificado, isTrue);
      expect(exp.documentosParaImpresion.map((a) => a.id), ['cedula', 'rut']);
    });

    test('un documento en revisión o devuelto lo bloquea', () {
      for (final estado in [
        EstadoDocumentoJuridico.enRevision,
        EstadoDocumentoJuridico.subsanadoEnRevision,
        EstadoDocumentoJuridico.devueltoSubsanar,
      ]) {
        final exp = _expediente([
          _doc('cedula', aprobado),
          _doc('rut', estado),
        ]);
        expect(exp.listoParaPdfUnificado, isFalse, reason: estado.name);
        expect(exp.documentosSinVerificarParaImpresion, 1);
      }
    });

    test('un obligatorio sin cargar lo bloquea', () {
      final exp = _expediente([
        _doc('cedula', aprobado),
        _doc('rut', EstadoDocumentoJuridico.pendiente),
      ]);
      expect(exp.listoParaPdfUnificado, isFalse);
    });

    test('un opcional sin cargar no bloquea y se omite del PDF', () {
      final exp = _expediente([
        _doc('cedula', aprobado),
        _doc('libreta', EstadoDocumentoJuridico.pendiente, obligatorio: false),
      ]);
      expect(exp.listoParaPdfUnificado, isTrue);
      expect(exp.documentosParaImpresion.map((a) => a.id), ['cedula']);
    });

    test('un opcional cargado pero sin verificar sí bloquea', () {
      final exp = _expediente([
        _doc('cedula', aprobado),
        _doc('libreta', EstadoDocumentoJuridico.enRevision, obligatorio: false),
      ]);
      expect(exp.listoParaPdfUnificado, isFalse);
    });

    test('sin documentos cargados no se habilita', () {
      expect(_expediente(const []).listoParaPdfUnificado, isFalse);
    });
  });

  group('TipoDocumentoParaUnir.detectar', () {
    TipoDocumentoParaUnir tipo(List<int> bytes, [String nombre = 'archivo']) =>
        TipoDocumentoParaUnir.detectar(bytes, nombre);

    test('reconoce la firma aunque la extensión no coincida', () {
      expect(
        tipo('%PDF-1.7'.codeUnits, 'cedula.jpg'),
        TipoDocumentoParaUnir.pdf,
      );
      expect(
        tipo([0x89, 0x50, 0x4E, 0x47, 0x0D]),
        TipoDocumentoParaUnir.imagen,
      );
      expect(tipo([0xFF, 0xD8, 0xFF, 0xE0]), TipoDocumentoParaUnir.imagen);
      expect(
        tipo([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits]),
        TipoDocumentoParaUnir.imagen,
      );
    });

    test('Word queda como no incrustable', () {
      expect(
        tipo([0x50, 0x4B, 0x03, 0x04], 'hoja_de_vida.docx'),
        TipoDocumentoParaUnir.sinIncrustar,
      );
      expect(
        tipo([0xD0, 0xCF, 0x11, 0xE0], 'certificado.doc'),
        TipoDocumentoParaUnir.sinIncrustar,
      );
    });

    test('usa la extensión si no reconoce la firma', () {
      expect(tipo([1, 2, 3], 'rut.PDF'), TipoDocumentoParaUnir.pdf);
      expect(tipo([1, 2, 3], 'foto.jpeg'), TipoDocumentoParaUnir.imagen);
    });
  });
}
