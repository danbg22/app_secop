---
name: Contrata Legal
description: Apoyo para la contratación pública colombiana alrededor de SECOP II; claro, institucional y legible para todos.
colors:
  navy-institucional: "#0E2646"
  tinta-pizarra: "#364F6B"
  gris-pizarra: "#64748B"
  crema-fondo: "#FEF9EB"
  blanco-tarjeta: "#FFFFFF"
  borde-frio: "#E6ECF5"
  borde-calido: "#E2DAC8"
  trazo-campo: "#D8DEE8"
  trazo-foco: "#CBD5E1"
  relleno-quieto: "#F1F5F9"
  carril-pendiente: "#E2E8F0"
  verde-hecho: "#16A34A"
  verde-texto: "#15803D"
  verde-lavado: "#DCFCE7"
  ambar-devuelto: "#D97706"
  ambar-texto: "#B45309"
  ambar-profundo: "#92400E"
  ambar-lavado: "#FEF3C7"
  ambar-aviso-fondo: "#FFFBEB"
  ambar-aviso-borde: "#FCD34D"
  rojo-falta: "#DC2626"
  rojo-texto: "#B91C1C"
  rojo-lavado: "#FEE2E2"
  azul-info-texto: "#1D4ED8"
  azul-info-lavado: "#DBEAFE"
  verde-azulado-pagado: "#0F766E"
  verde-azulado-lavado: "#CCFBF1"
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
  meta:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "12.3px"
    fontWeight: 400
    lineHeight: 1.35
rounded:
  hoja: "6px"
  icono: "10px"
  campo: "12px"
  volver: "14px"
  aviso: "16px"
  tarjeta: "20px"
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
    backgroundColor: "{colors.navy-institucional}"
    textColor: "{colors.blanco-tarjeta}"
    typography: "{typography.label-button}"
    rounded: "{rounded.pildora}"
    padding: "16px 22px"
  button-primary-disabled:
    backgroundColor: "{colors.trazo-foco}"
    textColor: "{colors.blanco-tarjeta}"
    rounded: "{rounded.pildora}"
  button-secondary:
    backgroundColor: "{colors.blanco-tarjeta}"
    textColor: "{colors.navy-institucional}"
    typography: "{typography.label-button}"
    rounded: "{rounded.pildora}"
    padding: "15px 18px"
  button-back:
    backgroundColor: "{colors.blanco-tarjeta}"
    textColor: "{colors.navy-institucional}"
    typography: "{typography.label-button}"
    rounded: "{rounded.volver}"
    padding: "14px 18px"
  card:
    backgroundColor: "{colors.blanco-tarjeta}"
    rounded: "{rounded.tarjeta}"
    padding: "22px"
  card-question:
    backgroundColor: "{colors.blanco-tarjeta}"
    textColor: "{colors.navy-institucional}"
    typography: "{typography.headline}"
    rounded: "{rounded.tarjeta}"
    padding: "26px"
  input-field:
    backgroundColor: "{colors.blanco-tarjeta}"
    textColor: "{colors.navy-institucional}"
    rounded: "{rounded.campo}"
  chip-status:
    typography: "{typography.label-dato}"
    rounded: "{rounded.campo}"
    padding: "4px 10px"
  chip-status-en-revision:
    backgroundColor: "{colors.azul-info-lavado}"
    textColor: "{colors.azul-info-texto}"
  chip-status-devuelto:
    backgroundColor: "{colors.ambar-lavado}"
    textColor: "{colors.ambar-texto}"
  chip-status-aprobado:
    backgroundColor: "{colors.verde-lavado}"
    textColor: "{colors.verde-texto}"
  chip-filter-selected:
    backgroundColor: "{colors.ambar-lavado}"
    textColor: "{colors.ambar-profundo}"
  notice-returned:
    backgroundColor: "{colors.ambar-aviso-fondo}"
    textColor: "{colors.ambar-profundo}"
    rounded: "{rounded.aviso}"
    padding: "16px"
  answer-row:
    textColor: "{colors.navy-institucional}"
    rounded: "{rounded.campo}"
    padding: "9px 6px 9px 12px"
  formal-sheet:
    backgroundColor: "{colors.blanco-tarjeta}"
    textColor: "{colors.navy-institucional}"
    rounded: "{rounded.hoja}"
    padding: "24px 26px"
