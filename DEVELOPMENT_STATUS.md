# Engineering Calculator — Development Status & Roadmap

**Last updated:** 23 September 2026  
**Status:** **ACTIVE — known-good 175-test checkpoint**  
**Active development branch:** `feature/portable-calculation-documents`  
**Earlier recovery branch:** `checkpoint/project-library-171-tests`  
**Current focus:** portable self-contained calculation/project documents, project-case editing, and consistent localized UI help  
**Last user-verified automated checkpoint:** **175 tests passed, 0 failures**

Read `AGENTS.md` first, then this file whenever resuming or refreshing development status.

# RESUME HERE

This is the authoritative restart point.

1. Confirm branch `feature/portable-calculation-documents`.
2. Run `git pull`, `git status`, and `git branch --show-current`.
3. Build the macOS target and run the complete suite with **⌘U** when making substantive code changes.
4. Current regression baseline: **175/175 tests passing**.
5. **Update Project Case is implemented and tested. Do not reimplement it.**
6. Localization/tooltips are now established infrastructure. Continue the UI audit as screens are touched; do not replace native navigation controls merely to add hover help.
7. Resume the substantive portable-document roadmap with **Project Library persistence/relaunch robustness and security-scoped access**, followed by the remaining cross-device/document-provider integration checks.

# CHECKPOINT SUMMARY

The portable-document architecture has progressed through standalone calculation persistence, material reconciliation, project persistence, persistent Project Library, project-owned calculation opening, and transactional updating of a project-owned calculation.

User-verified at this checkpoint:

- **175 tests passed, 0 failures** in the complete Xcode test suite;
- standalone Pipe Weight & Buoyancy `.eccalc` save/export/open works, including multi-layer cases;
- deterministic portable regression cases provide stable build-to-build comparisons;
- `.eccalc` and `.ecproject` document types/extensions are registered;
- project model supports multiple calculations and embedded material definitions;
- importing a standalone calculation into a project is atomic;
- identical project materials are deduplicated and same-UUID/different-definition conflicts are rejected rather than silently overwritten;
- Project Library catalogues saved/imported project files and metadata rather than duplicating project contents;
- projects can be named and their internal title renamed independently of the physical filename;
- a project-owned Pipe Weight & Buoyancy case opens through the normal live calculator restoration path using embedded material snapshots;
- **Update Project Case is implemented**: a live project-owned calculation can be edited and written transactionally back to its owning project while retaining project/calculation identity and material reconciliation rules;
- the updated project case can be reopened/persisted through the `.ecproject` workflow;
- `Localizable.xcstrings` is part of the Xcode application target and currently contains manually managed semantic keys for navigation/help/validation and Pipe Weight & Buoyancy UI text;
- Pipe Weight & Buoyancy uses localized semantic help for Save/Update, Open Calculation, Add Layer, Delete Layer, Move Up/Down and Create Material controls;
- the reusable Open Calculation toolbar control has verified macOS hover help;
- icon-only controls should carry accessibility labels in addition to pointer-platform help text;
- the native NavigationStack Back arrow is an intentional exception: preserve native navigation semantics rather than replacing it solely to add a tooltip.

# AUTOMATED TEST STATUS

The full user-run Xcode suite is green at **175/175**.

Coverage includes the established material framework and portable-document foundation, including:

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
- transactional project-case replacement/update behaviour added after the 171-test checkpoint.

## Still requiring integration/manual coverage

Do not infer the following solely from the 175 green tests:

- Project Library persistence across full application relaunch;
- durable security-scoped bookmark/access behaviour for externally selected files;
- real document-picker/iCloud-provider behaviour on physical devices;
- UI navigation semantics across repeated Home → Projects → Project → Calculator → back workflows;
- context-menu/long-press rename interaction on all platforms;
- filename-extension behaviour as observed through native macOS/iOS save panels;
- full tooltip/accessibility audit of every existing screen;
- full automatic extraction/localization of all ordinary visible SwiftUI strings;
- cross-device Mac ↔ iPhone portability.

# LOCALIZATION & UI HELP ARCHITECTURE

Use a single Apple String Catalog, `EngineeringCalculator/Localizable.xcstrings`, as the localization authority.

Current approach:

- English is the source language.
- Additional languages are added to the same String Catalog; do not create parallel Swift source files per language.
- Stable semantic keys are appropriate for tooltips, accessibility/help text, validation messages and other deliberately managed strings, for example `tooltip.*`, `navigation.*`, `validation.*` and calculator-specific namespaces.
- Manually maintained semantic catalog entries use `extractionState = manual`.
- Ordinary SwiftUI visible text can later use Xcode automatic String Catalog extraction. The earlier Xcode extraction experiment identified roughly 300 existing UI strings; adopt that deliberately as a separate localization phase rather than as an accidental side effect of an unrelated change.
- Engineering identifiers, file extensions, units, equations and machine-readable persistence keys must remain language-independent.

UI rule:

- all app-owned interactive buttons/icons should have concise explanatory help text where the platform supports hover help;
- icon-only controls should also have meaningful accessibility labels;
- help text should explain the action, not merely repeat an ambiguous symbol;
- use localized semantic strings rather than duplicating English tooltip text in Swift;
- native system navigation controls may retain native behaviour without custom replacement solely to add a tooltip. The standard Back arrow is the explicit current example.

`Localizable.xcstrings` is JSON; validate structural edits with a JSON parser such as `python3 -m json.tool`, not `plutil -lint`.

# MANUAL TESTING ALREADY PERFORMED

Observed on the Mac build during this development phase:

