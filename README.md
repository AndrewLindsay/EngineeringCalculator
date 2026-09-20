# Engineering Calculator

A modular SwiftUI engineering-calculation app for iOS and macOS.

## Current development status — 20 September 2026

Active development branch: `feature/material-property-framework`

The project is currently focused on the reusable Materials Library and temperature-dependent material-property framework before moving on to additional engineering calculators.

### Current working functionality

- Shared engineering material model used by calculators and the Materials Library.
- Built-in and user-created materials.
- Material categories and editable engineering properties.
- Simplified and advanced material-property editing.
- Temperature-dependent property representations: constant/scalar, tabulated/interpolated, polynomial, linear-reference, and relative-linear/TCR.
- Material Property Inspector with resolved value/method, graph and traceability information.
- User materials persist locally as JSON in Application Support.
- Existing pipe weight/buoyancy calculation remains operational.
- **Portable material interchange backend added:** human-readable `.ecmaterial` / `.ecmaterials` document model, format/version validation, safe import merge, duplicate UUID regeneration and duplicate-name renaming.

## Validation baseline

The last confirmed local baseline before the portable-file changes was **21 tests passed, 0 failures** (6 pipe/calculation tests + 15 material resolver tests). Run **⌘U** after pulling the current branch; the portable-file backend change must be regression-tested locally before it is treated as the new green baseline.

The deterministic material tests use artificial values with simple analytical answers, including:

- Constant density: `8000 kg/m³`.
- Young's modulus table: `0 °C = 200 GPa`, `100 °C = 180 GPa`, `200 °C = 160 GPa`; therefore `50 °C = 190 GPa`.
- Polynomial thermal conductivity: `k(T) = 10 + 0.1T + 0.001T²`; therefore `k(100 °C) = 30 W/(m·K)`.
- TCR resistivity: `ρ(T) = 1.0×10⁻⁶ [1 + 0.004(T − 20)] Ω·m`; therefore `ρ(20 °C) = 1.0×10⁻⁶ Ω·m` and `ρ(120 °C) = 1.4×10⁻⁶ Ω·m`.

## Phase 1 — Portable material import/export

### Implemented backend (20 September 2026)

`MaterialPortableCodec` now provides the portable-file core:

- single-material JSON export;
- complete user-library JSON export;
- `.ecmaterial` and `.ecmaterials` format identifiers;
- format version `1` validation;
- rejection of malformed JSON, unknown formats, unsupported future versions, empty documents and invalid single-material documents;
- imported built-in flags are cleared so imported data cannot masquerade as protected built-in data;
- duplicate UUIDs receive a new UUID;
- duplicate names are retained safely using an explicit ` (Imported N)` suffix rather than overwriting existing data;
- merge imports append to the existing user library rather than replacing it;
- `MaterialLibraryStore` exposes export/import data methods and persists successful imports.

Because `EngineeringMaterial`, `MaterialPropertySeries` and `MaterialPropertyEquation` are Codable, the portable document preserves scalar values, temperature tables, equations and coefficients, reference values/temperatures, validity ranges, extrapolation settings, traceability, identity metadata and notes.

### Next immediate work

1. **Run the current project locally with ⌘U.** The previously confirmed baseline is 21/21; report any compiler/test failure before continuing.
2. Add dedicated portable-file XCTest cases for:
   - single material round trip;
   - complete/multiple-material library round trip;
   - all equation/property representations;
   - malformed JSON;
   - unsupported future version;
   - duplicate UUID regeneration;
   - duplicate name rename/merge behaviour.
3. Add the user-facing SwiftUI document picker/exporter controls to the Materials Library:
   - **Export Material…** for a selected user material;
   - **Import Material(s)…**;
   - **Export User Library…**;
   - standard macOS/iOS file picker / iCloud Drive support.
4. Run the complete test suite again on macOS and then manually exercise file export/import on iPhone.

Do not proceed to Phase 2 until these Phase 1 items are green.

## Phase 2 — Debug validation materials and manual UI verification

Expose the deterministic validation fixtures to Debug builds only and manually verify constant values, table interpolation/range warnings, polynomial and TCR evaluation/graphs, invalid temperatures, material/property switching, synchronized units/method/traceability, and compact iPhone/macOS layouts.

## Phase 3 — Materials Library regression/UI pass

Verify All/Built-in/My Materials filtering, category organisation, drag/drop/copy behaviour, drop targets, create/edit/duplicate/move/delete, built-in protection, simplified/advanced views, multiline headings, macOS editor resizing/padding, and practical table/equation editing.

## Phase 4 — File format/versioning hardening

Freeze/document the first public material schema, define migrations, add compatibility fixture tests, and explicitly document units and temperature conventions.

## Phase 5 — Populate verified engineering materials

Add traceable real engineering materials only after the framework/editor/interchange format is stable. Preserve source, standard/grade, product form, condition and applicability, and avoid implying excessive precision.

## Phase 6 — Continue modular calculator development

New calculators should consume the shared material/property resolver and include deterministic unit tests.

## Current pipe calculation convention

Dry pipe mass/weight excludes internal contents and buoyancy.

Submerged weight is:

`(pipe mass + internal contents mass - displaced external-fluid mass) × g`

with `g = 9.80665 m/s²`.

## Development workflow

At the start of a development session:

```bash
git pull
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

When resuming this project, read this README, confirm the regression suite is green, and continue with the first incomplete Phase 1 item above.
