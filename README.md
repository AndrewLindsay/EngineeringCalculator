# Engineering Calculator

A modular SwiftUI engineering-calculation app for iOS and macOS.

## Current development status — 19 September 2026

Active development branch: `feature/material-property-framework`

The project is currently focused on the reusable Materials Library and temperature-dependent material-property framework before moving on to additional engineering calculators.

### Current working functionality

- Shared engineering material model used by calculators and the Materials Library.
- Built-in and user-created materials.
- Material categories and editable engineering properties.
- Simplified and advanced material-property editing.
- Temperature-dependent property representations:
  - constant/scalar values;
  - tabulated temperature/value data with linear interpolation;
  - polynomial equations;
  - linear-reference equations;
  - relative-linear / temperature coefficient of resistance (TCR) equations.
- Material Property Inspector for selecting a material/property, entering temperature, viewing the resolved value and method, graphing temperature-dependent behaviour, and reviewing equation/table/source information.
- User materials are automatically persisted locally as JSON in Application Support.
- Existing pipe weight/buoyancy calculation remains operational.

## Validation baseline

A deterministic material-property XCTest suite was added on 19 September 2026.

Current result on macOS: **21 tests passed, 0 failures**:

- 6 existing pipe/calculation tests.
- 15 MaterialPropertyResolver validation tests.

The material tests deliberately use artificial values with simple analytical answers rather than relying on real material reference data. They cover:

1. Constant property independent of temperature.
2. Exact tabulated temperature point.
3. Linear interpolation between table points.
4. Temperature below table range rejected.
5. Temperature above table range rejected.
6. Polynomial equation evaluation.
7. Polynomial minimum/maximum boundaries included.
8. Polynomial outside its allowed range rejected.
9. Relative-linear/TCR value at the reference temperature.
10. Relative-linear/TCR value away from the reference temperature.
11. Temperature-dependent equation requiring a temperature.
12. Missing property correctly reported as missing.
13. Available-property discovery matches actual material data.
14. Switching materials produces independent results with no state leakage.
15. Validation materials survive JSON encode/decode without loss.

### Known validation fixtures

The tests use deliberately simple definitions, including:

- Constant density: `8000 kg/m³`.
- Young's modulus table: `0 °C = 200 GPa`, `100 °C = 180 GPa`, `200 °C = 160 GPa`; therefore `50 °C = 190 GPa` by linear interpolation.
- Polynomial thermal conductivity: `k(T) = 10 + 0.1T + 0.001T²`; therefore `k(100 °C) = 30 W/(m·K)`.
- TCR resistivity: `ρ(T) = 1.0×10⁻⁶ [1 + 0.004(T − 20)] Ω·m`; therefore `ρ(20 °C) = 1.0×10⁻⁶ Ω·m` and `ρ(120 °C) = 1.4×10⁻⁶ Ω·m`.

### Running the regression tests

Before and after significant code changes:

1. Open `EngineeringCalculator.xcodeproj` in Xcode.
2. Select the EngineeringCalculator scheme and an appropriate Mac/iOS simulator destination.
3. Choose **Product → Test** or press **⌘U**.
4. Open the Xcode Test Navigator to review individual tests.
5. Do not merge a feature change while resolver/calculation tests are failing unless the expected behaviour has intentionally changed and the tests have been reviewed accordingly.

The 21-pass result is the current regression baseline.

## Next development phases

### Phase 1 — Portable material import/export

This is the next recommended implementation task.

The internal user library already saves to JSON, and the data structures are Codable. Add a user-facing portable file format on top of that foundation.

Required features:

- **Export Material…** for one selected user material.
- **Import Material…** for importing one or more materials.
- **Export User Library…** for all user-created materials.
- **Import User Library…** with merge behaviour rather than silently replacing the current library.
- Keep the underlying files human-readable JSON.
- Proposed custom extensions:
  - `.ecmaterial` for one material;
  - `.ecmaterials` for a material library.
