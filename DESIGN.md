---
name: Contrata Legal
description: Apoyo para la contratación pública colombiana alrededor de SECOP II; vidrio oscuro con la luz de la marca, legible para todos.
colors:
  fondo: "#07101F"
  tinta: "#0A1424"
  flotante: "#0E1A2EF2"
  velo: "#0308128A"
  texto: "#FFFFFF"
  texto-cuerpo: "#FFFFFFDE"
  texto-medio: "#FFFFFFB3"
  texto-suave: "#FFFFFF99"
  texto-tenue: "#FFFFFF80"
  texto-apagado: "#FFFFFF66"
  vidrio-suave: "#FFFFFF0A"
  campo: "#FFFFFF0D"
  vidrio: "#FFFFFF0F"
  vidrio-fuerte: "#FFFFFF1A"
  vidrio-intenso: "#FFFFFF29"
  vidrio-oscuro: "#07101F7A"
  borde: "#FFFFFF14"
  borde-fuerte: "#FFFFFF2E"
  acento: "#2F6BFF"
  acento-claro: "#60A5FA"
  acento-vidrio: "#2F6BFF38"
  dorado: "#FFC53D"
  dorado-vidrio: "#FFC53D2E"
  dorado-borde: "#FFC53D66"
  verde: "#4ADE80"
  verde-vidrio: "#22C55E24"
  ambar: "#F59E0B"
  ambar-vidrio: "#F59E0B24"
  rojo: "#F87171"
  rojo-vidrio: "#EF444426"
typography:
  display:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "30px"
    fontWeight: 800
    lineHeight: 1.12
    letterSpacing: "-0.6px"
  headline:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "22px"
    fontWeight: 800
    lineHeight: 1.25
    letterSpacing: "-0.3px"
  title:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "16.5px"
    fontWeight: 800
    lineHeight: 1.3
  body:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "14.5px"
    fontWeight: 400
    lineHeight: 1.45
  body-sm:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.4
  label-button:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "13.5px"
    fontWeight: 800
  label-dato:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "11.5px"
    fontWeight: 800
    letterSpacing: "0.6px"
rounded:
  ficha: "12px"
  campo: "14px"
  aviso: "16px"
  tarjeta: "20px"
  panel: "24px"
  pildora: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  entre-tarjetas: "14px"
  lg: "16px"
  xl: "22px"
  2xl: "26px"
  pagina: "40px"
components:
  button-primary:
    backgroundColor: "{colors.acento}"
    textColor: "{colors.texto}"
    typography: "{typography.label-button}"
    rounded: "{rounded.pildora}"
    padding: "16px 22px"
  button-primary-disabled:
    backgroundColor: "{colors.vidrio-fuerte}"
    textColor: "{colors.texto-apagado}"
    rounded: "{rounded.pildora}"
  button-highlight:
    backgroundColor: "{colors.dorado}"
    textColor: "{colors.tinta}"
    typography: "{typography.label-button}"
    rounded: "{rounded.pildora}"
  button-secondary:
    backgroundColor: "{colors.vidrio}"
    textColor: "{colors.texto}"
    typography: "{typography.label-button}"
    rounded: "{rounded.pildora}"
    padding: "15px 18px"
  card:
    backgroundColor: "{colors.vidrio}"
    rounded: "{rounded.tarjeta}"
    padding: "22px"
  card-over-photo:
    backgroundColor: "{colors.vidrio-oscuro}"
    rounded: "{rounded.panel}"
    padding: "24px"
  input-field:
    backgroundColor: "{colors.campo}"
    textColor: "{colors.texto}"
    rounded: "{rounded.campo}"
  nav-item-selected:
    backgroundColor: "{colors.dorado-vidrio}"
    textColor: "{colors.texto}"
    rounded: "{rounded.campo}"
  chip-status-aprobado:
    backgroundColor: "{colors.verde-vidrio}"
    textColor: "{colors.verde}"
    typography: "{typography.label-dato}"
    rounded: "{rounded.ficha}"
  chip-status-devuelto:
    backgroundColor: "{colors.ambar-vidrio}"
    textColor: "{colors.ambar}"
    typography: "{typography.label-dato}"
    rounded: "{rounded.ficha}"
  chip-status-falta:
    backgroundColor: "{colors.rojo-vidrio}"
    textColor: "{colors.rojo}"
    typography: "{typography.label-dato}"
    rounded: "{rounded.ficha}"
  dialog:
    backgroundColor: "{colors.flotante}"
    textColor: "{colors.texto-cuerpo}"
    rounded: "{rounded.panel}"
  formal-sheet:
    backgroundColor: "#FFFFFF"
    textColor: "#0E2646"
    rounded: "6px"
    padding: "24px 26px"
---

# Design System: Contrata Legal

## Overview

**Creative North Star: "Vidrio de noche"**

Contrata Legal se ve como una mesa de trabajo de vidrio en una oficina de noche: un fondo azul marino casi negro, mate, con manchas de luz muy difusas en los colores de la marca (azul arriba a la izquierda, dorado abajo a la derecha), y encima paneles de vidrio translúcido con un borde de 1 px apenas visible. La luz de fondo se percibe a través de los paneles; el contenido (plazos, valores, quién debe actuar) sigue siendo lo protagonista.

