# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Contrata Legal has two audiences, and each section is designed for the one that uses it:

- **Equipo jurídico de entidades públicas** (paid role): the head of the team (Master Jurídico), temporary lawyers with assigned permissions, and contract supervisors. They prepare and verify contracts, follow processes that run in SECOP II, and supervise monthly payments of service contracts. They work during office hours, usually with SECOP II open in another tab.
- **Personas** (free role): citizens and officials who look up public contracting data — entities, contracts, contractors, budget by internal dependency.

Two external participants touch the product without an account: **contractors**, who receive a link to upload documents and monthly reports, and **supervisors**, who approve reports inside the legal team.

Users include older or non-technical officials (for example, a regional director). Text must stay legible and steps explicit.

## Product Purpose

Make Colombian public contracting manageable and understandable. For legal teams: verify contractor documents, control legal deadlines, review offers, and supervise monthly payments with less manual work. For everyone: read SECOP II open data clearly — who contracts, how much, with whom, and how much has been executed.

Success: a legal team trusts the platform for its daily work, and a citizen can find what an entity contracted without knowing SECOP II.

## Positioning

A support tool, never a replacement for SECOP II. SECOP II is the official, transactional system: documents are published there, offers are received there, and awards happen there. Contrata Legal prepares, verifies, reminds, and explains around it. Bidders never enter the platform; only service contractors get a link to upload their own documents.

## Operating Context

- Data comes live from Datos Abiertos (datos.gov.co) SECOP II datasets, which can lag up to one day.
- Legal framework referenced in the UI: Ley 80 de 1993, Ley 1150 de 2007, Ley 1474 de 2011, Decreto 1082 de 2015, Ley 1581 de 2012 (personal data).
- Used mostly on office computers, also on phones (quick lookups; contractors uploading documents).
- Outputs that leave the app: Word drafts (evaluation report, responses to observations, compliance certificate) and a unified PDF of a contractor file, which are signed and published in SECOP II by the entity.

## Capabilities and Constraints

- Flutter web app, deployed for testing on Netlify; Firebase Auth and Firestore on the free (Spark) plan: no server functions, so no email notifications; files up to 25 MB stored in Firestore chunks.
- Roles: Persona (free), Equipo jurídico (paid, with temporary team members and permissions); Empresa licitante and Veeduría ciudadana exist as planned roles, not yet enabled.
- Legal team flows: contractor file with document verification and guest link (prestación de servicios); import and follow-up of processes from SECOP II with sync and change detection; monthly supervision (report → document review → supervisor approval → payment).
- Public flows: entity profile with budget by internal dependency, contract search including natural language, contractor profiles, AI copilot (Gemini, limited quota).
- All UI copy is Spanish (Colombia).

## Brand Commitments

- Name: **Contrata Legal**; logo at `assets/images/logo.png`.
- Typography already committed app-wide: Inter.
- Voice: plain, precise Spanish; legal terms used correctly and with their legal basis when it helps the user act; never implies the platform is official or replaces SECOP II.

## Evidence on Hand

- Original logos of 50 public entities in `assets/logos_entidades/` with sources in `assets/logos_entidades/FUENTES.md`.
- Real SECOP II data is available live; there are no customer testimonials, case studies, usage metrics, or pricing claims to show. Do not invent them.

## Product Principles

1. SECOP II decides; Contrata Legal supports. Every screen makes clear what happens in SECOP II and what is internal help.
2. Tell the user what to do next: pending items, deadlines, and "te toca" before everything else.
3. Show the source and the limits of public data honestly (lag, what is and is not included).
4. Legible for everyone: clear hierarchy, readable sizes, explicit steps, works on phone and desktop.
5. Protect personal data (Ley 1581): only the people who need it see it.

## Accessibility & Inclusion

Older and non-technical officials use the product: keep comfortable text sizes, strong contrast, explicit labels instead of icon-only actions, and confirmation before destructive actions.
