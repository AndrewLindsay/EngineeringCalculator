# Engineering Calculator

A modular SwiftUI engineering-calculation app for iOS and macOS.

> **Development agents/contributors:** Read `AGENTS.md` first, then `DEVELOPMENT_STATUS.md`. When the user says **refresh**, read both before continuing development.

## Current development status — 22 September 2026

**Active branch:** `feature/material-requirement-validation`  
**Current focus:** calculator/material integration and validated engineering calculations.

### Verified checkpoint

The current formally verified checkpoint is **89 tests passed, 0 failures**.

Completed and verified:

- shared Engineering Materials Library with built-in and user materials;
- portable `.ecmaterial` / `.ecmaterials` import/export;
- temperature-dependent property resolver with constants, tables and equations;
- reusable material comparison framework and macOS comparison UI;
- central material-requirement/validation API;
- required vs optional material properties;
- temperature-aware property validation including validity/range handling;
- standard requirement sets for mass, steady-state conduction, transient thermal and linear-elastic calculations;
- portable synthetic validation library in `TestData/EngineeringCalculator_Validation_Test_Materials.ecmaterials`;
- Pipe Weight & Buoyancy integrated with density validation;
- invalid/missing density blocks results instead of silently becoming zero;
- automated Pipe Weight material-validation regression tests;
- Multilayer Pipe Heat Transfer integrated with the shared Materials Library and `validatedCalculate()`;
- adaptive subdivision of temperature-dependent layers with convergence diagnostics;
- physical-layer-aware thermal-conductivity range validation, so a limited-range material is accepted when its solved local layer temperatures are valid and blocked when they are not;
- total resistance, heat rate, heat rate per length, UA and overall U on inside/outside area bases;
- physical layer results including interface temperatures, effective/min/max conductivity, resistance and computational-cell count;
- report-oriented interface-temperature chart with proportional physical-layer shading, interface markers and legend;
- chart radial-build datum fixed at 0 mm on the internal pipe surface;
- regression coverage for radial-build geometry and interface-temperature continuity.

## Multilayer pipe heat transfer — VERIFIED

The model implements steady-state radial conduction through concentric cylindrical layers:

`R_i = ln(r_o/r_i) / (2π k_i L)`

`Q = (T_inside - T_outside) / ΣR_i`

Temperature-dependent conductivity is resolved adaptively. Thick or strongly temperature-dependent physical layers may be subdivided into computational cells until the conductivity/heat-rate solution converges. The UI continues to report physical engineering layers rather than exposing solver cells as separate coatings.

Material property validity is checked against the solved temperature range of each physical layer. This allows, for example, a material with data only over a cold range to be used as an outer layer when that layer actually remains within the supported range.

The temperature-profile chart uses radial build from the internal pipe surface as its horizontal coordinate. Physical layer widths therefore correspond directly to coating/pipe thicknesses, while the numerical layer table retains actual ID/OD values.

## Immediate to-do list

1. Treat **89/89 tests passing** as the current regression baseline.
2. Perform a final macOS/iPhone visual regression of the heat-transfer calculator, including one-layer and multi-layer cases, light/dark mode and narrow-screen legend/layout behaviour.
3. Decide whether `feature/material-requirement-validation` is ready to merge after the visual regression.
4. Add inside/outside convection resistance and bulk-fluid/ambient boundary conditions as the next heat-transfer enhancement if desired.
5. Consider an advanced temperature-profile view showing adaptive computational-cell temperatures while retaining physical layers as the normal/reporting view.
6. Add report/export support for calculation inputs, material traceability, validation status, numerical results and the temperature-profile chart.
7. Select the next material-aware calculation to exercise a different property set — transient thermal (`ρ`, `Cp`, `k`) or mechanical (`E`, `ν`) are the leading candidates.
8. Continue the previously planned material-comparison PDF/print/CSV work when calculator/material integration is sufficiently mature.

## Material validation principle

Calculators must explicitly declare the material properties they require. Before results are evaluated, selected materials must be validated against those requirements. Missing or unresolvable required data must produce an actionable warning and block the result; it must not be silently replaced with zero or an arbitrary default.

New material-aware calculators should expose a safe `validatedCalculate()` entry point so callers cannot accidentally bypass validation.

For temperature-dependent calculations, validity should be assessed against the temperatures actually experienced by each physical material where the solver can determine them, rather than rejecting a material solely because a global system temperature lies outside its range.

## Current pipe weight convention

Dry pipe mass/weight excludes internal contents and buoyancy.

Submerged weight is:

`(pipe mass + internal contents mass - displaced external-fluid mass) × g`

with `g = 9.80665 m/s²`.

## Development workflow

At the start of a session:

```bash
git pull
git status
git branch --show-current
```

The current branch should be:

```text
feature/material-requirement-validation
```

Run the complete regression suite with **⌘U** before and after substantial changes. The current expected result is **89 tests passed, 0 failures**.

When a tested local change needs committing manually:

```bash
git status
git add .
git commit -m "Description of changes"
git push
```

For the detailed checkpoint, architecture decisions, validation fixtures and roadmap, see `DEVELOPMENT_STATUS.md`.
