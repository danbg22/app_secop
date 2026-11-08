import 'dart:convert';

import 'package:app_secop/services/presupuesto_dependencias_service.dart';
import 'package:app_secop/services/reporte_contratos_pdf_service.dart';
import 'package:app_secop/services/reporte_contratos_service.dart';
import 'package:app_secop/services/reporte_xlsx_service.dart';
import 'package:app_secop/widgets/reporte_contratos_flujo.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

ContratoReporte contrato(int i) =>
    ContratoReporte(
        id: 'CO1.PCCNTR.${9000000 + i}',
        numero: 'CO1.PCCNTR.${9000000 + i}',
        url:
            'https://community.secop.gov.co/Public/Tendering/OpportunityDetail/Index?noticeUID=CO1.NTC.$i',
        fechaFirmaIso: '${2023 + i % 4}-0${1 + i % 9}-15T00:00:00',
        inicioIso: '${2023 + i % 4}-0${1 + i % 9}-16T00:00:00',
        finIso: '${2023 + i % 4}-12-15T00:00:00',
        duracion: '90 Dia(s)',
        objeto:
            'PRESTACION DE SERVICIOS PROFESIONALES PARA APOYAR LA GESTION ADMINISTRATIVA NUMERO $i',
        modalidad: 'Contratación directa',
        tipo: 'Prestación de servicios',
        contratista: 'CONTRATISTA $i',
        documentoContratista: '${10000000 + i % 50}',
        valorCop: 1000000.0 * (i + 1),
        pagadoCop: 500000.0 * (i + 1),
        estado: i % 3 == 0 ? 'terminado' : 'En ejecución',
        cuenta: 'SENA REGIONAL CESAR Grupo de Apoyo Administrativo Mixto',
        fuente: 'Presupuesto General de la Nación · Inversión',
        dependencia: i.isEven
            ? 'Despacho de la Dirección Regional'
            : 'Centro Biotecnológico del Caribe',
      )
      ..contratosConEntidad = 3
      ..interrupcionHabiles = i % 40
      ..cargoDirectivo = 'No figura en SECOP II';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lee un contrato de SECOP II con plazo, fuente y enlace', () {
    final c = ContratoReporte.fromSecop({
      'id_contrato': 'CO1.PCCNTR.1',
      'referencia_del_contrato': 'CO1.PCCNTR.9560510',
      'fecha_de_firma': '2026-03-10T09:00:00.000',
      'fecha_de_inicio_del_contrato': '2026-03-12T00:00:00.000',
      'fecha_de_fin_del_contrato': '2026-06-11T00:00:00.000',
      'duraci_n_del_contrato': '3 Mes(es)',
      'dias_adicionados': '15',
      'objeto_del_contrato': 'Compra de materiales de formación',
      'modalidad_de_contratacion': 'Contratación directa',
      'tipo_de_contrato': 'Prestación de servicios',
      'proveedor_adjudicado': 'EMPRESA S.A.S.',
      'documento_proveedor': '900123456',
      'valor_del_contrato': '108793000',
      'valor_pagado': '50000000',
      'estado_contrato': 'En ejecución',
      'nombre_entidad':
          'SENA REGIONAL CESAR Grupo de Apoyo Administrativo Mixto',
      'presupuesto_general_de_la_nacion_pgn': '108793000',
      'recursos_propios': '0',
      'destino_gasto': 'Inversión',
      'urlproceso': {'url': 'https://community.secop.gov.co/x'},
    });
    expect(c.numero, 'CO1.PCCNTR.9560510');
    expect(c.anioFirma, 2026);
    // 3 meses desde el 12 de marzo: 92 días calendario.
    expect(c.plazoDias, 92);
    expect(c.diasAdicionados, 15);
    expect(c.fuente, 'Presupuesto General de la Nación · Inversión');
    expect(c.url, 'https://community.secop.gov.co/x');
    expect(
      c.dependencia,
      'SENA Regional Cesar Grupo de Apoyo Administrativo Mixto',
    );
    expect(pesos(c.valorCop), '\$ 108.793.000');
    expect(
      ContratoReporte.fromSecop({'duraci_n_del_contrato': '91 Dia(s)'})
          .plazoDias,
      91,
    );
  });

  test('el Anexo 1 tiene las columnas del oficio en su orden', () {
    final cols = FormatoReporte.anexoDirectiva018.columnas;
    expect(cols.take(9).map((c) => c.titulo), [
      'No.',
      'Contratista (nombre e identificación)',
      'Objeto del contrato',
      'Vigencia',
      'Valor (\$)',
      'Plazo (días)',
      'No. de contratos sucesivos con la entidad',
      '¿El objeto coincide con funciones del manual? (Sí/No)',
      'Enlace SECOP II',
    ]);
    expect(cols, contains(ColumnaReporte.interrupcion));
    expect(cols.where((c) => c.porDiligenciar), [
      ColumnaReporte.manual,
      ColumnaReporte.sigep,
    ]);
  });

  test('PDF del Anexo 1 de más de 20 páginas', () async {
    final bytes = await ReporteContratosPdfService.generar(
      entidad: 'Servicio Nacional de Aprendizaje - SENA',
      nit: '899999034',
      titulo: 'Anexo 1',
      criterios: const [('Periodo', '01/01/2023 a 31/10/2026')],
      contratos: [for (var i = 0; i < 400; i++) contrato(i)],
      generadoPor: 'Prueba',
      generadoEn: DateTime(2026, 11, 8, 10, 30),
      columnas: FormatoReporte.anexoDirectiva018.columnas,
      firmaResponsable: true,
    );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('hoja de cálculo válida con hipervínculos y total', () {
    final bytes = ReporteXlsxService.generar(
      hoja: 'Anexo 1',
      encabezado: const ['SENA · NIT 899999034', 'Anexo 1'],
      columnas: FormatoReporte.anexoDirectiva018.columnas,
      contratos: [for (var i = 0; i < 30; i++) contrato(i)],
      notas: const ['Nota de prueba & <caracteres> "especiales"'],
      firmaResponsable: true,
    );
    final zip = ZipDecoder().decodeBytes(bytes);
    expect(
      zip.files.map((f) => f.name),
      containsAll([
        '[Content_Types].xml',
        'xl/workbook.xml',
        'xl/worksheets/sheet1.xml',
        'xl/styles.xml',
      ]),
    );
    final hoja = utf8.decode(zip.findFile('xl/worksheets/sheet1.xml')!.content);
    expect(hoja, contains('HYPERLINK("https://community.secop.gov.co'));
    expect(hoja, contains('<f>SUM('));
    expect(hoja, contains('&amp; &lt;caracteres&gt; &quot;especiales&quot;'));
    expect(hoja, contains('state="frozen"'));
  });

  test('criterio exacto y consolidado: notas con los nombres registrados', () {
    const despacho = UnidadContratacion(
      etiqueta: 'Regional Cesar · Despacho de la Dirección Regional',
      nombre: 'Despacho de la Dirección Regional',
      partes: [
        DependenciaPresupuesto(
          clave: 'Cesar|Despacho',
          nombre: 'Despacho de la Dirección Regional',
          cuentaSecop:
              'SENA REGIONAL CESAR Grupo de Apoyo Administrativo Mixto',
          variantes: ['UNIDAD DE CONTRATACION DESPACHO REGIONAL ok'],
          procesos: 1167,
          asignadoCop: 0,
        ),
      ],
      esDespacho: true,
    );
    const centro = UnidadContratacion(
      etiqueta: 'Regional Cesar · Centro Biotecnológico del Caribe',
      partes: [
        DependenciaPresupuesto(
          clave: 'Cesar|CBC',
          nombre: 'Centro Biotecnológico del Caribe',
          cuentaSecop:
              'SENA REGIONAL CESAR Grupo de Apoyo Administrativo Mixto',
          variantes: ['UNIDAD DE CONTRATACIÓN CBC'],
          procesos: 1627,
          asignadoCop: 0,
        ),
      ],
    );
    const consolidado = UnidadContratacion(
      etiqueta: 'Regional Cesar · todas sus unidades (consolidado)',
      partes: [],
      subunidades: [despacho, centro],
    );
    expect(consolidado.esConsolidado, isTrue);
    expect(consolidado.procesos, 1167 + 1627);
    expect(consolidado.variantes, [
      'UNIDAD DE CONTRATACION DESPACHO REGIONAL ok',
      'UNIDAD DE CONTRATACIÓN CBC',
    ]);
    final o = OpcionesReporte(
      formato: FormatoReporte.anexoDirectiva018,
      columnas: FormatoReporte.anexoDirectiva018.columnas,
      desde: 2023,
      corte: DateTime(2026, 10, 31),
      soloPrestacionServicios: true,
      pdf: false,
      xlsx: true,
      unidad: consolidado,
    );
    final notas = notasReporte(o: o, unidad: consolidado);
    expect(notas.first, contains('UNIDAD DE CONTRATACIÓN CBC'));
    expect(notas.join(' '), contains('01/01/2023 y el 31/10/2026'));
    expect(notas.join(' '), contains('SUJ-025-CE-S2-2021'));
    expect(
      periodoTexto(2023, DateTime(2026, 10, 31)),
      '01/01/2023 a 31/10/2026',
    );
    expect(
      ReporteContratosService.filtroFechas(2023, DateTime(2026, 10, 31)),
      contains("fecha_de_firma <= '2026-10-31T23:59:59.999'"),
    );
  });

  test('nombre de archivo limpio', () {
    expect(
      ReporteContratosPdfService.nombreArchivo(
        'Servicio Nacional de Aprendizaje - SENA',
        'Anexo 1 Regional Cesar 2023-2026',
        DateTime(2026, 11, 8),
        extension: 'xlsx',
      ),
      'Reporte_contratos_Servicio_Nacional_de_Aprendizaje_SENA_Anexo_1_Regional_Cesar_2023_2026_20261108.xlsx',
    );
  });
}
