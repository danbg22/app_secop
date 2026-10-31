import 'package:cloud_firestore/cloud_firestore.dart';

/// Archivos de hasta 25 MB en Firestore, sin Firebase Storage (no disponible
/// en el plan Spark para proyectos nuevos).
///
/// Un documento de Firestore admite como máximo 1 MiB, así que el archivo en
/// base64 se divide en fragmentos guardados en `{documento}/partes/{i}`. El
/// documento principal guarda los metadatos y la cantidad de partes, y se
/// escribe al final: quien lo lea ve el archivo completo o la versión
/// anterior, nunca uno a medias. Los archivos pequeños siguen en un solo
/// documento (`archivoBase64`), compatible con los ya cargados.
class ArchivoFragmentado {
  ArchivoFragmentado._();

  /// Caracteres base64 por documento, con margen bajo el límite de 1 MiB.
  static const int tamanoFragmento = 700000;

  static const int _escriturasSimultaneas = 3;

  static Future<void> guardar(
    DocumentReference<Map<String, dynamic>> ref, {
    required String base64,
    required Map<String, dynamic> metadatos,
  }) async {
    if (base64.length <= tamanoFragmento) {
      await ref
          .set({...metadatos, 'archivoBase64': base64, 'partes': 0})
          .timeout(const Duration(seconds: 30));
      return;
    }

    final partes = <String>[
      for (var i = 0; i < base64.length; i += tamanoFragmento)
        base64.substring(
          i,
          i + tamanoFragmento > base64.length ? base64.length : i + tamanoFragmento,
        ),
    ];
    for (var i = 0; i < partes.length; i += _escriturasSimultaneas) {
      await Future.wait([
        for (var j = i; j < partes.length && j < i + _escriturasSimultaneas; j++)
          ref
              .collection('partes')
              .doc('$j')
              .set({'i': j, 'datos': partes[j]})
              .timeout(const Duration(seconds: 60)),
      ]);
    }
    await ref
        .set({...metadatos, 'partes': partes.length})
        .timeout(const Duration(seconds: 30));
  }

  /// Contenido base64 del archivo, o `null` si no existe. [metadatos] recibe
  /// el documento principal (para validar versión o huella).
  static Future<String?> leer(
    DocumentReference<Map<String, dynamic>> ref, {
    void Function(Map<String, dynamic> metadatos)? metadatos,
  }) async {
    final doc = await ref.get().timeout(const Duration(seconds: 20));
    final data = doc.data();
    if (data == null) return null;
    metadatos?.call(data);
    final directo = data['archivoBase64']?.toString() ?? '';
    if (directo.isNotEmpty) return directo;
    final partes = (data['partes'] as num?)?.toInt() ?? 0;
    if (partes <= 0) return null;
    final docs = await Future.wait([
      for (var i = 0; i < partes; i++)
        ref.collection('partes').doc('$i').get().timeout(const Duration(seconds: 60)),
    ]);
    final buffer = StringBuffer();
    for (final d in docs) {
      final datos = d.data()?['datos']?.toString() ?? '';
      if (datos.isEmpty) return null;
      buffer.write(datos);
    }
    return buffer.toString();
  }
}
