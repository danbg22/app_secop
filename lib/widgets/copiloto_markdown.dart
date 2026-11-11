import 'package:flutter/material.dart';

import '../tema/cristal.dart';

/// Renderiza el subconjunto de Markdown que devuelve el Copiloto IA:
/// títulos (`#`), viñetas (`-`, `*`, `•`, con sangría), listas numeradas,
/// `**negrita**`, `*cursiva*` y `` `código` ``. Todo lo demás se muestra como
/// texto plano, así una respuesta inesperada nunca rompe la burbuja.
class CopilotoMarkdown extends StatelessWidget {
  const CopilotoMarkdown(this.data, {super.key, required this.style});

  final String data;
  final TextStyle style;

  static final RegExp _heading = RegExp(r'^(#{1,6})\s+(.*)$');
  static final RegExp _bullet = RegExp(r'^(\s*)[-*•]\s+(.*)$');
  static final RegExp _numbered = RegExp(r'^(\s*)(\d{1,3})[.)]\s+(.*)$');
  static final RegExp _inline = RegExp(
    r'\*\*(.+?)\*\*|__(.+?)__|`([^`]+)`|(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])',
  );

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[];
    final paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      blocks.add(Text.rich(_inlineSpans(paragraph.join(' '), style)));
      paragraph.clear();
    }

    for (final rawLine in data.replaceAll('\r\n', '\n').split('\n')) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) {
        flushParagraph();
        continue;
      }
      if (RegExp(r'^\s*([-*_])\s*\1\s*\1[\s\-*_]*$').hasMatch(line)) {
        flushParagraph();
        blocks.add(const Divider(height: 12, color: Cristal.borde));
        continue;
      }

      final heading = _heading.firstMatch(line.trimLeft());
      if (heading != null) {
        flushParagraph();
        blocks.add(
          Text.rich(
            _inlineSpans(
              heading.group(2)!.replaceAll('**', ''),
              style.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: (style.fontSize ?? 13) + 1,
              ),
            ),
          ),
        );
        continue;
      }

      final bullet = _bullet.firstMatch(line);
      final numbered = bullet == null ? _numbered.firstMatch(line) : null;
      if (bullet != null || numbered != null) {
        flushParagraph();
        final indent = (bullet ?? numbered)!.group(1)!.length;
        final level = (indent ~/ 2).clamp(0, 3);
        final marker = bullet != null
            ? (level == 0 ? '•' : '◦')
            : '${numbered!.group(2)}.';
        final content = bullet != null ? bullet.group(2)! : numbered!.group(3)!;
        blocks.add(
          Padding(
            padding: EdgeInsets.only(left: 4.0 + level * 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: bullet != null ? 14 : 22,
                  child: Text(
                    marker,
                    style: style.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Expanded(child: Text.rich(_inlineSpans(content, style))),
              ],
            ),
          ),
        );
        continue;
      }

      paragraph.add(line.trim());
    }
    flushParagraph();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          blocks[i],
        ],
      ],
    );
  }

  static TextSpan _inlineSpans(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _inline.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      if (m.group(1) != null || m.group(2) != null) {
        spans.add(
          TextSpan(
            text: m.group(1) ?? m.group(2),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        );
      } else if (m.group(3) != null) {
        spans.add(
          TextSpan(
            text: m.group(3),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              backgroundColor: Color(0x18FFFFFF),
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: m.group(4),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return TextSpan(style: base, children: spans);
  }
}
