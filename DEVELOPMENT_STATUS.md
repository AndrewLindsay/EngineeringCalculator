# Engineering Calculator — Development Status & Roadmap

**Last updated:** 22 September 2026  
**Active branch:** `feature/portable-calculation-documents`  
**Current focus:** portable, self-contained saved calculations and calculation projects  
**Last verified automated checkpoint:** **89 tests passed, 0 failures**

Read `AGENTS.md` first, then this file when resuming development.

## Resume here

1. Switch to `feature/portable-calculation-documents`.
2. Run `git pull`, `git status`, and `git branch --show-current`.
3. Build the macOS target and run the complete suite with **⌘U**.
4. Expected baseline before persistence work: **89/89 tests passing**.
5. Implement portable calculation persistence in small independently testable commits. Do not add project UI before the persistence model, material embedding and reconciliation behaviour are covered by tests.

## Stable framework

The shared Materials Library supports built-in/user materials, categories, editing, scalar and temperature-dependent properties, traceability, local persistence, portable `.ecmaterial` / `.ecmaterials` interchange and material comparison.

`MaterialPropertyResolver` supports constant values, table values/interpolation and equations, including validity/range and extrapolation behaviour.

The reusable material requirement API provides required/optional properties, requirement sets, structured warnings/errors, temperature-aware checks, multi-material validation and `canCalculate` results. Standard sets cover mass/weight, steady-state conduction, transient thermal and linear-elastic calculations.

**Core rule:** calculators declare only the properties they actually need. Missing unrelated properties do not block a calculation; missing/unresolvable required properties do. New material-aware calculators should use a safe `validatedCalculate()` entry point.

For temperature-dependent calculations, use solved local physical-layer temperatures for range validation when available. Do not reject an otherwise valid material merely because a global system temperature lies outside its property range.

## Current automated checkpoint

**89 tests passed, 0 failures — user verified on 22 September 2026.**

This is the known-good baseline from commit `cde0448` (`Update development status to 89-test heat transfer checkpoint`) before portable calculation persistence development began.

## Portable Calculation Documents — ACTIVE PHASE

### Architectural objective

A saved standalone calculation or project must be wholly transportable and self-contained. It must be possible to move the document to a clean EngineeringCalculator installation and reproduce the saved engineering result without access to the originating material library.

The material library is a resource for creating and deliberately updating calculations. Embedded material definitions are part of the saved engineering record and are authoritative for reproducing the saved state.

### Phase 1 — persistence foundation

Implement and test:

- `CalculationDocument` / document container model;
- `SavedCalculation` with stable UUID;
- explicit document/schema versioning from the first format version;
- stable calculator type/schema identifier;
- stable identifiers for persisted inputs and outputs, so future calculation chaining does not depend on display labels;
- creation/modification metadata and optional notes;
- persistence of inputs, selected units, outputs, assumptions and validation information needed to reproduce/audit a calculation;
- stable persistence representations rather than serialising arbitrary runtime Swift calculator objects;
- encode/decode round-trip tests.

The persistence value model must not assume every future input is permanently a literal `Double`. It must leave room for future project-parameter references and calculation-output references without requiring the document architecture to be replaced.

### Phase 2 — self-contained embedded materials

Every document embeds the complete definition of every material needed by its calculations, including all available scalar and temperature-dependent properties, tables, equations/coefficients, units, validity/range information, references/provenance and relevant metadata.

Rules:

- preserve the material's persistent UUID across machines;
- do not save only the subset of properties currently used by the calculation;
- add a canonical content fingerprint/hash for comparison and integrity checks;
- a standalone calculation contains its required embedded materials;
- a project stores each embedded material once and calculations reference the project material by UUID;
- opening a calculation must not require the local material library to contain the material.

### Phase 3 — material reconciliation

When opening/importing a document, reconcile each embedded material with the local library by UUID and canonical content fingerprint:

1. UUID absent locally: import the embedded material as a new library material, retaining its UUID.
2. UUID present and content identical: reuse the existing local material and do not create a duplicate.
3. UUID present but content differs: record a material conflict. Do not silently overwrite the embedded material or the local library material.
4. A conflicting saved calculation initially continues to use its embedded definition so its historical result remains reproducible.
5. Provide later explicit compare/adopt/update actions; merely opening a document must not mutate an existing local material definition.

Imported documents must never regain protected built-in status merely because imported metadata claims it.

### Phase 4 — projects / calculation suites

Support both standalone calculations and projects. A project may contain multiple calculations and optional logical groups/folders plus project metadata such as name, project number, client, description, engineer, notes and creation/modification dates.

Project embedded materials are deduplicated. Multiple calculations using the same material UUID reference the same embedded project definition.

Future project-level shared parameters are anticipated. The first persistence format must therefore be extensible to support shared pressure, temperature, geometry, fluid/environment values etc. without replacing the saved-calculation model.

### Phase 5 — document UI

After the persistence and reconciliation layers are verified, add appropriate macOS/iOS document/library UI for operations such as New, Open, Save, Save As, Duplicate, Rename, Delete and Import/Export.

The same portable document format should be usable on macOS and iOS.

Candidate library organisation:

- Recent;
- Projects;
- Standalone Calculations.

### Phase 6 — robustness, compatibility and migration

Permanent regression coverage should include:

- save/encode/decode round trip;
- save, close and reopen result reproduction;
- transfer to a clean material library/install;
- import of a genuinely new material;
- existing identical material reuse without duplication;
- same UUID/different-content conflict detection;
- no silent local-library overwrite;
- multiple calculations sharing one embedded material;
- embedded material deduplication;
- complete scalar, table and equation/coefficient material preservation;
- temperature-dependent property preservation;
- unit preservation/conversion behaviour;
- missing/corrupt embedded material handling;
- corrupt calculation/document data handling;
- older schema migration;
- safe handling of unknown/newer schema versions;
- numerical result reproduction within defined tolerances.

