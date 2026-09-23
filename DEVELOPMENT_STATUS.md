# Engineering Calculator — Development Status & Roadmap

**Last updated:** 23 September 2026  
**Status:** **SAFE HOLD POINT — intentional development pause**  
**Active development branch:** `feature/portable-calculation-documents`  
**Known-good checkpoint branch:** `checkpoint/project-library-171-tests`  
**Current focus:** portable, self-contained saved calculations and persistent calculation projects  
**Last user-verified automated checkpoint:** **171 tests passed, 0 failures**

Read `AGENTS.md` first, then this file when resuming development.

# RESUME HERE

This is the authoritative restart point.

1. Confirm `feature/portable-calculation-documents`.
2. Run `git pull`, `git status`, and `git branch --show-current`.
3. Build the macOS target and run the complete suite with **⌘U**.
4. Expected regression baseline: **171/171 tests passing**.
5. Resume with **Update Project Case**: edit a project-owned calculation in the live calculator and transactionally write the changed engineering state back into its owning project.
6. Do not restart from the earlier 168-test/89-test checkpoints or repeat completed standalone/project-library work.

# CHECKPOINT SUMMARY

The portable-document architecture has progressed through standalone calculation persistence, atomic project import, project persistence and into a persistent Project Library plus project-owned calculation opening.

User-verified at this hold point:

- **171 tests passed, 0 failures** in the complete Xcode test suite;
- standalone Pipe Weight & Buoyancy `.eccalc` save/export/open works;
- multi-layer Pipe Weight & Buoyancy cases survive standalone save/open;
- deterministic portable regression cases exist for reliable build comparisons;
- project model supports multiple calculations and embedded materials;
- importing a standalone calculation into a project is atomic: material conflict failure does not leave a partial calculation/project mutation;
- project shared-material deduplication and encode/decode/reopen behaviour have automated regression coverage;
- `.eccalc` and `.ecproject` document types/extensions are registered;
- SwiftUI security-scoped imports decode the document payload instead of incorrectly requiring Apple's temporary provider URL to retain the visible filename extension;
- Project Library exists and replaces the previous direct-to-`Untitled Project` navigation;
- New Project requests an internal project name;
- Project Library catalogues saved/imported project files and metadata rather than duplicating project contents;
- project title can be renamed from the Project Library context menu (right-click macOS, press-and-hold iOS/iPadOS); the internal project title is independent of the physical filename;
- an `.eccalc` can be imported through Project Workspace and appears as a populated project calculation;
- a project-owned Pipe Weight & Buoyancy calculation opens in the normal live calculator using the project document's embedded material definitions;
- opening the project calculation does not intentionally import those embedded definitions into the global Material Library.

The known-good code checkpoint before this handover was commit `cef15a29da3c7f7763c87fa888ffb0ce3bdd25a3`; README/status documentation is being advanced immediately after it and the checkpoint branch should point at the final documentation commit.

# AUTOMATED TEST STATUS

## What the 171-test suite covers

The full user-run Xcode suite is green at **171/171**. Existing tests collectively cover the established material framework and portable-document foundation, including:

- material scalar/table/equation property persistence and resolution;
- material validation/requirements and calculator blocking when required properties are missing;
- material identity, canonical fingerprints and comparison behaviour;
- material portable import/export and conflict handling;
- Pipe Weight & Buoyancy numerical/persistence behaviour including multiple layers;
- Multilayer Pipe Heat Transfer numerical/material-aware behaviour and portable persistence;
- CalculationDocument encode/decode, file-type validation and persistence primitives;
- deterministic standalone portable calculation regression cases;
- standalone calculation embedded-material preservation;
- project workspace model add/rename/delete/move/duplicate operations covered by existing project tests;
- atomic standalone-calculation-to-project import;
- shared material deduplication when multiple imported calculations use the same definition;
- rejection/rollback for same-UUID conflicting embedded material definitions;
- project encode/decode/reopen retaining calculation IDs, cases and shared embedded materials.

## What is NOT yet automated

Do not infer these from the 171 green tests. Additional tests are still required for:

- editing an already project-owned calculation and replacing that case transactionally;
- preserving the existing calculation UUID during an Update Project Case operation;
- replacing inputs/outputs/timestamps during project-case update;
- updating/deduplicating embedded material snapshots during project-case update;
- rollback of the entire update if an updated material UUID conflicts;
- project save/reopen after an Update Project Case operation;
- Project Library persistence itself, including catalogue metadata refresh;
- durable security-scoped bookmark behaviour across application relaunch;
- UI navigation semantics (Project Library → Project → Calculator and back);
- context-menu/long-press rename interaction;
- real document-picker/iCloud-provider behaviour;
- filename-extension behaviour as observed through native macOS/iOS save panels.

