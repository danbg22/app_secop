import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../utils/file_downloader.dart';
import '../utils/texto_profesional.dart';
import 'reporte_contratos_modelo.dart';

/// Hoja de cálculo (.xlsx) del reporte de contratos, para entregar en
/// formatos como el Anexo 1 de la Directiva 018 de 2026.
///
/// El archivo se arma en el navegador: un .xlsx es un zip de XML (Office
/// Open XML). Una sola hoja, con encabezado fijo, valores numéricos donde
/// aplica, el número de contrato y el enlace como hipervínculos a SECOP II
/// y las columnas que debe diligenciar la entidad sombreadas.
class ReporteXlsxService {
  ReporteXlsxService._();

  // Índices de estilo (cellXfs en styles.xml).
  static const _sTitulo = 1;
  static const _sCabecera = 2;
  static const _sTexto = 3;
  static const _sNumero = 4;
  static const _sEnlace = 5;
  static const _sDiligenciar = 6;
  static const _sNota = 7;
  static const _sEntero = 8;

  static String _xml(String t) => t
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      // Caracteres de control no válidos en XML.
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

  static String _col(int i) {
    var n = i + 1;
    var s = '';
    while (n > 0) {
      final r = (n - 1) % 26;
      s = String.fromCharCode(65 + r) + s;
      n = (n - 1) ~/ 26;
    }
    return s;
  }

  static String _texto(String ref, String t, int estilo) =>
      '<c r="$ref" s="$estilo" t="inlineStr"><is><t xml:space="preserve">${_xml(t)}</t></is></c>';

  static String _numero(String ref, num v, int estilo) =>
      '<c r="$ref" s="$estilo"><v>$v</v></c>';

  static String _vinculo(String ref, String url, String texto) {
    String f(String t) => _xml(t.replaceAll('"', '""'));
    return '<c r="$ref" s="$_sEnlace" t="str"><f>HYPERLINK("${f(url)}","${f(texto)}")</f>'
        '<v>${_xml(texto)}</v></c>';
  }

  static double _ancho(ColumnaReporte c) => switch (c) {
    ColumnaReporte.fila => 6,
    ColumnaReporte.objeto => 60,
    ColumnaReporte.contratista => 34,
    ColumnaReporte.numero => 22,
    ColumnaReporte.enlace => 22,
    ColumnaReporte.dependencia => 34,
    ColumnaReporte.fuente => 30,
    ColumnaReporte.supervision => 30,
    ColumnaReporte.modalidad || ColumnaReporte.tipo => 22,
    ColumnaReporte.valor || ColumnaReporte.pagado => 16,
    _ => 14,
  };

  static String _celda(
    ColumnaReporte col,
    String ref,
    ContratoReporte c,
    int i,
  ) {
    switch (col) {
      case ColumnaReporte.fila:
        return _numero(ref, i + 1, _sEntero);
      case ColumnaReporte.numero:
        return c.url.startsWith('http')
            ? _vinculo(ref, c.url, c.numero)
            : _texto(ref, c.numero, _sTexto);
      case ColumnaReporte.enlace:
        return c.url.startsWith('http')
            ? _vinculo(ref, c.url, c.numero)
            : _texto(ref, '', _sTexto);
      case ColumnaReporte.vigencia:
        return c.anioFirma == null
            ? _texto(ref, '', _sTexto)
            : _numero(ref, c.anioFirma!, _sEntero);
      case ColumnaReporte.valor:
        return _numero(ref, c.valorCop.round(), _sNumero);
      case ColumnaReporte.pagado:
        return _numero(ref, c.pagadoCop.round(), _sNumero);
      case ColumnaReporte.plazo:
        return c.plazoDias == null
            ? _texto(ref, '', _sTexto)
            : _numero(ref, c.plazoDias!, _sEntero);
      case ColumnaReporte.sucesivos:
        return c.contratosConEntidad == null
            ? _texto(ref, '', _sTexto)
            : _numero(ref, c.contratosConEntidad!, _sEntero);
      case ColumnaReporte.interrupcion:
        return c.interrupcionHabiles == null
            ? _texto(ref, c.interrupcionNota, _sTexto)
            : _numero(ref, c.interrupcionHabiles!, _sEntero);
      case ColumnaReporte.manual || ColumnaReporte.sigep:
        return _texto(ref, '', _sDiligenciar);
      case ColumnaReporte.contratista:
        return _texto(
          ref,
          [
            TextoProfesional.titulo(c.contratista),
            if (c.documentoContratista.isNotEmpty) c.documentoContratista,
          ].join(' · '),
          _sTexto,
        );
      default:
        return _texto(ref, textoColumna(col, c, i), _sTexto);
    }
  }

