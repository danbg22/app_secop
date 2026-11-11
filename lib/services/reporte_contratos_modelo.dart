import '../utils/texto_profesional.dart';

/// Un contrato tal como entra al reporte (SECOP II, dataset jbjy-vk9h), con
/// los datos que se calculan después (contratos sucesivos, interrupción…).
class ContratoReporte {
  ContratoReporte({
    required this.numero,
    required this.fechaFirmaIso,
    required this.objeto,
    required this.modalidad,
    required this.contratista,
    required this.documentoContratista,
    required this.valorCop,
    required this.pagadoCop,
    required this.estado,
    required this.cuenta,
    this.id = '',
    this.url = '',
    this.inicioIso = '',
    this.finIso = '',
    this.duracion = '',
    this.diasAdicionados = 0,
    this.tipo = '',
    this.fuente = '',
    String? dependencia,
  }) : dependencia = dependencia ?? TextoProfesional.titulo(cuenta);

  final String id;
  final String numero;

  /// Página del proceso en SECOP II (community.secop.gov.co).
  final String url;
  final String fechaFirmaIso;
  final String inicioIso;
  final String finIso;
  final String objeto;
  final String modalidad;
  final String tipo;
  final String contratista;
  final String documentoContratista;
  final double valorCop;
  final double pagadoCop;
  final String estado;

  /// Cuenta compradora en SECOP II (p. ej. "SENA REGIONAL CESAR…").
  final String cuenta;

  /// Duración pactada como la publica SECOP II ("91 Dia(s)", "3 Mes(es)").
  final String duracion;
  final int diasAdicionados;

  /// Fuente de financiación según los valores que registra SECOP II.
  final String fuente;

  /// Unidad de contratación (despacho, centro) o cuenta de SECOP II.
  String dependencia;

  /// Contratos del contratista con la entidad en el periodo (calculado).
  int? contratosConEntidad;

  /// Días hábiles entre el fin del contrato anterior del contratista con la
  /// entidad y el inicio de este (calculado). null si no hubo anterior.
  int? interrupcionHabiles;
  String interrupcionNota = '';

  /// Si el contratista figura en SECOP II como supervisor u ordenador del
  /// gasto de contratos de la entidad (calculado).
  String cargoDirectivo = '';

  static double _num(dynamic v) => double.tryParse('${v ?? ''}') ?? 0;

  static const Map<String, String> _fuentes = {
    'presupuesto_general_de_la_nacion_pgn': 'Presupuesto General de la Nación',
    'recursos_propios': 'Recursos propios',
    'sistema_general_de_participaciones': 'Sistema General de Participaciones',
    'sistema_general_de_regal_as': 'Sistema General de Regalías',
    'recursos_de_credito': 'Recursos de crédito',
    'recursos_propios_alcald_as_gobernaciones_y_resguardos_ind_genas_':
        'Recursos propios territoriales',
  };

  static String _fuente(Map<String, dynamic> m) {
    final nombres = [
      for (final e in _fuentes.entries)
        if (_num(m[e.key]) > 0) e.value,
    ];
    if (nombres.isEmpty) {
      final origen = '${m['origen_de_los_recursos'] ?? ''}'.trim();
      if (origen.isNotEmpty && origen.toLowerCase() != 'no definido') {
        nombres.add(origen);
      }
    }
    final destino = '${m['destino_gasto'] ?? ''}'.trim();
    if (destino.isNotEmpty && destino.toLowerCase() != 'no definido') {
      nombres.add(destino);
    }
    return nombres.join(' · ');
  }

  factory ContratoReporte.fromSecop(
    Map<String, dynamic> m, {
    String? dependencia,
  }) {
    final ref = '${m['referencia_del_contrato'] ?? ''}'.trim();
    final url = m['urlproceso'];
    return ContratoReporte(
      id: '${m['id_contrato'] ?? ''}'.trim(),
      numero: ref.isNotEmpty ? ref : '${m['id_contrato'] ?? ''}',
      url: url is Map ? '${url['url'] ?? ''}' : '',
      fechaFirmaIso:
          '${m['fecha_de_firma'] ?? m['fecha_de_inicio_del_contrato'] ?? ''}',
      inicioIso: '${m['fecha_de_inicio_del_contrato'] ?? ''}',
      finIso: '${m['fecha_de_fin_del_contrato'] ?? ''}',
      objeto:
          '${m['objeto_del_contrato'] ?? m['descripcion_del_proceso'] ?? ''}'
              .trim(),
      modalidad: '${m['modalidad_de_contratacion'] ?? ''}'.trim(),
      tipo: '${m['tipo_de_contrato'] ?? ''}'.trim(),
      contratista: '${m['proveedor_adjudicado'] ?? ''}'.trim(),
      documentoContratista: '${m['documento_proveedor'] ?? ''}'.trim(),
      valorCop: _num(m['valor_del_contrato']),
      pagadoCop: _num(m['valor_pagado']),
      estado: '${m['estado_contrato'] ?? ''}'.trim(),
      cuenta: '${m['nombre_entidad'] ?? ''}'.trim(),
      duracion: '${m['duraci_n_del_contrato'] ?? ''}'.trim(),
      diasAdicionados: _num(m['dias_adicionados']).round(),
      fuente: _fuente(m),
      dependencia: dependencia,
    );
  }

