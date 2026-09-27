# Engineering Calculator — Development Status & Roadmap

**Last updated:** 26 September 2026  
**Status:** **SAFE HOLD POINT — physical iPhone/iCloud and bidirectional Mac ↔ iPhone portability verified; 183-test checkpoint green**  
**Active development branch:** `feature/portable-calculation-documents`  
**Earlier recovery branch:** `checkpoint/project-library-171-tests`  
**Current focus:** portable calculation/project document milestone validated; select next roadmap phase  
**Last user-verified automated checkpoint:** **183 tests passed, 0 failures**

Read `AGENTS.md` first, then this file whenever resuming or refreshing development status.

# RESUME HERE

This is the authoritative restart point.

1. Confirm branch `feature/portable-calculation-documents`.
2. Run `git pull`, `git status`, and `git branch --show-current`.
3. Build the macOS target and run the complete suite with **⌘U** before/after substantive changes. Expected baseline: **183/183 tests passing**.
4. Physical iPhone / Files / iCloud Drive validation and bidirectional Mac ↔ iPhone portability of `.eccalc` and `.ecproject` have now been manually verified.
5. Do **not** reimplement standalone in-place Save/Save As, project-owned calculation editing, dirty-state handling, independent project copies, UUID-based project identity, or the Project Library recovery workflow; these are established and tested.
6. Treat `.eccalc` / `.ecproject` files as authoritative portable engineering data and persistent UUIDs as authoritative identity.
7. The Project Library is cached catalogue metadata; externally changed project metadata may remain stale until the authoritative project is opened, after which the library refreshes correctly.
8. Select the next roadmap phase rather than adding more portability infrastructure without a demonstrated failure.

# CHECKPOINT SUMMARY

The portable-document architecture now covers standalone calculation persistence, material reconciliation, project persistence, persistent Project Library, project-owned calculation opening/editing, explicit dirty-state handling, independent copies, UUID-based duplicate detection, macOS Project Library relaunch/recovery behaviour, physical iPhone document-provider operation, and bidirectional Mac ↔ iPhone portability through iCloud Drive.

User-verified at this checkpoint:

- **183 tests passed, 0 failures** in the complete Xcode test suite after the iOS Save/Save As changes;
- standalone Pipe Weight & Buoyancy `.eccalc` save/export/open works, including multi-layer cases;
- `.eccalc` and `.ecproject` extensions are appended/registered correctly through the implemented document workflow;
- iOS standalone calculations support true in-place **Save** to an opened document and **Save As…** for an independent file;
- Save As creates an independent file association, and subsequent Save operations update only the file actually opened/selected;
- standalone document/calculation identity is preserved during in-place Save and Save As from an opened calculation;
- `.eccalc` data edited on Mac reopens correctly on iPhone, and the reverse portability path is verified;
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
- physical iPhone project opening reads the current authoritative `.ecproject` even when cached Project Library metadata was created before an external Mac edit;
- after opening an externally modified project, the Project Library refreshes its cached calculation count correctly;
- Mac → iPhone `.ecproject` changes, including newly added cases, were verified with correct values;
- iPhone → Mac `.ecproject` changes were verified by adding a case and deleting an existing case on iPhone, with the resulting project opening correctly on Mac;
- localization/tooltips remain established infrastructure using `Localizable.xcstrings`.

# AUTOMATED TEST STATUS

The full user-run Xcode suite is green at **183/183** after the physical-device Save/Save As implementation.

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

**Find Project remains an exceptional recovery/migration mechanism** when the original file has been deleted or become inaccessible but an identical/restored copy exists elsewhere. Identity/fingerprint checks prevent reconnection to an unrelated project.

# PHYSICAL IPHONE / ICLOUD / CROSS-DEVICE VALIDATION — VERIFIED 26 SEPTEMBER 2026

The previously outstanding physical-device and cross-device portability phase has now been completed successfully.

## Standalone `.eccalc`

- [x] Current branch builds and runs on a physical iPhone.
- [x] Fixed macOS-only bookmark options so shared Project Library code compiles on iOS while retaining macOS security-scoped bookmark behaviour.
- [x] Save/export through Files/iCloud Drive produces a valid `.eccalc` document.
- [x] Saved calculation reopens on iPhone with inputs, layers, embedded materials and results intact.
- [x] iPhone-created calculation opens correctly on Mac.
- [x] Mac modifications are visible when the same calculation is reopened on iPhone.
- [x] iOS duplicate-file `OSStatus -48` behaviour from exporter replacement was avoided by implementing true document-style in-place Save.
- [x] Opened standalone calculations retain their file URL and use security-scoped access for in-place Save.
- [x] Save As remains available for deliberately creating a separate file.
- [x] Two independently saved/opened `.eccalc` files were modified and reopened; changes remained isolated to the intended file.
- [x] Full regression suite remained **183/183 passing** after these changes.

