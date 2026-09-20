# Engineering Calculator

A modular SwiftUI engineering-calculation app for iOS and macOS.

> **Development agents/contributors:** Read [`AGENTS.md`](AGENTS.md) first for persistent development rules, then [`DEVELOPMENT_STATUS.md`](DEVELOPMENT_STATUS.md) for the current project checkpoint, implementation history and roadmap. When the user says **refresh**, both documents must be read before development continues.

## Current development status — 20 September 2026

Active development branch: `feature/material-property-framework`

The project is currently focused on the reusable Materials Library and temperature-dependent material-property framework before moving on to additional engineering calculators.

> **Detailed handover / development roadmap:** See [`DEVELOPMENT_STATUS.md`](DEVELOPMENT_STATUS.md). It records completed work, design decisions, test/checkpoint information, lessons from previous implementations, and the detailed development path ahead.

### Current working functionality

- Shared engineering material model used by calculators and the Materials Library.
- Built-in and user-created materials.
- Material categories and editable engineering properties.
- Simplified and advanced material-property editing.
- Temperature-dependent property representations: constant/scalar, tabulated/interpolated, polynomial, linear-reference, and relative-linear/TCR.
- Material Property Inspector with resolved value/method, graph and traceability information.
- User materials persist locally as JSON in Application Support.
- Existing pipe weight/buoyancy calculation remains operational.
- Portable material interchange using human-readable `.ecmaterial` / `.ecmaterials` files.
- Native macOS/iOS Material Files interface for importing and exporting user, built-in, complete, and individual materials.
- Safe import merge: imported data cannot become protected built-in data, UUID collisions are regenerated, and duplicate names receive an ` (Imported N)` suffix rather than overwriting existing materials.
- Custom material UTTypes are registered for `.ecmaterial` and `.ecmaterials`.
- Reusable multi-material comparison engine with explicit reference material, differences and engineering-aware equality.
- Multi-material selector preserves selection order and marks the first selection with a green `R`, followed by `2`, `3`, `4…` badges.
- macOS comparison opens in a native resizable/full-screen window.
- macOS comparison grid automatically fills available width, supports user-resizable columns, freezes Property + Reference columns, and only enables horizontal scrolling when the table actually exceeds the viewport.
- **Differences Only** and reference-material changes are supported in the comparison UI.

## Validation baseline

**Earlier recorded automated baseline: 33 tests passed, 0 failures** on macOS on 20 September 2026.

The user has subsequently confirmed that the complete current test suite passes and the project builds without errors. If the suite has grown beyond 33 tests, update the numeric baseline at the next formal validation checkpoint rather than assuming the older count is still current.

The automated suite includes the existing pipe/calculation tests, deterministic material resolver tests, portable material interchange tests and material comparison tests. Portable-file tests cover single and multiple-material round trips, preservation of equation kinds and temperature tables, malformed/empty/unsupported files, duplicate UUID handling, duplicate-name handling, built-in flag removal, and single-material document validation.

A manual end-to-end round trip has also been completed successfully through the native UI using `Relative Linear / TCR`: export to `.ecmaterial`, select through the native file picker, decode, merge, regenerate the duplicate UUID, rename the duplicate to `Relative Linear / TCR (Imported 2)`, and add it to My Materials.

The deterministic material tests use artificial values with simple analytical answers, including:

- Constant density: `8000 kg/m³`.
- Young's modulus table: `0 °C = 200 GPa`, `100 °C = 180 GPa`, `200 °C = 160 GPa`; therefore `50 °C = 190 GPa`.
- Polynomial thermal conductivity: `k(T) = 10 + 0.1T + 0.001T²`; therefore `k(100 °C) = 30 W/(m·K)`.
- TCR resistivity: `ρ(T) = 1.0×10⁻⁶ [1 + 0.004(T − 20)] Ω·m`; therefore `ρ(20 °C) = 1.0×10⁻⁶ Ω·m` and `ρ(120 °C) = 1.4×10⁻⁶ Ω·m`.

## Phase 1 — Portable material import/export — COMPLETE

`MaterialPortableCodec` and the Material Files UI provide:

- single-material JSON export;
- user-library, built-in-library and complete-library export;
- individual export of built-in and user materials;
- `.ecmaterial` and `.ecmaterials` registered file types;
- native macOS/iOS file importer/exporter support;
- format version `1` validation;
- rejection of malformed JSON, unknown formats, unsupported future versions, empty documents and invalid single-material documents;
- imported built-in flags are cleared so imported data cannot masquerade as protected built-in data;
- duplicate UUIDs receive a new UUID;
- duplicate names use an explicit ` (Imported N)` suffix;
- merge imports append to the existing user library rather than replacing it;
- scalar values, temperature tables, equations/coefficients, reference values/temperatures, validity ranges, extrapolation settings, traceability, identity metadata and notes survive portable-file round trips.

Built-in materials can deliberately be exported for independent checking. Exporting them does not modify the protected built-in library.

## Phase 2 — Material Comparison & Reporting — IN PROGRESS

### 2.1 Comparison engine — COMPLETE

The reusable comparison engine is independent of the SwiftUI presentation so the same comparison data can drive on-screen tables and future PDF/CSV/print/share outputs.