  DateTime? get firma => DateTime.tryParse(fechaFirmaIso);
  DateTime? get inicio => DateTime.tryParse(inicioIso);
  DateTime? get fin => DateTime.tryParse(finIso);
  int? get anioFirma => firma?.year;

  /// Inicio que se deduce cuando SECOP II no lo registra (contratos recién
  /// firmados, sin acta de inicio): la terminación menos los días
  /// prorrogados y el plazo pactado.
  static DateTime? estimarInicio(
    DateTime? fin,
    String duracion,
    int diasAdicionados,
  ) {
    if (fin == null) return null;
    final m = RegExp(r'(\d+)\s*([A-Za-zñÑ]+)').firstMatch(duracion);
    if (m == null) return null;
    final n = int.parse(m.group(1)!);
    if (n <= 0) return null;
    final unidad = m.group(2)!.toLowerCase();
    final f = DateTime(fin.year, fin.month, fin.day - diasAdicionados);
    if (unidad.startsWith('d')) {
      return DateTime(f.year, f.month, f.day - (n - 1));
    }
    if (unidad.startsWith('m')) return DateTime(f.year, f.month - n, f.day + 1);
    if (unidad.startsWith('a')) return DateTime(f.year - n, f.month, f.day + 1);
    return null;
  }

  /// La de SECOP II o, si falta, la deducida.
  DateTime? get inicioEfectivo =>
      inicio ?? estimarInicio(fin, duracion, diasAdicionados);

  bool get inicioEstimado => inicio == null && inicioEfectivo != null;

  /// Plazo pactado en días calendario: el que publica SECOP II en días o,
  /// si viene en meses o años, contado desde la fecha de inicio.
  int? get plazoDias {
    final m = RegExp(r'(\d+)\s*([A-Za-zñÑ]+)').firstMatch(duracion);
    if (m != null) {
      final n = int.parse(m.group(1)!);
      final unidad = m.group(2)!.toLowerCase();
      if (unidad.startsWith('d')) return n;
      final i = inicioEfectivo;
      if (i != null && unidad.startsWith('m')) {
        return DateTime(i.year, i.month + n, i.day).difference(i).inDays;
      }
      if (i != null && unidad.startsWith('a')) {
        return DateTime(i.year + n, i.month, i.day).difference(i).inDays;
      }
    }
    final i = inicio, f = fin;
    if (i != null && f != null && !f.isBefore(i)) {
      return f.difference(i).inDays + 1 - diasAdicionados;
    }
    return null;
  }

  /// Plazo en meses según la duración que publica SECOP II (que ya incluye
  /// las prórrogas): los días se cuentan de a 30. Si falta, de la fecha de
  /// inicio a la de terminación.
  double? get plazoMeses {
    final m = RegExp(r'(\d+)\s*([A-Za-zñÑ]+)').firstMatch(duracion);
    if (m != null) {
      final n = int.parse(m.group(1)!);
      final unidad = m.group(2)!.toLowerCase();
      if (n > 0 && unidad.startsWith('d')) return n / 30;
      if (n > 0 && unidad.startsWith('m')) return n.toDouble();
      if (n > 0 && unidad.startsWith('a')) return n * 12.0;
    }
    final i = inicio, f = fin;
    if (i != null && f != null && !f.isBefore(i)) {
      return (f.difference(i).inDays + 1) / 30;
    }
    return null;
  }

  /// Cargo o rol que se deduce del objeto (ver [cargoSegunObjeto]).
  String get cargo => cargoSegunObjeto(objeto);

  /// Valor mensual (honorarios): el valor del contrato entre el plazo en
  /// meses. En el SENA coincide con la tabla de honorarios.
  double? get valorMensual {
    final m = plazoMeses;
    return m == null || m <= 0 ? null : valorCop / m;
  }
}

