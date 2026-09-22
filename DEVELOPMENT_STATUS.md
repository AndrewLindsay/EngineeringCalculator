# Engineering Calculator — Development Status & Roadmap

**Last updated:** 22 September 2026  
**Active branch:** `feature/material-requirement-validation`  
**Current focus:** reusable material requirements and material-aware calculators  
**Last verified automated checkpoint:** **66 tests passed, 0 failures**  
**Next validation target:** **75 tests passed, 0 failures**

Read `AGENTS.md` first, then this file when resuming development.

## Resume here

1. Switch to `feature/material-requirement-validation`.
2. Run `git pull`, `git status`, and `git branch --show-current`.
3. Build the macOS target and run the complete suite with **⌘U**.
4. The last user-verified baseline is **66/66 tests passing**.
5. Continue the multilayer pipe heat-transfer integration below.

Do not claim the heat-transfer work is verified until its files are in the Xcode targets and the expanded suite passes.

## Stable framework

The shared Materials Library supports built-in/user materials, categories, editing, scalar and temperature-dependent properties, traceability, local persistence, portable `.ecmaterial` / `.ecmaterials` interchange and material comparison.

`MaterialPropertyResolver` supports constant values, table values/interpolation and equations, including validity/range and extrapolation behaviour.

The reusable material requirement API provides required/optional properties, requirement sets, structured warnings/errors, temperature-aware checks, multi-material validation and `canCalculate` results. Initial standard sets cover mass/weight, steady-state conduction, transient thermal and linear-elastic calculations.

**Core rule:** calculators declare only the properties they actually need. Missing unrelated properties do not block a calculation; missing/unresolvable required properties do. New material-aware calculators should use a safe `validatedCalculate()` entry point.

## Validation materials

`TestData/EngineeringCalculator_Validation_Test_Materials.ecmaterials` contains ten synthetic test materials: complete, density-only 1000/3000 kg/m³, missing density, missing thermal conductivity, missing heat capacity, tabulated k over 0–100 °C, complete linear-elastic, missing Poisson's ratio and empty material.

These fixtures are synthetic and must not be used as engineering design data. Manual import of all ten has been verified.

## Pipe Weight & Buoyancy — VERIFIED

Density is required for every solid layer. Missing density is shown explicitly, identifies the failing material/layer and blocks numerical results. Materials missing unrelated properties remain valid if density exists. A safe `validatedCalculate()` API exists, while the raw calculation remains for legacy/numerical regression use.

Automated tests cover valid single/multilayer cases, missing primary/additional-layer density, multiple invalid layers, unrelated missing thermal properties, recovery after material replacement and deterministic two-layer mass/diameter calculations.

**Verified checkpoint: 66 tests passed, 0 failures.**

## Multilayer pipe heat transfer — WORK IN PROGRESS

`EngineeringCalculator/PipeHeatTransferCalculator.swift` implements steady-state radial conduction through concentric cylindrical layers:

`R_i = ln(r_o/r_i) / (2π k_i L)`

`Q = (T_inside - T_outside) / ΣR_i`

It returns total resistance, heat rate, heat rate per unit length, final OD and per-layer resistance/temperature-drop information.

The calculator uses `validatedCalculate()` from the outset. Thermal conductivity is required for every layer; density and heat capacity are not required. `MaterialPropertyResolver` supplies k and respects table/equation validity ranges.

### Initial temperature-dependent approximation

For the first implementation, all temperature-dependent k values are evaluated at:

`T_eval = (T_inside + T_outside) / 2`

This is deliberately a first-pass approximation. After the engine/UI is verified, replace it with iterative layer-interface temperatures and layer-specific mean-temperature property evaluation.

### Tests written, not yet verified

`EngineeringCalculatorTests/PipeHeatTransferCalculatorTests.swift` contains nine tests covering analytical single-layer resistance, two-layer resistance, missing k, property specificity, exact tabulated k, interpolation, out-of-range rejection, summed layer temperature drops and length scaling.

These files are committed but are not yet part of the verified Xcode test checkpoint. Therefore **66**, not 75, remains the formal baseline.

## Immediate to-do list

1. Add `PipeHeatTransferCalculator.swift` to the application target.
2. Add `PipeHeatTransferCalculatorTests.swift` to the test target/Sources phase.
3. Run **⌘U**. Target: **75/75**.
4. Fix any engine/test issues before adding UI complexity.
5. Build the SwiftUI Multilayer Pipe Heat Transfer calculator.
6. Select each layer material from the shared Materials Library.
7. Show resolved k, evaluation temperature/method and material validation errors.
8. Display layer geometry, resistance, temperature drop and interface temperatures.
9. Add the calculator to navigation/registry and test macOS/iPhone.
10. Refine temperature-dependent conduction to iterative layer-specific k evaluation with convergence diagnostics.
11. Add internal/external convection resistance and bulk/ambient fluid boundary conditions.
12. Add tests where temperature-dependent k materially changes the answer.
13. After heat transfer is stable, choose a transient thermal (`ρ`, `Cp`, `k`) or mechanical (`E`, `ν`) calculator for the next material-integration exercise.

The PDF/print/CSV material-comparison work remains on the roadmap but is not the immediate priority.

## Testing philosophy

Prefer deterministic synthetic materials with analytically simple answers. Every material-aware calculator should test required properties present/missing, unrelated missing properties, temperature requirements/ranges, multiple materials, recovery after replacement and at least one independent numerical regression case.

## Important UI/framework decisions to preserve

- Material comparison selection order is explicit and the first selection is initially the reference.
- macOS comparison uses one aligned row structure, not independent left/right vertical scroll views.
- Frozen Property/Reference cells are opaque; columns can fill available width and be resized.
- Imported materials cannot regain protected built-in status.
- Invalid materials may be selectable so validation can explain what is missing; invalid calculations must be blocked rather than silently corrected.

## Git workflow

```bash
git pull
git status
git branch --show-current
```

Expected branch: `feature/material-requirement-validation`.

For locally tested changes not already committed remotely:

```bash
git status
git add .
git commit -m "Description of changes"
git push
```

**Current formal checkpoint:** 66/66.  
**Next formal checkpoint:** 75/75 after heat-transfer target integration.
