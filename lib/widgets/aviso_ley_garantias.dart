import 'package:flutter/material.dart';

import '../services/cronograma_proceso_service.dart';
import '../tema/cristal.dart';
import '../utils/banderas_control.dart';
import 'aviso_para_revisar.dart';

/// Señal de contratación directa firmada en Ley de Garantías, comprobada
/// contra el inicio del proceso en SECOP II.
///
/// SECOP II registra como fecha de firma el momento en que se completó la
/// firma electrónica, que puede ser días después de lo previsto. Si el
/// proceso se publicó y preveía firmarse antes del periodo, no se alerta: se
/// muestran las dos fechas para verificarlas. Mientras se consulta no se
/// muestra nada, para no presentar una alerta que luego desaparezca.
class AvisoLeyGarantias extends StatefulWidget {
  const AvisoLeyGarantias({super.key, required this.contrato});

  final Map<dynamic, dynamic> contrato;

  @override
  State<AvisoLeyGarantias> createState() => _AvisoLeyGarantiasState();
}

class _AvisoLeyGarantiasState extends State<AvisoLeyGarantias> {
  Future<EvaluacionGarantias?>? _evaluacion;

  @override
  void initState() {
    super.initState();
    _evaluacion = _evaluar();
  }

  @override
  void didUpdateWidget(AvisoLeyGarantias anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.contrato['fecha_de_firma'] !=
            widget.contrato['fecha_de_firma'] ||
        anterior.contrato['proceso_de_compra'] !=
            widget.contrato['proceso_de_compra']) {
      _evaluacion = _evaluar();
    }
  }

  Future<EvaluacionGarantias?> _evaluar() async {
    final sinInicio = BanderasControl.evaluarLeyDeGarantias(widget.contrato);
    if (sinInicio == null) return null;
    final portafolio = '${widget.contrato['proceso_de_compra'] ?? ''}';
    try {
      final inicios = await CronogramaProcesoService.iniciosDeProcesos([
        portafolio,
      ]);
      return BanderasControl.evaluarLeyDeGarantias(
        widget.contrato,
        inicio: inicios[portafolio],
      );
    } catch (_) {
      return sinInicio;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EvaluacionGarantias?>(
      future: _evaluacion,
      builder: (context, snap) {
        final e = snap.data;
        if (snap.connectionState != ConnectionState.done || e == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 22),
          child: e.alerta ? _alerta(e) : _nota(e),
        );
      },
    );
  }

  Widget _alerta(EvaluacionGarantias e) => AvisoParaRevisar(
    titulo: 'Contratación directa en Ley de Garantías',
    detalle:
        'SECOP II registra la firma de este contrato el ${fechaDiaMesAnio(e.firma)}, dentro del periodo '
        'de Ley de Garantías de las elecciones ${e.periodo.eleccion} '
        '(${fechaDiaMesAnio(e.periodo.desde)} a ${fechaDiaMesAnio(e.periodo.hasta)}). '
        'La Ley 996 de 2005 (art. 33) suspende la contratación directa en ese periodo, salvo '
        'defensa y seguridad, crédito público, emergencias, reconstrucción por desastres o '
        'atentados y las entidades de salud. '
        '${e.inicio == null ? 'No pudimos consultar el cronograma del proceso para confirmar cuándo empezó. ' : ''}'
        'Es una señal automática a partir de datos abiertos, no una conclusión: verifica en '
        'SECOP II la fecha real de firma y la justificación del contrato.',
  );

  Widget _nota(EvaluacionGarantias e) {
    final inicio = e.inicio!;
    final publicacion = inicio.publicacion;
    final prevista = inicio.firmaPrevista;
    final partes = [
      if (publicacion != null) 'se publicó el ${fechaDiaMesAnio(publicacion)}',
      if (prevista != null) 'preveía firmarse el ${fechaDiaMesAnio(prevista)}',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Cristal.vidrioSuave,
        borderRadius: BorderRadius.circular(Cristal.radioAviso),
        border: Border.all(color: Cristal.borde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_note_outlined, size: 20, color: Cristal.textoMedio),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Fechas para verificar: SECOP II registra la firma electrónica el '
              '${fechaDiaMesAnio(e.firma)}, pero el proceso ${partes.join(' y ')}, antes de la '
              'Ley de Garantías de las elecciones ${e.periodo.eleccion} (desde el '
              '${fechaDiaMesAnio(e.periodo.desde)}). La diferencia puede deberse a la demora en '
              'completar la firma electrónica; por eso no se marca como alerta.',
              style: TextStyle(
                color: Cristal.textoCuerpo,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
