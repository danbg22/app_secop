# Procedimiento de supresión de datos personales

Contrata Legal atiende las solicitudes de eliminación de datos (derecho de supresión, Ley 1581 de 2012) por PQRS. La app no tiene un botón para que la persona borre su cuenta: lo hace soporte siguiendo estos pasos, para verificar la identidad y conservar la evidencia.

> Revisión jurídica pendiente: los plazos y qué registros se conservan deben confirmarse contra la política de tratamiento de datos vigente.

## 1. Recepción

1. La persona envía un PQRS de tipo **"Supresión de datos personales"** desde Ayuda en la app. Queda un radicado en `pqrs_solicitudes`.
2. Soporte lo ve en la bandeja de administración de PQRS.

## 2. Verificación de identidad

1. Responder **al correo de la cuenta** (no a otro correo de contacto) pidiendo confirmar la solicitud.
2. No eliminar nada hasta que esa confirmación llegue desde el correo de la cuenta.
3. Si la persona tiene una suscripción activa, cancelar primero la renovación automática (pantalla Suscripción, o `suscripciones_planes` con estado `cancelada`), para que no haya cobros nuevos.

## 3. Eliminación (consola de Firebase, proyecto `secop-ia`)

Con el `uid` de la persona (Authentication → buscar por correo):

| Dónde | Qué hacer |
|---|---|
| Firestore `usuarios/{uid}` y sus subcolecciones | Eliminar. Conservar solo la subcolección `pqrs_solicitudes` si se necesita como evidencia del trámite. |
| `accesos_planes/{uid}`, `accesos_anteriores/{uid}`, `relojes_acceso/{uid}`, `limites_cedula/{uid}` | Eliminar. |
| `indices_unicidad` (documentos con `uid` igual al de la persona) | Eliminar, para liberar la cédula y el correo. |
| `perfiles_supervision/{uid}`, `juridicos_supervision/{uid}`, `plantillas_informe/{uid}` | Eliminar si existen. |
| `codigos_supervision` y `directorio_supervision/*/supervisores/{uid}` | Eliminar las entradas del supervisor. |
| `miembros_equipo/{correo}` y los que tengan `masterUid` igual al `uid` | Eliminar. |
| `contratos_supervision` donde la persona es el contratista | Consultar con la entidad antes de borrar: son registros contractuales que también le pertenecen a ella. |
| `expedientes_juridicos` creados por la persona | Son del equipo jurídico de la entidad: no se borran por esta solicitud, salvo que la persona sea la titular del equipo. |
| `pagos_wompi`, `suscripciones_planes` | **Conservar**: son soportes contables. Ya no se pueden asociar a una cuenta activa. |
| `identidades_prueba` | Conservar: son huellas cifradas (no la cédula) que evitan repetir la prueba gratis. |
| Authentication | Eliminar el usuario al final. |

## 4. Cierre

1. Responder el PQRS en la app (estado **Respondido**) y por correo, indicando la fecha de eliminación y qué registros se conservan por obligación legal.
2. Registrar el trámite en el radicado. No anotar en la respuesta la cédula ni otros datos personales.
