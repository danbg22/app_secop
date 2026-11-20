import 'package:flutter/material.dart';

import '../tema/cristal.dart';

/// Bandera de control: algo que conviene revisar en SECOP II, con la norma
/// que lo explica. No afirma que haya una irregularidad.
class AvisoParaRevisar extends StatelessWidget {
  const AvisoParaRevisar({
    super.key,
    required this.titulo,
    required this.detalle,
    this.puntos = const [],
  });

  final String titulo;
  final String detalle;

  /// Casos concretos (por ejemplo, los contratos que se cruzan).
  final List<String> puntos;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Cristal.ambarVidrio,
        borderRadius: BorderRadius.circular(Cristal.radioCampo),
        border: Border.all(color: Cristal.ambarBorde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.flag_outlined, size: 20, color: Cristal.ambar),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Para revisar · $titulo',
                  style: TextStyle(
                    color: Cristal.texto,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  detalle,
                  style: TextStyle(
                    color: Cristal.textoCuerpo,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                for (final p in puntos) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Cristal.ambar,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p,
                          style: TextStyle(
                            color: Cristal.textoMedio,
                            fontSize: 12.8,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
