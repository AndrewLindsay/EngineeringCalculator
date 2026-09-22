# Engineering Calculator

A modular SwiftUI engineering-calculation app for iOS and macOS.

> **Development agents/contributors:** Read `AGENTS.md` first, then `DEVELOPMENT_STATUS.md`. When the user says **refresh**, read both before continuing development.

## Current development status — HOLD POINT — 22 September 2026

**Active branch:** `feature/portable-calculation-documents`  
**Current focus:** portable, self-contained calculation documents and project workspaces.  
**Last user-verified automated checkpoint:** **168 tests passed, 0 failures**.

Development is intentionally paused at a stable hold point. **When work resumes, start with the project workspace `.ecproject` end-to-end save/open/reopen workflow.** Do not restart from the old material-framework or 89-test checkpoint.

### Verified checkpoint

Completed and verified through the current hold point:

- shared Engineering Materials Library with built-in and user materials;
- portable `.ecmaterial` / `.ecmaterials` material import/export;
- temperature-dependent property resolver with constants, tables and equations;
- reusable material comparison and material-requirement frameworks;
- material-property validation that blocks calculations when required engineering data such as density or conductivity is unavailable;
- Pipe Weight & Buoyancy and Multilayer Pipe Heat Transfer material-aware calculation integration;
- versioned portable calculation persistence model with stable calculation/input/output identifiers;
- complete embedded material definitions and canonical material fingerprinting;
- material reconciliation/conflict handling without silently overwriting local materials;
- deterministic portable calculation regression cases for reliable comparison between builds;
- standalone `.eccalc` calculation save/export/open support;
- Pipe Weight & Buoyancy standalone documents preserving multiple material layers across save/open;
- portable regression coverage for Pipe Weight & Buoyancy and Pipe Heat Transfer;
- project persistence/container work and project workspace UI foundations;
- `.ecproject` Uniform Type Identifier added for project document import/export;
- latest complete regression suite: **168/168 tests passing**.

## Resume here — exact next task

The next development task is to exercise and finish the **project workspace end-to-end document workflow**:

1. Create a project containing multiple calculations.
2. Include calculations/materials that exercise shared embedded-material handling.
3. Save/export the project as `.ecproject`.
4. Close/reopen/import the saved project.
5. Verify every calculation, input, output, material reference and embedded material survives the round trip.
6. Verify project embedded-material deduplication and historical calculation reproducibility.
7. Add/fix automated regression tests for any behaviour exposed by this end-to-end exercise.
8. Only after this workflow is verified should the project-document UI phase be considered complete and development move to robustness/schema-migration work or the deferred calculator roadmap.

See `DEVELOPMENT_STATUS.md` for the detailed handover and architecture decisions.

## Material validation principle

Calculators must explicitly declare the material properties they require. Before results are evaluated, selected materials must be validated against those requirements. Missing or unresolvable required data must produce an actionable warning and block the result; it must not be silently replaced with zero or an arbitrary default.

New material-aware calculators should expose a safe `validatedCalculate()` entry point so callers cannot accidentally bypass validation.

For temperature-dependent calculations, validity should be assessed against the temperatures actually experienced by each physical material where the solver can determine them, rather than rejecting a material solely because a global system temperature lies outside its range.

## Portable document principle

A transferred standalone calculation or project must be able to reproduce its saved engineering state without access to the originating material library. Embedded material definitions form part of the saved engineering record. Opening a historical document must not silently replace its embedded definition with a changed local-library definition.

Standalone calculations use `.eccalc`; projects use `.ecproject`.

## Current pipe weight convention

Dry pipe mass/weight excludes internal contents and buoyancy.

Submerged weight is:

`(pipe mass + internal contents mass - displaced external-fluid mass) × g`

with `g = 9.80665 m/s²`.

## Development workflow

At the start of the next session:

```bash
git pull
git status
git branch --show-current
```

The current branch should be:

```text
feature/portable-calculation-documents
```

Run the complete regression suite with **⌘U** before substantial new changes. The current expected result is **168 tests passed, 0 failures**.

When a tested local change needs committing manually:

```bash
git status
git add .
git commit -m "Description of changes"
git push
```

For the detailed checkpoint, architecture decisions, validation fixtures and roadmap, see `DEVELOPMENT_STATUS.md`.
