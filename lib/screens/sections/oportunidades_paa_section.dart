import 'package:flutter/material.dart';

import '../../data/estructura_paa.dart';
import '../../services/paa_service.dart';
import '../gestion_contractual/estilo_contractual.dart';
import '../licitaciones/entidad_paa_screen.dart';
import '../licitaciones/prediccion_paa_screen.dart';

/// Empresa licitante: proyección de lo que cada entidad va a contratar, a
/// partir de su Plan Anual de Adquisiciones. Se busca la entidad cabeza
/// (SENA, Ministerio del Trabajo) y desde ahí sus regionales.
class OportunidadesPaaSection extends StatefulWidget {
  const OportunidadesPaaSection({super.key});

  @override
  State<OportunidadesPaaSection> createState() =>
      _OportunidadesPaaSectionState();
}

class _Encontrada {
  const _Encontrada({
    required this.nit,
    required this.nombre,
    required this.cuentas,
    this.familia,
  });

  final String nit;
  final String nombre;
  final FamiliaPaa? familia;
  final List<PlanPaa> cuentas;
}

class _OportunidadesPaaSectionState extends State<OportunidadesPaaSection> {
  final _busqueda = TextEditingController();
  late int _anio = DateTime.now().year;
  List<_Encontrada>? _resultados;
  bool _buscando = false;
  String? _error;

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final t = _busqueda.text.trim();
    if (t.length < 3) {
      setState(
        () => _error = 'Escribe al menos 3 letras del nombre de la entidad.',
      );
      return;
    }
    setState(() {
      _buscando = true;
      _error = null;
      _resultados = null;
    });
    try {
      final porNit = await PaaService.buscarEntidades(t, _anio);
      if (!mounted) return;
      // Las seccionales con NIT propio (MinTrabajo) se reúnen en su familia.
      final familias = <FamiliaPaa, List<PlanPaa>>{};
      final porEntidad = <String, List<PlanPaa>>{};
      for (final e in porNit.entries) {
        for (final p in e.value) {
          final f = EstructuraPaa.familiaDe(p.nombreEntidad);
          if (f != null) {
            familias.putIfAbsent(f, () => []).add(p);
          } else {
            porEntidad.putIfAbsent(e.key, () => []).add(p);
          }
        }
      }
      setState(
        () => _resultados = [
          for (final e in familias.entries)
            _Encontrada(
              nit: '',
              nombre: e.key.nombre,
              cuentas: e.value,
              familia: e.key,
            ),
          for (final e in porEntidad.entries)
            _Encontrada(
              nit: e.key,
              nombre: EstructuraPaa.nombreEntidad(e.key, [
                for (final p in e.value) CuentaPaa(plan: p),
              ]),
              cuentas: e.value,
            ),
        ],
      );
    } on PaaException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _abrir(_Encontrada e) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => EntidadPaaScreen(
          nit: e.nit,
          familia: e.familia,
          nombre: e.nombre,
          anio: _anio,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
    final anios = [
      DateTime.now().year + 1,
      DateTime.now().year,
      DateTime.now().year - 1,
    ];
    final campo = TextField(
      controller: _busqueda,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _buscar(),
      decoration: InputDecoration(
        hintText: 'Entidad (ej. SENA, Ministerio del Trabajo, Valledupar)',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: EstiloContractual.borde),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: EstiloContractual.borde),
        ),
      ),
    );
    final boton = FilledButton.icon(
      onPressed: _buscando ? null : _buscar,
      style: EstiloContractual.botonPrincipal(),
      icon: const Icon(Icons.search_rounded, size: 19),
      label: const Text('Buscar', style: EstiloContractual.etiquetaBoton),
    );
    final resultados = _resultados;

    return Container(
      color: EstiloContractual.crema,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: mobile ? 16 : 36,
          vertical: mobile ? 16 : 28,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Proyección de contratación',
                  style: EstiloContractual.titulo,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Qué proyecta contratar cada entidad, en qué mes y por cuánto, según su '
                  'Plan Anual de Adquisiciones, verificado contra los procesos y contratos reales de SECOP II.',
                  style: EstiloContractual.subtitulo,
                ),
                const SizedBox(height: 16),
                const AvisoPrediccionPaa(),
                const SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(mobile ? 16 : 22),
                  decoration: EstiloContractual.tarjeta(),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '¿Qué entidad te interesa?',
                          style: EstiloContractual.tituloGrupo,
                        ),
                        const SizedBox(height: 12),
                        if (mobile) ...[
                          campo,
                          const SizedBox(height: 10),
                          boton,
                        ] else
                          Row(
                            children: [
                              Expanded(child: campo),
                              const SizedBox(width: 12),
                              boton,
                            ],
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Año:',
                              style: TextStyle(
                                color: EstiloContractual.texto,
                                fontSize: 13,
                              ),
                            ),
                            for (final a in anios)
                              ChoiceChip(
                                label: Text('$a'),
                                selected: _anio == a,
                                selectedColor: const Color(0xFFDCE6F5),
                                checkmarkColor: EstiloContractual.navy,
                                onSelected: (_) {
                                  setState(() => _anio = a);
                                  if (_busqueda.text.trim().length >= 3) {
                                    _buscar();
                                  }
                                },
                              ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 13,
                            ),
                          ),
                        ],
                        if (_buscando)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        if (resultados != null) ...[
                          const SizedBox(height: 16),
                          if (resultados.isEmpty)
                            Text(
                              _anio > DateTime.now().year
                                  ? 'Aún no hay planes $_anio con ese nombre. Las entidades publican el PAA del año a más tardar el 31 de enero.'
                                  : 'No encontramos entidades con PAA $_anio con ese nombre. Prueba con otra parte del nombre o la sigla.',
                              style: const TextStyle(
                                color: EstiloContractual.gris,
                                fontSize: 13,
                              ),
                            )
                          else ...[
                            Text(
                              '${resultados.length} entidad${resultados.length == 1 ? '' : 'es'} con PAA $_anio',
                              style: const TextStyle(
                                color: EstiloContractual.gris,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            for (final (i, e) in resultados.indexed) ...[
                              if (i > 0)
                                const Divider(
                                  height: 1,
                                  color: Color(0xFFEDF0F4),
                                ),
                              InkWell(
                                onTap: () => _abrir(e),
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              e.nombre,
                                              style: const TextStyle(
                                                color: EstiloContractual.navy,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              e.cuentas.length == 1
                                                  ? 'Ver su proyección de contratación'
                                                  : '${e.cuentas.length} cuentas coinciden con la búsqueda · ver su estructura',
                                              style: const TextStyle(
                                                color: EstiloContractual.gris,
                                                fontSize: 12.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: EstiloContractual.gris,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ],
                    ),
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
