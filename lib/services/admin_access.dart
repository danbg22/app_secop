import 'payment_service.dart';

/// Cuentas administradoras de Contrata Legal: tienen todos los roles activos
/// sin pasar por la pasarela de pago.
///
/// Solo se listan correos (nunca contraseñas ni cédulas: todo lo que va en la
/// app es visible en el navegador). El acceso se concede únicamente cuando el
/// usuario inició sesión en Firebase con ese correo y lo tiene verificado, así
/// nadie puede obtenerlo registrando un correo ajeno sin confirmarlo.
class AdminAccess {
  static const Set<String> correosAdministradores = <String>{
    'danielbg2231@gmail.com',
    'ivanbolano19@gmail.com',
  };

  static bool esAdministrador(String? email) =>
      correosAdministradores.contains((email ?? '').trim().toLowerCase());

  /// Todos los roles del catálogo, en el orden oficial.
  static List<String> get todosLosRoles => List<String>.unmodifiable(
        AdminConfiguracionRolesYPagos.catalogoRoles.map((r) => r.id),
      );
}
