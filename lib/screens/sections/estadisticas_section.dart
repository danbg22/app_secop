import 'package:flutter/material.dart';

import '../../utils/csv_exporter.dart';

class EstadisticasSection extends StatelessWidget {
  const EstadisticasSection({super.key});

  static const Color _azulOscuro = Color(0xFF1A2B4C);

  void _exportStatsCsv(BuildContext context) {
    final rows = <List<dynamic>>[
      ['Dependencia', 'Contratos', 'Valor Contratado'],
      ['Obras Públicas', '386', '\$ 68.420 M'],
      ['Educación', '294', '\$ 42.180 M'],
      ['Salud', '218', '\$ 31.760 M'],
      ['Planeación', '164', '\$ 19.320 M'],
    ];

    exportCsv(
      context: context,
      rows: rows,
      fileName: 'Reporte_Estadisticas_SECOP.csv',
    );
  }

  Widget _statHighlight(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF4D6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFB77900), size: 16),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _azulOscuro,
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRightSide(BuildContext context) {
    Widget panel({required Widget child, Color color = Colors.white}) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: _azulOscuro.withValues(alpha: 0.05),
              blurRadius: 13,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lo más destacado',
                style: TextStyle(
                  color: _azulOscuro,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _statHighlight(
                Icons.account_balance,
                'Obras públicas concentra la mayor inversión.',
              ),
              _statHighlight(
                Icons.description,
                'La modalidad directa lidera en número de contratos.',
              ),
              _statHighlight(
                Icons.trending_up,
                'La contratación aumentó frente al año anterior.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        panel(
          color: const Color(0xFF0B2136),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Color(0xFFFFD54F),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Explorar mapa de calor',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD54F),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      'NUEVO',
                      style: TextStyle(
                        color: _azulOscuro,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Identifica zonas con mayor concentración de inversión pública.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.map_outlined,
                    size: 48,
                    color: Color(0x5579B8D8),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD54F),
                    foregroundColor: _azulOscuro,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: const Text(
                    'Ver mapa →',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.insert_drive_file_outlined,
                    color: Color(0xFF1976D2),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Exportar reporte general',
                      style: TextStyle(
                        color: _azulOscuro,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Descarga un resumen de la contratación pública en formato CSV.',
                style: TextStyle(
                  color: Colors.blueGrey.shade600,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _exportStatsCsv(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD54F),
                    foregroundColor: _azulOscuro,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: const Text(
                    'Exportar reporte →',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget selector(String label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE4E9EF)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _azulOscuro,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 17,
              color: Color(0xFF78909C),
            ),
          ],
        ),
      );
    }

    Widget kpi({
      required IconData icon,
      required Color iconColor,
      required Color iconBackground,
      required String label,
      required String value,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _azulOscuro.withValues(alpha: 0.05),
                blurRadius: 13,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 10),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _azulOscuro,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'En 2026',
                style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 9),
              ),
            ],
          ),
        ),
      );
    }

    Widget chartPanel({
      required String title,
      required Widget content,
      required int flex,
    }) {
      return Expanded(
        flex: flex,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: _azulOscuro.withValues(alpha: 0.05),
                blurRadius: 13,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _azulOscuro,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Descargar gráfica',
                    onPressed: () => _exportStatsCsv(context),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.download_outlined,
                      size: 18,
                      color: Color(0xFF78909C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(height: 218, child: content),
            ],
          ),
        ),
      );
    }

    Widget placeholderChart(String message, {IconData icon = Icons.bar_chart}) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEDF0F4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 35, color: const Color(0xFFB0BEC5)),
            const SizedBox(height: 9),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 11),
            ),
          ],
        ),
      );
    }

    Widget tableHeader(String label, {TextAlign align = TextAlign.left}) {
      return Expanded(
        child: Text(
          label,
          textAlign: align,
          style: TextStyle(
            color: Colors.blueGrey.shade600,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final departmentRows = [
      ('Obras Públicas', '386', '\$ 68.420 M'),
      ('Educación', '294', '\$ 42.180 M'),
      ('Salud', '218', '\$ 31.760 M'),
      ('Planeación', '164', '\$ 19.320 M'),
    ];

    return Expanded(
      child: Container(
        color: const Color(0xFFFFF8E7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 75,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 120,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  const ColoredBox(color: Color(0xFFFFF8E7)),
                                  ShaderMask(
                                    blendMode: BlendMode.dstIn,
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.transparent,
                                        Colors.white,
                                      ],
                                      stops: [0.05, 0.85],
                                    ).createShader(bounds),
                                    child: Image.asset(
                                      'assets/images/fondo_valledupar.jpg',
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const SizedBox.expand(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Estadísticas',
                                  style: TextStyle(
                                    color: _azulOscuro,
                                    fontSize: 29,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Analiza la contratación pública y descubre sus tendencias.',
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _azulOscuro.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(child: selector('Valledupar')),
                          const SizedBox(width: 9),
                          Expanded(child: selector('2026')),
                          const SizedBox(width: 9),
                          Expanded(child: selector('Trimestre')),
                          const SizedBox(width: 9),
                          Expanded(child: selector('Sector')),
                          const SizedBox(width: 9),
                          ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Datos actualizados para Valledupar, 2026.',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text(
                              'Actualizar datos',
                              style: TextStyle(fontSize: 10),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _azulOscuro,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        kpi(
                          icon: Icons.description,
                          iconColor: const Color(0xFF1976D2),
                          iconBackground: const Color(0xFFE3F2FD),
                          label: 'Total contratos',
                          value: '1.248',
                        ),
                        const SizedBox(width: 11),
                        kpi(
                          icon: Icons.monetization_on,
                          iconColor: const Color(0xFF388E3C),
                          iconBackground: const Color(0xFFE8F5E9),
                          label: 'Valor contratado',
                          value: '\$182.400 M',
                        ),
                        const SizedBox(width: 11),
                        kpi(
                          icon: Icons.account_balance,
                          iconColor: const Color(0xFF303F9F),
                          iconBackground: const Color(0xFFE8EAF6),
                          label: 'Entidades',
                          value: '48',
                        ),
                        const SizedBox(width: 11),
                        kpi(
                          icon: Icons.people,
                          iconColor: const Color(0xFF00897B),
                          iconBackground: const Color(0xFFE0F2F1),
                          label: 'Contratistas',
                          value: '487',
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        chartPanel(
                          title: 'Evolución de la contratación (Mes a mes)',
                          flex: 2,
                          content: placeholderChart(
                            'Gráfica de Barras Verticales aquí',
                          ),
                        ),
                        const SizedBox(width: 14),
                        chartPanel(
                          title: 'Contratos por modalidad',
                          flex: 1,
                          content: placeholderChart(
                            'Gráfica de Dona aquí',
                            icon: Icons.donut_large,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        chartPanel(
                          title: '¿En qué se ha contratado más?',
                          flex: 1,
                          content: placeholderChart(
                            'Barras horizontales por sector',
                            icon: Icons.bar_chart,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: _azulOscuro.withValues(alpha: 0.05),
                                  blurRadius: 13,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Contratación por dependencia',
                                  style: TextStyle(
                                    color: _azulOscuro,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  color: const Color(0xFFF4F6F8),
                                  child: Row(
                                    children: [
                                      tableHeader('Dependencia'),
                                      tableHeader(
                                        'Contratos',
                                        align: TextAlign.center,
                                      ),
                                      tableHeader(
                                        'Valor contratado',
                                        align: TextAlign.right,
                                      ),
                                    ],
                                  ),
                                ),
                                for (final row in departmentRows)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 12,
                                    ),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Color(0xFFEEF1F4),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            row.$1,
                                            style: const TextStyle(
                                              color: _azulOscuro,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            row.$2,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: _azulOscuro,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            row.$3,
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              color: _azulOscuro,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(flex: 25, child: _buildStatsRightSide(context)),
            ],
          ),
        ),
      ),
    );
  }
}