1. Standalone Pipe Weight & Buoyancy calculations save/open and restore multiple material layers.
2. A standalone `.eccalc` can be imported into a Project Workspace.
3. File-extension/document-type registration and provider-URL handling were corrected after real save/import testing exposed them.
4. Named Project Library workflow and project rename have been exercised.
5. A project-owned Pipe Weight & Buoyancy calculation opens using embedded project material definitions rather than silently substituting the global library.
6. The Update Project Case workflow has been implemented and exercised: open project-owned case → edit → update project case → persist/reopen.
7. Complete Xcode suite reported **175 tests passed** after the project-case work and again before the latest tooltip-only Open Calculation change.
8. macOS hover help for the reusable Open/Load Calculation folder icon was manually verified after the localized help change.

# PHYSICAL DEVICE / PLATFORM TESTING STILL REQUIRED

## Physical iPhone / iPad

- [ ] Install and launch the current project-document build on a physical iPhone.
- [ ] Verify Project Library layout at phone width and all controls remain accessible at Compact, Standard and Comfortable interface densities.
- [ ] Create a named project and confirm the title is visible in the workspace and library.
- [ ] Press and hold a project entry; verify Rename appears, rename the project, leave/re-enter Projects and confirm persistence.
- [ ] Save/export a standalone calculation without manually typing `.eccalc`; verify Files shows the extension.
- [ ] Save/export a project without manually typing `.ecproject`; verify Files shows the extension.
- [ ] Import/open `.eccalc` and `.ecproject` through Files/iCloud Drive.
- [ ] Verify no false unsupported-extension error occurs with document-provider/security-scoped URLs.
- [ ] Open a project-owned Pipe Weight & Buoyancy case and confirm all inputs, layers, material selections and results restore correctly.
- [ ] Edit a project-owned case, Update Project Case, save, terminate/relaunch, reopen and verify edited values/results.
- [ ] Verify embedded project material definitions do not silently appear in or overwrite the global Material Library.
- [ ] Fully terminate/relaunch and reopen catalogued projects; use security-scoped bookmarks if plain stored URLs are not durable.
- [ ] Move/rename/delete a catalogued project externally and verify clear inaccessible/missing-file handling.

## macOS integration checks still required

- [ ] Explicitly verify saving `Test Calculation` produces `Test Calculation.eccalc` without manually entering the extension.
- [ ] Explicitly verify saving `Test Project` produces `Test Project.ecproject` without manually entering the extension.
- [ ] Save a named project, return to Project Library, and verify the correct internal title and calculation count.
- [ ] Right-click → Rename, reopen and confirm the renamed internal title persists while filename remains unchanged.
- [ ] Fully quit/relaunch and verify Project Library entries can reopen their files; implement security-scoped bookmarks if required.
- [ ] Repeatedly verify Home → Projects → Project → Calculator → Project → Projects → Home navigation.
- [ ] Import two calculations sharing the same material, save/reopen and manually verify both calculations/results.
- [ ] Exercise a deliberate same-UUID/different-content material conflict through the UI and confirm no partial mutation.
- [ ] Verify light/dark mode and all interface-density settings for Project Library, Project Workspace and restored calculation views.
- [ ] Continue tooltip/accessibility audit of app-owned controls as each screen is touched.

## Cross-device portability

- [ ] Mac → iPhone `.eccalc` with a clean/different local material library reproduces saved result.
- [ ] Mac → iPhone `.ecproject` reproduces project calculations without originating library materials.
- [ ] Repeat iPhone → Mac.
- [ ] Exercise the same project through iCloud Drive where practical.

# EXACT NEXT DEVELOPMENT TASK — PROJECT LIBRARY RELAUNCH ROBUSTNESS

The next substantive portable-document task is to validate and, if required, harden persistent access to Project Library files across application relaunch.

Required workflow:

1. Create or import a real `.ecproject` into Project Library.
2. Save it outside the app's temporary working context using the normal macOS/iOS picker workflow.
3. Fully terminate the application.
4. Relaunch and attempt to reopen the catalogued project from Project Library.
5. If the stored URL does not retain sandbox access, implement persistent security-scoped bookmark storage/resolution rather than copying project contents into the catalogue.
6. Preserve the architectural rule that the `.ecproject` file is authoritative and Project Library is only a catalogue/locator.
7. Handle stale/moved/deleted files clearly; do not silently create replacement projects.
8. Add deterministic automated coverage for bookmark/catalogue persistence logic where platform APIs allow it, then repeat the real relaunch test.

After this is stable, proceed through the remaining macOS/physical-iPhone document-provider and cross-device portability checklist before declaring portable project documents complete.

# ARCHITECTURE DECISIONS TO PRESERVE

## Portable document authority

A transferred standalone calculation or project must be wholly self-contained. Embedded material definitions are part of the engineering record and are authoritative for reproducing the saved state. A changed local Material Library must not silently alter a historical calculation.

Standalone calculations use `.eccalc`; projects use `.ecproject`.

## Project Library authority

The Project Library is a catalogue, not a second copy of project data. The `.ecproject` file remains authoritative. Catalogue metadata may include project title, file location, calculation count and modified date.

Persistent access to externally selected files must respect macOS/iOS sandboxing. If plain URLs do not survive relaunch reliably, store security-scoped bookmarks rather than copying project contents into the catalogue.

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
175 tests passed, 0 failures
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

The 171-test checkpoint branch remains useful for historical recovery, but it predates Update Project Case and the localization/help infrastructure. Prefer the current feature branch for ongoing development.
