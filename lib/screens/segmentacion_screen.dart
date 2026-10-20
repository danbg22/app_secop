import 'package:flutter/material.dart';
import 'resultados_screen.dart';

class SegmentacionScreen extends StatefulWidget {
  const SegmentacionScreen({super.key});

  @override
  State<SegmentacionScreen> createState() => _SegmentacionScreenState();
}

class _SegmentacionScreenState extends State<SegmentacionScreen> {
  String nivelSeleccionado = 'Municipal';
  
  // Lista FINITA de los 32 Departamentos + Bogotá D.C.
  final List<String> departamentos = [
    'Amazonas', 'Antioquia', 'Arauca', 'Archipiélago de San Andrés, Providencia y Santa Catalina', 
    'Atlántico', 'Bogotá D.C.', 'Bolívar', 'Boyacá', 'Caldas', 'Caquetá', 'Casanare', 'Cauca', 
    'Cesar', 'Chocó', 'Córdoba', 'Cundinamarca', 'Guainía', 'Guaviare', 'Huila', 'La Guajira', 
    'Magdalena', 'Meta', 'Nariño', 'Norte de Santander', 'Putumayo', 'Quindío', 'Risaralda', 
    'Santander', 'Sucre', 'Tolima', 'Valle del Cauca', 'Vaupés', 'Vichada'
  ];

  // Mapeo extendido de municipios principales por departamento
  final Map<String, List<String>> municipiosPorDepto = {
    'Amazonas': ['Leticia', 'Puerto Nariño'],
    'Antioquia': ['Medellín', 'Bello', 'Itagüí', 'Envigado', 'Rionegro', 'Apartadó', 'Turbo', 'Caucasia'],
    'Arauca': ['Arauca', 'Arauquita', 'Saravena', 'Tame'],
    'Archipiélago de San Andrés, Providencia y Santa Catalina': ['San Andrés', 'Providencia'],
    'Atlántico': ['Barranquilla', 'Soledad', 'Malambo', 'Sabanalarga', 'Puerto Colombia', 'Baranoa'],
    'Bogotá D.C.': ['Bogotá D.C.'],
    'Bolívar': ['Cartagena', 'Magangué', 'Turbaco', 'Carmen de Bolívar', 'Arjona'],
    'Boyacá': ['Tunja', 'Duitama', 'Sogamoso', 'Chiquinquirá', 'Puerto Boyacá'],
    'Caldas': ['Manizales', 'La Dorada', 'Chinchiná', 'Villamaría', 'Riosucio'],
    'Caquetá': ['Florencia', 'San Vicente del Caguán', 'Cartagena del Chairá'],
    'Casanare': ['Yopal', 'Aguazul', 'Paz de Ariporo', 'Villanueva'],
    'Cauca': ['Popayán', 'Santander de Quilichao', 'El Tambo', 'Puerto Tejada'],
    'Cesar': ['Valledupar', 'Aguachica', 'Agustín Codazzi', 'Bosconia', 'La Paz', 'Pueblo Bello', 'Curumaní', 'El Paso'],
    'Chocó': ['Quibdó', 'Istmina', 'Tadó', 'Condoto'],
    'Córdoba': ['Montería', 'Lorica', 'Sahagún', 'Cereté', 'Montelíbano'],
    'Cundinamarca': ['Soacha', 'Chía', 'Zipaquirá', 'Facatativá', 'Fusagasugá', 'Girardot', 'Mosquera', 'Funza'],
    'Guainía': ['Inírida'],
    'Guaviare': ['San José del Guaviare', 'Calamar', 'El Retorno'],
    'Huila': ['Neiva', 'Pitalito', 'Garzón', 'La Plata'],
    'La Guajira': ['Riohacha', 'Maicao', 'Uribia', 'San Juan del Cesar', 'Fonseca'],
    'Magdalena': ['Santa Marta', 'Ciénaga', 'Zona Bananera', 'Fundación', 'El Banco'],
    'Meta': ['Villavicencio', 'Acacías', 'Granada', 'Puerto López', 'Puerto Gaitán'],
    'Nariño': ['Pasto', 'Tumaco', 'Ipiales', 'Túquerres'],
    'Norte de Santander': ['Cúcuta', 'Ocaña', 'Villa del Rosario', 'Los Patios', 'Pamplona'],
    'Putumayo': ['Mocoa', 'Puerto Asís', 'Orito', 'Valle del Guamuez'],
    'Quindío': ['Armenia', 'Calarcá', 'La Tebaida', 'Circasia', 'Montenegro'],
    'Risaralda': ['Pereira', 'Dosquebradas', 'Santa Rosa de Cabal', 'La Virginia'],
    'Santander': ['Bucaramanga', 'Floridablanca', 'Girón', 'Piedecuesta', 'Barrancabermeja', 'San Gil', 'Socorro'],
    'Sucre': ['Sincelejo', 'Corozal', 'San Marcos', 'Tolú'],
    'Tolima': ['Ibagué', 'Espinal', 'Melgar', 'Chaparral', 'Líbano'],
    'Valle del Cauca': ['Cali', 'Buenaventura', 'Palmira', 'Tuluá', 'Yumbo', 'Cartago', 'Buga', 'Jamundí'],
    'Vaupés': ['Mitú'],
    'Vichada': ['Puerto Carreño', 'La Primavera']
  };