A permanent portability regression requirement is:

> A calculation transferred to a clean EngineeringCalculator installation must reproduce the original engineering result without requiring access to the originating material library.

## Compatibility decisions — preserve unless deliberately superseded

The following decisions exist specifically to avoid future architectural backtracking. If one is deliberately changed, preserve the old decision in Git history and explain the reason in the changing commit.

### Future project parameters

Persisted calculation inputs must be extensible beyond literal values so they can later reference shared project parameters. Do not build the initial format around `[String: Double]` or another representation that would force a persistence redesign.

### Future calculation chaining

Calculations need stable UUIDs and persisted inputs/outputs need stable machine identifiers independent of display names. This permits a future calculation output to become another calculation's input without fragile string matching.

### Future formal calculation reports

Persistence must retain enough information to support auditable calculation reports later: inputs, units, assumptions, selected/embedded material provenance, validation messages, calculator/schema version and results. Report/export is a consumer of the persisted engineering record, not a separate source of truth.

### Material evolution and historical reproducibility

An embedded material is not merely a cache of the current library material. It is part of the saved engineering record. Library changes must not silently alter historical calculations.

### Cross-device portability

Do not introduce macOS-only persistence semantics. The document representation should remain portable between macOS and iOS even if the surrounding UI differs.

## Development sequence from the 89-test baseline

1. Persistence value/document model and schema versioning.
2. Stable calculation/input/output identifiers.
3. Encode/decode and round-trip tests.
4. Complete embedded material representation.
5. Canonical material fingerprinting.
6. Material reconciliation and conflict handling.
7. Clean-install portability/result-reproduction tests.
8. Standalone calculation save/open integration.
9. Project container and material deduplication.
10. Project/standalone document UI.
11. Shared project parameters and calculation chaining in later phases after the base persistence format is proven.
12. Resume calculator-library expansion after persistence is stable.

## Previously verified material-aware calculators

### Pipe Weight & Buoyancy

Density is required for every solid layer. Missing density is shown explicitly, identifies the failing material/layer and blocks numerical results. Materials missing unrelated properties remain valid if density exists. A safe `validatedCalculate()` API exists, while the raw calculation remains for legacy/numerical regression use.

### Multilayer Pipe Heat Transfer

Steady-state radial conduction through concentric cylindrical layers is implemented and verified, including adaptive treatment of temperature-dependent conductivity and location-aware property-range validation. The calculator uses `validatedCalculate()` and reports physical-layer results separately from internal computational cells.

The heat-transfer profile uses radial build measured from the internal pipe surface; physical layer widths are proportional to actual radial thickness, and chart bands represent physical material layers rather than adaptive computational cells.

Future heat-transfer enhancements such as inside/outside convection films remain valid roadmap items, but they are deferred until portable calculation persistence is established.

## Deferred roadmap — still compatible

These tasks remain valid and are not superseded by the persistence work:

- final macOS/iPhone heat-transfer visual regression and light/dark mode checks;
- inside/outside convection films and bulk-fluid/ambient temperatures;
- optional adaptive computational-cell chart detail;
- formal calculation report/export capability;
- further material-aware calculators, including transient thermal (`ρ`, `Cp`, `k`) and linear-elastic/mechanical (`E`, `ν`);
- material-comparison PDF/print/CSV work.

No current portable-document requirement contradicts these goals. Persistence is intentionally being implemented first so these later features can use a stable saved engineering record rather than introducing incompatible storage mechanisms.

## Testing philosophy

Prefer deterministic synthetic materials with analytically simple answers. Every material-aware calculator should test required properties present/missing, unrelated missing properties, temperature requirements/ranges, multiple materials, recovery after replacement and at least one independent numerical regression case.

Persistence tests should additionally verify identity, portability, reproducibility, conflict safety, schema compatibility and failure behaviour. Never silently repair or substitute engineering data merely to make a saved calculation load.

## Important UI/framework decisions to preserve

- Material comparison selection order is explicit and the first selection is initially the reference.
- macOS comparison uses one aligned row structure, not independent left/right vertical scroll views.
- Frozen Property/Reference cells are opaque; columns can fill available width and be resized.
- Imported materials cannot regain protected built-in status.
- Invalid materials may be selectable so validation can explain what is missing; invalid calculations must be blocked rather than silently corrected.
- Heat-transfer charts use the internal pipe surface as the zero radial-build datum; actual diameters belong in the numerical layer table.
- Heat-transfer chart bands represent physical material layers, not adaptive computational cells.

## Git/versioning policy

Git history is part of the engineering/development record. Preserve enough information to determine what changed, why it changed and what behaviour was expected at that checkpoint.

Use small meaningful commits for persistence work rather than one large final commit. Tests for deliberately changed behaviour should be added/updated in the same logical commit, with the reason documented.

Suggested commit progression:

1. `Add calculation persistence data model and schema versioning`
2. `Add self-contained embedded material definitions`
3. `Add material UUID and content fingerprint reconciliation`
4. `Add material conflict detection without library overwrite`
5. `Add calculation save/load round-trip tests`
6. `Add clean-install portable calculation tests`
7. `Add project calculation container and material deduplication`
8. `Add standalone calculation document UI`
9. `Add project document UI`

Before and after substantial changes run the complete suite with **⌘U**. The starting expected result on this branch is **89 tests passed, 0 failures**.

Normal workflow:

```bash
git pull
git status
git branch --show-current
# build/test in Xcode
git status
git add .
git commit -m "Description of changes"
git push
```

**Current formal checkpoint before persistence implementation: 89/89.**
