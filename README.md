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
- Portable material interchange using human-readable `.ecmaterial` / `.ecmaterials` files.
- Native macOS/iOS Material Files interface for importing and exporting user, built-in, complete, and individual materials.
- Safe import merge: imported data cannot become protected built-in data, UUID collisions are regenerated, and duplicate names receive an ` (Imported N)` suffix rather than overwriting existing materials.
- Custom material UTTypes are registered for `.ecmaterial` and `.ecmaterials`.

## Validation baseline

**Current confirmed baseline: 33 tests passed, 0 failures** on macOS on 20 September 2026.

This comprises the existing pipe/calculation tests, the deterministic material resolver suite, and the portable material interchange tests. The portable-file suite covers single and multiple-material round trips, preservation of equation kinds and temperature tables, malformed/empty/unsupported files, duplicate UUID handling, duplicate-name handling, built-in flag removal, and single-material document validation.

A manual end-to-end round trip has also been completed successfully through the native UI using `Relative Linear / TCR`: export to `.ecmaterial`, select through the native file picker, decode, merge, regenerate the duplicate UUID, rename the duplicate to `Relative Linear / TCR (Imported 2)`, and add it to My Materials.

The deterministic material tests use artificial values with simple analytical answers, including:

- Constant density: `8000 kg/m³`.
- Young's modulus table: `0 °C = 200 GPa`, `100 °C = 180 GPa`, `200 °C = 160 GPa`; therefore `50 °C = 190 GPa`.
- Polynomial thermal conductivity: `k(T) = 10 + 0.1T + 0.001T²`; therefore `k(100 °C) = 30 W/(m·K)`.
- TCR resistivity: `ρ(T) = 1.0×10⁻⁶ [1 + 0.004(T − 20)] Ω·m`; therefore `ρ(20 °C) = 1.0×10⁻⁶ Ω·m` and `ρ(120 °C) = 1.4×10⁻⁶ Ω·m`.

## Phase 1 — Portable material import/export — COMPLETE

`MaterialPortableCodec` and the Material Files UI now provide:

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

## Phase 2 — Material Comparison & Reporting — NEXT

The next major feature is a reusable comparison engine and reporting model. It must be independent of the SwiftUI presentation so the same comparison data can later drive on-screen tables, PDF reports, CSV/Excel-compatible output, printing and sharing/email.

### 2.1 Comparison engine

- Compare two or more materials at once.
- The first selected material is the reference/baseline.
- Compare built-in and user/project-specific materials interchangeably.
- Group comparison rows into identity/traceability, physical, thermal, mechanical, electrical and service-limit sections.
- Represent missing properties explicitly rather than treating them as zero.
- For numeric scalar properties calculate absolute difference and percentage difference against the reference where meaningful.
- Use engineering-aware equality/tolerance rules rather than fragile formatted-string equality.
- Preserve raw values/units separately from display formatting so reports and calculations use the source data.

### 2.2 Temperature-dependent property comparison

For each temperature-dependent property compare both the resolved values and the underlying definition. Detect changes including:

- constant/scalar versus table versus equation;
- equation kind (polynomial, linear-reference, relative-linear/TCR);
- coefficients;
- reference value and reference temperature;
- tabulated temperature/value points;
- valid minimum/maximum temperature;
- extrapolation permission;
- source/basis/traceability.

Two materials may therefore have the same value at one temperature but still be reported as having different property models.

### 2.3 Comparison UI

- Multi-select two or more materials from the Materials Library.
- Clearly identify/reorder the reference material.
- Display properties as rows and materials as columns.
- Highlight changed values while keeping identical values visually quiet.
- Show absolute and percentage difference where applicable, e.g. `+273 kg/m³ (+3.48%)`.
- Provide **All properties** and **Differences only** modes.
- Remain usable on both macOS and iPhone; use horizontal scrolling or an adaptive presentation rather than shrinking engineering data excessively.

### 2.4 Report-ready output model

The comparison result must be structured independently of the view and contain enough information to generate formal engineering documentation. Planned report content:

- title/date and optional project/report metadata;
- material names, grade/designation, product form and condition;
- reference material clearly identified;
- grouped comparison table;
- absolute and percentage differences;
- source/basis/notes;
- indication of changed temperature-dependent models;
- optional expanded equation/table definitions;
- optional evaluated comparison table/plot at selected temperatures.

### 2.5 Export/share

After the comparison engine and UI are validated:

1. PDF report generation suitable for printing and inclusion in engineering reports.
2. CSV export for Excel and independent checking.
3. Native share sheet so generated reports can be saved to Files, AirDropped, emailed or passed to another application.
4. Printing support through the native platform workflow.

PDF/report generation should consume the comparison model rather than scrape or screenshot the SwiftUI table.

## Phase 3 — Debug validation materials and manual UI verification

Expose the deterministic validation fixtures to Debug builds only and manually verify constant values, table interpolation/range warnings, polynomial and TCR evaluation/graphs, invalid temperatures, material/property switching, synchronized units/method/traceability, and compact iPhone/macOS layouts.

## Phase 4 — Materials Library regression/UI pass

Verify All/Built-in/My Materials filtering, category organisation, drag/drop/copy behaviour, drop targets, create/edit/duplicate/move/delete, built-in protection, simplified/advanced views, multiline headings, macOS editor resizing/padding, and practical table/equation editing.

## Phase 5 — File format/versioning hardening

Freeze/document the first public material schema, define migrations, add compatibility fixture tests, and explicitly document units and temperature conventions. Consider adding portable-file provenance metadata so an independently reviewed export records that it originated from the built-in library without allowing a subsequent import to regain protected built-in status.

## Phase 6 — Populate verified engineering materials

Add traceable real engineering materials only after the framework/editor/interchange format is stable. Preserve source, standard/grade, product form, condition and applicability, and avoid implying excessive precision.

## Phase 7 — Continue modular calculator development

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

Run the regression suite with **⌘U** before and after substantial changes. The current expected baseline is **33 tests passed, 0 failures**.

When a tested change is ready to commit manually:

```bash
git status
git add .
git commit -m "Description of changes"
git push
```

When resuming this project, read this README, confirm the 33-test regression suite is green, and continue with **Phase 2.1 — Comparison engine**.