  // Base de datos de sugerencias para el Buscador Predictivo de Entidades
  final List<String> entidadesSugeridas = [
    'SENA', 'Ministerio de Educación', 'Ministerio de Salud', 'Ministerio de TIC',
    'INVIAS', 'ICBF', 'Agencia Nacional de Infraestructura', 'Agencia Nacional de Tierras',
    'Policía Nacional', 'Ejército Nacional', 'Defensoría del Pueblo', 'Contraloría General',
    'Gobernación', 'Alcaldía', 'Hospital', 'Secretaría de Salud', 'Secretaría de Educación',
    'Instituto de Deportes', 'Empresa de Servicios Públicos'
  ];

  String? departamentoSeleccionado;
  String? municipioSeleccionado;
  
  // Controlador mágico que leerá lo que el usuario escriba libremente en la entidad
  TextEditingController _entidadTextoController = TextEditingController();

  Widget _construirChipNivel(String titulo, IconData icono) {
    bool isSelected = nivelSeleccionado == titulo;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: isSelected ? Colors.white : Colors.blueGrey),
          const SizedBox(width: 8),
          Text(titulo),
        ],
      ),
      selected: isSelected,
      selectedColor: Colors.blue.shade700,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
      backgroundColor: Colors.grey.shade100,
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            nivelSeleccionado = titulo;
            // Al cambiar de nivel, reseteamos los menús desplegables
            departamentoSeleccionado = null;
            municipioSeleccionado = null;
            _entidadTextoController.clear();
          });
        }
      },
    );
  }

  void _ejecutarBusqueda() {
    if (nivelSeleccionado == 'Municipal' && (municipioSeleccionado == null || municipioSeleccionado!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor selecciona un municipio de la lista')));
      return;
    }
    if (nivelSeleccionado == 'Departamental' && (departamentoSeleccionado == null || departamentoSeleccionado!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor selecciona un departamento de la lista')));
      return;
    }
    if (nivelSeleccionado == 'Nacional' && _entidadTextoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escribe el nombre de la entidad nacional (Ej. SENA)')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultadosScreen(
          nivel: nivelSeleccionado,
          departamento: departamentoSeleccionado,
          municipio: municipioSeleccionado,
          // Enviamos lo que sea que haya quedado escrito en la caja de entidad
          dependencia: _entidadTextoController.text.isEmpty ? 'Todas las dependencias' : _entidadTextoController.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Filtro de Entidades', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800), // Diseño centrado para PC
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('1. Nivel de la Entidad', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _construirChipNivel('Nacional', Icons.account_balance),
                    _construirChipNivel('Departamental', Icons.map),
                    _construirChipNivel('Municipal', Icons.location_city),
                  ],
                ),
                const SizedBox(height: 32),

                // MENÚ DESPLEGABLE: DEPARTAMENTO (Lista estricta)
                if (nivelSeleccionado != 'Nacional') ...[
                  const Text('2. Selecciona el Departamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      prefixIcon: const Icon(Icons.map_outlined),
                    ),
                    hint: const Text('Ej. Cesar'),
                    initialValue: departamentoSeleccionado,
                    items: departamentos.map((String depto) {
                      return DropdownMenuItem(value: depto, child: Text(depto));
                    }).toList(),
                    onChanged: (String? nuevoValor) {
                      setState(() {
                        departamentoSeleccionado = nuevoValor;
                        municipioSeleccionado = null; // Reinicia el municipio al cambiar depto
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // MENÚ DESPLEGABLE: MUNICIPIO (Lista estricta)
                if (nivelSeleccionado == 'Municipal') ...[
                  const Text('3. Selecciona el Municipio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                    hint: const Text('Ej. Valledupar'),
                    initialValue: municipioSeleccionado,
                    items: departamentoSeleccionado == null 
                      ? [] 
                      : (municipiosPorDepto[departamentoSeleccionado!] ?? []).map((String muni) {
                          return DropdownMenuItem(value: muni, child: Text(muni));
                        }).toList(),
                    onChanged: (String? nuevoValor) {
                      setState(() {
                        municipioSeleccionado = nuevoValor;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // BUSCADOR PREDICTIVO TIPO GOOGLE: ENTIDAD (Texto Libre con Sugerencias)
                const Text('Entidad / Dependencia (Opcional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 12),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                    // Busca coincidencias ignorando mayúsculas y minúsculas
                    return entidadesSugeridas.where((String entidad) => 
                      entidad.toLowerCase().contains(textEditingValue.text.toLowerCase())
                    );
                  },
                  onSelected: (String seleccion) {
                    _entidadTextoController.text = seleccion;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    // Enlazamos el controlador para poder leer texto libre aunque no seleccione una opción
                    _entidadTextoController = controller;
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: nivelSeleccionado == 'Nacional' ? 'Empieza a escribir... Ej. SENA' : 'Empieza a escribir... Ej. Secretaría',
                        prefixIcon: const Icon(Icons.business),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 40),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _ejecutarBusqueda,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Buscar Contratos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}