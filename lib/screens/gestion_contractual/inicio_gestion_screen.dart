import 'package:flutter/material.dart';

import 'estilo_contractual.dart';

/// Los dos caminos de la gestión contractual.
enum CaminoGestion { prestacionServicios, importarSecop }

/// Pantalla de inicio de una gestión: la prestación de servicios se
/// estructura aquí antes de ir a SECOP II; las demás modalidades ya existen
/// en SECOP II y se importan para hacerles seguimiento.
class InicioGestionScreen extends StatelessWidget {
  const InicioGestionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final dosColumnas = ancho >= 860;
    final opciones = [
      _OpcionCamino(
        icono: Icons.edit_document,
        color: const Color(0xFF0F766E),
        fondo: const Color(0xFFCCFBF1),
        etiqueta: 'Antes de SECOP II',
        titulo: 'Estructurar nuevo proceso',
        subtitulo:
            'Prestación de servicios profesionales y de apoyo a la gestión',
        puntos: const [
          'Creas el expediente del contratista desde cero.',
          'Le envías un enlace para que cargue sus documentos.',
          'El equipo verifica, devuelve para subsanar y emite el aval.',
          'Cuando todo está listo, lo publicas en SECOP II.',
        ],
        accion: 'Estructurar proceso',
        onTap: () => Navigator.pop(context, CaminoGestion.prestacionServicios),
      ),
      _OpcionCamino(
        icono: Icons.cloud_download_outlined,
        color: const Color(0xFF1D4ED8),
        fondo: const Color(0xFFDBEAFE),
        etiqueta: 'Ya está en SECOP II',
        titulo: 'Importar proceso existente',
        subtitulo: 'Licitación, selección abreviada, mínima cuantía, concurso de méritos y demás',
        puntos: const [
          'Pegas el ID o el enlace del proceso en SECOP II.',
          'La app trae su estado, fechas, valor y documentos publicados.',
          'Con un clic actualizas el estado y ves qué cambió.',
          'El equipo lleva cronograma, observaciones y verificación de ofertas.',
        ],
        accion: 'Importar desde SECOP II',
        onTap: () => Navigator.pop(context, CaminoGestion.importarSecop),
      ),
    ];

    return PantallaContractual(
      anchoMaximo: 1040,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PildoraVolver(
            etiqueta: 'Equipo jurídico',
            onTap: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '¿Qué vas a gestionar?',
          textAlign: TextAlign.center,
          style: EstiloContractual.titulo,
        ),
        const SizedBox(height: 10),
        const Text(
          'El camino depende de la modalidad: la prestación de servicios se prepara aquí antes de publicarla; '
          'las demás modalidades se crean en SECOP II y aquí se les hace seguimiento.',
          textAlign: TextAlign.center,
          style: EstiloContractual.subtitulo,
        ),
        const SizedBox(height: 28),
        if (dosColumnas)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: opciones[0]),
                const SizedBox(width: 18),
                Expanded(child: opciones[1]),
              ],
            ),
          )
        else ...[
          opciones[0],
          const SizedBox(height: 16),
          opciones[1],
        ],
        const SizedBox(height: 30),
      ],
    );
  }
}

class _OpcionCamino extends StatefulWidget {
  const _OpcionCamino({
    required this.icono,
    required this.color,
    required this.fondo,
    required this.etiqueta,
    required this.titulo,
    required this.subtitulo,
    required this.puntos,
    required this.accion,
    required this.onTap,
  });

  final IconData icono;
  final Color color;
  final Color fondo;
  final String etiqueta;
  final String titulo;
  final String subtitulo;
  final List<String> puntos;
  final String accion;
  final VoidCallback onTap;

  @override
  State<_OpcionCamino> createState() => _OpcionCaminoState();
}

class _OpcionCaminoState extends State<_OpcionCamino> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(0, _encima ? -3 : 0, 0),
        decoration: EstiloContractual.tarjeta(
          colorBorde: _encima ? widget.color : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: widget.fondo,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          widget.icono,
                          color: widget.color,
                          size: 26,
                        ),
                      ),
                      const Spacer(),
                      EtiquetaColor(
                        texto: widget.etiqueta,
                        color: widget.color,
                        fondo: widget.fondo,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.titulo,
                    style: const TextStyle(
                      color: EstiloContractual.navy,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitulo,
                    style: TextStyle(
                      color: widget.color,
                      fontSize: 13.2,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final p in widget.puntos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 17,
                            color: widget.color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p,
                              style: const TextStyle(
                                color: EstiloContractual.texto,
                                fontSize: 13.3,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: widget.onTap,
                      style: EstiloContractual.botonPrincipal().copyWith(
                        backgroundColor: WidgetStatePropertyAll(widget.color),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(
                        widget.accion,
                        style: EstiloContractual.etiquetaBoton,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