---

# Design System: Contrata Legal

## Overview

**Creative North Star: "La Oficina Clara"**

Contrata Legal is an institutional workroom laid on warm paper: a cream ground, clean white cards resting on it with a barely-there navy shadow, one deep navy voice for text and action, and pill-shaped buttons. It is calm and administrative rather than expressive; the drama is left to the content (deadlines, amounts, who must act next). Every surface reads like a well-kept office desk where the next thing to do is already on top.

Density is moderate. Cards carry generous padding (16px on phones, 22px on desktop) and stack with a steady 14–16px gap. Colour beyond navy is semantic only: green means done, amber means returned or waiting on a correction, red means missing or late, blue means informational or in review. The Supervisión module adds two expressions of the same world: the guided assistant (one large question card at a time, previous answers stacked above as quiet rows) and the reviewer split (a formal paper sheet on the left, the reviewer's own cards on the right).

The system is built for older and non-technical officials as much as for lawyers, so legibility outranks compactness: explicit text labels on actions, strong navy-on-white contrast, and confirmation before anything destructive.

**Key Characteristics:**
- Cream ground (crema-fondo), white cards, deep navy (navy-institucional) for text and the one primary action.
- Inter throughout, heavy weights (800) for titles and buttons, regular for reading text.
- Pill buttons; generously rounded cards (20px); fields at 12px.
- One soft, low-contrast navy shadow under cards; no hard or offset shadows.
- State colours carry meaning only, always paired with a word or icon.

## Colors

One institutional navy over warm cream and white, with a fixed semantic set of green, amber, red, and blue that only appears when it means something.

### Primary
- **Navy Institucional** (navy-institucional): headings, values, the primary pill button, the focused field stroke, the "current" stage dot, success snackbars. It is the only brand colour that fills an action.

### Neutral
- **Crema Fondo** (crema-fondo): the page ground on every Gestión contractual and Supervisión screen. Never used inside cards.
- **Blanco Tarjeta** (blanco-tarjeta): cards, fields, secondary buttons, the assistant's top band, the formal sheet.
- **Tinta Pizarra** (tinta-pizarra): running text, subtitles, help copy under a question.
- **Gris Pizarra** (gris-pizarra): metadata, dates, counters ("6 de 12 listos"), pending stage names, uppercase data keys.
- **Borde Frío** (borde-frio): default 1.3px card border.
- **Borde Cálido** (borde-calido): secondary and back-button strokes, the "Paso x de y" pill; the warm stroke ties outlined controls to the cream ground.
- **Trazo Campo** (trazo-campo): resting field border.
- **Trazo Foco** (trazo-foco): border of the active question card (it is the one card on screen that is slightly stronger) and the disabled primary button fill.
- **Relleno Quieto** (relleno-quieto): icon tiles in card headers, the quoted obligation text inside a question card, neutral chips.
- **Carril Pendiente** (carril-pendiente): pending stage dots and connectors, the formal sheet's border.

### Semantic states
- **Verde Hecho / Texto / Lavado** (verde-hecho, verde-texto, verde-lavado): completed step check, progress bar fill, approved stage dots and connectors, "Aprobado" chip.
- **Ámbar Devuelto / Texto / Profundo / Lavado** (ambar-devuelto, ambar-texto, ambar-profundo, ambar-lavado): returned steps and stage dots, the "Devuelto" chip, the "Devolver al contratista" action text, selected return-item chips.
- **Aviso de devolución** (ambar-aviso-fondo, ambar-aviso-borde): the returned-report notice and the border of a returned question card.
- **Rojo Falta / Texto / Lavado** (rojo-falta, rojo-texto, rojo-lavado): failed automatic checks, overdue deadline chip, error snackbars.
- **Azul Info** (azul-info-texto, azul-info-lavado): "Vence el …" deadline chip, "En revisión" chip.
- **Verde Azulado Pagado** (verde-azulado-pagado, verde-azulado-lavado): the final "Pagado" state only.

### Named Rules
**The Colour Means Something Rule.** Green, amber, red, and blue appear only to state a status (hecho, devuelto, falta, en revisión). Decorative use of a state colour is a bug; a state colour never appears without its word or icon.

**The One Navy Rule.** Navy is the only filled action colour. A screen has one filled navy button per decision point; every other action is a white pill with the warm stroke or a plain text button.

## Typography

**Display Font:** Inter (bundled in `assets/fonts/inter`, with system sans-serif fallback)
**Body Font:** Inter
**Label/Mono Font:** Inter (no mono in use)

**Character:** A single humanist sans used at two temperatures: extra-bold (800) navy for anything you scan for (titles, questions, values, button labels), regular slate for anything you read.

### Hierarchy
- **Display** (800, 30px, 1.12, -0.6px): screen titles on hub screens; the read-only report view uses it reduced to 26px.
- **Headline** (800, 22px desktop / 19px mobile, 1.25, -0.3px): the single question in the guided assistant ("¿Qué hiciste para cumplir la obligación 5?").
- **Title** (800, 16.5px): card titles and the assistant's top-band report name.
- **Group title** (800, 15px, navy, sentence case; `EstiloContractual.tituloGrupo`): headings for groups inside a screen ("Datos del proceso", "Procesos en SECOP II (4)"). This replaces the old uppercase section labels.
- **Body** (400, 14.5px, 1.45): subtitles; question help text runs at 13.5px with the same leading.
- **Body small** (400, 13px, ~1.4): list rows, verification results, formal-sheet values.
- **Label button** (800, 13.5px): text on every pill button.
- **Label dato** (800, 11.5px, +0.6px, uppercase): the key in a key–value pair (CONTRATO, PERIODO, VALOR A COBRAR). Value sits below or beside it in navy 800 at 13–14px.
- **Meta** (400, 12.3px, gris-pizarra): dates, "Siguen 6 pasos…", file names, counters.

### Named Rules
**The Two Temperatures Rule.** Weight does the hierarchy, not size jumps: 800 navy for what is scanned, 400 slate for what is read. Mid weights (600/700) are reserved for list-row labels and stage names.

**The Uppercase Is a Key Rule.** Uppercase letter-spaced text is only the key of a data pair. It never introduces a section or sits above a heading.

## Layout

Single centred column on cream, constrained by purpose: 780px for the guided assistant, 820px for the read-only report, 920px for configuration (plan, template), 1080px default, 1120px for trays (bandeja, contract supervision), 1320px for the reviewer split. Page padding is 40px horizontal and 24px vertical on desktop, 16px and 14px below 680px.

Rhythm: cards stack with 14–16px gaps; inside a card, 16px after the header, 18px between a question and its input, 22px before the action row. Stacked previous answers sit 6px apart.

Responsive behaviour: card padding tightens at 680px; the assistant switches to mobile spacing and drops the deadline chip at 720px; multi-field rows stack at 640px; the reviewer split (formal sheet left, decision cards right) collapses to one column below 1000px, and the stage rail turns vertical.

The guided assistant has its own frame: a white top band (back, report name, period, deadline chip, "Paso x de y" pill, 5px green progress bar with "n de m listos · Guardado") above a scrolling cream column of: returned notice (if any), the last three answered steps as compact rows ("Ver las n respuestas anteriores" reveals the rest), the current question card, and a one-line remaining-steps note.

## Elevation & Depth

Mostly flat with one ambient lift. Cards sit on the cream ground with a 1.3px cool border and a very soft navy shadow; nothing floats higher except the formal sheet, which reads as paper laid on the desk. Depth never signals interactivity; borders and colour do.

### Shadow Vocabulary
- **Tarjeta** (`box-shadow: 0 6px 18px rgba(14, 38, 70, 0.04)`): every card, including the question card and status headers.
- **Hoja** (`box-shadow: 0 8px 22px rgba(14, 38, 70, 0.07)`): the formal report sheet in the reviewer split only.

### Named Rules
**The Paper On A Desk Rule.** Shadows are diffuse, navy-tinted, and under 8% opacity. Hard, offset, or black shadows are outside this world.

## Shapes

Soft and friendly at the container scale, crisp at the document scale. Cards round at 20px, notices at 16px, the back control at 14px, fields and chips at 12px, icon tiles at 10px; every button that triggers an action is a full pill. The formal report sheet is the deliberate exception at 6px: it imitates an official printed page, so it stays nearly square. Status dots on the stage rail are 28px circles; history markers are 8px navy dots.

## Components

### Buttons
- **Shape:** full pill (999px).
- **Primary:** navy fill, white 13.5px/800 label, 16px × 22px padding; trailing arrow icon when it advances ("Siguiente"). Disabled fills with trazo-foco and is paired with a one-line reason below ("Marca los tres puntos para aprobar.").
- **Secondary:** white fill, 1.2px borde-calido stroke, navy label, 15px × 18px. A cautionary secondary ("Devolver al contratista") keeps the white pill and recolours only the label and icon to ambar-texto.
- **Back:** "← Volver" as a white outlined control with the warm stroke at 14px radius, top-left of the page; in the assistant's top band it is an icon button with the "Volver" tooltip, and it saves before leaving.
- **Text buttons:** navy, for "Anterior", "Editar", "Ver las n respuestas anteriores", "Abrir"/"Ver".

### Chips
- **Status:** 12px radius, 4px × 10px, 11.5px/800 text on its tonal wash (en revisión blue, devuelto amber, aprobado green, pagado teal, pendiente/borrador slate), optional 13px leading icon.
- **Filter (return items):** Material filter chips at 12.3px; selected state fills ambar-lavado with an ambar-profundo check, because selecting an item means "this must be corrected".

### Cards / Containers
- **Corner Style:** 20px.
- **Background:** white on cream.
- **Shadow Strategy:** Tarjeta shadow (see Elevation & Depth).
- **Border:** 1.3px borde-frio; trazo-foco on the active question card; ambar-aviso-borde when the content was returned.
- **Internal Padding:** 22px desktop / 16px mobile; the question card 26px / 18px.
- **Header:** optional 18px navy icon in a 10px-radius relleno-quieto tile, 16.5px/800 title, 12.8px slate subtitle, optional trailing action.

### Inputs / Fields
- **Style:** filled white, 12px radius, 1px trazo-campo stroke, floating label, helper text up to three lines.
- **Focus:** 1.5px navy stroke.
- **Money:** peso fields format thousands with dots while typing (3.500.000).
- **Required observations:** the label states it ("Observación para el contratista (obligatoria)") and the dependent action stays disabled until it is filled.

### Navigation
- Page-level: back pill top-left, then a white header card with title, metadata line, and status chips aligned right.
- Assistant: "Paso x de y" pill opens a menu of every step with a check, amber undo, or empty-circle icon, so any step can be revisited.

### Guided question card (signature)
One question per screen, written as a direct question in navy headline type, help line beneath, then the input, then "Anterior" (text) left and the primary pill right. Changing step cross-fades with a 3% upward slide over 220ms (ease-out cubic). Answered steps collapse into **answer rows**: translucent white (70%) 12px-radius rows with a state icon, the step name at 13px/700, a one-line ellipsised summary in gris-pizarra, and "Editar".

### Stage rail (signature)
Numbered 28px circles joined by 2px connectors: green with a check when approved, navy with the number when current, amber with an undo icon when returned, light slate when pending. Each carries the stage name and, below it, who approved or who is responsible. Horizontal in wide headers, vertical in the reviewer's side column.

### Formal sheet (signature)
The report as the entity will print it: centred entity header lines at 12.5px/800, the report title at 16px/800, then key–value rows (uppercase 170px key column, navy value) separated by hairlines, numbered obligations with the obligation in slate and the activity below. Square-ish 6px corners and the Hoja shadow set it apart from the app's own cards.

### Returned notice
Amber wash, amber stroke, 16px radius, 16px padding: "{Etapa} devolvió tu informe" in 15px/800 ambar-profundo, the observation verbatim at 13.5px, author and date at 11.8px, and an "Ir a corregir: {paso}" text button. It always leads the screen.

### Texto en la interfaz (convenciones de copy)

- **Idioma y registro.** Español de Colombia. Al contratista se le habla de **tú** ("¿Qué hiciste para cumplir la obligación 5?", "Sé concreto", "Enlace devolvió tu informe"). Al revisor también se le tutea en las instrucciones ("Tu revisión · Jefe de sectorial", "Marca lo que debe corregir y explícale cómo").
- **Preguntas, no rótulos.** En el asistente, cada paso es una pregunta directa con una línea de ayuda que dice qué se espera ("qué hiciste, cuántos, en qué fechas y qué entregaste").
- **Lenguaje llano.** Frases cortas, sin siglas sin explicar; los términos jurídicos (CDP, RP, IBC, planilla) se usan con su nombre correcto. La app aclara su papel: "La app revisa estos puntos; la decisión es de quien tiene la etapa", "Lo arma la app".
- **Decir qué sigue y tranquilizar.** "Siguen 6 pasos. Lo que escribes se guarda automáticamente.", "6 de 12 listos · Guardado", "Marca los tres puntos para aprobar."
- **Botones con verbo y destino.** "Siguiente", "No tengo, seguir", "Ir a corregir: Obligación 4", "Devolver al contratista", "Revisado y verificado". Nunca solo un ícono para una acción.
- **Obligatorio se dice en la etiqueta**, entre paréntesis: "(obligatoria)", "(opcional)".
- **Formatos.** Número: "N.º 1". Fechas legibles con día abreviado: "dom 8 nov 2026"; rangos con raya: "9 oct 2026 – 8 nov 2026". Pesos con signo y punto de miles: "$ 3.500.000". Separador de metadatos: " · ".
- **Plurales correctos** en contadores ("Sigue 1 paso" / "Siguen 6 pasos", "Ver la respuesta anterior" / "Ver las 2 respuestas anteriores").
- **Devoluciones**: la observación del revisor se muestra textual y primero; quien devuelve debe escribirla (mínimo 10 caracteres) antes de poder devolver.

## Do's and Don'ts

### Do:
- **Do** place every Gestión contractual and Supervisión screen on crema-fondo with white 20px cards carrying the Tarjeta shadow and a 1.3px borde-frio border.
- **Do** keep exactly one filled navy pill per decision point; everything else is a white pill with the borde-calido stroke or a navy text button.
- **Do** pair every state colour with its word or icon (check, undo, error) and use the fixed meanings: green hecho, amber devuelto, red falta, blue en revisión/información.
- **Do** lead with what the user must do now: returned notice first, current question card largest, remaining steps and autosave stated in one line.
- **Do** keep reading text at 13px or larger and metadata at 11.5px or larger; labels must stay legible for older officials.
- **Do** use uppercase 11.5px/800 letter-spaced text only as the key of a key–value pair.
- **Do** render the formal report as a 6px-radius sheet with hairline rows when the user is reviewing what the entity will sign.
- **Do** write UI copy in Colombian Spanish, tú to the user, as direct questions and verb-first buttons.

### Don't:
- **Don't** use state colours decoratively or as brand accents.
- **Don't** use hard, offset, or black shadows; depth is the soft navy Tarjeta or Hoja shadow only.
- **Don't** put uppercase letter-spaced labels above headings or sections as eyebrows; uppercase is reserved for data keys.
- **Don't** ship icon-only actions; every action has a visible text label (icon buttons need a tooltip and are limited to back/close in bands).
- **Don't** fill a returned or destructive action in red or amber; it stays a white pill with a recoloured label, and destructive actions confirm first.
- **Don't** lay a long scroll of identical field cards for a guided task; ask one question at a time and collapse answered steps into rows.
