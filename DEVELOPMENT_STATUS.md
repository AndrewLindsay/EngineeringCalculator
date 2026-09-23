# Engineering Calculator — Development Status & Roadmap

**Last updated:** 23 September 2026  
**Status:** **ACTIVE — known-good 183-test checkpoint**  
**Active development branch:** `feature/portable-calculation-documents`  
**Earlier recovery branch:** `checkpoint/project-library-171-tests`  
**Current focus:** portable self-contained calculation/project documents and robust Project Library file access  
**Last user-verified automated checkpoint:** **183 tests passed, 0 failures**

Read `AGENTS.md` first, then this file whenever resuming or refreshing development status.

# RESUME HERE

This is the authoritative restart point.

1. Confirm branch `feature/portable-calculation-documents`.
2. Run `git pull`, `git status`, and `git branch --show-current`.
3. Build the macOS target and run the complete suite with **⌘U** when making substantive code changes.
4. Current regression baseline: **183/183 tests passing**.
5. Project-owned Pipe Weight & Buoyancy cases are live-editable and have safe dirty-state handling. Do not reimplement this workflow.
6. Project identity is UUID-based; filename/location is not project identity.
7. Imported standalone calculations become project-owned snapshots, not live links to the source `.eccalc` file.
8. Independent project copies receive new project UUIDs and must remain independent.
9. Resume with **Project Library persistence/relaunch robustness and security-scoped access**, followed by document-provider and cross-device integration checks.

# CHECKPOINT SUMMARY

The portable-document architecture now covers standalone calculation persistence, material reconciliation, project persistence, persistent Project Library, project-owned calculation opening/editing, explicit dirty-state handling, independent copies and UUID-based duplicate detection.

User-verified at this checkpoint:

- **183 tests passed, 0 failures** in the complete Xcode test suite;
- standalone Pipe Weight & Buoyancy `.eccalc` save/export/open works, including multi-layer cases;
- `.eccalc` and `.ecproject` extensions are appended/registered correctly through the implemented document workflow;
- project model supports multiple calculations and embedded material definitions;
- importing a standalone calculation into a project creates a project-owned snapshot rather than a live link to the original file;
- identical project materials are deduplicated and same-UUID/different-definition conflicts are rejected rather than silently overwritten;
- Project Library catalogues project files/metadata rather than duplicating project contents;
- projects can be named and their internal title renamed independently of the physical filename;
- project identity is based on persistent project UUID rather than filename/path;
- opening the same project UUID from another filename/location updates the existing Project Library identity rather than creating a second logical project;
- creating an independent copy gives it a new project UUID and preserves calculations/materials;
- project-owned Pipe Weight & Buoyancy calculations open through the normal live calculator restoration path using embedded material snapshots;
- editing a project-owned calculation marks it dirty; leaving it prompts the user to Update Project / Discard Changes / Cancel;
- updating a calculation changes the in-memory project but does not silently overwrite the `.ecproject` file;
- leaving a dirty project prompts Save / Don't Save / Cancel;
- Don't Save returns to the last persisted project state rather than accidentally committing in-memory edits;
- a newly created independent copy is dirty until explicitly saved, preventing the back arrow from silently losing it;
- Project Library identity survives `ProjectLibraryStore` reload in automated coverage;
- localization/tooltips remain established infrastructure using `Localizable.xcstrings`.

# AUTOMATED TEST STATUS

The full user-run Xcode suite is green at **183/183**.

Coverage includes the established material framework and portable-document foundation plus the project lifecycle regression layer:

- material scalar/table/equation property persistence and resolution;
- material validation/requirements and calculator blocking when required properties are missing;
- material identity, canonical fingerprints and comparison behaviour;
- material portable import/export and conflict handling;
- Pipe Weight & Buoyancy numerical/persistence behaviour including multiple layers;
- Multilayer Pipe Heat Transfer numerical/material-aware behaviour and portable persistence;
- CalculationDocument encode/decode, file-type validation and persistence primitives;
- deterministic standalone portable calculation regression cases;
- standalone calculation embedded-material preservation;
- project workspace add/rename/delete/move/duplicate operations;
- atomic standalone-calculation-to-project import;
- shared material deduplication and rejection/rollback for same-UUID conflicting definitions;
- project encode/decode/reopen retaining calculation IDs, cases and shared embedded materials;
- transactional project-case replacement/update behaviour;
- unsaved calculation edits do not mutate the saved project snapshot;
- Don't Save/reopen restores the last persisted engineering state;
- Save/reopen preserves the updated engineering state;
- imported `.eccalc` calculations are project-owned rather than linked to the source file;
- independent project copies receive new project UUIDs while retaining calculations/materials;
- same-project UUID from another filename/location resolves as the existing logical project;
- genuinely independent project UUIDs create separate Project Library entries;
- project identity persists across `ProjectLibraryStore` reload.

# STILL REQUIRING INTEGRATION / MANUAL COVERAGE

Do not infer the following solely from the 183 green tests:

- Project Library access across a **full application termination and relaunch** for files selected outside the app sandbox;
- durable security-scoped bookmark/access behaviour for externally selected files;
- moved/renamed/deleted external project-file recovery behaviour;
- real document-picker/iCloud-provider behaviour on physical devices;
- cross-device Mac ↔ iPhone portability;
- complete tooltip/accessibility and localization audit.

# LOCALIZATION & UI HELP ARCHITECTURE

Use the single Apple String Catalog `EngineeringCalculator/Localizable.xcstrings` as the localization authority. English is the source language. Stable semantic keys remain appropriate for help/accessibility/validation text, while engineering identifiers, file extensions, units, equations and persistence keys remain language-independent. Preserve native navigation semantics rather than replacing native controls solely to add tooltips.

