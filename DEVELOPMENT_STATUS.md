# Engineering Calculator — Development Status & Roadmap

**Last updated:** 20 September 2026  
**Active branch:** `feature/material-property-framework`  
**Current focus:** Materials Library / material-property framework  
**Immediate next task:** Phase 2.4 — PDF material-comparison reporting

This document is the detailed project handover/checkpoint. It is intended to make it possible to stop work on Engineering Calculator, work on another project, and later resume without reconstructing the development state from chat history.

The root `README.md` remains the concise project overview. This file should be updated whenever a development phase is completed, a major design decision changes, or work stops at a useful checkpoint.

---

## 1. Resume here

When returning to the project:

1. Open the repository and switch to `feature/material-property-framework`.
2. Run:

```bash
git pull
git status
git branch --show-current
```

3. Confirm the working tree is clean.
4. Build the macOS target.
5. Run the complete regression suite with **⌘U**.
6. Smoke-test the Materials Library and Material Comparison screens.
7. Continue with **Phase 2.4 — PDF material-comparison reporting** below.

At the latest checkpoint the user reported that the complete current test suite passed and the project built without errors. The earlier documented automated-test baseline was **33 tests passed, 0 failures**; if the suite has since grown, treat the current Xcode test navigator as authoritative and update this document with the new count at the next formal validation checkpoint.

---

## 2. Current architecture and important design decisions

### 2.1 Shared material framework

Engineering materials are shared resources intended to be consumed by multiple calculators rather than embedded independently in each calculator.

The framework supports:

- protected built-in materials;
- editable user materials;
- material categories and identity/traceability metadata;
- simplified and advanced property editing;
- scalar/constant properties;
- tabulated temperature-dependent properties;
- polynomial equations;
- linear-reference equations;
- relative-linear/TCR equations;
- source/basis/notes information;
- resolved property values through the common material-property resolver.

### 2.2 User material persistence

User materials persist locally as JSON in Application Support.

Portable interchange is separate from the internal persistence mechanism and uses `.ecmaterial` / `.ecmaterials` files.

### 2.3 Portable material-file safety rules

Imports must not overwrite or impersonate protected built-in materials.

Current rules:

- imported built-in flags are removed;
- duplicate UUIDs are regenerated;
- duplicate names are renamed with ` (Imported N)`;
- imports merge into the user library;
- malformed, empty, unknown-format and unsupported-version documents are rejected;
- scalar values, tables, equations, validity ranges, extrapolation settings and traceability survive round trips.

### 2.4 Comparison architecture

The comparison calculation is intentionally independent of the presentation layer. `MaterialComparisonEngine` produces comparison data that can be reused by the on-screen table and future PDF/CSV/print/share outputs.

Important comparison rules:

- two or more materials may be selected;
- selection order is preserved;
- the first selected material initially becomes the reference;
- the reference can subsequently be changed;
- changing reference reorders the comparison so the reference is the first comparison material;
- missing values are explicit rather than zero;
- numeric differences include absolute and percentage differences where meaningful;
- engineering-aware numeric tolerances are used;
- property-series definitions are compared structurally, not only by formatted text.

---

## 3. Completed development history

### Phase 0 — Initial modular calculator foundation — COMPLETE

Established the SwiftUI Engineering Calculator project for macOS and iOS, including the existing pipe weight/buoyancy calculator and shared unit/material infrastructure.

Current pipe convention:

`submerged weight = (pipe mass + internal contents mass - displaced external-fluid mass) × g`

with `g = 9.80665 m/s²`.

Dry pipe mass/weight excludes internal contents and buoyancy.

### Phase 1 — Materials Library framework — COMPLETE / STABLE BASELINE

Implemented the reusable Materials Library, including:

- built-in and user materials;
- All / Built-in / My Materials organisation;
- material creation/editing/duplication/movement/deletion rules;
- built-in protection;
- drag/drop and copy behaviour;
- simplified and advanced material-property views;
- additional mechanical/electrical/thermal/service-limit properties;
- multiline heading/layout fixes;
- macOS and iOS presentation work;
- material selection from calculator workflows.

### Phase 1A — Temperature-dependent property framework — COMPLETE

Implemented and tested:

- scalar/constant properties;
- tabulated interpolation;
- polynomial equations;
- linear-reference equations;
- relative-linear/TCR equations;
- reference values and temperatures;
- valid temperature ranges;
- extrapolation rules;
- traceability fields;
- Material Property Inspector;
- resolved value/method display;
- graphing/inspection support.

