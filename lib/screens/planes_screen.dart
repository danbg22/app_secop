import 'package:flutter/material.dart';
import '../services/payment_service.dart';

class PlanesScreen extends StatefulWidget {
  const PlanesScreen({Key? key}) : super(key: key);

  @override
  _PlanesScreenState createState() => _PlanesScreenState();
}

class _PlanesScreenState extends State<PlanesScreen> {
  final _paymentService = PaymentService();
  bool _procesando = false;
  bool _pagoAnual = false; // Controla el switch Mensual/Anual

  void _comprarPlan(String plan) async {
    setState(() => _procesando = true);
    
    // Simulamos el pago (sin input de tarjeta por ahora para simplificar la UI)
    bool pagoExitoso = await _paymentService.procesarSuscripcion('user_123', plan, '0000');
    
    setState(() => _procesando = false);

    if (pagoExitoso) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('¡Bienvenido al plan $plan!'), backgroundColor: Colors.green),
      );
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange[50], // Fondo cálido
      body: Row(
        children: [
          // BARRA LATERAL (Pasos)
          Container(
            width: 250,
            color: Colors.orange[50],
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.business_center, color: Colors.blue, size: 30),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Inteligencia SECOP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blue)),
                    )
                  ],
                ),
                const SizedBox(height: 60),
                _construirPaso(1, 'Selecciona tu plan', activo: true),
                _construirLineaConexion(),
                _construirPaso(2, 'Crea tu cuenta'),
                _construirLineaConexion(),
                _construirPaso(3, 'Completa tu perfil'),
                _construirLineaConexion(),
                _construirPaso(4, '¡Listo!'),
              ],
            ),
          ),
          
          // CONTENIDO PRINCIPAL
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(30), bottomLeft: Radius.circular(30)),
              ),
              padding: const EdgeInsets.all(50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Elige el plan que se ajusta a ti', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Text('Tu acceso a una Colombia más transparente, empieza aquí.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                      // Switch Mensual / Anual
                      Row(
                        children: [
                          const Text('Mensual', style: TextStyle(fontWeight: FontWeight.bold)),
                          Switch(
                            value: _pagoAnual,
                            onChanged: (val) => setState(() => _pagoAnual = val),
                            activeColor: Colors.yellow[700],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.yellow[700], borderRadius: BorderRadius.circular(12)),
                            child: const Text('Anual', style: TextStyle(fontWeight: FontWeight.bold)),
                          )
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 40),
                  
                  if (_procesando) 
                    const Center(child: CircularProgressIndicator())
                  else
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _TarjetaPlan(
                            titulo: 'Básico',
                            descripcion: 'Ideal para ciudadanos que quieren consultar información.',
                            precio: '0',
                            beneficios: const ['Búsqueda de contratos', 'Información básica de entidades', 'Acceso a datos públicos', 'Sin registros ni alertas'],
                            onTap: () => _comprarPlan('Básico'),
                            destacado: false,
                          ),
                          _TarjetaPlan(
                            titulo: 'Pro',
                            descripcion: 'Para veedores, estudiantes y empresas que quieren ir más lejos.',
                            precio: '19.900',
                            beneficios: const ['Todo lo del plan Básico', 'Alertas personalizadas', 'Perfiles de contratistas', 'Análisis comparativos', 'Descargas en Excel / PDF'],
                            onTap: () => _comprarPlan('Pro'),
                            destacado: true,
                          ),
                          _TarjetaPlan(
                            titulo: 'Empresarial',
                            descripcion: 'Para empresas que licitan y gestionan contratación pública.',
                            precio: '49.900',
                            beneficios: const ['Todo lo del plan Pro', 'Gestión de procesos de contratación', 'Seguimiento en tiempo real', 'Soporte prioritario', 'Integración con SECOP'],
                            onTap: () => _comprarPlan('Empresarial'),
                            destacado: false,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // WIDGETS AUXILIARES PARA EL MENÚ LATERAL
  Widget _construirPaso(int numero, String texto, {bool activo = false}) {
    return Row(
      children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: activo ? Colors.yellow[700] : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(numero.toString(), style: TextStyle(fontWeight: FontWeight.bold, color: activo ? Colors.black : Colors.grey[600]))),
        ),
        const SizedBox(width: 15),
        Text(texto, style: TextStyle(fontWeight: activo ? FontWeight.bold : FontWeight.normal, color: activo ? Colors.black : Colors.grey)),
      ],
    );
  }

  Widget _construirLineaConexion() {
    return Padding(
      padding: const EdgeInsets.only(left: 14.0, top: 5, bottom: 5),
      child: Container(width: 2, height: 30, color: Colors.grey[300]),
    );
  }
}

// WIDGET PARA LAS TARJETAS DE PLANES
class _TarjetaPlan extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final String precio;
  final List<String> beneficios;
  final VoidCallback onTap;
  final bool destacado;

  const _TarjetaPlan({
    required this.titulo,
    required this.descripcion,
    required this.precio,
    required this.beneficios,
    required this.onTap,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: destacado ? Colors.yellow[700]! : Colors.grey[200]!, width: destacado ? 2 : 1),
        boxShadow: destacado ? [const BoxShadow(color: Colors.black12, blurRadius: 10)] : [],
      ),
      child: Column(
        children: [
          if (destacado)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.yellow[700],
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
              ),
              child: const Text('Más popular', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(destacado ? Icons.person : Icons.business, color: Colors.blue[900]),
                    const SizedBox(width: 10),
                    Text(titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(descripcion, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('\$$precio', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    const Text(' /mes', style: TextStyle(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 24),
                // Lista de beneficios
                ...beneficios.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(b, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                )).toList(),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: destacado ? Colors.yellow[700] : Colors.white,
                      foregroundColor: destacado ? Colors.black : Colors.blue[900],
                      side: destacado ? BorderSide.none : BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                    ),
                    onPressed: onTap,
                    child: const Text('Seleccionar'),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}