# EXACT NEXT DEVELOPMENT TASK — PROJECT LIBRARY RELAUNCH ROBUSTNESS

The next substantive task is to validate and, if required, harden persistent access to Project Library files across application relaunch.

Required workflow:

1. Create/save or import a real `.ecproject` through the normal macOS picker workflow.
2. Confirm the Project Library entry points to that authoritative project file.
3. Fully terminate Engineering Calculator — not merely navigate back to Home.
4. Relaunch the application and reopen the project from Project Library.
5. Determine whether the stored URL retains sandbox access after relaunch.
6. If not, implement persistent security-scoped bookmark storage/resolution for external project files.
7. Preserve the architectural rule that the `.ecproject` file is authoritative and Project Library remains only a catalogue/locator.
8. Detect stale/moved/deleted/inaccessible files and present a clear recovery path; never silently create a replacement project.
9. Add deterministic automated coverage for bookmark/catalogue persistence logic where platform APIs permit it.
10. Repeat the real terminate/relaunch test, then proceed to physical-iPhone/document-provider and cross-device portability testing.

# ARCHITECTURE DECISIONS TO PRESERVE

## Portable document authority

A transferred standalone calculation or project must be wholly self-contained. Embedded material definitions are part of the engineering record and authoritative for reproducing the saved state. A changed local Material Library must not silently alter a historical calculation.

Standalone calculations use `.eccalc`; projects use `.ecproject`.

## Project ownership and save boundaries

A calculation contained in a project is project-owned data. Importing a standalone `.eccalc` copies its persisted calculation/material state into the project; subsequent project edits do not mutate the original standalone file.

Editing a project calculation first changes working/in-memory state. Updating the project case commits that working calculation into the in-memory project. Saving the project commits the in-memory project to the authoritative `.ecproject` file. These boundaries are deliberate because automatic file writes would remove the user's ability to discard work while no general undo/version-history system exists.

## Project identity

Persistent project UUID is authoritative identity. Filename, displayed title and URL/location are mutable metadata and must not be used as logical identity.

Opening another file representing the same project UUID must not silently create a second logical Project Library project. An independent copy must receive a new project UUID.

## Project Library authority

The Project Library is a catalogue, not a second copy of project data. The `.ecproject` file remains authoritative. Catalogue metadata may include project UUID, title, file location, calculation count and modified date.

Persistent access to externally selected files must respect macOS/iOS sandboxing. If plain URLs do not survive relaunch reliably, store security-scoped bookmarks rather than copying project contents into the catalogue.

## Material reconciliation

- UUID absent: genuinely new material may be added/embedded retaining identity.
- UUID present and content identical: reuse/deduplicate.
- UUID present but content differs: report a conflict; never silently overwrite.
- Imported data must not gain protected built-in status from untrusted metadata.
- Historical calculations continue using their embedded definition unless the user deliberately adopts a different definition.

## Future extensibility

Persisted calculation inputs must remain extensible beyond literal doubles so future shared project parameters and calculation-output chaining can be introduced without replacing the persistence architecture. Stable UUIDs/machine identifiers must remain independent of display names.

# PLATFORM TESTING AFTER RELAUNCH ROBUSTNESS

## Physical iPhone / iPad

- [ ] Install and launch the current project-document build on a physical iPhone.
- [ ] Verify Project Library layout and controls at phone width.
- [ ] Create/save a project and verify `.ecproject` handling through Files/iCloud Drive.
- [ ] Import/open `.eccalc` and `.ecproject` through Files/iCloud Drive.
- [ ] Open/edit/update/save/relaunch/reopen a project-owned Pipe Weight & Buoyancy case.
- [ ] Verify embedded project materials do not silently overwrite the global Material Library.
- [ ] Test externally moved/renamed/deleted catalogued project files.

## Cross-device portability

- [ ] Mac → iPhone `.eccalc` with a clean/different local material library reproduces saved result.
- [ ] Mac → iPhone `.ecproject` reproduces project calculations without originating library materials.
- [ ] Repeat iPhone → Mac.
- [ ] Exercise the same project through iCloud Drive where practical.

# DEFERRED ROADMAP — AFTER PROJECT DOCUMENTS ARE STABLE

- project metadata/groups/folders refinements;
- shared project parameters;
- calculation chaining using stable input/output identifiers;
- schema migration and safe unknown/newer-schema handling;
- formal calculation report/export capability;
- deliberate whole-app String Catalog extraction and additional-language work;
- final macOS/iPhone heat-transfer visual regression and light/dark mode checks;
- inside/outside convection films and bulk-fluid/ambient temperatures;
- optional adaptive computational-cell chart detail;
- further material-aware calculators, including transient thermal (`ρ`, `Cp`, `k`) and linear-elastic/mechanical (`E`, `ν`);
- material-comparison PDF/print/CSV work.

# TESTING PHILOSOPHY

Prefer deterministic synthetic materials and analytically simple answers. Portable regression cases should use fixed known inputs so build-to-build comparisons are meaningful and repeatable.

Never silently repair or substitute engineering data merely to make a saved calculation load. Failure/conflict behaviour is part of engineering correctness and should be tested explicitly.

# GIT / RECOVERY

Development branch:

```text
feature/portable-calculation-documents
```

Earlier known-good recovery branch:

```text
checkpoint/project-library-171-tests
```

Current user-verified suite baseline:

```text
183 tests passed, 0 failures
```

Normal resume workflow:

```bash
git pull
git status
git branch --show-current
# build macOS target
# run complete Xcode suite with ⌘U
```

Normal commit workflow:

```bash
git status
git add .
git commit -m "Description of changes"
git push
```

The 171-test checkpoint branch remains useful for historical recovery, but it predates the completed project lifecycle/dirty-state work. Prefer the current feature branch for ongoing development.