Deterministic validation fixtures include simple analytical cases such as:

- density `8000 kg/m³`;
- Young's modulus table `0 °C = 200 GPa`, `100 °C = 180 GPa`, `200 °C = 160 GPa`, giving `50 °C = 190 GPa`;
- polynomial thermal conductivity `k(T) = 10 + 0.1T + 0.001T²`, giving `k(100 °C) = 30 W/(m·K)`;
- TCR resistivity `ρ(T) = 1.0×10⁻⁶ [1 + 0.004(T − 20)] Ω·m`, giving `ρ(20 °C) = 1.0×10⁻⁶ Ω·m` and `ρ(120 °C) = 1.4×10⁻⁶ Ω·m`.

### Phase 1B — Portable material import/export — COMPLETE

Implemented `MaterialPortableCodec`, Material Files UI and native file import/export.

Completed capabilities:

- single-material export;
- user-library export;
- built-in-library export for independent review;
- complete-library export;
- individual built-in/user material export;
- `.ecmaterial` and `.ecmaterials` UTTypes;
- native macOS/iOS importer/exporter;
- format version 1 validation;
- safe merge rules described above.

Manual end-to-end round-trip validation was successfully completed using the `Relative Linear / TCR` test material.

### Phase 2.1 — Material comparison engine — COMPLETE

Implemented reusable comparison structures and `MaterialComparisonEngine`.

Comparison sections currently include:

- Identity & Traceability;
- Physical;
- Thermal;
- Mechanical;
- Electrical;
- Service Limits.

Comparison rows include scalar properties and property-model rows. Numeric values can show delta and percentage difference against the reference.

### Phase 2.2 — Multi-material selection/reference workflow — COMPLETE

The original comparison selector automatically continued after the second material even though the requirement was “two or more”. This was corrected.

Current behaviour:

- any number of materials ≥ 2 may be selected before continuing;
- comparison starts only when **Compare (n)** is pressed;
- the first selection displays a green **R** reference badge;
- subsequent selections display **2, 3, 4…**;
- deleting a selection renumbers the remaining selections;
- adding another material appends it to the end of the selection order;
- comparison columns preserve selection order;
- the reference may be changed from the comparison screen;
- **Differences Only** is available.

### Phase 2.3 — macOS comparison table — COMPLETE AND MANUALLY TESTED

The Mac comparison UI went through several iterations. The final implementation should be preserved unless a later requirement justifies redesign.

Current tested behaviour:

- comparison opens in a separate native macOS window;
- window is resizable and supports full screen;
- minimum window width prevents shrinking to an unusable layout;
- grid expands to use the available window width when only a few materials are present;
- Property and Reference columns remain frozen on the left during horizontal scrolling;
- additional material columns scroll horizontally when required;
- horizontal scrollbar is absent when the table fits the viewport;
- horizontal scrollbar appears when manually widened columns or additional materials exceed the viewport;
- column widths can be adjusted by the user;
- automatic columns grow to use available width before horizontal scrolling is required;
- opaque frozen-cell backgrounds prevent scrolling text from showing through;
- changed cells use comparison highlighting across the full cell area;
- section headings remain aligned during horizontal scrolling;
- vertically wrapped rows remain aligned because the comparison is presented as one unified row structure;
- reference selection and Differences Only continue to work.

Latest manually verified state: the user confirmed that manually widening columns causes horizontal scrolling to appear as expected, and that the scrollbar behaviour is correct when the table fits.

Relevant implementation files:

- `EngineeringCalculator/MaterialComparison.swift`
- `EngineeringCalculator/MacMaterialComparisonGrid.swift`
- `EngineeringCalculator/MaterialLibraryView.swift` (entry/presentation integration)

Do not revert to the earlier design with independent left/right vertical scroll views; that implementation caused unsynchronised scrolling, divergent row heights and wasted blank space when resizing.

---

## 4. Current checkpoint

**The comparison engine, multi-selection/reference workflow, and current macOS comparison grid are considered complete.**

The project is ready to move from interactive comparison UI into reusable report/export output.

No known local changes existed at the checkpoint; `git status` reported:

```text
On branch feature/material-property-framework
Your branch is up to date with 'origin/feature/material-property-framework'.

nothing to commit, working tree clean
```

