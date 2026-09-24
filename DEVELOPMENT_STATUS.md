# Engineering Calculator — Development Status & Roadmap

**Last updated:** 24 September 2026  
**Status:** **SAFE HOLD POINT — known-good 183-test checkpoint; macOS Project Library recovery verified**  
**Active development branch:** `feature/portable-calculation-documents`  
**Earlier recovery branch:** `checkpoint/project-library-171-tests`  
**Current focus:** physical-device/document-provider validation and Mac ↔ iPhone portability  
**Last user-verified automated checkpoint:** **183 tests passed, 0 failures**

Read `AGENTS.md` first, then this file whenever resuming or refreshing development status.

# RESUME HERE

This is the authoritative restart point.

1. Confirm branch `feature/portable-calculation-documents`.
2. Run `git pull`, `git status`, and `git branch --show-current`.
3. Build the macOS target and run the complete suite with **⌘U** before/after substantive changes. Expected baseline: **183/183 tests passing**.
4. Do **not** reimplement project-owned calculation editing, dirty-state handling, independent project copies, UUID-based project identity, or the macOS Project Library recovery workflow; these are established and tested.
5. Proceed to **physical iPhone / Files / iCloud Drive document-provider testing**.
6. Then test **Mac ↔ iPhone portability** of both `.eccalc` and `.ecproject` documents.
7. Treat the `.ecproject` file as authoritative project data and the persistent project UUID as authoritative identity.
8. Add security-scoped-bookmark hardening only if real physical-device/document-provider testing demonstrates that the existing persistent file access is insufficient.

# CHECKPOINT SUMMARY

The portable-document architecture now covers standalone calculation persistence, material reconciliation, project persistence, persistent Project Library, project-owned calculation opening/editing, explicit dirty-state handling, independent copies, UUID-based duplicate detection, and macOS Project Library relaunch/recovery behaviour.

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
- editing a project-owned calculation marks it dirty; leaving it prompts Update Project / Discard Changes / Cancel;
- updating a calculation changes the in-memory project but does not silently overwrite the `.ecproject` file;
- leaving a dirty project prompts Save / Don't Save / Cancel;
- Don't Save returns to the last persisted project state;
- a newly created independent copy is dirty until explicitly saved;
- Project Library identity survives `ProjectLibraryStore` reload in automated coverage;
- localization/tooltips remain established infrastructure using `Localizable.xcstrings`.

# AUTOMATED TEST STATUS

The full user-run Xcode suite is green at **183/183**.

Coverage includes:

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

# MACOS PROJECT LIBRARY PERSISTENCE / RECOVERY — VERIFIED 24 SEPTEMBER 2026

The previously outstanding real application-lifecycle and filesystem recovery tests have now been completed successfully.

Manually verified:

- [x] Catalogue/open a real `.ecproject` through the normal macOS workflow.
- [x] Fully terminate Engineering Calculator and relaunch it.
- [x] Reopen the project successfully from Project Library after relaunch.
- [x] Rename/move the project within the filesystem and confirm the application continues to track it.
- [x] Permanently delete the referenced original and confirm the project becomes unavailable rather than being silently replaced.
- [x] Create an independently copied, byte-identical recovery `.ecproject` and verify its bytes before the destructive test.
- [x] Use **Find Project** to reconnect the missing Project Library entry to that identical copy.
- [x] Attempt to substitute a different project and confirm the project/fingerprint checks reject it.
- [x] Fully quit/relaunch again and confirm the recovered project remains linked and opens normally.

## Interpretation

The existing macOS persistent reference mechanism is robust enough for the tested local-filesystem lifecycle. A normal Finder rename/move does **not** require Find Project.

**Find Project remains useful as an exceptional recovery/migration mechanism** when the original file has been deleted or become inaccessible but an identical/restored copy exists elsewhere. The identity/fingerprint checks prevent it from silently reconnecting the catalogue entry to an unrelated project.

Do **not** add security-scoped-bookmark complexity merely because it was previously anticipated. The current macOS behaviour is working. Security-scoped bookmarks remain a fallback if physical-device, iCloud Drive or other document-provider testing demonstrates a real persistence/access failure.

# STILL REQUIRING INTEGRATION / MANUAL COVERAGE

Do not infer the following solely from the 183 green tests or the successful macOS local-filesystem testing:

- real document-picker/Files/iCloud-provider behaviour on a physical iPhone/iPad;
- persistent access after physical-device termination/relaunch;
- iCloud/document-provider move/rename/offline/access behaviour;
- cross-device Mac ↔ iPhone portability;
- complete tooltip/accessibility and localization audit;
- final light/dark mode and interface-density visual checks for the project workflow.

# EXACT NEXT VALIDATION PHASE — PHYSICAL IPHONE / DOCUMENT PROVIDERS

Required workflow:

1. Install and launch the current build on a physical iPhone.
2. Verify Project Library layout, navigation and controls at phone width.
3. Create a named project on iPhone and verify rename behaviour persists.
4. Save/export `.eccalc` and `.ecproject` files through Files/iCloud Drive and confirm correct extensions.
5. Import/open `.eccalc` and `.ecproject` through the iOS document picker.
6. Verify project-owned Pipe Weight & Buoyancy cases restore every input/layer/material correctly.
7. Open → edit → Update Project → Save Project → terminate app → relaunch → reopen and verify edited state/results persist.
8. Verify embedded project materials do not silently populate or overwrite the global Material Library.
9. Exercise moved/renamed/deleted project files through the actual document provider where practical.
10. If persistent access fails, investigate security-scoped bookmark persistence/resolution; otherwise leave the simpler working mechanism intact.
11. Proceed to Mac ↔ iPhone portability testing.

# CROSS-DEVICE PORTABILITY AFTER PHYSICAL-DEVICE VALIDATION

- [ ] Mac → iPhone `.eccalc` with a clean/different local material library reproduces the saved result.
- [ ] Mac → iPhone `.ecproject` reproduces project calculations without originating library materials.
- [ ] Repeat iPhone → Mac.
- [ ] Exercise the same project through iCloud Drive where practical.
- [ ] Confirm the portable file remains authoritative and no device-local material library is required to reproduce the calculation.

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

Persistent external-file access must respect platform sandboxing/document-provider behaviour. The tested macOS local-filesystem mechanism currently survives relaunch and file moves. Add security-scoped bookmark persistence only if another supported environment demonstrates that it is necessary.

## Material reconciliation

- UUID absent: genuinely new material may be added/embedded retaining identity.
- UUID present and content identical: reuse/deduplicate.
- UUID present but content differs: report a conflict; never silently overwrite.
- Imported data must not gain protected built-in status from untrusted metadata.
- Historical calculations continue using their embedded definition unless the user deliberately adopts a different definition.

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

Earlier recovery branch:

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

The 171-test checkpoint branch remains useful for historical recovery, but it predates the completed project lifecycle/dirty-state and recovery work. Prefer the current feature branch for ongoing development.