# MANUAL TESTING ALREADY PERFORMED

The following behaviours have been manually observed during development on the Mac build:

1. Standalone Pipe Weight & Buoyancy calculations have previously been saved/opened, including restoration of multiple material layers.
2. A standalone `.eccalc` was imported into a Project Workspace and displayed as a populated Pipe Weight & Buoyancy case (the observed case showed 14 inputs).
3. A file saved without a manually typed `.eccalc` extension exposed the missing document-type registration; `.eccalc`/`.ecproject` registration was then added and the automated suite remained green.
4. The earlier SwiftUI importer error `Unsupported Engineering Calculator document extension '.'` was traced to a temporary security-scoped provider URL and the importer was made payload-based/UTType-filtered.
5. The Project Library architecture was exercised sufficiently to expose the lack of project naming; New Project naming and context-menu rename were then added.
6. A project-owned Pipe Weight & Buoyancy case was opened in the live calculator. The restoration dialog reported that the calculation was restored from the project using embedded material snapshots.
7. After the latest project naming/library/opening changes, the user reran the complete Xcode suite and reported **171 tests passed**.

These observations are useful integration evidence but are not yet a complete release-level manual test matrix.

# PHYSICAL DEVICE / PLATFORM TESTING STILL REQUIRED

The following should be treated as an explicit outstanding checklist. Record results here as they are completed.

## Physical iPhone / iPad

- [ ] Install and launch the current project-document build on a physical iPhone.
- [ ] Verify Project Library layout at phone width and all controls remain accessible at Compact, Standard and Comfortable interface densities.
- [ ] Create a named project and confirm the title is visible in the workspace and library.
- [ ] Press and hold a project entry; verify Rename appears, rename the project, leave/re-enter Projects and confirm persistence.
- [ ] Save/export a standalone calculation using a filename without typing `.eccalc`; verify Files shows the `.eccalc` extension.
- [ ] Save/export a project using a filename without typing `.ecproject`; verify Files shows the `.ecproject` extension.
- [ ] Import/open `.eccalc` from Files/iCloud Drive through the native document picker.
- [ ] Import/open `.ecproject` from Files/iCloud Drive through the native document picker.
- [ ] Verify no false `Unsupported ... extension '.'` error occurs with document-provider/security-scoped URLs.
- [ ] Open a project-owned Pipe Weight & Buoyancy case and confirm all inputs, layers, material selections and results restore correctly.
- [ ] Verify embedded project material definitions do not silently appear in or overwrite the device's global Material Library.
- [ ] Fully terminate and relaunch the app, then reopen catalogued projects. If plain stored URLs fail after relaunch, implement security-scoped bookmark persistence before calling Project Library persistence complete.
- [ ] Move or rename a catalogued project externally in Files and verify the app fails clearly rather than crashing or silently creating another project.
- [ ] Delete a catalogued project externally and verify a clear inaccessible/missing-file state.
- [ ] After Update Project Case is implemented: edit a project-owned case, update it, save project, terminate/relaunch, reopen and verify edited values/results.

## macOS integration checks still required

- [ ] Explicitly verify saving `Test Calculation` produces `Test Calculation.eccalc` without manually entering the extension.
- [ ] Explicitly verify saving `Test Project` produces `Test Project.ecproject` without manually entering the extension.
- [ ] Save a named project, return to Project Library, and verify the correct internal title and calculation count.
- [ ] Right-click → Rename, reopen the project and confirm the renamed internal title persists while the filename remains unchanged.
- [ ] Fully quit/relaunch the Mac app and verify Project Library entries can reopen their files; implement security-scoped bookmarks if required.
- [ ] Verify navigation repeatedly: Home → Projects → Project → Calculator → Project → Projects → Home. In particular, confirm Projects can be returned to even if its navigation/tab item is already highlighted.
- [ ] Import two calculations sharing the same material, save/reopen the project and manually verify both calculations and expected results.
- [ ] Exercise a deliberate same-UUID/different-content material conflict through the UI and confirm there is no partial project mutation.
- [ ] Verify light/dark mode and all interface-density settings for Project Library, Project Workspace and restored project calculation views.

## Cross-device portability

