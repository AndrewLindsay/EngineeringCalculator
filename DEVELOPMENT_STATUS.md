# Engineering Calculator — Development Status & Roadmap

**Last updated:** 22 September 2026  
**Status:** **HOLD POINT — intentional development pause**  
**Active branch:** `feature/portable-calculation-documents`  
**Current focus:** portable, self-contained saved calculations and calculation projects  
**Last user-verified automated checkpoint:** **168 tests passed, 0 failures**

Read `AGENTS.md` first, then this file when resuming development.

# RESUME HERE

This is the authoritative restart point.

1. Switch to / confirm `feature/portable-calculation-documents`.
2. Run `git pull`, `git status`, and `git branch --show-current`.
3. Build the macOS target and run the complete suite with **⌘U**.
4. Expected regression baseline: **168/168 tests passing**.
5. Resume with the **project workspace `.ecproject` end-to-end save/open/reopen workflow** described below.
6. Do not restart from the earlier 89-test material-framework checkpoint or repeat already completed standalone-document work.

## Hold-point summary

The portable-document architecture has progressed from the original persistence foundation through standalone calculation integration and into project workspace support.

User-verified at this hold point:

- **168 tests passed, 0 failures**;
- standalone Pipe Weight & Buoyancy `.eccalc` save/export and open work;
- multi-layer Pipe Weight & Buoyancy cases survive standalone save/open, including the previously observed two-material-layer restoration defect;
- portable deterministic regression cases exist so the same inputs can be reused reliably for comparisons between builds;
- project workspace code is present and builds/tests after adding the missing `.engineeringProject` UTType;
- `.ecproject` is the project-document extension and `com.andrewlindsay.engineeringcalculator.project` is the project UTType identifier.

The last code change immediately before this hold point added the missing project UTType used by `ProjectWorkspaceView`. After that change the user ran the complete test suite and reported **168 tests passed**.

## Exact next development task — project workspace end-to-end validation

Start here when development resumes.

Exercise the project workflow as a real user and then add/fix regression coverage as required:

1. Create a new project.
2. Add multiple saved calculations to it, preferably including both Pipe Weight & Buoyancy and Pipe Heat Transfer where supported by the current project UI/adapters.
3. Use multiple materials, including at least one material shared by more than one calculation, so project material deduplication is exercised.
4. Save/export the project as `.ecproject`.
5. Close the project/workspace or otherwise return to a clean state.
6. Reopen/import the saved `.ecproject`.
7. Confirm all calculations are present and remain individually identifiable.
8. Confirm persisted inputs, units, outputs and calculation IDs survive the round trip.
9. Confirm all material selections/references survive the round trip.
10. Confirm each embedded project material is stored once and shared calculations reference it by UUID rather than creating unnecessary duplicate definitions.
11. Confirm the reopened calculations reproduce the saved engineering results within the defined regression tolerances.
12. Confirm opening the project does not silently overwrite conflicting local-library material definitions.
13. Add deterministic automated tests for any project-workspace behaviour not already covered.
14. Re-run the full suite and establish the next formal checkpoint before moving on.

Do not treat the project UI phase as complete until the above end-to-end workflow is demonstrated.

## Stable framework already established

The shared Materials Library supports built-in/user materials, categories, editing, scalar and temperature-dependent properties, traceability, local persistence, portable `.ecmaterial` / `.ecmaterials` interchange and material comparison.

`MaterialPropertyResolver` supports constant values, table values/interpolation and equations, including validity/range and extrapolation behaviour.

The reusable material requirement API provides required/optional properties, requirement sets, structured warnings/errors, temperature-aware checks, multi-material validation and `canCalculate` results. Standard sets cover mass/weight, steady-state conduction, transient thermal and linear-elastic calculations.

**Core rule:** calculators declare only the properties they actually need. Missing unrelated properties do not block a calculation; missing/unresolvable required properties do. New material-aware calculators should use a safe `validatedCalculate()` entry point.

