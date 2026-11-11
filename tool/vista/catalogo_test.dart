import 'package:app_secop/tema/cristal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'soporte.dart';

void main() {
  setUpAll(cargarFuentes);

  testWidgets('catálogo del tema', (tester) async {
    ventana(tester, 1280, 900);
    await tester.pumpWidget(appCristal(const _Catalogo()));
    await tester.pump(const Duration(milliseconds: 400));
    await capturar(tester, 'catalogo');
  });
}

class _Catalogo extends StatelessWidget {
  const _Catalogo();

  @override
  Widget build(BuildContext context) {
    Widget chip(String t, Color c, Color f, [IconData? i]) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: f, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (i != null) ...[Icon(i, size: 13, color: c), const SizedBox(width: 5)],
        Text(t, style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w800)),
      ]),
    );
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(36),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Supervisión de contratos', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Cristal.texto, letterSpacing: -0.6)),
              const SizedBox(height: 6),
              const Text('Informes mensuales de los contratistas de prestación de servicios.', style: TextStyle(fontSize: 14.5, color: Cristal.textoSuave)),
              const SizedBox(height: 22),
              PanelCristal(
                padding: const EdgeInsets.all(22),
                interactivo: true,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 38, height: 38, decoration: BoxDecoration(color: Cristal.vidrioFuerte, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.assignment_outlined, size: 18)),
                    const SizedBox(width: 12),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Informe de octubre', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Cristal.texto)),
                      Text('Carlos Mario Vanegas · CO1.PCCNTR.9306724', style: TextStyle(fontSize: 12.8, color: Cristal.textoSuave)),
                    ])),
                    chip('En revisión', Cristal.acentoClaro, Cristal.azulVidrio, Icons.hourglass_top_rounded),
                  ]),
                  const SizedBox(height: 16),
                  const Text('VALOR A COBRAR', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Cristal.textoSuave)),
                  const Text('\$ 4.737.497', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Cristal.texto)),
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(value: 0.5, minHeight: 5, borderRadius: BorderRadius.all(Radius.circular(4))),
                  const SizedBox(height: 6),
                  const Text('6 de 12 listos · Guardado', style: TextStyle(fontSize: 12.3, color: Cristal.textoTenue)),
                ]),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                chip('Aprobado', Cristal.verde, Cristal.verdeVidrio, Icons.check_circle_rounded),
                chip('Devuelto', Cristal.ambar, Cristal.ambarVidrio, Icons.undo_rounded),
                chip('Falta', Cristal.rojo, Cristal.rojoVidrio, Icons.error_rounded),
                chip('Destacado', Cristal.dorado, Cristal.doradoVidrio, Icons.star_rounded),
                chip('Pendiente', Cristal.textoSuave, Cristal.vidrioFuerte),
              ]),
              const SizedBox(height: 18),
              Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.arrow_forward_rounded, size: 18), label: const Text('Siguiente')),
                OutlinedButton(onPressed: () {}, child: const Text('Devolver al contratista')),
                ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Cristal.dorado, foregroundColor: Cristal.tinta), child: const Text('Empezar ahora')),
                TextButton(onPressed: () {}, child: const Text('Ver las 2 respuestas anteriores')),
                const FilledButton(onPressed: null, child: Text('Aprobar')),
              ]),
              const SizedBox(height: 18),
              const TextField(decoration: InputDecoration(labelText: 'Observación para el contratista (obligatoria)', hintText: 'Explícale qué debe corregir')),
              const SizedBox(height: 12),
              Row(children: [
                ChoiceChip(label: const Text('Vigencia 2026'), selected: true, onSelected: (_) {}),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Desde 2023 hasta hoy'), selected: false, onSelected: (_) {}),
                const SizedBox(width: 16),
                Checkbox(value: true, onChanged: (_) {}),
                Checkbox(value: false, onChanged: (_) {}),
                Switch(value: true, onChanged: (_) {}),
                Switch(value: false, onChanged: (_) {}),
                const SizedBox(width: 12),
                const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
              ]),
            ]),
          ),
          const SizedBox(width: 28),
          SizedBox(
            width: 420,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Cristal.ambarVidrio, borderRadius: BorderRadius.circular(16), border: Border.all(color: Cristal.ambarBorde)),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Enlace devolvió tu informe', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Cristal.ambar)),
                  SizedBox(height: 4),
                  Text('Falta la planilla de seguridad social de octubre.', style: TextStyle(fontSize: 13.5, color: Cristal.textoCuerpo)),
                ]),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Tarjeta de Material', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Cristal.texto)),
                    const SizedBox(height: 6),
                    const Text('Texto de lectura al 87 %. Subtítulos al 60 % y detalles al 50 %.'),
                    const Divider(height: 24),
                    ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.description_outlined), title: const Text('Estudios previos.pdf'), subtitle: const Text('Cargado el 9 nov 2026'), trailing: TextButton(onPressed: () {}, child: const Text('Abrir'))),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Cristal.acentoVidrio, borderRadius: BorderRadius.circular(20), border: Border.all(color: Cristal.acentoBorde)),
                child: const Row(children: [
                  Icon(Icons.auto_awesome_rounded, color: Cristal.dorado),
                  SizedBox(width: 12),
                  Expanded(child: Text('Bloque que antes era azul marino: ahora es vidrio teñido de azul.', style: TextStyle(color: Cristal.texto, fontWeight: FontWeight.w600))),
                ]),
              ),
              const SizedBox(height: 14),
              AlertDialog(
                insetPadding: EdgeInsets.zero,
                title: const Text('¿Eliminar el proceso?'),
                content: const Text('Se borra de tu lista. En SECOP II no cambia nada.'),
                actions: [TextButton(onPressed: () {}, child: const Text('Cancelar')), FilledButton(onPressed: () {}, child: const Text('Eliminar'))],
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