- [ ] Save a representative `.eccalc` on Mac, open it on iPhone with a clean/different local material library and reproduce the saved result.
- [ ] Save a representative `.ecproject` on Mac, open it on iPhone and reproduce project calculations without requiring originating library materials.
- [ ] Repeat in the opposite direction (iPhone → Mac).
- [ ] Where practical, exercise the same project through iCloud Drive to validate provider/security-scoped behaviour.

# EXACT NEXT DEVELOPMENT TASK — UPDATE PROJECT CASE

Implement project-aware editing without creating a second source of truth.

Required behaviour:

1. A project-owned calculation opens in the existing live calculator restoration path.
2. The user changes inputs/material selections and recalculates normally.
3. An explicit **Update Project Case** action writes the live engineering state back to the owning Project Workspace.
4. The existing calculation UUID is retained.
5. Persisted inputs and outputs are replaced with the new values/results.
6. Calculation/project modification timestamps are updated.
7. Complete required material definitions used by the updated case are embedded in the project.
8. Identical embedded materials are deduplicated; calculations reference project materials by UUID.
9. A same-UUID/different-definition conflict must reject the operation atomically.
10. No failed update may leave changed calculations or partially merged material definitions behind.
11. Saving/reopening the `.ecproject` must reproduce the updated case.

Add automated tests before relying on UI testing. Minimum new tests:

- successful project-case replacement retains calculation UUID;
- inputs/outputs and modified timestamp change as expected;
- unchanged/shared materials remain deduplicated;
- newly required material is added once;
- conflicting material causes complete rollback;
- encode/decode/reopen after update retains updated calculation and material state.

Then perform the manual workflow:

`Create Project → Add Calculation → Open → Edit → Update Project Case → Save Project → Close → Reopen → verify edited values/results`

# ARCHITECTURE DECISIONS TO PRESERVE

## Portable document authority

A transferred standalone calculation or project must be wholly self-contained. Embedded material definitions are part of the engineering record and are authoritative for reproducing the saved state. A changed local Material Library must not silently alter a historical calculation.

Standalone calculations use `.eccalc`; projects use `.ecproject`.

## Project Library authority

The Project Library is a catalogue, not a second copy of project data. The `.ecproject` file remains authoritative. Catalogue metadata may include project title, file location, calculation count and modified date.

Persistent access to externally selected files must respect macOS/iOS sandboxing. If testing shows plain URLs do not survive relaunch reliably, store security-scoped bookmarks rather than copying project contents into the catalogue.

## Material reconciliation

- UUID absent: genuinely new material may be added/embedded retaining identity.
- UUID present and content identical: reuse/deduplicate.
- UUID present but content differs: report a conflict; never silently overwrite.
- Imported data must not gain protected built-in status from untrusted metadata.
- Historical calculations continue using their embedded definition unless the user deliberately adopts a different definition.

## Future extensibility

Persisted calculation inputs must remain extensible beyond literal doubles so future shared project parameters and calculation-output chaining can be introduced without replacing the persistence architecture. Stable UUIDs/machine identifiers must remain independent of display names.

# DEFERRED ROADMAP — AFTER PROJECT DOCUMENTS ARE STABLE

- project metadata/groups/folders refinements;
- shared project parameters;
- calculation chaining using stable input/output identifiers;
- schema migration and safe unknown/newer-schema handling;
- formal calculation report/export capability;
- final macOS/iPhone heat-transfer visual regression and light/dark mode checks;
- inside/outside convection films and bulk-fluid/ambient temperatures;
- optional adaptive computational-cell chart detail;
- further material-aware calculators, including transient thermal (`ρ`, `Cp`, `k`) and linear-elastic/mechanical (`E`, `ν`);
- material-comparison PDF/print/CSV work.

# TESTING PHILOSOPHY

Prefer deterministic synthetic materials and analytically simple answers. Portable regression cases should use fixed known inputs so build-to-build comparisons are meaningful and repeatable.

Never silently repair or substitute engineering data merely to make a saved calculation load. Failure/conflict behaviour is part of the engineering correctness of the application and should be tested explicitly.

# GIT / RECOVERY

Development branch:

```text
feature/portable-calculation-documents
```

Known-good recovery branch:

```text
checkpoint/project-library-171-tests
```

Expected suite at this hold point:

```text
171 tests passed, 0 failures
```

Normal resume workflow:

```bash
git pull
git status
git branch --show-current
# build macOS target
a# run complete Xcode suite with ⌘U
```

Normal commit workflow:

```bash
git status
git add .
git commit -m "Description of changes"
git push
```

If later development needs to be abandoned, return to `checkpoint/project-library-171-tests`, which is intended to represent this known-good 171-test Project Library/project-opening checkpoint plus its handover documentation.
