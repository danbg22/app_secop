import 'package:flutter/material.dart';

import '../perfil_contratista_screen.dart';

class ContratistasSection extends StatelessWidget {
  const ContratistasSection({super.key});

  static const Color _azulOscuro = Color(0xFF1A2B4C);
  static const TextStyle _contractorHeaderStyle = TextStyle(
    color: Color(0xFF526575),
    fontSize: 9,
    fontWeight: FontWeight.w600,
  );

  void _openContractorProfile(BuildContext context, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PerfilContratistaScreen(
          nombreContratista: name,
          nombreBuscado: name,
        ),
      ),
    );
  }

  Widget _paginationButton(
    IconData? icon, {
    String? label,
    bool selected = false,
  }) {
    return Container(
      width: 27,
      height: 27,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: selected ? _azulOscuro : Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: selected ? _azulOscuro : const Color(0xFFE1E6EC),
        ),
      ),
      child: Center(
        child: icon != null
            ? Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : Colors.blueGrey.shade500,
              )
            : Text(
                label ?? '',
                style: TextStyle(
                  color: selected ? Colors.white : _azulOscuro,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildContractorTableRow(
    BuildContext context, {
    required int index,
    required String initials,
    required String name,
    required String nit,
    required String personType,
    required String contracts,
    required String value,
  }) {
    final isNaturalPerson = personType == 'Persona natural';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEF1F4))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '$index',
              style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 10),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: _azulOscuro,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
          Expanded(
            flex: 2,
            child: Text(
              nit,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 10),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: isNaturalPerson
                      ? const Color(0xFFFFF4D6)
                      : const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  personType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isNaturalPerson
                        ? const Color(0xFF8D6E00)
                        : const Color(0xFF1565C0),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              contracts,
              style: const TextStyle(
                color: _azulOscuro,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _azulOscuro,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 92,
            child: OutlinedButton(
              onPressed: () => _openContractorProfile(context, name),
              style: OutlinedButton.styleFrom(
                foregroundColor: _azulOscuro,
                side: const BorderSide(color: Color(0xFFD8E0E8)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Ver perfil →',
                maxLines: 1,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContractorsRightSide(BuildContext context) {
    Widget panel({required Widget child, Color color = Colors.white}) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _azulOscuro.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
    }

    const topContractors = [
      ('CV', 'Consorcio Vías del Cesar', '24 contratos', '\$3.840 M'),
      ('SD', 'Soluciones Digitales S.A.S.', '17 contratos', '\$1.275 M'),
      ('JM', 'Juan Manuel Rodríguez', '8 contratos', '\$48.2 M'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Top contratistas',
                style: TextStyle(
                  color: _azulOscuro,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              for (var index = 0; index < topContractors.length; index++) ...[
                if (index > 0) const SizedBox(height: 14),
                InkWell(
                  onTap: () =>
                      _openContractorProfile(context, topContractors[index].$2),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      Container(
                        width: 23,
                        height: 23,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: index == 0
                              ? const Color(0xFFFFD54F)
                              : const Color(0xFFF0F2F5),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: _azulOscuro,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFE3F2FD),
                        child: Text(
                          topContractors[index].$1,
                          style: const TextStyle(
                            color: _azulOscuro,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topContractors[index].$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _azulOscuro,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${topContractors[index].$3} · ${topContractors[index].$4}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.blueGrey.shade500,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        panel(
          color: const Color(0xFF0B2136),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Mapa de contratistas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD54F),
                      borderRadius: BorderRadius.circular(6),
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
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Visualiza relaciones entre contratistas, entidades y contratos.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  SizedBox(
                    width: 65,
                    height: 56,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 15,
                          top: 27,
                          child: Transform.rotate(
                            angle: -0.4,
                            child: Container(
                              width: 37,
                              height: 1,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 2,
                          top: 21,
                          child: Icon(
                            Icons.circle,
                            size: 12,
                            color: Color(0xFFFFD54F),
                          ),
                        ),
                        const Positioned(
                          left: 29,
                          top: 5,
                          child: Icon(
                            Icons.circle,
                            size: 15,
                            color: Color(0xFF64B5F6),
                          ),
                        ),
                        const Positioned(
                          right: 2,
                          bottom: 8,
                          child: Icon(
                            Icons.circle,
                            size: 12,
                            color: Color(0xFF80CBC4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      _openContractorProfile(context, 'Consorcio Vías del Cesar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: const Text(
                    'Ver mapa interactivo →',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        panel(
          color: const Color(0xFFFFF4D6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Color(0xFFB77900)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Conoce más sobre un contratista',
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
                'Consulta su historial, contratos y entidades relacionadas.',
                style: TextStyle(
                  color: Colors.blueGrey.shade700,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      _openContractorProfile(context, 'María Fernanda Rojas'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD54F),
                    foregroundColor: _azulOscuro,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: const Text(
                    'Explorar historial completo →',
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
    Widget filterDropdown(String label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE1E6EC)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(color: _azulOscuro, fontSize: 11),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: Color(0xFF78909C),
            ),
          ],
        ),
      );
    }

    Widget summaryCard({
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
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _azulOscuro,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    const contractors = [
      (
        initials: 'JM',
        name: 'Juan Manuel Rodríguez',
        nit: '1.065.842.391',
        kind: 'Persona natural',
        contracts: '8',
        value: '\$ 48.200.000',
      ),
      (
        initials: 'CV',
        name: 'Consorcio Vías del Cesar',
        nit: '901.284.632-1',
        kind: 'Persona jurídica',
        contracts: '24',
        value: '\$ 3.840.500.000',
      ),
      (
        initials: 'MR',
        name: 'María Fernanda Rojas',
        nit: '49.782.163',
        kind: 'Persona natural',
        contracts: '6',
        value: '\$ 36.750.000',
      ),
      (
        initials: 'SD',
        name: 'Soluciones Digitales S.A.S.',
        nit: '900.638.471-5',
        kind: 'Persona jurídica',
        contracts: '17',
        value: '\$ 1.275.900.000',
      ),
      (
        initials: 'CG',
        name: 'Carlos Alberto Guerra',
        nit: '77.184.936',
        kind: 'Persona natural',
        contracts: '5',
        value: '\$ 29.400.000',
      ),
    ];

    return Expanded(
      child: Container(
        color: const Color(0xFFFFF8E7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 75,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 126,
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
                                  'Contratistas',
                                  style: TextStyle(
                                    color: _azulOscuro,
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Conoce quiénes ejecutan los contratos y cómo participan.',
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
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onSubmitted: (q) {
                              if (q.trim().isNotEmpty) {
                                _openContractorProfile(context, q.trim());
                              }
                            },
                            decoration: InputDecoration(
                              hintText:
                                  'Buscar contratista por nombre o NIT...',
                              hintStyle: TextStyle(
                                color: Colors.blueGrey.shade400,
                                fontSize: 11,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Color(0xFF78909C),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        filterDropdown('Sector económico'),
                        const SizedBox(width: 9),
                        filterDropdown('Rango de valor'),
                        const SizedBox(width: 9),
                        filterDropdown('Año'),
                        const SizedBox(width: 9),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.filter_list, size: 17),
                          label: const Text(
                            'Filtros avanzados',
                            style: TextStyle(fontSize: 10),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _azulOscuro,
                            side: const BorderSide(color: Color(0xFFD5DDE6)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        summaryCard(
                          icon: Icons.people,
                          iconColor: const Color(0xFF1976D2),
                          iconBackground: const Color(0xFFE3F2FD),
                          label: 'Total de contratistas',
                          value: '2.486',
                        ),
                        const SizedBox(width: 12),
                        summaryCard(
                          icon: Icons.insert_drive_file,
                          iconColor: const Color(0xFF1976D2),
                          iconBackground: const Color(0xFFE3F2FD),
                          label: 'Total de contratos',
                          value: '3.842',
                        ),
                        const SizedBox(width: 12),
                        summaryCard(
                          icon: Icons.monetization_on,
                          iconColor: const Color(0xFF388E3C),
                          iconBackground: const Color(0xFFE8F5E9),
                          label: 'Valor contratado',
                          value: '\$426.8 mil M',
                        ),
                        const SizedBox(width: 12),
                        summaryCard(
                          icon: Icons.account_balance,
                          iconColor: const Color(0xFF303F9F),
                          iconBackground: const Color(0xFFE8EAF6),
                          label: 'Entidades que contratan',
                          value: '48',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _azulOscuro.withValues(alpha: 0.05),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Lista de contratistas',
                                    style: TextStyle(
                                      color: _azulOscuro,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Ordenar por: ',
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade500,
                                    fontSize: 10,
                                  ),
                                ),
                                const Text(
                                  'Mayor valor',
                                  style: TextStyle(
                                    color: _azulOscuro,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Color(0xFF78909C),
                                  size: 17,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            color: const Color(0xFFF4F6F8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 30,
                                  child: Text(
                                    '#',
                                    style: _contractorHeaderStyle,
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Contratista',
                                    style: _contractorHeaderStyle,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'NIT',
                                    style: _contractorHeaderStyle,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Tipo de persona',
                                    style: _contractorHeaderStyle,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Total de contratos',
                                    style: _contractorHeaderStyle,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Valor contratado',
                                    style: _contractorHeaderStyle,
                                  ),
                                ),
                                SizedBox(
                                  width: 92,
                                  child: Text(
                                    'Acciones',
                                    textAlign: TextAlign.center,
                                    style: _contractorHeaderStyle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: contractors.length,
                            itemBuilder: (context, index) {
                              final contractor = contractors[index];
                              return _buildContractorTableRow(
                                context,
                                index: index + 1,
                                initials: contractor.initials,
                                name: contractor.name,
                                nit: contractor.nit,
                                personType: contractor.kind,
                                contracts: contractor.contracts,
                                value: contractor.value,
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Mostrando 1-5 de 486 contratistas',
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade500,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                _paginationButton(Icons.chevron_left),
                                _paginationButton(
                                  null,
                                  label: '1',
                                  selected: true,
                                ),
                                _paginationButton(null, label: '2'),
                                _paginationButton(null, label: '3'),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    '...',
                                    style: TextStyle(color: Color(0xFF78909C)),
                                  ),
                                ),
                                _paginationButton(null, label: '49'),
                                _paginationButton(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(flex: 25, child: _buildContractorsRightSide(context)),
            ],
          ),
        ),
      ),
    );
  }
}