- Preserve all material data, including:
  - scalar properties;
  - temperature tables;
  - equation type and coefficients;
  - reference values/reference temperatures;
  - validity ranges and extrapolation setting;
  - source and basis/traceability information;
  - category, grade, designation, product form and condition;
  - notes and other metadata.
- Validate document format and format version on import.
- Handle duplicate UUIDs and duplicate names explicitly; never silently overwrite an existing user material.
- Work on both macOS and iOS/iCloud Drive through the standard document picker/file exporter interfaces.

Add automated tests for:

- single-material export/import round trip;
- complete user-library round trip;
- multiple materials;
- all property representations surviving serialization;
- malformed/invalid JSON;
- unsupported future format version;
- duplicate UUID handling;
- duplicate name handling/merge policy.

### Phase 2 — Debug validation materials and manual UI verification

Expose the same deterministic validation fixtures to Debug builds only, without adding them to the production built-in library.

Use these fixtures to manually verify the Material Property Inspector and editor on both macOS and iPhone/iOS.

Check:

- constant property display;
- exact table point;
- interpolation;
- table range warnings;
- polynomial evaluation and graph;
- equation validity boundaries;
- TCR evaluation and graph;
- missing/invalid temperature handling;
- switching material/property updates all displayed data;
- graph, result, units, method and traceability remain synchronized;
- layouts remain usable in compact iPhone portrait mode and macOS windows.

### Phase 3 — Materials Library regression/UI pass

Once the calculation framework and import/export are stable, perform a focused pass over the Materials Library UI to ensure earlier functionality has not regressed.

Verify/restore as required:

- **All / Built-in / My Materials** filtering.
- Category organisation.
- Drag/drop between categories.
- Clear, adequately sized drop targets.
- No duplicate/disabled empty-category drop areas.
- Dragging a built-in material creates a user copy automatically.
- Dragging/copying a user material also creates a copy when appropriate.
- User materials can be created, edited, duplicated, moved and deleted.
- Built-in materials remain protected from destructive editing.
- Simplified property view remains concise while Advanced exposes the full property set.
- Multiline headings such as Maximum service temperature display correctly on Mac and iPhone.
- Material editor is appropriately resizable on macOS and has adequate left/right padding.
- Tabular temperature data and equation/coefficient data are practical to enter and edit.

### Phase 4 — File format/versioning hardening

Before a large real material database is populated:

- Freeze/document the first public material-file schema.
- Define migration behaviour for future schema versions.
- Add compatibility tests using stored fixture files from previous versions.
- Consider checksums or validation diagnostics if useful, but keep files readable and version-control friendly.
- Document units and temperature conventions explicitly in the schema/readme.

### Phase 5 — Populate verified engineering materials

Only after the framework, editor and file interchange are stable:

- Add real engineering materials from traceable sources.
- Record source, standard/grade, product form, condition and applicability.
- Distinguish nominal/reference values from temperature-dependent data.
- Avoid implying excessive precision in handbook/default values.
- Add source-specific regression checks for important materials where appropriate.

### Phase 6 — Continue modular calculator development

With the material system stable, return to additional engineering calculation modules. New calculators should consume the shared material/property resolver rather than implementing independent material lookup/interpolation logic.

Each new calculation module should include deterministic unit tests and should be added to the app-wide regression suite.

## Current pipe calculation convention

Dry pipe mass/weight excludes internal contents and buoyancy.

Submerged weight is:

`(pipe mass + internal contents mass - displaced external-fluid mass) × g`

with `g = 9.80665 m/s²`.

## Development workflow

At the start of a development session:

```bash
git pull
```

Confirm the current branch before editing:

```bash
git branch --show-current
```

For the current material-property work this should be:

```text
feature/material-property-framework
```

Run the regression suite with **⌘U** before and after substantial changes.

When a tested change is ready to commit manually:

```bash
git status
git add .
git commit -m "Description of changes"
git push
```

When resuming this project, read **Current development status**, confirm the regression suite is green, and continue with the first incomplete phase above.
