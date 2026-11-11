# Capturas de revisión visual

Pruebas de Flutter que dibujan pantallas reales con el tema de vidrio y
guardan una imagen PNG en `tool/vista/capturas/` (no se suben a git). Sirven
para revisar el diseño sin abrir un navegador.

```
flutter test tool/vista/pantallas_test.dart --update-goldens   # portada, ingreso, registro, inicio
flutter test tool/vista/secciones_test.dart --update-goldens   # secciones del panel (usa Datos Abiertos)
flutter test tool/vista/detalle_test.dart --update-goldens     # entidad, contrato, contratista, perfil, pago
flutter test tool/vista/gestion_test.dart --update-goldens     # gestión contractual, supervisión, diálogos
flutter test tool/vista/catalogo_test.dart --update-goldens    # catálogo de componentes
```

No usan Firebase real: `firebase_falso.dart` simula la sesión. Las que
consultan SECOP II necesitan internet.
