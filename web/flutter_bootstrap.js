{{flutter_js}}
{{flutter_build_config}}

// Sin el service worker de Flutter (obsoleto): la app se carga siempre desde
// la web publicada, así cada publicación le llega a todos los usuarios.
_flutter.loader.load();
