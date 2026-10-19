import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Importación necesaria

import 'detalle_screen.dart';
import 'perfil_contratista_screen.dart';
import '../utils/csv_exporter.dart';

class ResultadosScreen extends StatefulWidget {
  final String nivel;
  final String? municipio;
  final String? departamento;

  final String entidad; // NUEVO: Ej. "Alcaldía", "SENA", "Gobernación"
  final String
  dependencia; // Ej. "Secretaría de Salud", "Todas las dependencias"
  final String? nitContratista;
  final String? nombreContratista;

  const ResultadosScreen({
    Key? key,
    required this.nivel,
    this.municipio,
    this.departamento,
    this.entidad = 'Todas las entidades', // Añadimos un valor por defecto
    required this.dependencia,
    this.nitContratista,
    this.nombreContratista,
  }) : super(key: key);

  @override
  _ResultadosScreenState createState() => _ResultadosScreenState();
}

class _ResultadosScreenState extends State<ResultadosScreen> {
  List<dynamic> contratos = [];
  List<dynamic> contratosFiltrados = [];
  TextEditingController controladorBusqueda = TextEditingController();
  Timer? _temporizadorRebote;
  final formatoMoneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  bool isLoading = true;
  bool cargandoMas = false;
  bool hayMasDatos = true;
  String mensajeError = '';

  int limitePagina = 50;
  int offsetActual = 0;
  ScrollController controladorScroll = ScrollController();

  bool isLoadingPresupuesto = true;
  double totalGastadoGlobal = 0;
  double presupuestoGlobalEstimado = 0;

  Map<String, double> distribucionActual = {};

  final List<Color> paletaColoresGrafico = [
    Colors.orange,
    Colors.blue,
    Colors.red.shade300,
    Colors.purple.shade300,
    Colors.green.shade300,
    Colors.teal.shade300,
    Colors.amber.shade600,
    Colors.cyan.shade400,
    Colors.pink.shade300,
  ];

  String filtroEstado = 'Todos';
  String ordenValor = 'Ninguno';

  String _normalizarTexto(String texto) {
    return texto
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');
  }

  // SET PARA GESTIONAR IDs DE FAVORITOS EN MEMORIA
  Set<String> favoritosIds = {};

  @override
  void initState() {
    super.initState();
    _cargarFavoritosLocales();
    _calcularPresupuestoGlobal();
    cargarDatos(limpiar: true);

    controladorScroll.addListener(() {
      if (controladorScroll.position.pixels >=
          controladorScroll.position.maxScrollExtent - 200) {
        if (!isLoading && !cargandoMas && hayMasDatos) {
          cargarDatos(limpiar: false);
        }
      }
    });
  }

  @override
  void dispose() {
    controladorScroll.dispose();
    _temporizadorRebote?.cancel();
    controladorBusqueda.dispose();
    super.dispose();
  }

  // --- LÓGICA DE ALMACENAMIENTO LOCAL ---
  Future<void> _cargarFavoritosLocales() async {
    final prefs = await SharedPreferences.getInstance();
    final listaStrings = prefs.getStringList('contratos_favoritos') ?? [];
    if (!mounted) return;
    setState(() {
      favoritosIds = listaStrings.map((c) {
        final map = json.decode(c);
        return (map['proceso_de_compra'] ??
                (map['nombre_entidad'] + map['descripcion_del_proceso']))
            .toString();
      }).toSet();
    });
  }