## Project `.ecproject`

- [x] Mac-modified project opened on iPhone with all current calculations and correct values.
- [x] Adding another project case on Mac was correctly reflected when the authoritative project was subsequently opened on iPhone.
- [x] Project Library initially displayed its cached/last-known calculation count after an external edit; after opening the project it refreshed to the current count as designed.
- [x] Added a case on iPhone, deleted an existing case, saved the project, then opened it on Mac; additions/deletions and remaining calculation data were correct.
- [x] Bidirectional Mac ↔ iPhone project portability through iCloud Drive is therefore verified.

### Observation retained for future regression testing

During one early iPhone attempt to open a Mac-updated project, the app reported that it did not have access to the file. A second attempt opened the current file correctly. This was **not reproduced** in the subsequent cold-start/cross-device testing, where the current project opened normally. Treat this as an unreproduced observation rather than a confirmed defect; investigate only if it recurs.

# REMAINING MANUAL / INTEGRATION COVERAGE

The core portability milestone is complete. Remaining useful coverage is non-blocking unless a regression appears:

- iCloud/document-provider move/rename/offline behaviour on physical iPhone/iPad;
- longer-term persistent access across provider/account state changes;
- complete tooltip/accessibility and localization audit;
- final light/dark mode and interface-density visual checks for the project workflow;
- repeat cross-device tests as regression coverage after future persistence/schema changes.

# ARCHITECTURE DECISIONS TO PRESERVE

## Portable document authority

A transferred standalone calculation or project must be wholly self-contained. Embedded material definitions are part of the engineering record and authoritative for reproducing the saved state. A changed local Material Library must not silently alter a historical calculation.

Standalone calculations use `.eccalc`; projects use `.ecproject`.

## Standalone Save / Save As semantics

An opened standalone calculation retains its source URL and supports true in-place **Save**. **Save As…** deliberately creates/selects another file. In-place saves use security-scoped resource access where supplied by the document provider and preserve the existing document/calculation UUID identity.

Do not revert to using exporter replacement as the normal Save path on iOS; physical-device testing demonstrated an `OSStatus -48` duplicate-file failure when attempting to replace an existing file that way.

## Project ownership and save boundaries

A calculation contained in a project is project-owned data. Importing a standalone `.eccalc` copies its persisted calculation/material state into the project; subsequent project edits do not mutate the original standalone file.

Editing a project calculation first changes working/in-memory state. Updating the project case commits that working calculation into the in-memory project. Saving the project commits the in-memory project to the authoritative `.ecproject` file. These boundaries are deliberate because automatic file writes would remove the user's ability to discard work while no general undo/version-history system exists.

## Project identity

Persistent project UUID is authoritative identity. Filename, displayed title and URL/location are mutable metadata and must not be used as logical identity.

Opening another file representing the same project UUID must not silently create a second logical Project Library project. An independent copy must receive a new project UUID.

## Project Library authority

The Project Library is a catalogue, not a second copy of project data. The `.ecproject` file remains authoritative. Catalogue metadata may include project UUID, title, file location, calculation count and modified date.

Cached metadata may be stale after another device modifies the authoritative file. This is acceptable provided opening the project reads the current `.ecproject` and refreshes the catalogue metadata, which physical-device testing verified.

Persistent external-file access must respect platform sandboxing/document-provider behaviour. Security-scoped bookmark resolution is platform-conditional where required, and imported/opened iOS document URLs use security-scoped resource access.

## Material reconciliation

- UUID absent: genuinely new material may be added/embedded retaining identity.
- UUID present and content identical: reuse/deduplicate.
- UUID present but content differs: report a conflict; never silently overwrite.
- Imported data must not gain protected built-in status from untrusted metadata.
- Historical calculations continue using their embedded definition unless the user deliberately adopts a different definition.

# DEFERRED ROADMAP — NEXT PHASE SELECTION

Portable document/project infrastructure has reached a validated cross-device checkpoint. Candidate next phases include:

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

The 171-test checkpoint branch remains useful for historical recovery, but it predates the completed project lifecycle/dirty-state, recovery and physical-device portability work. Prefer the current feature branch for ongoing development.
