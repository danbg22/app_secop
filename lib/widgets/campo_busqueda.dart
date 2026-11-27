import 'package:flutter/material.dart';

/// Superficie clara común para los buscadores en ambos modos de la app.
class CampoBusqueda extends StatelessWidget {
  const CampoBusqueda({
    super.key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.search,
    this.maxLength,
    this.style,
    required this.decoration,
  });

  static const superficie = Color(0xF0EFF2F7);
  static const tinta = Color(0xFF16243A);
  static const _secundario = Color(0xFF44546A);
  static const _foco = Color(0xFF2458AB);

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final int? maxLength;
  final TextStyle? style;
  final InputDecoration decoration;

  @override
  Widget build(BuildContext context) {
    final base =
        decoration.border ??
        OutlineInputBorder(borderRadius: BorderRadius.circular(14));
    final sinBorde = base == InputBorder.none;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      maxLength: maxLength,
      cursorColor: _foco,
      style: (style ?? const TextStyle()).copyWith(color: tinta),
      decoration: decoration.copyWith(
        filled: decoration.filled ?? true,
        fillColor: superficie,
        hoverColor: Colors.transparent,
        hintStyle: (decoration.hintStyle ?? const TextStyle()).copyWith(
          color: _secundario,
        ),
        labelStyle: (decoration.labelStyle ?? const TextStyle()).copyWith(
          color: _secundario,
        ),
        floatingLabelStyle: const TextStyle(color: _foco),
        prefixIconColor: _secundario,
        suffixIconColor: _secundario,
        border: base,
        enabledBorder: sinBorde
            ? base
            : (decoration.enabledBorder ?? base).copyWith(
                borderSide: const BorderSide(color: Color(0xFFABB8CA)),
              ),
        focusedBorder: sinBorde
            ? base
            : (decoration.focusedBorder ?? base).copyWith(
                borderSide: const BorderSide(color: _foco, width: 1.6),
              ),
      ),
    );
  }
}
