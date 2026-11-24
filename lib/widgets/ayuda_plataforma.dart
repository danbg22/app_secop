import 'package:flutter/material.dart';

import '../tema/cristal.dart';
import 'pqrs_help_dialog.dart';

abstract final class AyudaPlataforma {
  static Future<void> mostrar(BuildContext context) async {
    final destino = await mostrarDialogoCristal<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Ayuda'),
        children: [
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Cartilla de uso'),
            subtitle: const Text('Mini tutoriales para usar Contrata Legal'),
            onTap: () => Navigator.pop(ctx, 'cartilla'),
          ),
          ListTile(
            leading: const Icon(Icons.support_agent_rounded),
            title: const Text('Enviar un mensaje a soporte'),
            subtitle: const Text('Consultas, peticiones, quejas y sugerencias'),
            onTap: () => Navigator.pop(ctx, 'soporte'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (destino == 'soporte') {
      PqrsHelpDialog.show(context);
    } else if (destino == 'cartilla') {
      await mostrarDialogoCristal<void>(
        context: context,
        builder: (_) => const _CartillaUso(),
      );
    }
  }
}

class _CartillaUso extends StatelessWidget {
  const _CartillaUso();

  static const capitulos = [
    (
      'Buscar y revisar contratos',
      Icons.description_outlined,
      [
        'Abre Contratos. Busca el número de referencia, la entidad o palabras del objeto contractual. Pulsa Buscar.',
        'Usa los filtros para acotar por año, ubicación, modalidad, estado o valor. Cambia el orden si quieres ver primero los más recientes o los de mayor valor.',
        'Abre un resultado. Compara objeto, contratista, fechas y valor. Sigue el enlace a SECOP para revisar el expediente original y sus documentos.',
      ],
    ),
    (
      'Explorar procesos y oportunidades',
      Icons.pending_actions_outlined,
      [
        'Abre Procesos. Revisa la vista general o busca por entidad, número de proceso o palabras del objeto.',
        'Filtra por estado. En un proceso abierto revisa el cronograma y confirma en SECOP la fecha límite y las condiciones de participación.',
        'Usa Compartir en el detalle. Al abrir el enlace sin sesión se muestra una vista previa. Al iniciar sesión se abre el proceso compartido.',
      ],
    ),
    (
      'Consultar una entidad o un contratista',
      Icons.groups_2_outlined,
      [
        'En Entidades, busca por nombre o NIT. Abre el perfil y revisa los resultados de Contratos o Procesos.',
        'En Contratistas, busca por nombre, NIT o cédula. Abre Ver perfil para consultar el historial en SECOP y filtrar por año.',
        'Si necesitas comprobar quién suscribió un contrato o en qué calidad, abre el expediente original desde el detalle.',
      ],
    ),
    (
      'Armar y descargar un reporte',
      Icons.picture_as_pdf_outlined,
      [
        'Pulsa Seleccionar contratos en Contratos o Seleccionar contratistas en Contratistas. Marca los resultados que quieras incluir.',
        'Marca los contratos que quieras incluir. Puedes hacer otra búsqueda y seguir agregando. Pulsa el contador para revisar o retirar elementos.',
        'Pulsa Descargar reporte PDF. Se descargará un resumen de los contratos elegidos y quedará lista una nueva búsqueda.',
      ],
    ),
    (
      'Seguir novedades y consultar soporte',
      Icons.notifications_none_rounded,
      [
        'Pulsa Seguir en los perfiles que quieras vigilar. La campana de Alertas reúne las novedades de seguimiento.',
        'Desde Ayuda, elige Enviar un mensaje a soporte. Completa el asunto y el mensaje y guarda el número de radicado.',
        'Abre el ícono de mensajes de soporte para consultar tus solicitudes y leer las respuestas.',
      ],
    ),
    (
      'Gestionar tu cuenta y suscripción',
      Icons.manage_accounts_outlined,
      [
        'Si la plataforma solicita tu cédula, escribe el número de tu cuenta. Si ya está vinculada a otra cuenta, recupera el acceso a esa cuenta o contacta a soporte.',
        'En Planes, abre la opción Suscripción del plan que quieras revisar. Allí puedes confirmar un pago y consultar la renovación, si está disponible.',
        'Si autorizaste un cobro automático, revisa la fecha del próximo pago. Cancela la renovación al menos 24 horas antes para evitar ese cobro.',
      ],
    ),
    (
      'Usar el flujo de supervisión',
      Icons.fact_check_outlined,
      [
        'El supervisor configura su perfil, designa a Jurídico y comparte su código único con el contratista.',
        'El contratista confirma el código, registra los datos del contrato y envía la solicitud. El supervisor revisa y aprueba la vinculación.',
        'Con el plan configurado, el contratista presenta el informe. Jurídico revisa primero y el supervisor toma la decisión final.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cartilla de uso'),
    content: SizedBox(
      width: 600,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (titulo, icono, pasos) in capitulos)
              ExpansionTile(
                leading: Icon(icono, color: Cristal.acentoClaro),
                title: Text(titulo),
                children: [
                  for (final (indice, paso) in pasos.indexed)
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: Cristal.doradoVidrio,
                        child: Text(
                          '${indice + 1}',
                          style: TextStyle(color: Cristal.texto),
                        ),
                      ),
                      title: Text(paso),
                    ),
                ],
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
    ],
  );
}
