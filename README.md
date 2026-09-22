# Engineering Calculator

A modular SwiftUI engineering-calculation app for iOS and macOS.

> **Development agents/contributors:** Read `AGENTS.md` first, then `DEVELOPMENT_STATUS.md`. When the user says **refresh**, read both before continuing development.

## Current development status — 22 September 2026

**Active branch:** `feature/material-requirement-validation`  
**Current focus:** calculator/material integration and validated engineering calculations.

### Verified checkpoint

The last formally verified checkpoint is **66 tests passed, 0 failures**.

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
- automated Pipe Weight material-validation regression tests.

### Work in progress — multilayer pipe heat transfer

`PipeHeatTransferCalculator.swift` and `PipeHeatTransferCalculatorTests.swift` have been added to the branch but are **not yet part of the verified checkpoint**.

The initial model implements steady-state radial conduction through concentric cylindrical layers:

`R_i = ln(r_o/r_i) / (2π k_i L)`

`Q = (T_inside - T_outside) / ΣR_i`

Design decisions for this calculator:

- it uses `validatedCalculate()` from the start;
- every solid layer declares thermal conductivity `k` as required;
- unrelated missing properties such as density do not block conduction calculations;
- temperature-dependent `k` is supported through `MaterialPropertyResolver`;
- the first implementation evaluates temperature-dependent `k` at the arithmetic mean of the specified inside/outside boundary temperatures;
- layer-specific iterative property evaluation is a planned refinement, not yet implemented.

Nine heat-transfer tests have been written for analytical single/two-layer resistance, missing `k`, property specificity, tabulated/interpolated `k`, out-of-range rejection, temperature drops and length scaling.

## Immediate to-do list

1. Add `PipeHeatTransferCalculator.swift` to the application target and `PipeHeatTransferCalculatorTests.swift` to the test target.
2. Run the complete suite. **Next target: 75/75 tests passing.**
3. Build the SwiftUI Heat Transfer calculator on top of the verified engine.
4. Manually test constant and temperature-dependent `k` using the validation-material library.
5. Add UI/integration regression coverage.
6. Refine temperature-dependent conduction to use layer-specific iterative mean temperatures.
7. Add inside/outside convection resistance and ambient/bulk-fluid boundary conditions.
8. Re-run macOS and iOS integration/regression tests.
9. Decide whether the next material-aware calculator should exercise transient thermal properties (`ρ`, `Cp`, `k`) or mechanical properties (`E`, `ν`).

The previously planned comparison PDF/print/CSV work remains on the roadmap, but calculator/material integration is the current priority.

## Material validation principle

Calculators must explicitly declare the material properties they require. Before results are evaluated, selected materials must be validated against those requirements. Missing or unresolvable required data must produce an actionable warning and block the result; it must not be silently replaced with zero or an arbitrary default.

New material-aware calculators should expose a safe `validatedCalculate()` entry point so callers cannot accidentally bypass validation.

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

Run the complete regression suite with **⌘U** before and after substantial changes.

When a tested local change needs committing manually:

```bash
git status
git add .
git commit -m "Description of changes"
git push
```

For the detailed checkpoint, architecture decisions, validation fixtures and roadmap, see `DEVELOPMENT_STATUS.md`.
