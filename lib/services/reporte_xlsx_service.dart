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
  static const _sDecimal = 9;

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
    ColumnaReporte.nombre => 30,
    ColumnaReporte.cargo => 26,
    ColumnaReporte.perfil => 40,
    ColumnaReporte.documento => 14,
    ColumnaReporte.mensual => 16,
    ColumnaReporte.meses => 10,
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
      case ColumnaReporte.manual ||
          ColumnaReporte.sigep ||
          ColumnaReporte.perfil:
        return _texto(ref, '', _sDiligenciar);
      case ColumnaReporte.documento:
        // Como texto, para que no se vea en notación científica.
        return _texto(ref, c.documentoContratista, _sEntero);
      case ColumnaReporte.meses:
        final m = c.plazoMeses;
        return m == null
            ? _texto(ref, '', _sTexto)
            : _numero(ref, (m * 10).round() / 10, _sDecimal);
      case ColumnaReporte.mensual:
        final v = c.valorMensual;
        return v == null
            ? _texto(ref, '', _sTexto)
            : _numero(ref, v.round(), _sNumero);
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
<numFmts count="2"><numFmt numFmtId="164" formatCode="&quot;\$&quot; #,##0"/><numFmt numFmtId="165" formatCode="0.0"/></numFmts>
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
<cellXfs count="10">
<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
<xf numFmtId="0" fontId="2" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>
<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf>
<xf numFmtId="164" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment vertical="top"/></xf>
<xf numFmtId="0" fontId="3" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf>
<xf numFmtId="0" fontId="0" fillId="3" borderId="1" xfId="0" applyFill="1" applyBorder="1"/>
<xf numFmtId="0" fontId="4" fillId="0" borderId="0" xfId="0" applyFont="1"/>
<xf numFmtId="1" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="top"/></xf>
<xf numFmtId="165" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="top"/></xf>
</cellXfs>
</styleSheet>''';

  /// Genera el .xlsx. [encabezado] son las líneas sobre la tabla (entidad,
  /// título, criterios); [notas] van debajo. Con [porDependencia] y varias
  /// dependencias, una hoja de resumen y una hoja por dependencia.
  static Uint8List generar({
    required String hoja,
    required List<String> encabezado,
    required List<ColumnaReporte> columnas,
    required List<ContratoReporte> contratos,
    List<String> notas = const [],
    bool firmaResponsable = false,
    bool porDependencia = false,
  }) {
    final grupos = <String, List<ContratoReporte>>{};
    if (porDependencia) {
      for (final c in contratos) {
        (grupos[c.dependencia] ??= []).add(c);
      }
    }
    final hojas = <(String, String, String)>[];
    final usados = <String>{};
    String nombreHoja(String n) {
      var s = n.replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ').trim();
      // "Regional Cesar · Despacho…" → "Despacho…".
      if (s.contains(' · ')) s = s.substring(s.lastIndexOf(' · ') + 3);
      if (s.isEmpty) s = 'Hoja';
      // Excel admite 31 caracteres: primero sin conectores y luego
      // cortando en un espacio (el nombre completo va dentro de la hoja).
      if (s.length > 31) {
        s = s
            .split(RegExp(r'\s+'))
            .where(
              (p) => !{
                'de',
                'del',
                'la',
                'las',
                'los',
                'y',
                'e',
                'el',
              }.contains(p.toLowerCase()),
            )
            .join(' ');
      }
      if (s.length > 31) {
        final corte = s.substring(0, 32).lastIndexOf(' ');
        s = s.substring(0, corte > 0 ? corte : 31).trim();
      }
      final base = s;
      var k = base;
      for (var i = 2; !usados.add(k.toLowerCase()); i++) {
        final sufijo = ' ($i)';
        k = '${base.length + sufijo.length > 31 ? base.substring(0, 31 - sufijo.length).trim() : base}$sufijo';
      }
      return k;
    }

    if (grupos.length > 1) {
      final resumen = nombreHoja('Resumen');
      hojas.add((resumen, _hojaResumen(encabezado, grupos), ''));
      for (final e in grupos.entries) {
        final n = nombreHoja(e.key);
        final (xml, filtro) = _hoja(
          encabezado: [
            ...encabezado.take(2),
            'Dependencia: ${e.key}',
            ...encabezado.skip(2),
          ],
          columnas: columnas,
          contratos: e.value,
          notas: notas,
          firmaResponsable: firmaResponsable,
        );
        hojas.add((n, xml, filtro));
      }
    } else {
      final (xml, filtro) = _hoja(
        encabezado: encabezado,
        columnas: columnas,
        contratos: contratos,
        notas: notas,
        firmaResponsable: firmaResponsable,
      );
      hojas.add((nombreHoja(hoja), xml, filtro));
    }

    final libro =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'
        '${[for (final (i, h) in hojas.indexed) '<sheet name="${_xml(h.$1)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
        '</sheets><definedNames>'
        '${[for (final (i, h) in hojas.indexed)
          if (h.$3.isNotEmpty) '<definedName name="_xlnm._FilterDatabase" localSheetId="$i" hidden="1">\'${_xml(h.$1)}\'!${h.$3}</definedName>'].join()}'
        '</definedNames></workbook>';
    final tipos =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '${[for (var i = 1; i <= hojas.length; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '</Types>';
    const relaciones =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';
    final relacionesLibro =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '${[for (var i = 1; i <= hojas.length; i++) '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>'].join()}'
        '<Relationship Id="rId${hojas.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '</Relationships>';

    ArchiveFile archivo(String nombre, String contenido) =>
        ArchiveFile.bytes(nombre, utf8.encode(contenido));
    final zip = Archive()
      ..addFile(archivo('[Content_Types].xml', tipos))
      ..addFile(archivo('_rels/.rels', relaciones))
      ..addFile(archivo('xl/workbook.xml', libro))
      ..addFile(archivo('xl/_rels/workbook.xml.rels', relacionesLibro))
      ..addFile(archivo('xl/styles.xml', _estilos));
    for (final (i, h) in hojas.indexed) {
      zip.addFile(archivo('xl/worksheets/sheet${i + 1}.xml', h.$2));
    }
    return ZipEncoder().encodeBytes(zip);
  }

  /// Hoja de resumen: contratos y valor por dependencia.
  static String _hojaResumen(
    List<String> encabezado,
    Map<String, List<ContratoReporte>> grupos,
  ) {
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
    final cab = r + 1;
    fila(
      [
        _texto('A$cab', 'Dependencia', _sCabecera),
        _texto('B$cab', 'Contratos', _sCabecera),
        _texto('C$cab', 'Valor total (\$)', _sCabecera),
      ].join(),
      alto: 30,
    );
    for (final e in grupos.entries) {
      final n = r + 1;
      fila(
        [
          _texto('A$n', e.key, _sTexto),
          _numero('B$n', e.value.length, _sEntero),
          _numero(
            'C$n',
            e.value.fold<double>(0, (s, c) => s + c.valorCop).round(),
            _sNumero,
          ),
        ].join(),
      );
    }
    final n = r + 1;
    fila(
      [
        _texto('A$n', 'TOTAL', _sCabecera),
        '<c r="B$n" s="$_sEntero"><f>SUM(B${cab + 1}:B${n - 1})</f><v>${grupos.values.fold<int>(0, (s, l) => s + l.length)}</v></c>',
        '<c r="C$n" s="$_sNumero"><f>SUM(C${cab + 1}:C${n - 1})</f><v>${grupos.values.expand((l) => l).fold<double>(0, (s, c) => s + c.valorCop).round()}</v></c>',
      ].join(),
    );
    fila('');
    fila(
      _texto(
        'A${r + 1}',
        'Cada dependencia tiene su hoja con el detalle de los contratos.',
        _sNota,
      ),
    );
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<cols><col min="1" max="1" width="60" customWidth="1"/><col min="2" max="2" width="14" customWidth="1"/>'
        '<col min="3" max="3" width="20" customWidth="1"/></cols>'
        '<sheetData>$filas</sheetData></worksheet>';
  }

  /// Una hoja con la tabla de contratos. Devuelve el XML y el rango del
  /// filtro automático.
  static (String, String) _hoja({
    required List<String> encabezado,
    required List<ColumnaReporte> columnas,
    required List<ContratoReporte> contratos,
    required List<String> notas,
    required bool firmaResponsable,
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
    final filtro =
        '\$A\$$filaCabecera:\$$ultima\$${filaCabecera + contratos.length}';
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
    return (hojaXml, filtro);
  }

  static bool descargar(Uint8List bytes, String nombre) => downloadBinaryBytes(
    bytes: bytes,
    fileName: nombre,
    mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
}