  static const _estilos =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<numFmts count="1"><numFmt numFmtId="164" formatCode="&quot;\$&quot; #,##0"/></numFmts>
<fonts count="5">
<font><sz val="10"/><name val="Calibri"/></font>
<font><b/><sz val="13"/><color rgb="FF0E2646"/><name val="Calibri"/></font>
<font><b/><sz val="10"/><color rgb="FF0E2646"/><name val="Calibri"/></font>
<font><u/><sz val="10"/><color rgb="FF1D4ED8"/><name val="Calibri"/></font>
<font><i/><sz val="9"/><color rgb="FF64748B"/><name val="Calibri"/></font>
</fonts>
<fills count="4">
<fill><patternFill patternType="none"/></fill>
<fill><patternFill patternType="gray125"/></fill>
<fill><patternFill patternType="solid"><fgColor rgb="FFDCE6F2"/><bgColor indexed="64"/></patternFill></fill>
<fill><patternFill patternType="solid"><fgColor rgb="FFFFF7D6"/><bgColor indexed="64"/></patternFill></fill>
</fills>
<borders count="2">
<border><left/><right/><top/><bottom/><diagonal/></border>
<border><left style="thin"><color rgb="FFB8C4D6"/></left><right style="thin"><color rgb="FFB8C4D6"/></right><top style="thin"><color rgb="FFB8C4D6"/></top><bottom style="thin"><color rgb="FFB8C4D6"/></bottom><diagonal/></border>
</borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="9">
<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
<xf numFmtId="0" fontId="2" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>
<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf>
<xf numFmtId="164" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment vertical="top"/></xf>
<xf numFmtId="0" fontId="3" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf>
<xf numFmtId="0" fontId="0" fillId="3" borderId="1" xfId="0" applyFill="1" applyBorder="1"/>
<xf numFmtId="0" fontId="4" fillId="0" borderId="0" xfId="0" applyFont="1"/>
<xf numFmtId="1" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="top"/></xf>
</cellXfs>
</styleSheet>''';

  /// Genera el .xlsx. [encabezado] son las líneas sobre la tabla (entidad,
  /// título, criterios); [notas] van debajo.
  static Uint8List generar({
    required String hoja,
    required List<String> encabezado,
    required List<ColumnaReporte> columnas,
    required List<ContratoReporte> contratos,
    List<String> notas = const [],
    bool firmaResponsable = false,
  }) {
    final filas = StringBuffer();
    var r = 0;
    void fila(String celdas, {double? alto}) {
      r++;
      filas.write(
        '<row r="$r"${alto == null ? '' : ' ht="$alto" customHeight="1"'}>$celdas</row>',
      );
    }

    for (final (i, linea) in encabezado.indexed) {
      fila(_texto('A${r + 1}', linea, i == 0 ? _sTitulo : _sNota));
    }
    fila('');
    final filaCabecera = r + 1;
    fila(
      [
        for (final (i, c) in columnas.indexed)
          _texto('${_col(i)}$filaCabecera', c.titulo, _sCabecera),
      ].join(),
      alto: 58,
    );
    for (final (i, c) in contratos.indexed) {
      final n = r + 1;
      fila(
        [
          for (final (j, col) in columnas.indexed)
            _celda(col, '${_col(j)}$n', c, i),
        ].join(),
      );
    }
    // Total del valor.
    final iValor = columnas.indexOf(ColumnaReporte.valor);
    if (iValor >= 0 && contratos.isNotEmpty) {
      final n = r + 1;
      final colV = _col(iValor);
      fila(
        [
          _texto('A$n', 'TOTAL (${contratos.length} contratos)', _sCabecera),
          '<c r="$colV$n" s="$_sNumero"><f>SUM($colV${filaCabecera + 1}:$colV${n - 1})</f>'
              '<v>${contratos.fold<double>(0, (s, c) => s + c.valorCop).round()}</v></c>',
        ].join(),
      );
    }
    fila('');
    if (columnas.any((c) => c.porDiligenciar)) {
      fila(
        _texto(
          'A${r + 1}',
          'Las columnas sombreadas en amarillo no están en datos públicos: debe diligenciarlas la entidad.',
          _sNota,
        ),
      );
    }
    for (final n in notas) {
      fila(_texto('A${r + 1}', 'Nota: $n', _sNota));
    }
    if (firmaResponsable) {
      fila('');
      fila(
        _texto(
          'A${r + 1}',
          'Servidor responsable de la información: ______________________   '
              'Cargo: ______________________   Correo / teléfono: ______________________',
          _sTexto,
        ),
      );
    }

    final ultima = _col(columnas.length - 1);
    final hojaXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheetViews><sheetView workbookViewId="0"><pane ySplit="$filaCabecera" topLeftCell="A${filaCabecera + 1}" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>
<sheetFormatPr defaultRowHeight="15"/>
<cols>${[for (final (i, c) in columnas.indexed) '<col min="${i + 1}" max="${i + 1}" width="${_ancho(c)}" customWidth="1"/>'].join()}</cols>
<sheetData>$filas</sheetData>
<autoFilter ref="A$filaCabecera:$ultima${filaCabecera + contratos.length}"/>
<pageSetup orientation="landscape" paperSize="5" fitToWidth="1" fitToHeight="0"/>
</worksheet>''';

    final nombreHoja = _xml(
      hoja.replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ').trim(),
    );
    final libro =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets><sheet name="${nombreHoja.length > 31 ? nombreHoja.substring(0, 31) : nombreHoja}" sheetId="1" r:id="rId1"/></sheets>
<definedNames><definedName name="_xlnm._FilterDatabase" localSheetId="0" hidden="1">'${nombreHoja.length > 31 ? nombreHoja.substring(0, 31) : nombreHoja}'!\$A\$$filaCabecera:\$$ultima\$${filaCabecera + contratos.length}</definedName></definedNames>
</workbook>''';

    const tipos = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>''';
    const relaciones =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';
    const relacionesLibro =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

    ArchiveFile archivo(String nombre, String contenido) =>
        ArchiveFile.bytes(nombre, utf8.encode(contenido));
    final zip = Archive()
      ..addFile(archivo('[Content_Types].xml', tipos))
      ..addFile(archivo('_rels/.rels', relaciones))
      ..addFile(archivo('xl/workbook.xml', libro))
      ..addFile(archivo('xl/_rels/workbook.xml.rels', relacionesLibro))
      ..addFile(archivo('xl/styles.xml', _estilos))
      ..addFile(archivo('xl/worksheets/sheet1.xml', hojaXml));
    return ZipEncoder().encodeBytes(zip);
  }

  static bool descargar(Uint8List bytes, String nombre) => downloadBinaryBytes(
    bytes: bytes,
    fileName: nombre,
    mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
}
