import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'perfil_contratista_screen.dart';
import '../services/sigep_service.dart';

class ResultadosBusquedaScreen extends StatefulWidget {
  final String query;

  const ResultadosBusquedaScreen({super.key, required this.query});

  @override
  State<ResultadosBusquedaScreen> createState() =>
      _ResultadosBusquedaScreenState();
}

class _ResultadosBusquedaScreenState extends State<ResultadosBusquedaScreen> {
  late Future<List<_ResultadoPersona>> _resultadosFuture;

  @override
  void initState() {
    super.initState();
    _resultadosFuture = _buscarCoincidencias();
  }

  // Quita las tildes y las eñes para que "Bolaño" y "Bolano" sean iguales
  String _quitarTildesYNies(String texto) {
    return texto
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ñ', 'N');
  }

  Future<List<_ResultadoPersona>> _buscarCoincidencias() async {
    final query = widget.query.trim();
    if (query.isEmpty) return [];

    final isNumeric = RegExp(r'^[0-9]+$').hasMatch(query);
    final queryWords = _quitarTildesYNies(query)
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    final secopParams = <String, String>{
      r'$select': 'proveedor_adjudicado, documento_proveedor',
      r'$limit': '2000',
    };
    if (isNumeric) {
      secopParams[r'$where'] = "documento_proveedor = '$query'";
    } else {
      secopParams[r'$q'] = query;
    }
    final secopUri = Uri.https(
      'www.datos.gov.co',
      '/resource/jbjy-vk9h.json',
      secopParams,
    );

    final sources = await Future.wait<List<Map<String, dynamic>>>([
      _buscarSecop(secopUri).catchError((e) {
        debugPrint('SECOP Error: $e');
        return <Map<String, dynamic>>[];
      }),
      SigepService.buscarListaServidores(query).catchError((e) {
        debugPrint('SIGEP Error: $e');
        return <Map<String, dynamic>>[];
      }),
    ]);

    final secopRecords = sources[0];
    final sigepRecords = sources[1];
    final resultsByName = <String, _ResultadoPersona>{};

    bool cumpleFiltro(Map<String, dynamic> record, String nameCrudo) {
      if (isNumeric) {
        final docSecop = record['documento_proveedor']?.toString() ?? '';
        final docSigep1 = record['identificacion']?.toString() ?? '';
        final docSigep2 = record['numero_documento']?.toString() ?? '';
        final docSigep3 = record['documento']?.toString() ?? '';
        return docSecop == query ||
            docSigep1 == query ||
            docSigep2 == query ||
            docSigep3 == query;
      }

      final nameNormalizado = _quitarTildesYNies(nameCrudo);
      return queryWords.every((word) => nameNormalizado.contains(word));
    }

    for (final record in secopRecords) {
      final name = _cleanName(record['proveedor_adjudicado']);
      if (name == null || !cumpleFiltro(record, name)) continue;
      _addResult(resultsByName, name: name, subtitle: 'Contratista SECOP');
    }

    for (final record in sigepRecords) {
      final nombreCrudo =
          record['nombre_completo'] ??
          record['nombres_y_apellidos'] ??
          record['nombre_funcionario'] ??
          record['nombre_pep'] ??
          "${record['nombres'] ?? ''} ${record['apellidos'] ?? ''}".trim();

      final name = _cleanName(nombreCrudo);
      if (name == null || !cumpleFiltro(record, name)) continue;

      final entidad = _cleanName(
        record['entidad'] ?? record['nombre_entidad'] ?? record['institucion'],
      );
      _addResult(
        resultsByName,
        name: name,
        subtitle: entidad ?? 'Servidor público SIGEP',
      );
    }

    final results = resultsByName.values.toList()
      ..sort(
        (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
      );
    return results;
  }

  void _addResult(
    Map<String, _ResultadoPersona> resultsByName, {
    required String name,
    required String subtitle,
  }) {
    final key = _normalize(name);
    final existing = resultsByName[key];
    if (existing == null) {
      resultsByName[key] = _ResultadoPersona(name, subtitle);
    } else if (!existing.subtitulo.contains(subtitle)) {
      existing.subtitulo = '${existing.subtitulo} · $subtitle';
    }
  }

  Future<List<Map<String, dynamic>>> _buscarSecop(Uri uri) async {
    final response = await http.get(uri);
    if (response.statusCode != 200) return [];
    final decoded = json.decode(response.body);
    if (decoded is List)
      return decoded.whereType<Map<String, dynamic>>().toList();
    return [];
  }

  String? _cleanName(dynamic value) {
    if (value == null) return null;
    final cleaned = value.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty || cleaned.toUpperCase() == 'NULL') return null;
    return cleaned;
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Resultados de búsqueda',
          style: TextStyle(
            color: Color(0xFF17365D),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF17365D)),
      ),
      body: FutureBuilder<List<_ResultadoPersona>>(
        future: _resultadosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final results = snapshot.data ?? [];
          if (results.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_search_outlined,
                      size: 72,
                      color: Colors.blueGrey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No se encontraron resultados para "${widget.query}".',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.blueGrey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final resultado = results[index];
              return Card(
                color: Colors.white,
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: Icon(
                      Icons.person_outline,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  title: Text(
                    resultado.nombre.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF17365D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(resultado.subtitulo),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.blueGrey,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PerfilContratistaScreen(
                          nombreBuscado: resultado.nombre,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ResultadoPersona {
  final String nombre;
  String subtitulo;
  _ResultadoPersona(this.nombre, this.subtitulo);
}