/// Columnas que se pueden incluir en el reporte (PDF y hoja de cálculo).
enum ColumnaReporte {
  fila('No.', 22),
  numero('N.º contrato', 80),
  documento('Cédula / NIT', 58),
  nombre('Nombre del contratista', 0, flex: 1.6),
  cargo('Cargo o rol (según el objeto)', 0, flex: 1.2),
  contratista('Contratista (nombre e identificación)', 0, flex: 2),
  perfil(
    'Perfil (formación y experiencia exigidas)',
    0,
    flex: 1.6,
    porDiligenciar: true,
  ),
  objeto('Objeto del contrato', 0, flex: 4),
  vigencia('Vigencia', 34),
  firma('Fecha de firma', 46),
  modalidad('Modalidad', 66),
  tipo('Tipo de contrato', 62),
  mensual('Valor mensual (\$)', 64, numerica: true),
  valor('Valor (\$)', 68, numerica: true),
  pagado('Valor pagado (\$)', 64, numerica: true),
  plazo('Plazo (días)', 34, numerica: true),
  meses('Plazo (meses)', 34, numerica: true),
  sucesivos('No. de contratos sucesivos con la entidad', 46, numerica: true),
  manual(
    '¿El objeto coincide con funciones del manual? (Sí/No)',
    50,
    porDiligenciar: true,
  ),
  enlace('Enlace SECOP II', 80),
  dependencia('Dependencia', 0, flex: 1.4),
  fuente('Fuente de financiación', 0, flex: 1.3),
  inicio('Fecha de inicio', 46),
  terminacion('Fecha de terminación', 46),
  interrupcion(
    'Días hábiles de interrupción respecto del contrato anterior',
    52,
    numerica: true,
  ),
  sigep('Registro en SIGEP II (Sí/No)', 40, porDiligenciar: true),
  supervision(
    '¿Tiene a cargo supervisión, ordenación del gasto o manejo de bienes? (Sí/No)',
    66,
  ),
  estado('Estado', 50);

  const ColumnaReporte(
    this.titulo,
    this.anchoPdf, {
    this.flex = 0,
    this.numerica = false,
    this.porDiligenciar = false,
  });

  final String titulo;

  /// Ancho fijo en el PDF (puntos); 0 si es flexible.
  final double anchoPdf;
  final double flex;
  final bool numerica;

  /// La entidad debe diligenciarla: no está en datos públicos.
  final bool porDiligenciar;

  /// Necesita consultar el historial del contratista con la entidad.
  bool get requiereHistorial =>
      this == sucesivos || this == interrupcion || this == supervision;
}

/// Formatos predefinidos del reporte.
enum FormatoReporte {
  anexoDirectiva018(
    'Anexo 1 · Directiva 018 de 2026 (Procuraduría)',
    'Relación de contratos de prestación de servicios, vigencias 2023–2026, con las columnas del '
        'Anexo 1 y las adicionales que pide el oficio.',
  ),
  contratistasOps(
    'Contratistas OPS: cédula, perfil y honorarios',
    'Por dependencia: cédula, nombre, perfil, objeto, plazo, valor mensual y valor total de los contratos de '
        'prestación de servicios del año. Con el consolidado, una hoja por dependencia.',
  ),
  general(
    'Relación general de contratos',
    'Número, firma, objeto, modalidad, contratista, valor y estado.',
  ),
  personalizado('Personalizado', 'Elige las columnas que necesites.');

  const FormatoReporte(this.titulo, this.descripcion);
  final String titulo;
  final String descripcion;

  /// Título del documento generado.
  String get tituloDocumento => switch (this) {
    anexoDirectiva018 =>
      'Anexo 1 · Relación de contratos de prestación de servicios',
    contratistasOps => 'Contratistas de prestación de servicios (OPS)',
    general || personalizado => 'Relación de contratos',
  };

  /// Prefijo del nombre del archivo (null: sin prefijo).
  String? get prefijoArchivo => switch (this) {
    anexoDirectiva018 => 'Anexo 1',
    contratistasOps => 'Contratistas OPS',
    general || personalizado => null,
  };

