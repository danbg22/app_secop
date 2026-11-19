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
navegador):

```
flutter build web --release \
  --dart-define=RECAPTCHA_SITE_KEY=<clave de sitio reCAPTCHA v3> \
  --dart-define=WOMPI_PUBLIC_KEY=<pub_prod_...>
```

Los secretos de Wompi (llave privada, eventos e integridad) **no** se
compilan en la app: van en el servidor que confirma los pagos.

En la consola de Firebase / Google Cloud:

1. **App Check**: registrar la app web con reCAPTCHA v3 y, cuando las
   métricas muestren solicitudes verificadas, exigirlo (Enforce) en
   Firestore y en Firebase AI Logic.
2. **Llave de API**: en Google Cloud > Credenciales, restringir la llave web
   a los dominios de la app.
3. **Reglas**: probar `firestore.rules` en el simulador de reglas de la
   consola (ingreso y subida desde el enlace del contratista sin sesión,
   aprobación del equipo) y luego `firebase deploy --only firestore:rules`.
