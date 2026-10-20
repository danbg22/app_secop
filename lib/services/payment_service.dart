class PaymentService {
  
  // Diccionario con los precios oficiales de la plataforma
  final Map<String, double> preciosPlanes = {
    'Básico': 0.0,
    'Pro': 19900.0,
    'Empresarial': 49900.0,
  };

  // Simula la conexión con un banco o pasarela como Wompi/MercadoPago
  Future<bool> procesarSuscripcion(String uidUsuario, String planElegido, String numeroTarjeta) async {
    double montoACobrar = preciosPlanes[planElegido] ?? 0.0;

    if (montoACobrar == 0.0) {
      print('Asignando plan Básico gratuito al usuario $uidUsuario...');
      return true; // No requiere cobro
    }

    print('Conectando con la pasarela bancaria...');
    print('Intentando cobrar \$$montoACobrar a la tarjeta terminada en ${numeroTarjeta.substring(numeroTarjeta.length - 4)}');
    
    // Simulamos el tiempo de respuesta del banco (2 segundos)
    await Future.delayed(const Duration(seconds: 2));

    // Aquí iría la lógica real (try-catch) para manejar fondos insuficientes o tarjetas bloqueadas
    print('¡Transacción aprobada! El usuario ahora es $planElegido.');
    
    // Retornamos true para indicarle a la pantalla que el pago pasó
    return true; 
  }
}