  List<ColumnaReporte> get columnas => switch (this) {
    anexoDirectiva018 => const [
      ColumnaReporte.fila,
      ColumnaReporte.contratista,
      ColumnaReporte.objeto,
      ColumnaReporte.vigencia,
      ColumnaReporte.valor,
      ColumnaReporte.plazo,
      ColumnaReporte.sucesivos,
      ColumnaReporte.manual,
      ColumnaReporte.enlace,
      ColumnaReporte.dependencia,
      ColumnaReporte.fuente,
      ColumnaReporte.inicio,
      ColumnaReporte.terminacion,
      ColumnaReporte.interrupcion,
      ColumnaReporte.sigep,
      ColumnaReporte.supervision,
    ],
    contratistasOps => const [
      ColumnaReporte.fila,
      ColumnaReporte.documento,
      ColumnaReporte.nombre,
      ColumnaReporte.cargo,
      ColumnaReporte.perfil,
      ColumnaReporte.objeto,
      ColumnaReporte.meses,
      ColumnaReporte.mensual,
      ColumnaReporte.valor,
      ColumnaReporte.enlace,
    ],
    general || personalizado => const [
      ColumnaReporte.fila,
      ColumnaReporte.numero,
      ColumnaReporte.firma,
      ColumnaReporte.objeto,
      ColumnaReporte.modalidad,
      ColumnaReporte.contratista,
      ColumnaReporte.valor,
      ColumnaReporte.estado,
    ],
  };
}

/// Lo que el usuario eligió en el diálogo del reporte.
class OpcionesReporte {
  const OpcionesReporte({
    required this.formato,
    required this.columnas,
    required this.desde,
    required this.corte,
    required this.soloPrestacionServicios,
    required this.pdf,
    required this.xlsx,
    this.unidad,
  });

  final FormatoReporte formato;

  /// En el orden en que se muestran.
  final List<ColumnaReporte> columnas;

  /// Año inicial (desde el 1 de enero).
  final int desde;

  /// Fecha de corte: contratos firmados hasta este día inclusive.
  final DateTime corte;

  /// Solo prestación de servicios profesionales y de apoyo a la gestión.
  final bool soloPrestacionServicios;
  final bool pdf;
  final bool xlsx;

  /// Criterio exacto por unidad de contratación (null: filtros de pantalla).
  final Object? unidad;

  bool get requiereHistorial => columnas.any((c) => c.requiereHistorial);
}

String fechaCorta(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null || d.year < 2000) return '';
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(d.day)}/${dos(d.month)}/${d.year}';
}

String fechaDia(DateTime d) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(d.day)}/${dos(d.month)}/${d.year}';
}

String pesos(double v) {
  final t = v.round().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '\$ $t';
}

/// Mayúsculas sin tildes (también las que llegan como marcas combinadas).
String _plano(String t) {
  const tildes = {
    'Á': 'A',
    'É': 'E',
    'Í': 'I',
    'Ó': 'O',
    'Ú': 'U',
    'Ü': 'U',
    'Ñ': 'N',
  };
  return t
      .toUpperCase()
      .replaceAll(RegExp('[\u0300-\u036f]'), '')
      .split('')
      .map((c) => tildes[c] ?? c)
      .join();
}

/// Cargo o rol del contratista según el objeto del contrato. SECOP II no
/// publica un campo de cargo (los contratistas de prestación de servicios
/// no ocupan cargos de planta): se deduce de las palabras del objeto.
String cargoSegunObjeto(String objeto) {
  final o = _plano(objeto);
  bool r(String p) => RegExp(p).hasMatch(o);
  if (o.trim().isEmpty) return '';
  if (r('ETAPA PRODUCTIVA') && !r('IMPARTIR')) {
    return 'Instructor(a) de seguimiento a etapa productiva';
  }
  if (r(
    r'INSTRUCT|IMPARTIR FORMACI|ORIENTAR (LA )?FORMACI|FORMACION PROFESIONAL INTEGRAL COMO',
  )) {
    return 'Instructor(a)';
  }
  const reglas = <(String, String)>[
    ('ORIENTACION OCUPACIONAL', 'Orientador(a) ocupacional'),
    ('ORIENTACION VOCACIONAL', 'Orientador(a) vocacional'),
    ('CONDUCCION|CONDUCTOR', 'Conductor(a)'),
    ('INTERPRETE', 'Guía intérprete de lengua de señas'),
    ('TECNOACADEMIA', 'Profesional de Tecnoacademia'),
    ('TECNOPARQUE', 'Experto(a) de Tecnoparque'),
    ('ABOGAD|JURIDIC|EN DERECHO|SUSTANCIACI', 'Abogado(a)'),
    (
      'EVALUACION.{0,40}COMPETENCIAS|EVALUADOR',
      'Evaluador(a) de competencias laborales',
    ),
    ('DINAMIZADOR', 'Dinamizador(a)'),
    ('AUXILIAR DE ENFERMER', 'Auxiliar de enfermería'),
    ('CONSULTA MEDICA', 'Médico(a) general'),
    ('ODONTOL', 'Odontólogo(a)'),
    ('PSICOLOG', 'Psicólogo(a)'),
    (
      'COMUNICADOR|PERIODIST|AUDIOVISUAL|GRAFIC',
      'Profesional de comunicaciones',
    ),
    ('ARQUITECT', 'Profesional de infraestructura'),
    ('SABEDOR', 'Sabedor(a)'),
    (
      'DEPORTE|ACTIVIDAD FISICA|ENTRENAMIENTO',
      'Profesional de deporte y actividad física',
    ),
    ('EMPRENDIMIENTO', 'Gestor(a) de emprendimiento'),
    (
      'GESTION DOCUMENTAL|CORRESPONDENCIA|ARCHIV',
      'Apoyo en gestión documental',
    ),
    ('CONTRACTUAL', 'Apoyo a la gestión contractual'),
    ('FINANCIER|PRESUPUEST', 'Apoyo financiero'),
    ('SOPORTE TECNICO', 'Técnico(a) de soporte'),
    (
      r'SERVICIOS? PROFESIONAL|COMO PROFESIONAL|PROFESIONAL(ES)? (DE APOYO|ESPECIALIZAD)|PERSONALES PROFESIONAL',
      'Profesional de apoyo',
    ),
  ];
  for (final (patron, cargo) in reglas) {
    if (r(patron)) return cargo;
  }
  final cabeza = o.length > 110 ? o.substring(0, 110) : o;
  if (cabeza.contains('TECNIC') || cabeza.contains('TECNOLOG')) {
    return 'Técnico(a) de apoyo';
  }
  return 'Apoyo a la gestión';
}

