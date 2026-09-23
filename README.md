# Engineering Calculator

A modular SwiftUI engineering-calculation app for iOS and macOS.

> **Development agents/contributors:** Read `AGENTS.md` first, then `DEVELOPMENT_STATUS.md`. When the user says **refresh**, read both before continuing development.

## Current development status — SAFE HOLD POINT — 23 September 2026

**Active development branch:** `feature/portable-calculation-documents`  
**Known-good checkpoint branch:** `checkpoint/project-library-171-tests` (to be advanced to the documentation commit for this handover)  
**Current focus:** portable, self-contained calculation documents and persistent project workspaces.  
**Last user-verified automated checkpoint:** **171 tests passed, 0 failures** on macOS/Xcode.

Development is intentionally paused at a stable hold point. **When work resumes, the next implementation task is Update Project Case:** edit a project-owned calculation in the live calculator and transactionally write its changed inputs, outputs, timestamps and embedded material snapshots back into the owning project.

## Verified at this checkpoint

Completed and user-verified through the current hold point:

- shared Engineering Materials Library with built-in and user materials;
- portable `.ecmaterial` / `.ecmaterials` material import/export;
- temperature-dependent property resolver with constants, tables and equations;
- reusable material comparison and material-requirement frameworks;
- material-property validation that blocks calculations when required engineering data is unavailable;
- Pipe Weight & Buoyancy and Multilayer Pipe Heat Transfer material-aware calculation integration;
- versioned portable calculation persistence model with stable calculation/input/output identifiers;
- complete embedded material definitions and canonical material fingerprinting;
- material reconciliation/conflict handling without silently overwriting local materials;
- deterministic portable calculation regression cases for reliable build-to-build comparison;
- standalone `.eccalc` calculation save/export/open support;
- Pipe Weight & Buoyancy standalone documents preserving multiple material layers across save/open;
- portable regression coverage for Pipe Weight & Buoyancy and Pipe Heat Transfer;
- atomic import of standalone calculations into projects, including rollback on material conflicts;
- project calculation/material round-trip persistence and shared-material deduplication regression coverage;
- `.eccalc` and `.ecproject` UTType/extension registration;
- Project Library architecture: create named projects, import/open saved projects and catalogue project metadata;
- project rename from the Project Library using the context menu (right-click on macOS; press-and-hold on iOS/iPadOS);
- standalone `.eccalc` import into a project through the Project Workspace UI;
- project-owned Pipe Weight & Buoyancy cases opening in the live calculator using their embedded material snapshots rather than silently substituting global-library definitions;
- latest complete regression suite: **171/171 tests passing**.

## Manual testing already performed in this development phase

The user has manually exercised the current macOS build sufficiently to confirm:

- an `.eccalc` Pipe Weight & Buoyancy case can be imported into a project and appears with its persisted inputs;
- project naming works and projects are presented through the Project Library rather than all appearing as `Untitled Project`;
- a project-owned Pipe Weight & Buoyancy calculation can be opened in the normal live calculator;
- the restoration UI reports that embedded project material snapshots are being used;
- the full Xcode regression suite passes after the Project Library/project-open integration.

These manual checks are **not** a substitute for the outstanding physical-device/cross-device testing listed in `DEVELOPMENT_STATUS.md`.

## Resume here — exact next task

Implement **Update Project Case** transactionally:

1. Open a project-owned calculation in the live calculator.
2. Allow the user to modify inputs and recalculate normally.
3. Provide an explicit project-aware update action rather than treating the edit as an unrelated standalone `.eccalc` save.
4. Preserve the existing calculation UUID.
5. Replace persisted inputs and outputs and update timestamps.
6. Rebuild/update the calculation's required embedded material snapshots.
7. Deduplicate identical project materials and retain stable UUID references.
8. Reject UUID/content conflicts without partially modifying the project.
9. Mark/update the project modification state.
10. Add deterministic automated tests for success, material deduplication, conflict rollback and project encode/decode/reopen after an update.
11. Then exercise the complete manual workflow: Create Project → Add Calculation → Open → Edit → Update Project Case → Save Project → Close → Reopen → verify edited values/results.

Do not begin the deferred calculator roadmap before this project editing lifecycle is stable.

## Physical-device / platform testing still required

Before this project-document phase is considered release-ready, explicitly test on a real iPhone/iPad where applicable and repeat critical macOS lifecycle checks. At minimum:

- install/run the current build on a physical iPhone;
- open the Project Library and verify layout, navigation and controls at phone size;
- create a named project on iPhone;
- verify press-and-hold exposes Rename and that renaming persists;
- save/export `.eccalc` and `.ecproject` files without manually typing extensions and confirm the correct extensions are present;
- import/open `.eccalc` and `.ecproject` through the iOS document picker;
- verify security-scoped/document-provider URLs work with Files/iCloud Drive and do not trigger false extension errors;
- verify a project-owned Pipe Weight & Buoyancy case opens and restores every input/layer/material correctly;
- verify embedded project materials do not silently populate or overwrite the global Material Library;
- after Update Project Case is implemented, edit/update/save/reopen a project case on-device and verify results persist;
- fully terminate/relaunch the app and verify Project Library entries can still reopen their files. This is especially important because persistent external-file access may require security-scoped bookmarks rather than storing plain URLs;
- test moving/renaming/deleting a catalogued `.ecproject` externally and ensure the app reports the missing/inaccessible file cleanly;
- where iCloud Drive is used, test the same project across Mac and iPhone to confirm the portable file remains authoritative and no device-local material library is required to reproduce the calculation;
- repeat key navigation on macOS: Calculator → Project → Project Library → Home, including returning to Projects after a Projects tab/navigation item is already selected;
- perform light/dark mode and compact/standard/comfortable interface-density checks on both Mac and iPhone for the new Project Library/workspace UI.

## Material validation principle

Calculators must explicitly declare the material properties they require. Before results are evaluated, selected materials must be validated against those requirements. Missing or unresolvable required data must produce an actionable warning and block the result; it must not be silently replaced with zero or an arbitrary default.

New material-aware calculators should expose a safe `validatedCalculate()` entry point so callers cannot accidentally bypass validation.

## Portable document principle

A transferred standalone calculation or project must reproduce its saved engineering state without access to the originating material library. Embedded material definitions form part of the saved engineering record. Opening a historical document must not silently replace its embedded definition with a changed local-library definition.

Standalone calculations use `.eccalc`; projects use `.ecproject`.

## Development workflow

At the start of the next session:

```bash
git pull
git status
git branch --show-current
```

The development branch should be:

```text
feature/portable-calculation-documents
```

Run the complete regression suite with **⌘U** before substantial new changes. The current expected result is **171 tests passed, 0 failures**.

Known-good recovery branch:

```text
checkpoint/project-library-171-tests
```

When a tested local change needs committing manually:

```bash
git status
git add .
git commit -m "Description of changes"
git push
```

For the detailed checkpoint, architecture decisions, exact automated/manual test status and roadmap, see `DEVELOPMENT_STATUS.md`.