---

## 5. Immediate next development — Phase 2.4 PDF comparison report

### Objective

Generate a formal engineering-style PDF from `MaterialComparison` data. The report must consume the comparison model directly; it must **not** screenshot or scrape the SwiftUI comparison table.

### Recommended implementation sequence

#### 2.4.1 Define a report model/options object

Create a platform-independent set of report options, for example:

- report title;
- project name/number (optional);
- prepared-by field (optional);
- report date;
- reference material;
- selected materials/order;
- All Properties vs Differences Only;
- include/exclude identity metadata;
- include/exclude source/basis/notes;
- include expanded temperature-property definitions;
- future option for evaluated-temperature tables/plots.

Do not couple these options to PDF drawing APIs.

#### 2.4.2 Create reusable report rows/sections

Transform `MaterialComparison` into report-ready sections. Preserve raw values and units as long as possible and format only at the rendering boundary.

The report should clearly identify:

- reference material;
- material names;
- grade/designation;
- product form/condition where present;
- grouped properties;
- missing values;
- changed values;
- absolute differences;
- percentage differences;
- source/basis/notes.

#### 2.4.3 PDF renderer

Implement PDF generation using native Apple PDF/printing facilities appropriate to the existing deployment targets.

Requirements:

- multi-page output;
- repeating table headings where practical;
- readable engineering typography;
- sensible page margins;
- no clipped rows;
- wrapped long Source/Notes content;
- clear reference-column identification;
- page number/footer;
- date/report metadata;
- deterministic formatting suitable for independent checking.

A landscape page orientation will probably be preferable for multi-material comparison tables, but the renderer should be designed so page/layout choices are explicit rather than hard-coded into comparison logic.

#### 2.4.4 PDF UI integration

Add an **Export PDF** action to the comparison window after renderer tests pass.

The first UI should be simple. Avoid building a complex report designer before the underlying report model and PDF output are validated.

#### 2.4.5 PDF tests

Add automated tests for the report model before relying on visual PDF inspection.

At minimum verify:

- reference material/order is preserved;
- Differences Only filters correctly;
- missing values remain explicit;
- numeric delta/percentage values survive report transformation;
- long text is retained;
- temperature-dependent model descriptions are retained;
- empty optional metadata does not create invalid rows;
- output generation succeeds for 2, 3 and several materials.

Then manually inspect representative PDFs on macOS.

### Acceptance criteria for Phase 2.4

Phase 2.4 is complete when:

- a user can compare materials and export a readable multi-page PDF;
- PDF data matches the on-screen comparison/reference selection;
- Differences Only is respected;
- long rows wrap rather than clip;
- report is usable in an engineering document without screenshots;
- automated report-model tests pass;
- existing regression tests remain green.

---

## 6. Development path after PDF reporting

### Phase 2.5 — Print support

Reuse the report/PDF layout model for native printing. Do not create an unrelated second report format.

### Phase 2.6 — CSV / Excel-compatible comparison export

Export machine-readable comparison data including:

- property section;
- property name;
- units;
- reference value;
- compared values;
- absolute difference;
- percentage difference;
- model/type information where relevant;
- source/basis/notes as appropriate.

CSV should be designed for independent engineering checking, not merely mimic the visual table.

### Phase 2.7 — Native share workflow

Use native macOS/iOS sharing for generated PDF/CSV files so users can save, AirDrop, email or pass reports to other applications. Avoid implementing a custom email subsystem.

### Phase 2.8 — Enhanced temperature-dependent comparison

The current table can identify that property definitions differ, but richer comparison remains desirable.

Planned work:

- expand table/equation definitions;
- show coefficients and validity ranges clearly;
- evaluate multiple materials at user-selected temperatures;
- compare resolved values at those temperatures;
- overlay material-property curves on a common graph;
- identify extrapolated/out-of-range values;
- include optional evaluated tables/plots in reports.

---

## 7. Later framework phases

### Phase 3 — Debug validation materials and manual UI verification

Expose deterministic fixtures in Debug builds only and verify:

- constants;
- interpolation;
- range/extrapolation warnings;
- polynomial evaluation;
- TCR evaluation;
- graphs;
- invalid temperatures;
- material/property switching;
- units/method/traceability synchronisation;
- compact iPhone/macOS layouts.

### Phase 4 — Materials Library regression/UI pass

Perform a deliberate end-to-end regression of:

