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

Compilar con las claves de producción (ninguna es secreta: van en el
navegador). La clave de sitio de App Check (Fraud Defense) ya viene por
defecto en `lib/main.dart`:

```
flutter build web --release \
  --dart-define=WOMPI_PUBLIC_KEY=<pub_prod_...>
```

Los secretos de Wompi (llave privada, eventos e integridad) **no** se
compilan en la app: van en el servidor que confirma los pagos.

En la consola de Firebase / Google Cloud:

1. **App Check**: registrar la app web (SecopApp) con Fraud Defense (reCAPTCHA Enterprise) y, cuando las
   métricas muestren solicitudes verificadas, exigirlo (Enforce) en
   Firestore y en Firebase AI Logic.
2. **Llave de API**: en Google Cloud > Credenciales, restringir la llave web
   a los dominios de la app.
3. **Reglas**: probar `firestore.rules` en el simulador de reglas de la
   consola (ingreso y subida desde el enlace del contratista sin sesión,
   aprobación del equipo) y luego `firebase deploy --only firestore:rules`.

## Roles y supervisión de contratos

| Rol | Precio | Sección |
|---|---|---|
| Persona | plan pago | Consulta (Inicio, Contratos, Entidades, Contratistas, Favoritos) |
| Equipo jurídico entidad | plan pago | Gestión contractual y revisión documental |
| Supervisión → Supervisor | plan pago | Registra su vinculación y dependencia, designa a Jurídico y configura el flujo de revisión |
| Supervisión → Jurídico | gratis | Revisa los informes en las etapas asignadas a su correo verificado |
| Supervisión → Contratista | gratis | Registra los datos del contrato, elige supervisor por NIT y dependencia y presenta sus informes |

Al completar su alta, el supervisor registra el acto de nombramiento o su propio contrato. La persona designada como Jurídico activa su cuenta con el mismo correo. Cada contrato recibe una copia de la plantilla al configurar sus informes. El supervisor puede ajustar las etapas, los responsables, las obligaciones y los documentos.

Los contratos nuevos se guardan en `contratos_supervision`. La bandeja del supervisor conserva sus asignaciones anteriores y el contratista puede abrir sus enlaces históricos. Publica las reglas de Firestore junto con la versión de la app.
