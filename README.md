# app_secop

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Lanzamiento a producción

La app web se compila con `flutter build web --release`. App Check usa la clave
de sitio de Fraud Defense configurada en `lib/main.dart`.

### Pruebas y suscripciones

Firebase Functions decide el acceso a cada plan y firma el Checkout de Wompi.
En el proyecto de Firebase, configura estos parámetros de Functions:

- `PLANES_INICIO_PRUEBA`: instante UTC del lanzamiento en formato ISO 8601.
  Las cuentas nuevas desde ese instante reciben 30 días a partir de la fecha
  de creación de Firebase Auth. Las cuentas anteriores conservan el acceso
  respaldado por pagos históricos que el servidor puede confirmar en Wompi.
- `WOMPI_PUBLIC_KEY`: llave pública del comercio y del ambiente elegido.
- `PLANES_RETORNO`: URL de la app después del pago. Por defecto usa
  `https://contratalegal.co/`.

Guarda `WOMPI_PRIVATE_KEY`, `WOMPI_INTEGRITY_SECRET` y `WOMPI_EVENTS_SECRET` en
Secret Manager con `firebase functions:secrets:set NOMBRE`. Las llaves deben ser del mismo ambiente
que la llave pública. Configura en el panel de Wompi la URL del webhook
`https://us-central1-secop-ia.cloudfunctions.net/eventosWompi` para
`transaction.updated`. Los importes del servidor están en
`functions/planes.mjs` y los visibles en `lib/services/payment_service.dart`.

Prueba en un proyecto de staging y con Wompi Sandbox antes de publicar
coordinadamente las funciones, las reglas y la aplicación web. Revisa que
el libro de pagos históricos de producción tenga referencias verificables
para las cuentas que ya pagaron. Para apuntar una compilación web a las
funciones de staging, define `ACCESO_PLAN_URL` con su URL HTTPS y registra ese
origen en `connect-src` de `web/index.html`. La primera confirmación de Wompi inicia
un mes de suscripción en hora de Colombia. La renovación se paga desde la app.

En la consola de Firebase / Google Cloud:

1. **App Check**: registrar la app web (SecopApp) con Fraud Defense (reCAPTCHA Enterprise) y, cuando las
   métricas muestren solicitudes verificadas, exigirlo (Enforce) en
   Firestore y en Firebase AI Logic.
2. **Llave de API**: en Google Cloud > Credenciales, restringir la llave web
   a los dominios de la app.
3. **Reglas**: probar `firestore.rules` en el simulador de reglas de la
   consola (ingreso y subida desde el enlace del contratista sin sesión,
   aprobación del equipo) y luego `firebase deploy --only firestore:rules,firestore:indexes`.
   El índice de `pqrs_solicitudes` permite consultar en el buzón los radicados globales y los históricos del perfil.

## Roles y supervisión de contratos

| Rol | Precio | Sección |
|---|---|---|
| Persona | plan pago con prueba | Consulta (Inicio, Contratos, Entidades, Contratistas, Procesos, Favoritos) |
| Equipo jurídico entidad | plan pago con prueba | Gestión contractual y revisión documental |
| Supervisión → Supervisor | plan pago con prueba | Registra su vinculación y dependencia, designa a Jurídico y configura el flujo de revisión |
| Supervisión → Jurídico | gratis | Revisa los informes en las etapas asignadas a su correo verificado |
| Supervisión → Contratista | gratis | Registra los datos del contrato, elige supervisor por NIT y dependencia y presenta sus informes |

Al completar su alta, el supervisor registra el acto de nombramiento o su propio contrato. La persona designada como Jurídico activa su cuenta con el mismo correo. Cada contrato recibe una copia de la plantilla al configurar sus informes. El supervisor puede ajustar las etapas, los responsables, las obligaciones y los documentos.

Los contratos nuevos se guardan en `contratos_supervision`. La bandeja del supervisor conserva sus asignaciones anteriores y el contratista puede abrir sus enlaces históricos. Publica las reglas de Firestore junto con la versión de la app.
