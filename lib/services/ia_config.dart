/// Configuración compartida de los modelos de Gemini (Firebase AI Logic).
class IaConfig {
  IaConfig._();

  /// Modelo usado por el Copiloto IA y el análisis de documentos. Google
  /// retira versiones antiguas para proyectos nuevos: si Gemini responde 404
  /// "no longer available", actualizar aquí.
  static const String modeloGemini = 'gemini-3.5-flash';
}