/// Meses con un decimal (coma decimal), sin ",0" cuando es exacto.
String mesesTexto(double? m) {
  if (m == null) return '';
  final r = (m * 10).round() / 10;
  return r == r.roundToDouble()
      ? '${r.round()}'
      : r.toStringAsFixed(1).replaceAll('.', ',');
}

/// Texto de una celda (PDF). La hoja de cálculo usa números donde aplica.
String textoColumna(ColumnaReporte col, ContratoReporte c, int i) =>
    switch (col) {
      ColumnaReporte.fila => '${i + 1}',
      ColumnaReporte.numero => c.numero,
      ColumnaReporte.documento => c.documentoContratista,
      ColumnaReporte.nombre => TextoProfesional.titulo(c.contratista),
      ColumnaReporte.perfil => '',
      ColumnaReporte.cargo => c.cargo,
      ColumnaReporte.meses => mesesTexto(c.plazoMeses),
      ColumnaReporte.mensual =>
        c.valorMensual == null ? '' : pesos(c.valorMensual!),
      ColumnaReporte.contratista => [
        TextoProfesional.titulo(c.contratista),
        if (c.documentoContratista.isNotEmpty) 'Doc. ${c.documentoContratista}',
      ].join('\n'),
      ColumnaReporte.objeto => TextoProfesional.oracion(c.objeto),
      ColumnaReporte.vigencia => '${c.anioFirma ?? ''}',
      ColumnaReporte.firma => fechaCorta(c.fechaFirmaIso),
      ColumnaReporte.modalidad =>
        c.modalidad.isEmpty ? '' : TextoProfesional.etiqueta(c.modalidad),
      ColumnaReporte.tipo => c.tipo,
      ColumnaReporte.valor => pesos(c.valorCop),
      ColumnaReporte.pagado => pesos(c.pagadoCop),
      ColumnaReporte.plazo => [
        '${c.plazoDias ?? ''}',
        if (c.diasAdicionados > 0) '+${c.diasAdicionados} prorrogados',
      ].where((t) => t.isNotEmpty).join('\n'),
      ColumnaReporte.sucesivos => '${c.contratosConEntidad ?? ''}',
      ColumnaReporte.manual => '',
      // El número del contrato, enlazado al proceso en SECOP II.
      ColumnaReporte.enlace => c.url.isEmpty ? '' : c.numero,
      ColumnaReporte.dependencia => c.dependencia,
      ColumnaReporte.fuente => c.fuente,
      ColumnaReporte.inicio =>
        c.inicioEstimado
            ? '${fechaDia(c.inicioEfectivo!)} (estimada)'
            : fechaCorta(c.inicioIso),
      ColumnaReporte.terminacion => fechaCorta(c.finIso),
      ColumnaReporte.interrupcion => [
        if (c.interrupcionHabiles != null) '${c.interrupcionHabiles}',
        if (c.interrupcionNota.isNotEmpty) c.interrupcionNota,
      ].join('\n'),
      ColumnaReporte.sigep => '',
      ColumnaReporte.supervision => c.cargoDirectivo,
      ColumnaReporte.estado =>
        c.estado.isEmpty
            ? ''
            : c.estado[0].toUpperCase() + c.estado.substring(1).toLowerCase(),
    };
