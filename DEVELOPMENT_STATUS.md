# Engineering Calculator — Development Status & Roadmap

**Last updated:** 22 September 2026  
**Active branch:** `feature/material-requirement-validation`  
**Current focus:** reusable material requirements and material-aware calculators  
**Last verified automated checkpoint:** **89 tests passed, 0 failures**

Read `AGENTS.md` first, then this file when resuming development.

## Resume here

1. Switch to `feature/material-requirement-validation`.
2. Run `git pull`, `git status`, and `git branch --show-current`.
3. Build the macOS target and run the complete suite with **⌘U**.
4. Expected baseline: **89/89 tests passing**.
5. The multilayer pipe heat-transfer/material-validation phase is now functionally verified. Perform final macOS/iPhone visual regression, then decide whether to merge this branch or continue with the next enhancement.

## Stable framework

The shared Materials Library supports built-in/user materials, categories, editing, scalar and temperature-dependent properties, traceability, local persistence, portable `.ecmaterial` / `.ecmaterials` interchange and material comparison.

`MaterialPropertyResolver` supports constant values, table values/interpolation and equations, including validity/range and extrapolation behaviour.

The reusable material requirement API provides required/optional properties, requirement sets, structured warnings/errors, temperature-aware checks, multi-material validation and `canCalculate` results. Standard sets cover mass/weight, steady-state conduction, transient thermal and linear-elastic calculations.

**Core rule:** calculators declare only the properties they actually need. Missing unrelated properties do not block a calculation; missing/unresolvable required properties do. New material-aware calculators should use a safe `validatedCalculate()` entry point.

For temperature-dependent calculations, use solved local physical-layer temperatures for range validation when available. Do not reject an otherwise valid material merely because a global system temperature lies outside its property range.

## Validation materials

`TestData/EngineeringCalculator_Validation_Test_Materials.ecmaterials` provides deterministic synthetic materials for material-validation and calculation testing. The set includes complete and deliberately incomplete materials plus temperature-dependent conductivity cases used to exercise missing-property and range-validation behaviour.

These fixtures are synthetic and must not be used as engineering design data.

## Pipe Weight & Buoyancy — VERIFIED

Density is required for every solid layer. Missing density is shown explicitly, identifies the failing material/layer and blocks numerical results. Materials missing unrelated properties remain valid if density exists. A safe `validatedCalculate()` API exists, while the raw calculation remains for legacy/numerical regression use.

Automated tests cover valid single/multilayer cases, missing primary/additional-layer density, multiple invalid layers, unrelated missing thermal properties, recovery after material replacement and deterministic two-layer mass/diameter calculations.

## Multilayer Pipe Heat Transfer — VERIFIED

`EngineeringCalculator/PipeHeatTransferCalculator.swift` implements steady-state radial conduction through concentric cylindrical layers:

`R_i = ln(r_o/r_i) / (2π k_i L)`

`Q = (T_inside - T_outside) / ΣR_i`

The calculator uses `validatedCalculate()` from the outset. Thermal conductivity is required for every solid layer; unrelated missing density or heat capacity does not block steady-state conduction.

### Adaptive temperature-dependent conductivity

The initial global-mean-temperature approximation has been replaced by an adaptive solution. Temperature-dependent physical layers can be subdivided into computational cells, with conductivity resolved at local temperatures and refinement continued until the heat-rate/conductivity solution converges.

The result retains the distinction between:

- **physical engineering layers** — pipe wall, coating, insulation etc.; and
- **computational cells** — internal numerical subdivisions used only where refinement is required.

Constant-k thick layers do not require unnecessary subdivision.

### Location-aware property-range validation

Thermal-conductivity range checking is based on the temperatures actually encountered in each solved physical layer. This supports physically valid arrangements where a limited-temperature-range material is used only in a sufficiently cold or hot part of the wall system.

Regression coverage includes paired cases where the same limited-range material succeeds as a cold outer layer but fails when moved to the hot inner side.

Out-of-range properties are blocked rather than silently extrapolated when extrapolation is not permitted.

### Heat-transfer outputs

The calculator/UI reports:

- final outside diameter;
- total conduction resistance;
- overall conductance `UA`;
- overall heat-transfer coefficient on inside-area and outside-area bases;
- heat rate and heat rate per unit length;
- heat-flow direction;
- per-physical-layer ID/OD, interface temperatures, effective conductivity, minimum/maximum resolved conductivity, resistance and computational-cell count;
- adaptive solver/convergence information.

### Temperature-profile chart

The report-oriented Swift Charts profile displays:

- radial build measured from **0 mm at the internal pipe surface**;
- physical layer widths proportional to actual radial thickness;
- shaded material bands with legend;
- dashed physical-layer interface markers;
- solved interface temperatures and automatic endpoint/collision-aware label positioning.

Actual physical ID/OD values remain available in the numerical results table.

Regression tests protect the radial-build datum, cumulative physical-layer geometry and temperature continuity so the graph cannot silently revert to centreline/diameter coordinates.

## Current automated checkpoint

**89 tests passed, 0 failures — user verified on 22 September 2026.**

This supersedes the earlier 66/75/79/81/83/85-test development checkpoints.

## Immediate to-do list

1. Perform final macOS visual regression of the heat-transfer UI with single- and multi-layer cases.
2. Perform iPhone visual regression, especially chart legend/labels and horizontally dense layer results.
3. Check light and dark mode presentation.
4. If visual regression is clean, decide whether to merge `feature/material-requirement-validation` into the main development branch.
5. Candidate next heat-transfer enhancement: inside/outside convection films and bulk-fluid/ambient temperatures.
6. Candidate advanced chart enhancement: optionally display adaptive computational-cell temperature detail without changing the normal physical-layer reporting view.
7. Add calculation report/export capability including inputs, selected material traceability, validation messages, numerical results and chart output.
8. Choose the next material-aware calculator to exercise another requirement set. Leading candidates are transient thermal (`ρ`, `Cp`, `k`) and linear-elastic/mechanical (`E`, `ν`).
9. Return to material-comparison PDF/print/CSV work when appropriate.

## Testing philosophy

Prefer deterministic synthetic materials with analytically simple answers. Every material-aware calculator should test required properties present/missing, unrelated missing properties, temperature requirements/ranges, multiple materials, recovery after replacement and at least one independent numerical regression case.

For adaptive numerical calculations, also test convergence metadata, physical-layer continuity, constant-property limiting cases, property-range boundaries and presentation-data transformations that encode engineering meaning.

## Important UI/framework decisions to preserve

- Material comparison selection order is explicit and the first selection is initially the reference.
- macOS comparison uses one aligned row structure, not independent left/right vertical scroll views.
- Frozen Property/Reference cells are opaque; columns can fill available width and be resized.
- Imported materials cannot regain protected built-in status.
- Invalid materials may be selectable so validation can explain what is missing; invalid calculations must be blocked rather than silently corrected.
- Heat-transfer charts use the internal pipe surface as the zero radial-build datum; actual diameters belong in the numerical layer table.
- Heat-transfer chart bands represent physical material layers, not adaptive computational cells.

## Git workflow

```bash
git pull
git status
git branch --show-current
```

Expected branch while this phase remains open: `feature/material-requirement-validation`.

Run the full test suite with **⌘U** before and after substantial changes. Current expected result: **89 tests passed, 0 failures**.

For locally tested changes not already committed remotely:

```bash
git status
git add .
git commit -m "Description of changes"
git push
```

**Current formal checkpoint: 89/89.**
