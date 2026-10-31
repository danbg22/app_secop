import 'package:flutter/material.dart';

import '../../data/modalidades_contratacion.dart';
import 'estilo_contractual.dart';

/// Primer paso de Gestión contractual: escoger la modalidad de selección.
/// Devuelve la modalidad elegida con `Navigator.pop`.
class SelectorModalidadScreen extends StatelessWidget {
  const SelectorModalidadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final columnas = ancho >= 1040 ? 3 : (ancho >= 680 ? 2 : 1);
    final directas = modalidadesContratacion
        .where((m) => !m.esCompetitiva)
        .toList();
    final competitivas = modalidadesContratacion
        .where((m) => m.esCompetitiva)
        .toList();

    Widget grilla(List<ModalidadContratacion> modalidades) => LayoutBuilder(
      builder: (context, c) {
        const espacio = 16.0;
        final anchoTarjeta = (c.maxWidth - espacio * (columnas - 1)) / columnas;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final m in modalidades)
              SizedBox(
                width: anchoTarjeta,
                child: _TarjetaModalidad(
                  modalidad: m,
                  onTap: () => Navigator.pop(context, m),
                ),
              ),
          ],
        );
      },
    );

    return PantallaContractual(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PildoraVolver(
            etiqueta: 'Gestión contractual',
            onTap: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '¿Qué modalidad vas a tramitar?',
          textAlign: TextAlign.center,
          style: EstiloContractual.titulo,
        ),
        const SizedBox(height: 10),
        const Text(
          'Cada modalidad trae sus etapas, campos y documentos según la Ley 80 de 1993, '
          'la Ley 1150 de 2007 y el Decreto 1082 de 2015.',
          textAlign: TextAlign.center,
          style: EstiloContractual.subtitulo,
        ),
        const SizedBox(height: 28),
        const Text('CONTRATACIÓN DIRECTA', style: EstiloContractual.seccion),
        const SizedBox(height: 10),
        grilla(directas),
        const SizedBox(height: 28),
        const Text(
          'CONVOCATORIA PÚBLICA CON OFERENTES',
          style: EstiloContractual.seccion,
        ),
        const SizedBox(height: 10),
        grilla(competitivas),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _TarjetaModalidad extends StatefulWidget {
  const _TarjetaModalidad({required this.modalidad, required this.onTap});

  final ModalidadContratacion modalidad;
  final VoidCallback onTap;

  @override
  State<_TarjetaModalidad> createState() => _TarjetaModalidadState();
}

class _TarjetaModalidadState extends State<_TarjetaModalidad> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.modalidad;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 236),
          padding: const EdgeInsets.all(12),
          decoration: EstiloContractual.tarjeta(
            colorBorde: _hover ? m.color.withValues(alpha: 0.6) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 72,
                width: double.infinity,
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                decoration: BoxDecoration(
                  color: m.fondo,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: m.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Icon(m.icono, color: Colors.white, size: 21),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.nombre,
                      style: const TextStyle(
                        color: EstiloContractual.navy,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m.resumen,
                      style: const TextStyle(
                        color: EstiloContractual.texto,
                        fontSize: 12.8,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            m.esCompetitiva
                                ? '${m.etapas.length} etapas · ${m.documentosOferente.length} requisitos por oferente'
                                : (m.etapas.isEmpty
                                      ? 'Expediente con enlace al contratista'
                                      : '${m.etapas.length} etapas · un contratista'),
                            style: TextStyle(
                              color: m.color,
                              fontSize: 11.8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: _hover ? m.color : EstiloContractual.gris,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
