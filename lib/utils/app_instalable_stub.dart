/// Fuera del navegador no hay instalación como app web ni versiones
/// publicadas que vigilar.
bool navegadorOfreceInstalar() => false;

Future<bool> pedirInstalacion() async => false;

bool abiertaComoApp() => false;

bool esIphoneOIpad() => false;

void alCambiarInstalable(void Function() aviso) {}

Future<String?> huellaVersionPublicada() async => null;

void recargarApp() {}