- All/Built-in/My Materials filters;
- category organisation;
- drag/drop;
- copy behaviour;
- drop targets;
- create/edit/duplicate/move/delete;
- built-in protection;
- simplified/advanced views;
- multiline headings;
- macOS editor resizing/padding;
- practical table/equation editing;
- material selection from calculators.

### Phase 5 — File-format/versioning hardening

Before treating the material format as a stable public interchange format:

- freeze/document schema version 1;
- document all units and temperature conventions;
- define migration strategy;
- add compatibility fixtures;
- test old fixtures against future versions;
- consider provenance metadata for exported built-in materials without allowing imports to regain built-in protection.

### Phase 6 — Populate verified engineering materials

Only after the framework/editor/interchange/reporting layers are stable:

- add real engineering materials from traceable sources;
- record standard/grade;
- record product form and condition;
- record temperature/applicability limits;
- preserve source/basis;
- avoid false precision;
- independently verify important values.

### Phase 7 — Continue modular engineering calculators

Resume expansion of the Engineering Calculator itself. New calculators should use the shared material/property resolver rather than duplicate material constants.

Each new calculator should include deterministic unit tests and clearly documented engineering assumptions.

---

## 8. Testing strategy

### Automated regression

Run **⌘U** before and after substantial framework changes.

The earlier recorded baseline was 33 passing tests. The latest user validation reported all current tests passing. Update the numeric baseline when the next test-suite expansion is committed and verified.

### Manual macOS comparison smoke test

Before modifying comparison/report code, useful quick checks are:

1. Select four materials in non-alphabetical order.
2. Confirm badges show `R`, `2`, `3`, `4`.
3. Remove selection 2 and confirm renumbering.
4. Add another material and confirm it appends.
5. Compare and confirm column order.
6. Change the reference and confirm recalculation/reordering.
7. Toggle Differences Only.
8. Resize the Mac comparison window.
9. Confirm Property + Reference remain frozen while horizontally scrolling.
10. Widen a material column until horizontal scrolling becomes necessary.
11. Confirm the scrollbar disappears when the table again fits the viewport.
12. Check long Source/Notes rows for wrapping, alignment and opaque backgrounds.

### Test-data philosophy

Prefer deterministic artificial materials with simple analytical expected values for automated tests. Real material data is useful for presentation/integration testing but should not replace deterministic unit fixtures.

---

## 9. Git/development workflow

Start a session:

```bash
git pull
git status
git branch --show-current
```

Expected active branch for the current framework work:

```text
feature/material-property-framework
```

Before committing:

```bash
git status
git add .
git commit -m "Description of changes"
git push
```

After a GitHub-side change made through ChatGPT, normally use:

```bash
git pull
```

Then build/test locally before considering the change complete.

Keep commits focused. Do not combine unrelated calculator work with material-framework/reporting changes if it can reasonably be avoided.

---

## 10. Known design lessons from the comparison UI work

These are recorded to avoid repeating unsuccessful approaches:

1. A fixed-size sheet is unsuitable for a multi-material desktop comparison. Use a native resizable Mac window for the comparison result.
2. Independent vertical scroll views for frozen and scrolling columns do not work well: row wrapping causes misalignment and scrolling becomes unsynchronised.
3. A single unified row/table structure is preferable for vertical alignment.
4. Frozen Property/Reference cells must have opaque backgrounds or horizontally scrolling content shows through.
5. Fixed material widths waste space when only a few materials are compared. Automatic widths should fill the viewport until minimum widths/explicit user resizing require scrolling.
6. Horizontal scrolling should be conditional on actual table width; constructing an always-horizontal ScrollView can create a scrollbar even when the visible table fits.
7. macOS deployment compatibility matters: avoid relying on newer SwiftUI scroll-geometry APIs unless the project's deployment target is deliberately raised.
8. Do not raise the deployment target solely to implement frozen-column scrolling when an AppKit-compatible solution can support the existing target.

---

## 11. Definition of the next coding session

Unless priorities change, the next coding session should begin with:

**Task:** Design and implement the report-ready comparison model and first PDF renderer tests.

Suggested first commit scope:

- add report options/model types;
- transform `MaterialComparison` into report sections/rows;
- add deterministic tests for report transformation;
- do **not** add the final PDF UI button until the report model is tested.

Once those tests are green, proceed to the actual PDF renderer and a representative exported report.
