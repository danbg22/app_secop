/// NIT colombiano: dígito de verificación (algoritmo de la DIAN) y las
/// formas en que SECOP lo guarda.
class Nit {
  Nit._();

  static const List<int> _pesos = [
    3, 7, 13, 17, 19, 23, 29, 37, 41, 43, 47, 53, 59, 67, 71, //
  ];

  /// Dígito de verificación de [nit] (solo los dígitos del NIT, sin DV).
  static int digitoVerificacion(String nit) {
    final digitos = nit.replaceAll(RegExp(r'[^0-9]'), '');
    var suma = 0;
    for (var i = 0; i < digitos.length && i < _pesos.length; i++) {
      suma += int.parse(digitos[digitos.length - 1 - i]) * _pesos[i];
    }
    final residuo = suma % 11;
    return residuo > 1 ? 11 - residuo : residuo;
  }

  /// Formas de un NIT de 9 dígitos en los datos abiertos: sin DV
  /// (`892300285`), con DV pegado (`8923002856`, SECOP II) y con guion
  /// (`892300285-6`, SECOP I).
  static List<String> formas(String nit) {
    final digitos = nit.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitos.length != 9) return [if (digitos.isNotEmpty) digitos];
    final dv = digitoVerificacion(digitos);
    return [digitos, '$digitos$dv', '$digitos-$dv'];
  }

  /// Formas solo con dígitos de un NIT, para columnas numéricas o para
  /// comparar exacto (`nit_entidad` de SECOP II es un número): sin y con
  /// dígito de verificación. Acepta el NIT con o sin DV; otros documentos
  /// (cédulas) van tal cual.
  static List<String> formasNumericas(String nit) {
    final digitos = nit.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitos.length == 10) {
      final base = digitos.substring(0, 9);
      if ('${digitoVerificacion(base)}' == digitos.substring(9)) {
        return [base, digitos];
      }
    }
    return formas(digitos).where((f) => !f.contains('-')).toList();
  }
}