For temperature-dependent calculations, use solved local physical-layer temperatures for range validation when available. Do not reject an otherwise valid material merely because a global system temperature lies outside its property range.

## Portable Calculation Documents — architecture and completed direction

### Architectural objective

A saved standalone calculation or project must be wholly transportable and self-contained. It must be possible to move the document to a clean EngineeringCalculator installation and reproduce the saved engineering result without access to the originating material library.

The material library is a resource for creating and deliberately updating calculations. Embedded material definitions are part of the saved engineering record and are authoritative for reproducing the saved state.

### Persistence foundation

The persistence model is versioned and uses stable calculation, input and output identifiers. Persistence representations are separate from arbitrary runtime Swift calculator objects. The input/value architecture is intended to remain extensible for future project-parameter references and calculation-output references rather than assuming every future input is permanently a literal `Double`.

Deterministic portable regression fixtures have been added so identical saved inputs can be used for reliable comparison between builds.

### Self-contained embedded materials

Documents embed the complete material definitions required by their calculations rather than only the properties immediately consumed by a calculator. Persistent material UUIDs and canonical material fingerprints support identity, comparison and portability.

A standalone calculation contains the embedded definitions it needs. A project is designed to store each embedded material once and allow calculations to reference that project material by UUID.

### Material reconciliation

The intended and tested design direction remains:

1. UUID absent locally: embedded material can be imported as a new library material while retaining identity.
2. UUID present and content identical: reuse without unnecessary duplication.
3. UUID present but content differs: record a conflict rather than silently overwriting either definition.
4. Historical calculations continue to use their embedded definition unless the user deliberately adopts/updates another definition.
5. Imported data must not gain protected built-in status merely because incoming metadata claims it.

### Standalone calculations — verified integration

Standalone calculations use `.eccalc`.

Pipe Weight & Buoyancy has been exercised through the standalone document UI. A regression was found where a saved case containing two additional material layers reopened with only one layer visible. The restoration path was corrected and regression coverage added. The user subsequently verified that a case containing UNS S32760 plus Concrete reopened with both additional layers present and the layer stack/results restored.

Standalone open/save therefore forms part of the current known-good checkpoint and should not be reimplemented when development resumes.

### Project calculations — current active boundary

Projects use `.ecproject`.

Project persistence/container and workspace work has begun. `ProjectWorkspaceView` uses a project-specific Uniform Type Identifier. A build failure exposed that `.engineeringProject` had not yet been defined; this was corrected by adding:

`com.andrewlindsay.engineeringcalculator.project`

as the project UTType, conforming to JSON. The full regression suite then passed **168/168**.

**This is where development is paused.** The next task is not another architectural redesign; it is the concrete end-to-end project save/reopen validation described at the top of this document.

## Compatibility decisions — preserve unless deliberately superseded

### Future project parameters

Persisted calculation inputs must remain extensible beyond literal values so they can later reference shared project parameters. Do not replace the persistence model with `[String: Double]` or another representation that would force a redesign.

### Future calculation chaining

Calculations need stable UUIDs and persisted inputs/outputs need stable machine identifiers independent of display names. This permits a future calculation output to become another calculation's input without fragile string matching.

### Future formal calculation reports

Persistence must retain enough information to support auditable calculation reports later: inputs, units, assumptions, selected/embedded material provenance, validation messages, calculator/schema version and results. Report/export is a consumer of the persisted engineering record, not a separate source of truth.

### Material evolution and historical reproducibility

An embedded material is not merely a cache of the current library material. It is part of the saved engineering record. Library changes must not silently alter historical calculations.

### Cross-device portability

Do not introduce macOS-only persistence semantics. The document representation should remain portable between macOS and iOS even if the surrounding UI differs.

## Previously verified material-aware calculators

### Pipe Weight & Buoyancy