  Future<void> _toggleFavorito(dynamic contrato) async {
    final String idUnico =
        contrato['proceso_de_compra'] ??
        (contrato['nombre_entidad'] + contrato['descripcion_del_proceso']);
    final prefs = await SharedPreferences.getInstance();
    List<String> listaStrings =
        prefs.getStringList('contratos_favoritos') ?? [];

    setState(() {
      if (favoritosIds.contains(idUnico)) {
        favoritosIds.remove(idUnico);
        listaStrings.removeWhere((c) {
          final map = json.decode(c);
          final mapId =
              map['proceso_de_compra'] ??
              (map['nombre_entidad'] + map['descripcion_del_proceso']);
          return mapId == idUnico;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Eliminado de Favoritos')));
      } else {
        favoritosIds.add(idUnico);
        listaStrings.add(json.encode(contrato)); // Guardamos el JSON completo
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Añadido a Favoritos ⭐')));
      }
    });
    await prefs.setStringList('contratos_favoritos', listaStrings);
  }
  // ----------------------------------------

  String _formatearValorCorto(double valor) {
    if (valor >= 1000000000000) {
      return '\$ ${(valor / 1000000000000).toStringAsFixed(1)} Billones';
    } else if (valor >= 1000000000) {
      return '\$ ${(valor / 1000000000).toStringAsFixed(1)} Mil M';
    } else if (valor >= 1000000) {
      return '\$ ${(valor / 1000000).toStringAsFixed(1)} M';
    } else {
      return '\$ ${valor.toStringAsFixed(0)}';
    }
  }

  String _construirUrlBase() {
    String base = 'https://www.datos.gov.co/resource/jbjy-vk9h.json?';
    List<String> queryConditions = [];

    // NUEVO: Detectamos si estamos en modo "Due Diligence" (buscando a una persona o empresa)
    bool esDueDiligence =
        (widget.nitContratista != null && widget.nitContratista!.isNotEmpty) ||
        (widget.nombreContratista != null &&
            widget.nombreContratista!.isNotEmpty);

    // 1. Filtro de Tiempo (El candado inteligente)
    // Si NO es Due Diligence, busca solo en 2026. Si es Due Diligence, trae TODO el historial histórico.
    if (!esDueDiligence) {
      queryConditions.add(
        "fecha_de_firma >= '2026-01-01T00:00:00.000' AND fecha_de_firma <= '2026-12-31T23:59:59.000'",
      );
    }

    // 2. Lógica Condicional: Entidad vs Geografía
    if (widget.entidad != 'Todas las entidades') {
      String entLimpia = widget.entidad
          .toLowerCase()
          .replaceAll('á', 'a')
          .replaceAll('é', 'e')
          .replaceAll('í', 'i')
          .replaceAll('ó', 'o')
          .replaceAll('ú', 'u')
          .toUpperCase();

      String entFuzzy = entLimpia.replaceAll(' ', '%');
      queryConditions.add("upper(nombre_entidad) like '%$entFuzzy%'");
    } else {
      // Si desde el Home enviamos nivel = 'Todos', se ignoran estos 3 IFs y se busca en toda Colombia
      if (widget.nivel == 'Municipal' && widget.municipio != null) {
        queryConditions.add(
          "upper(ciudad) like '%${widget.municipio!.toUpperCase()}%'",
        );
      } else if (widget.nivel == 'Departamental' &&
          widget.departamento != null) {
        queryConditions.add(
          "upper(departamento) like '%${widget.departamento!.toUpperCase()}%'",
        );
      } else if (widget.nivel == 'Nacional') {
        queryConditions.add("orden = 'Nacional'");
      }
    }

    // 3. Filtro de Dependencia
    if (widget.dependencia != 'Todas las dependencias') {
      String depLimpia = widget.dependencia
          .toLowerCase()
          .replaceAll('á', 'a')
          .replaceAll('é', 'e')
          .replaceAll('í', 'i')
          .replaceAll('ó', 'o')
          .replaceAll('ú', 'u')
          .toUpperCase();
      queryConditions.add("upper(descripcion_del_proceso) like '%$depLimpia%'");
    }

    // 4. Filtro de Due Diligence (NIT del Contratista)
    if (widget.nitContratista != null && widget.nitContratista!.isNotEmpty) {
      queryConditions.add(
        "documento_proveedor like '%${widget.nitContratista}%'",
      );
    }

    // 5. Filtro por NOMBRE del contratista (con limpieza difusa)
    if (widget.nombreContratista != null &&
        widget.nombreContratista!.isNotEmpty) {
      // Limpiamos las tildes del texto que digitas para evitar fallos si en la alcaldía lo registraron sin tildes
      String nombreLimpio = widget.nombreContratista!
          .toLowerCase()
          .replaceAll('á', 'a')
          .replaceAll('é', 'e')
          .replaceAll('í', 'i')
          .replaceAll('ó', 'o')
          .replaceAll('ú', 'u')
          .toUpperCase();

      // Convertimos los espacios en comodines %. Ej: "IVAN BOLAÑO" -> "IVAN%BOLAÑO"
      String nombreFuzzy = nombreLimpio.replaceAll(' ', '%');
      queryConditions.add("upper(proveedor_adjudicado) like '%$nombreFuzzy%'");
    }

    if (queryConditions.isNotEmpty) {
      String querySQL = queryConditions.join(" AND ");
      base += '\$where=${Uri.encodeComponent(querySQL)}&';
    }

    return base;
  }

  Future<void> _calcularPresupuestoGlobal() async {
    try {
      // Reemplaza la línea de urlStr en _calcularPresupuestoGlobal por esta:
      final urlStr =
          '${_construirUrlBase()}\$select=valor_del_contrato,descripcion_del_proceso,nombre_entidad,tipo_de_contrato&\$limit=50000';
      final respuesta = await http.get(Uri.parse(urlStr));

      if (respuesta.statusCode == 200) {
        final List<dynamic> data = json.decode(respuesta.body);

        var datosFiltrados = data;
        if (widget.dependencia != 'Todas las dependencias') {
          final keyword = _normalizarTexto(widget.dependencia);
          datosFiltrados = data.where((contrato) {
            final descripcion = _normalizarTexto(
              (contrato['descripcion_del_proceso'] ?? '').toString(),
            );
            final entidad = _normalizarTexto(
              (contrato['nombre_entidad'] ?? '').toString(),
            );
            return descripcion.contains(keyword) || entidad.contains(keyword);
          }).toList();
        }

        double sumaTotal = 0;
        Map<String, double> distribucionGastos =
            {}; // NUEVO: Mapa para el gráfico

        for (var contrato in datosFiltrados) {
          if (contrato['valor_del_contrato'] != null) {
            double valorContrato =
                double.tryParse(contrato['valor_del_contrato'].toString()) ?? 0;

            if (valorContrato < 50000000000) {
              sumaTotal += valorContrato;

              // Agrupamos el gasto por tipo de contrato para el gráfico
              String tipo = contrato['tipo_de_contrato'] ?? 'Otros';
              distribucionGastos[tipo] =
                  (distribucionGastos[tipo] ?? 0) + valorContrato;
            }
          }
        }

        setState(() {
          totalGastadoGlobal = sumaTotal;
          // Guardamos el mapa en una variable de la clase para que el Widget Build la use
          this.distribucionActual = distribucionGastos;
          isLoadingPresupuesto = false;
        });
      }
    } catch (e) {
      setState(() => isLoadingPresupuesto = false);
    }
  }

  Color _obtenerColorEstado(String estado) {
    final estadoLower = estado.toLowerCase();
    if (estadoLower.contains('celebrado') ||
        estadoLower.contains('liquidado') ||
        estadoLower.contains('terminado'))
      return Colors.green;
    if (estadoLower.contains('enviado') ||
        estadoLower.contains('convocado') ||
        estadoLower.contains('evaluaci') ||
        estadoLower.contains('adjudicado'))
      return Colors.orange;
    if (estadoLower.contains('borrador') ||
        estadoLower.contains('descartado') ||
        estadoLower.contains('cancelado'))
      return Colors.grey;
    return Colors.blue;
  }

  Future<void> cargarDatos({required bool limpiar}) async {
    if (limpiar) {
      setState(() {
        isLoading = true;
        offsetActual = 0;
        hayMasDatos = true;
        contratos.clear();
        contratosFiltrados.clear();
      });
    } else {
      setState(() => cargandoMas = true);
    }

    try {
      final urlStr =
          '${_construirUrlBase()}\$limit=$limitePagina&\$offset=$offsetActual&\$order=fecha_de_firma DESC';
      final respuesta = await http.get(Uri.parse(urlStr));

      if (respuesta.statusCode == 200) {
        final List<dynamic> data = json.decode(respuesta.body);

        if (data.isEmpty || data.length < limitePagina) {
          hayMasDatos = false;
        }

        var datosNuevos = data;
        if (widget.dependencia != 'Todas las dependencias') {
          final keyword = _normalizarTexto(widget.dependencia);
          datosNuevos = data.where((contrato) {
            final descripcion = _normalizarTexto(
              (contrato['descripcion_del_proceso'] ?? '').toString(),
            );
            final entidad = _normalizarTexto(
              (contrato['nombre_entidad'] ?? '').toString(),
            );
            return descripcion.contains(keyword) || entidad.contains(keyword);
          }).toList();
        }

        // ---> AQUÍ DEJAS EL RESTO DEL CÓDIGO QUE YA TENÍAS EN ESTA FUNCIÓN <---
        // (Donde agregabas "datosNuevos" a tu lista principal y hacías el setState)

        final datosProcesados = datosNuevos.map((contrato) {
          double valor = 0;
          if (contrato['valor_del_contrato'] != null) {
            valor =
                double.tryParse(contrato['valor_del_contrato'].toString()) ?? 0;
          }
          contrato['valor_formateado'] = formatoMoneda.format(valor);
          contrato['nombre_entidad'] =
              contrato['nombre_entidad'] ?? 'Entidad no especificada';
          contrato['descripcion_del_proceso'] =
              contrato['descripcion_del_proceso'] ?? 'Sin descripción';
          contrato['estado_contrato'] =
              contrato['estado_contrato'] ?? 'Desconocido';

          return contrato;
        }).toList();

        setState(() {
          contratos.addAll(datosProcesados);
          offsetActual += limitePagina;
          if (limpiar)
            isLoading = false;
          else
            cargandoMas = false;
        });
        aplicarFiltros();
      } else {
        setState(() {
          mensajeError = 'Error del servidor';
          isLoading = false;
          cargandoMas = false;
        });
      }
    } catch (e) {
      setState(() {
        mensajeError = 'Error de conexión';
        isLoading = false;
        cargandoMas = false;
      });
    }
  }

  void aplicarFiltros() {
    if (_temporizadorRebote?.isActive ?? false) _temporizadorRebote!.cancel();

    _temporizadorRebote = Timer(const Duration(milliseconds: 300), () {
      List<dynamic> resultadosTemporales = List.from(contratos);

      if (controladorBusqueda.text.isNotEmpty) {
        final busqueda = controladorBusqueda.text.toLowerCase();
        resultadosTemporales = resultadosTemporales.where((contrato) {
          final entidad = contrato['nombre_entidad'].toString().toLowerCase();
          final descripcion = contrato['descripcion_del_proceso']
              .toString()
              .toLowerCase();
          final proveedor = (contrato['proveedor_adjudicado'] ?? '')
              .toString()
              .toLowerCase();
          return entidad.contains(busqueda) ||
              descripcion.contains(busqueda) ||
              proveedor.contains(busqueda);
        }).toList();
      }

      if (filtroEstado != 'Todos') {
        resultadosTemporales = resultadosTemporales.where((contrato) {
          final color = _obtenerColorEstado(contrato['estado_contrato']);
          if (filtroEstado == 'En Proceso') return color == Colors.orange;
          if (filtroEstado == 'Celebrados') return color == Colors.green;
          if (filtroEstado == 'Borradores') return color == Colors.grey;
          return true;
        }).toList();
      }

      if (ordenValor == 'Mayor a Menor') {
        resultadosTemporales.sort((a, b) {
          double valA =
              double.tryParse(a['valor_del_contrato']?.toString() ?? '0') ?? 0;
          double valB =
              double.tryParse(b['valor_del_contrato']?.toString() ?? '0') ?? 0;
          return valB.compareTo(valA);
        });
      } else if (ordenValor == 'Menor a Mayor') {
        resultadosTemporales.sort((a, b) {
          double valA =
              double.tryParse(a['valor_del_contrato']?.toString() ?? '0') ?? 0;
          double valB =
              double.tryParse(b['valor_del_contrato']?.toString() ?? '0') ?? 0;
          return valA.compareTo(valB);
        });
      }

      setState(() {
        contratosFiltrados = resultadosTemporales;
      });
    });
  }

  void _exportarAExcel() {
    if (contratosFiltrados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar.')),
      );
      return;
    }

    List<List<dynamic>> filas = [
      [
        'Entidad',
        'Objeto del Proceso',
        'Proveedor',
        'Estado',
        'Valor del Contrato',
        'Modalidad',
        'Fecha de Firma',
      ],
    ];

    for (var contrato in contratosFiltrados) {
      String descripcion =
          (contrato['descripcion_del_proceso'] ?? 'Sin descripción')
              .toString()
              .replaceAll('\n', ' ')
              .replaceAll(';', ',');
      String entidad = (contrato['nombre_entidad'] ?? 'Sin entidad')
          .toString()
          .replaceAll(';', ',');
      String proveedor = (contrato['proveedor_adjudicado'] ?? 'Por definir')
          .toString()
          .replaceAll(';', ',');

      filas.add([
        entidad,
        descripcion,
        proveedor,
        contrato['estado_contrato'] ?? 'Desconocido',
        contrato['valor_del_contrato'] ?? '0',
        contrato['modalidad_de_contratacion'] ?? 'No especificada',
        contrato['fecha_de_firma'] != null
            ? contrato['fecha_de_firma'].toString().split('T')[0]
            : 'En proceso',
      ]);
    }

    String nombreArchivo = widget.nivel == 'Municipal'
        ? widget.municipio!
        : widget.nivel == 'Departamental'
        ? widget.departamento!
        : 'Nacional';

    exportCsv(
      context: context,
      rows: filas,
      fileName: 'Reporte_SECOP_$nombreArchivo.csv',
    );
  }

  Widget _construirChipFiltro(String etiqueta, Color colorBase) {
    final isSelected = filtroEstado == etiqueta;
    return ChoiceChip(
      label: Text(
        etiqueta,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? colorBase : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: colorBase.withOpacity(0.15),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? colorBase.withOpacity(0.5) : Colors.grey.shade300,
      ),
      onSelected: (bool selected) {
        setState(() => filtroEstado = etiqueta);
        aplicarFiltros();
      },
    );
  }

  List<PieChartSectionData> _generarSecciones() {
    if (distribucionActual.isEmpty || totalGastadoGlobal == 0) {
      return [
        PieChartSectionData(
          color: Colors.grey.shade300,
          value: 100,
          title: '',
          radius: 18,
        ),
      ];
    }

    int index = 0;
    return distribucionActual.entries.map((entry) {
      final color = paletaColoresGrafico[index % paletaColoresGrafico.length];
      final porcentaje = (entry.value / totalGastadoGlobal) * 100;
      index++;
      return PieChartSectionData(
        color: color,
        value: porcentaje,
        title: '',
        radius: 18,
      );
    }).toList();
  }

  List<Widget> _generarLeyendas() {
    if (distribucionActual.isEmpty)
      return [
        const Text(
          'Sin datos calculables',
          style: TextStyle(color: Colors.grey),
        ),
      ];

    int index = 0;
    // Ordenamos de mayor a menor para que el gráfico tenga más sentido
    var entradasOrdenadas = distribucionActual.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entradasOrdenadas.map((entry) {
      final color = paletaColoresGrafico[index % paletaColoresGrafico.length];
      final porcentaje = (entry.value / totalGastadoGlobal) * 100;
      index++;

      // Acortamos textos muy largos (ej. "Prestación de Servicios" a 22 letras)
      String nombreTipo = entry.key;
      if (nombreTipo.length > 22)
        nombreTipo = '${nombreTipo.substring(0, 22)}...';

      return Padding(
        padding: const EdgeInsets.only(bottom: 6.0),
        child: IndicadorLeyenda(
          color: color,
          texto: nombreTipo,
          porcentaje: '${porcentaje.toStringAsFixed(1)}%',
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    String tituloAppbar = widget.nivel == 'Municipal'
        ? 'Municipio: ${widget.municipio}'
        : widget.nivel == 'Departamental'
        ? 'Depto: ${widget.departamento}'
        : 'Orden Nacional';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mostrará "DEPARTAMENTO DEL CESAR" en lugar de solo el Municipio
            Text(
              widget.entidad != 'Todas las entidades'
                  ? widget.entidad
                  : tituloAppbar,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              widget.dependencia,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        // ... (conserva el resto de tu código del AppBar)
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.home_outlined,
              color: Colors.blueGrey,
              size: 28,
            ),
            tooltip: 'Volver al Inicio',
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _exportarAExcel,
        backgroundColor: Colors.green[700],
        icon: const Icon(Icons.table_chart, color: Colors.white),
        label: const Text(
          'Exportar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      // CAMBIO CLAVE 1: Reemplazamos Column por ListView y le asignamos el controlador
      body: ListView(
        controller: controladorScroll,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: isLoadingPresupuesto
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '¿En qué se está gastando?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 700),
                          child: SizedBox(
                            height: 180,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      PieChart(
                                        PieChartData(
                                          sectionsSpace: 2,
                                          centerSpaceRadius: 60,
                                          startDegreeOffset: -90,
                                          sections: _generarSecciones(), // <-- AQUÍ LLAMAMOS LA FUNCIÓN DINÁMICA
                                        ),
                                      ),
                                      SizedBox(
                                        width: 90,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                'Total',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              Text(
                                                _formatearValorCorto(
                                                  totalGastadoGlobal,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 40),
                                Expanded(
                                  // Usamos SingleChildScrollView por si hay muchos tipos de contratos distintos
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: _generarLeyendas(), // <-- AQUÍ LLAMAMOS LAS LEYENDAS DINÁMICAS
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: controladorBusqueda,
              onChanged: (val) => aplicarFiltros(),
              decoration: InputDecoration(
                hintText: 'Buscar en contratos descargados...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(
                  Icons.filter_alt_outlined,
                  color: Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                _construirChipFiltro('Todos', Colors.blue),
                const SizedBox(width: 8),
                _construirChipFiltro('En Proceso', Colors.orange),
                const SizedBox(width: 8),
                _construirChipFiltro('Celebrados', Colors.green),
                const SizedBox(width: 8),
                _construirChipFiltro('Borradores', Colors.grey),
                const SizedBox(width: 16),
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: ordenValor,
                      icon: const Icon(
                        Icons.sort,
                        size: 16,
                        color: Colors.grey,
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      items: ['Ninguno', 'Mayor a Menor', 'Menor a Mayor']
                          .map(
                            (String value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value == 'Ninguno' ? 'Ordenar por...' : value,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => ordenValor = newValue);
                          aplicarFiltros();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // CAMBIO CLAVE 2: Eliminamos el "Expanded"
          isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : mensajeError.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      mensajeError,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : contratosFiltrados.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No hay resultados.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                )
              : ListView.builder(
                  // CAMBIO CLAVE 3: Bloqueamos el scroll interno para usar el del ListView padre
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: contratosFiltrados.length + (cargandoMas ? 1 : 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemBuilder: (context, index) {
                    if (index == contratosFiltrados.length)
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    final contrato = contratosFiltrados[index];
                    final idUnico =
                        (contrato['proceso_de_compra'] ??
                                '${contrato['nombre_entidad']}${contrato['descripcion_del_proceso']}')
                            .toString();
                    return _TarjetaContrato(
                      contrato: contrato,
                      esFavorito: favoritosIds.contains(idUnico),
                      onToggleFavorite: () => _toggleFavorito(contrato),
                      onReturnFromDetail: _cargarFavoritosLocales,
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _construirIndicador(IconData icono, String titulo, String valor) {
    return Column(
      children: [
        Icon(icono, color: Colors.yellow[700], size: 30),
        const SizedBox(height: 8),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(titulo, style: TextStyle(fontSize: 14, color: Colors.blue[200])),
      ],
    );
  }
}

class IndicadorLeyenda extends StatelessWidget {
  final Color color;
  final String texto;
  final String porcentaje;

  const IndicadorLeyenda({
    super.key,
    required this.color,
    required this.texto,
    required this.porcentaje,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            porcentaje,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaContrato extends StatelessWidget {
  final dynamic contrato;
  final bool esFavorito;
  final VoidCallback onToggleFavorite;
  final Future<void> Function() onReturnFromDetail;

  const _TarjetaContrato({
    required this.contrato,
    required this.esFavorito,
    required this.onToggleFavorite,
    required this.onReturnFromDetail,
  });

  @override
  Widget build(BuildContext context) {
    final entidad = contrato['nombre_entidad'] ?? 'Entidad no registrada';
    final proveedor =
        contrato['proveedor_adjudicado'] ?? 'Proveedor sin nombre';
    final valor = contrato['valor_del_contrato'] ?? '0';
    final valorNumerico = num.tryParse(valor.toString());
    final valorFormateado = valorNumerico != null
        ? NumberFormat.decimalPattern('es_CO').format(valorNumerico.toInt())
        : valor.toString();
    // Limpiamos saltos de línea y espacios extra del texto original
    final String objetoRaw =
        contrato['descripcion_del_proceso'] ?? 'Sin descripción registrada';
    final objeto = objetoRaw.replaceAll(RegExp(r'\s+'), ' ').trim();
    final fechaFirma = contrato['fecha_de_firma'] != null
        ? contrato['fecha_de_firma'].toString().split('T')[0]
        : 'Sin fecha';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetalleContratoScreen(contrato: contrato),
            ),
          );
          await onReturnFromDetail();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '\$ $valorFormateado',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      fechaFirma,
                      style: TextStyle(
                        color: Colors.blue[900],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: esFavorito
                        ? 'Eliminar de favoritos'
                        : 'Guardar en favoritos',
                    onPressed: onToggleFavorite,
                    icon: Icon(
                      esFavorito ? Icons.star : Icons.star_border,
                      color: esFavorito ? Colors.orange : Colors.blueGrey,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.account_balance,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entidad,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PerfilContratistaScreen(
                          nombreContratista: proveedor.toString(),
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 6.0,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Colors.teal, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            proveedor,
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                objeto,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