El fondo se pinta una sola vez (`FondoCristal`, en `MaterialApp.builder`) y todas las pantallas usan `Scaffold` transparente. En las cabeceras de las secciones, la foto de Valledupar aparece desenfocada y fundida con el fondo (`FotoAmbiente.cabecera`); en la pantalla de inicio y en el registro se ve nítida a la derecha, y las tarjetas que van encima de ella son vidrio oscuro con desenfoque real.

El sistema sirve tanto a abogados como a funcionarios mayores o poco técnicos: la legibilidad manda. El texto principal es blanco pleno; la jerarquía se hace con opacidad, nunca con grises sólidos; toda acción lleva su palabra.

**Key Characteristics:**
- Fondo mate `fondo` (#07101F) con cuatro manchas radiales difusas, estático.
- Paneles de vidrio: relleno blanco al 4–10 %, borde blanco al 8 %, esquinas de 16–24 px.
- Acentos en su variante brillante: azul `acento` para la acción principal, dorado `dorado` para "dónde estás" y lo destacado.
- Inter en todo; jerarquía del texto por opacidad (100 / 87 / 70 / 60 / 50 / 40 %).
- Movimiento: cambios de vista simultáneos (sale hacia un lado, entra desde el opuesto) y 0,3 s de transición en todo lo que reacciona al cursor.

## Colors

Un fondo casi negro de la familia del azul marino de la marca, vidrio blanco translúcido encima, y los colores de la marca encendidos.

### Fondo y superficies
- **Fondo** (fondo): el lienzo de toda la app, mate. Nunca dentro de una tarjeta.
- **Vidrio** (vidrio-suave, vidrio, vidrio-fuerte, vidrio-intenso): rellenos al 4, 6, 10 y 16 %. Tarjeta en reposo = vidrio; bajo el cursor = vidrio-fuerte; seleccionado o presionado = vidrio-intenso.
- **Vidrio oscuro** (vidrio-oscuro): paneles que van sobre la foto; siempre con desenfoque real detrás.
- **Flotante** (flotante): diálogos, menús, avisos; casi opaco para que el texto se lea sobre cualquier cosa.
- **Borde / Borde fuerte** (borde, borde-fuerte): 1 px al 8 % en reposo, 18 % en campos y bajo el cursor.

### Texto (blanco por opacidad)
- **Texto** 100 %: títulos, cifras, valores, etiquetas de botón.
- **Texto cuerpo** 87 %: lectura. **Texto medio** 70 %: apoyo. **Texto suave** 60 %: subtítulos y metadatos. **Texto tenue** 50 %: rótulos pequeños e íconos en reposo. **Texto apagado** 40 %: deshabilitado.
- **Tinta** (#0A1424): el texto sobre rellenos claros o brillantes (dorado, celeste, verde). `Cristal.sobre(color)` lo elige solo.

### Marca
- **Acento** (#2F6BFF): el único relleno de la acción principal de cada decisión.
- **Acento claro** (#60A5FA): enlaces, íconos activos, trazo de foco de los campos.
- **Dorado** (#FFC53D): dónde estás (opción activa del menú, pestaña activa, barra de navegación), la llamada principal de la portada y el rol recomendado. Lleva texto `tinta`.

### Estados (siempre con su palabra o ícono)
- **Verde** hecho / aprobado / pagado. **Ámbar** devuelto / por subsanar / advertencia. **Rojo** falta / vencido / error. **Azul** en revisión / información.
- Cada estado tiene su vidrio teñido (verde-vidrio, ambar-vidrio, rojo-vidrio, acento-vidrio) para pastillas y avisos.

### Named Rules
**La Regla de la Luz.** El color pleno es luz: se reserva para la acción principal (azul), para "dónde estás" (dorado) y para los estados. Todo lo demás es vidrio blanco y texto blanco.

**La Regla de la Opacidad.** Nunca un gris sólido para jerarquizar texto: blanco con la opacidad del nivel que corresponda.

**La Regla del Ámbar.** El ámbar de advertencia (#F59E0B) y el dorado de la marca (#FFC53D) no se intercambian: el dorado nunca significa "cuidado".

## Typography

**Fuente única:** Inter (empaquetada en `assets/fonts/inter`).

**Carácter:** una sans humanista en dos temperaturas: extra negrita (800) blanca para lo que se busca con la vista (títulos, valores, botones) y regular al 87 % para lo que se lee.

### Hierarchy
- **Display** (800, 30 px, -0,6): título de pantalla de Gestión contractual y Supervisión. Inicio: 56 px en escritorio, 36 en celular.
- **Headline** (800, 22 px): título de tarjeta principal, pregunta del asistente.
- **Title** (800, 16,5 px): título de tarjeta.
- **Body** (400, 14,5 px, 1,45) y **Body-sm** (400, 13 px): lectura.
- **Label-button** (800, 13,5 px): botones.
- **Label-dato** (800, 11,5 px, +0,6, mayúsculas): solo como clave de un par clave–valor.

### Named Rules
**Nada por debajo de 11,5 px.** Metadatos a 11,5 px como mínimo; lectura a 13 px o más.

## Layout

Escritorio: menú lateral flotante de 240 px (68 px contraído) a 12 px de los bordes, y el contenido a su derecha. Celular (< 768 px): barra superior transparente con el logo y la sección, y barra de navegación inferior de vidrio. Tarjetas con 16 px de relleno en celular y 22 px en escritorio, separadas 14–16 px.

## Elevation & Depth

La profundidad no viene de sombras sino de capas de vidrio:
1. Fondo mate con manchas de luz (nivel 0).
2. Paneles en el flujo: relleno translúcido + borde (nivel 1). Sin sombra.
3. Lo que se superpone (diálogos, menús, avisos): superficie `flotante` y, para los diálogos, un velo que oscurece y desenfoca lo de atrás (sigma 14).

### Desenfoque
El desenfoque real (`BackdropFilter`, sigma 20) se usa solo donde hay algo nítido detrás: tarjetas sobre la foto, diálogos, el menú contraído. Los paneles en el flujo no lo llevan: sobre un fondo que ya es difuso se verían igual y en listas largas costaría rendimiento en la web.

## Shapes

Panel 24 px (diálogos, menú lateral, tarjetas grandes sobre foto) · Tarjeta 20 px · Aviso 16 px · Campo 14 px · Ficha 12 px · Botones en píldora. La hoja formal del informe conserva 6 px: imita papel.

## Motion

- **Entre rutas** (`TransicionLiquida`, 360 ms): la pantalla que sale se desvanece y se desliza 3,5 % hacia un lado mientras la que entra aparece desde el lado opuesto, a la vez. Al volver, el movimiento se invierte.
- **Dentro de una pantalla** (`CambioLiquido`): secciones del menú, pestañas y pasos usan el mismo movimiento; si las vistas tienen orden, ir a una anterior invierte el sentido.
- **Diálogos** (`mostrarDialogoCristal`): suben levemente y crecen de 97,5 % a 100 % mientras el velo desenfoca lo de atrás.
- **Microinteracciones**: 300 ms `easeInOut` en todo lo que reacciona al cursor (paneles, opciones del menú, botones, `InkWell`): el relleno y el borde suben de opacidad.

## Components

### Buttons
- **Principal**: píldora azul `acento`, etiqueta blanca 13,5/800. Una por decisión.
- **Destacado**: píldora dorada con texto `tinta` (portada "Crear cuenta", rol recomendado).
- **Secundario**: píldora de vidrio con borde fuerte y texto blanco.
- **Texto**: azul claro, sin relleno.
- Todos con el velo de 300 ms bajo el cursor y anillo de foco al 14 % para el teclado.

### Cards / Containers
`PanelCristal`: vidrio + borde de 1 px + esquinas de 20 px; con `onTap` o `interactivo` reacciona al cursor. Sobre la foto: vidrio oscuro con `desenfoque: true`.

### Inputs / Fields
Relleno `campo` (5 %), borde blanco al 18 %, esquinas de 14 px; al enfocar, borde azul claro de 1,5 px. Etiqueta flotante en azul claro.

### Navigation
- **Menú lateral**: panel de vidrio flotante. Opción activa: vidrio dorado con borde dorado e ícono dorado; las demás al 70 % y suben a 100 % con el cursor. La lista se desvanece en el borde por donde queda contenido y se desplaza sola hasta la opción activa.
- **Barra inferior (celular)**: vidrio suave con borde superior; activo en dorado.

### Islas claras
Lo que imita papel o necesita fondo blanco sigue blanco: la hoja formal del informe (`PapelClaro`), el panel de firma, los logos de terceros (`PlacaLogo`).

## Do's and Don'ts

### Do:
- **Do** usar los tokens de `lib/tema/cristal.dart`; ningún color suelto en las pantallas.
- **Do** dejar el `Scaffold` transparente y dejar que `FondoCristal` pinte el fondo.
- **Do** escribir encima de un relleno brillante con `Cristal.sobre(color)`.
- **Do** desenfocar de verdad solo lo que va sobre la foto o se superpone.
- **Do** acompañar cada color de estado con su palabra o ícono.
- **Do** abrir los diálogos con `mostrarDialogoCristal` y animar los cambios de vista con `CambioLiquido`.

### Don't:
- **Don't** usar grises sólidos para el texto ni negro puro para el fondo.
- **Don't** poner sombras a las tarjetas de vidrio.
- **Don't** usar el dorado como advertencia ni el ámbar como marca.
- **Don't** usar mayúsculas espaciadas como rótulo de sección; solo como clave de un dato.
- **Don't** dejar una acción solo con ícono sin su ayuda emergente.

## Cómo volver al diseño anterior

El diseño anterior ("La Oficina Clara": fondo crema, tarjetas blancas, azul marino) quedó guardado en la etiqueta `diseno-clasico-2026-11-11` y en la rama `respaldo/diseno-clasico`. Para verlo o recuperarlo: `git checkout respaldo/diseno-clasico`.