Density is required for every solid layer. Missing density is shown explicitly, identifies the failing material/layer and blocks numerical results. Materials missing unrelated properties remain valid if density exists. A safe `validatedCalculate()` API exists, while the raw calculation remains for legacy/numerical regression use.

The standalone persistence adapter preserves pipe geometry, fluid values, all additional material layers, outputs and embedded materials. Multi-layer save/reopen behaviour is part of the current verified checkpoint.

### Multilayer Pipe Heat Transfer

Steady-state radial conduction through concentric cylindrical layers is implemented and verified, including adaptive treatment of temperature-dependent conductivity and location-aware property-range validation. The calculator uses `validatedCalculate()` and reports physical-layer results separately from internal computational cells.

The heat-transfer profile uses radial build measured from the internal pipe surface; physical layer widths are proportional to actual radial thickness, and chart bands represent physical material layers rather than adaptive computational cells.

Portable calculation adapter/regression coverage has been added for this calculator as part of the persistence work.

## Deferred roadmap — resume only after project documents are stable

These tasks remain valid and are not superseded:

- project metadata/groups/folders refinements;
- shared project parameters;
- calculation chaining using stable input/output identifiers;
- schema migration and safe unknown/newer-schema handling;
- final macOS/iPhone heat-transfer visual regression and light/dark mode checks;
- inside/outside convection films and bulk-fluid/ambient temperatures;
- optional adaptive computational-cell chart detail;
- formal calculation report/export capability;
- further material-aware calculators, including transient thermal (`ρ`, `Cp`, `k`) and linear-elastic/mechanical (`E`, `ν`);
- material-comparison PDF/print/CSV work.

## Permanent portability regression requirements

Regression coverage should continue to protect:

- save/encode/decode round trip;
- save, close and reopen result reproduction;
- transfer to a clean material library/install;
- import of genuinely new materials;
- identical material reuse without duplication;
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

Permanent rule:

> A calculation transferred to a clean EngineeringCalculator installation must reproduce the original engineering result without requiring access to the originating material library.

## Testing philosophy

Prefer deterministic synthetic materials and analytically simple answers. The portable regression cases should use fixed, known inputs so build-to-build comparisons are meaningful and repeatable.

Every material-aware calculator should test required properties present/missing, unrelated missing properties, temperature requirements/ranges, multiple materials, recovery after replacement and at least one independent numerical regression case.

Persistence tests should additionally verify identity, portability, reproducibility, conflict safety, schema compatibility and failure behaviour. Never silently repair or substitute engineering data merely to make a saved calculation load.

## Important UI/framework decisions to preserve

- Material comparison selection order is explicit and the first selection is initially the reference.
- macOS comparison uses one aligned row structure, not independent left/right vertical scroll views.
- Frozen Property/Reference cells are opaque; columns can fill available width and be resized.
- Imported materials cannot regain protected built-in status.
- Invalid materials may be selectable so validation can explain what is missing; invalid calculations must be blocked rather than silently corrected.
- Heat-transfer charts use the internal pipe surface as the zero radial-build datum; actual diameters belong in the numerical layer table.
- Heat-transfer chart bands represent physical material layers, not adaptive computational cells.
- Standalone Pipe Weight & Buoyancy restoration must preserve every additional layer, not merely the first.
- Project material storage should deduplicate shared definitions while calculations retain stable UUID references.

## Git/versioning policy

Git history is part of the engineering/development record. Preserve enough information to determine what changed, why it changed and what behaviour was expected at each checkpoint.

Use small meaningful commits. Tests for deliberately changed behaviour should be added/updated in the same logical change where practical.

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

Before and after substantial changes run the complete suite with **⌘U**.

# CURRENT HOLD POINT

**Branch:** `feature/portable-calculation-documents`  
**Regression baseline:** **168/168 tests passed**  
**Next task:** **End-to-end `.ecproject` project workspace save → close → reopen validation with multiple calculations and shared embedded materials, followed by permanent regression coverage.**
