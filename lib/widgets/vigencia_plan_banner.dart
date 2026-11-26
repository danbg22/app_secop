import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../screens/pasarela_pago_wompi_screen.dart';
import '../services/acceso_planes.dart';
import '../services/payment_service.dart';
import '../tema/cristal.dart';

class VigenciaPlanBanner extends StatelessWidget {
  const VigenciaPlanBanner({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AccesoPlanes.cambios,
    builder: (context, _) {
      final estado = AccesoPlanes.estado;
      if (estado == null) return const SizedBox.shrink();
      final planPorRenovar = AccesoPlanes.pagosEnLineaDisponibles
          ? estado.planPorRenovar
          : null;
      final rol = planPorRenovar ?? (estado.enPrueba ? estado.rolPrueba : null);
      if (rol == null) {
        return const SizedBox.shrink();
      }
      final plan = PaymentService.obtenerConfiguracionRol(rol);
      final dias = estado.diasPrueba;
      final fin = planPorRenovar == null
          ? estado.fechaFinPrueba
          : estado.finPagoMensual(planPorRenovar)!;
      final finColombia = fin.subtract(const Duration(hours: 5));
      final resumen = planPorRenovar != null
          ? 'Tu periodo pagado vence pronto'
          : dias == 1
          ? 'Último día de prueba'
          : '$dias días de prueba restantes';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        decoration: BoxDecoration(
          color: Cristal.doradoVidrio,
          border: Border(bottom: BorderSide(color: Cristal.doradoBorde)),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${plan.nombrePlan} · $resumen',
                  style: TextStyle(
                    color: Cristal.texto,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Hasta el ${DateFormat('dd/MM/yyyy HH:mm').format(finColombia)} (hora de Colombia)',
                  style: TextStyle(color: Cristal.textoMedio, fontSize: 12),
                ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PasarelaPagoWompiScreen(
                    rolId: rol,
                    esFlujoRegistro: false,
                  ),
                ),
              ),
              child: Text(
                planPorRenovar == null
                    ? 'Suscribirme ahora'
                    : 'Ver suscripción',
              ),
            ),
          ],
        ),
      );
    },
  );
}