Implemented behaviour includes:

- compare two or more materials;
- first selected material initially becomes the reference;
- reference can subsequently be changed;
- built-in and user materials can be compared together;
- grouped identity/traceability, physical, thermal, mechanical, electrical and service-limit rows;
- explicit missing values;
- numeric absolute and percentage differences where meaningful;
- engineering-aware equality/tolerance rules;
- structural comparison of temperature-dependent property definitions.

### 2.2 Comparison selection/reference workflow — COMPLETE

- Multi-select remains open until the user presses **Compare (n)**.
- First selection is shown with a green **R** badge.
- Later selections are numbered `2`, `3`, `4…`.
- Removing a selection renumbers the remaining materials.
- New selections append to the end of the order.
- Selection order is retained in the comparison.
- Reference material can be changed from the comparison screen.
- **All properties** / **Differences Only** behaviour is available.

### 2.3 macOS comparison UI — COMPLETE / MANUALLY TESTED

The current Mac implementation has been manually tested and should be treated as the comparison-UI baseline:

- separate native resizable comparison window;
- full-screen capable;
- minimum usable window width;
- grid expands to fill available width when only a few materials are compared;
- user-resizable Property/material columns;
- frozen Property and Reference columns;
- opaque frozen cells so scrolling content does not show through;
- section headings remain aligned while scrolling;
- horizontal scrollbar appears only when the actual table width exceeds the viewport;
- scrollbar disappears when the table fits again;
- long/wrapped rows remain aligned.

See `DEVELOPMENT_STATUS.md` for implementation history and design lessons, including approaches that were tried and rejected.

### 2.4 PDF comparison reporting — NEXT

The immediate next development task is a report-ready comparison model followed by PDF generation.

The PDF/report implementation should:

- consume `MaterialComparison` directly rather than screenshotting the SwiftUI table;
- clearly identify the reference material;
- preserve material order;
- support All Properties and Differences Only;
- group engineering properties by section;
- include values, units, absolute/percentage differences, missing values and traceability;
- wrap long source/notes content;
- support multi-page output;
- provide deterministic, engineering-report-quality formatting;
- be covered by automated report-model tests before the final UI export action is added.

The detailed implementation sequence and acceptance criteria are in `DEVELOPMENT_STATUS.md`.

### 2.5–2.8 Planned comparison/reporting work

After PDF reporting:

1. Native print support reusing the report model/layout.
2. CSV / Excel-compatible comparison export.
3. Native share workflow for PDF/CSV files.
4. Enhanced temperature-dependent comparison: expanded equations/tables, selected-temperature evaluation and common plots.

## Phase 3 — Debug validation materials and manual UI verification

Expose deterministic validation fixtures to Debug builds only and manually verify constant values, table interpolation/range warnings, polynomial and TCR evaluation/graphs, invalid temperatures, material/property switching, synchronized units/method/traceability, and compact iPhone/macOS layouts.

## Phase 4 — Materials Library regression/UI pass

Verify All/Built-in/My Materials filtering, category organisation, drag/drop/copy behaviour, drop targets, create/edit/duplicate/move/delete, built-in protection, simplified/advanced views, multiline headings, macOS editor resizing/padding, and practical table/equation editing.

## Phase 5 — File format/versioning hardening

Freeze/document the first public material schema, define migrations, add compatibility fixture tests, and explicitly document units and temperature conventions. Consider adding portable-file provenance metadata so an independently reviewed export records that it originated from the built-in library without allowing a subsequent import to regain protected built-in status.

## Phase 6 — Populate verified engineering materials

Add traceable real engineering materials only after the framework/editor/interchange/reporting format is stable. Preserve source, standard/grade, product form, condition and applicability, and avoid implying excessive precision.

## Phase 7 — Continue modular calculator development

New calculators should consume the shared material/property resolver and include deterministic unit tests.

Before a calculator evaluates results, it must validate that every selected material provides the properties required by that calculation. Missing required data (for example density, specific heat capacity or thermal conductivity) must produce a clear, actionable user warning rather than silently substituting zero/default data or producing a misleading result. Calculators should declare their required and optional material properties so validation can be handled by a reusable central material-validation layer. Temperature-dependent properties must also be checked for resolvability at the requested operating condition, including validity range/extrapolation rules. See `DEVELOPMENT_STATUS.md` for the planned validation architecture and test cases.

## Current pipe calculation convention

Dry pipe mass/weight excludes internal contents and buoyancy.

Submerged weight is:

`(pipe mass + internal contents mass - displaced external-fluid mass) × g`

with `g = 9.80665 m/s²`.

## Development workflow

At the start of a development session:

```bash
git pull
git status
git branch --show-current
```

For the current work the branch should be `feature/material-property-framework`.

Run the regression suite with **⌘U** before and after substantial changes.

When a tested change is ready to commit manually:

```bash
git status
git add .
git commit -m "Description of changes"
git push
```

When resuming this project after a break, read **`AGENTS.md` first**, then **`DEVELOPMENT_STATUS.md`**, confirm the full regression suite is green, smoke-test the comparison screen, and continue with **Phase 2.4 — PDF comparison reporting**.
