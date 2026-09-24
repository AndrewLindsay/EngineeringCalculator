# Engineering Calculator

A modular SwiftUI engineering-calculation app for iOS and macOS.

> **Development agents/contributors:** Read `AGENTS.md` first, then `DEVELOPMENT_STATUS.md`. When the user says **refresh**, read both before continuing development.

## Current development status — SAFE HOLD POINT — 24 September 2026

**Active development branch:** `feature/portable-calculation-documents`  
**Earlier recovery branch:** `checkpoint/project-library-171-tests`  
**Current focus:** portable, self-contained calculation/project documents and cross-platform validation.  
**Last user-verified automated checkpoint:** **183 tests passed, 0 failures** on macOS/Xcode.

The portable project lifecycle is now established and the macOS Project Library persistence/recovery workflow has been manually verified. The next major validation phase is physical-iPhone/document-provider testing followed by Mac ↔ iPhone portability testing.

## Verified at this checkpoint

Completed and user-verified through the current hold point:

- shared Engineering Materials Library with built-in and user materials;
- portable `.ecmaterial` / `.ecmaterials` material import/export;
- temperature-dependent property resolver with constants, tables and equations;
- reusable material comparison and material-requirement frameworks;
- material-property validation that blocks calculations when required engineering data is unavailable;
- Pipe Weight & Buoyancy and Multilayer Pipe Heat Transfer material-aware integration;
- versioned portable calculation persistence with stable calculation/input/output identifiers;
- complete embedded material definitions and canonical material fingerprinting;
- material reconciliation/conflict handling without silently overwriting local materials;
- deterministic portable calculation regression cases for build-to-build comparison;
- standalone `.eccalc` save/export/open support, including multiple Pipe Weight & Buoyancy layers;
- `.eccalc` and `.ecproject` UTType/extension registration and automatic extension handling;
- atomic standalone-calculation import into projects;
- project calculation/material round-trip persistence and shared-material deduplication;
- Project Library creation, import/open, metadata catalogue and project rename;
- project identity based on persistent UUID rather than filename/path;
- same-project UUID detection across different filenames/locations;
- independent project copies with new UUIDs while retaining calculations/materials;
- project-owned Pipe Weight & Buoyancy cases opening in the live calculator using embedded material snapshots;
- project-owned calculation editing, explicit Update Project behaviour and transactional persistence;
- dirty-state handling with Update/Discard/Cancel and Save/Don't Save/Cancel boundaries;
- **183/183 complete Xcode regression suite passing**.

## Project Library persistence and recovery — manually verified 24 September 2026

The macOS Project Library has now been exercised through real filesystem and application-lifecycle tests:

- a catalogued `.ecproject` remains accessible after fully quitting and relaunching Engineering Calculator;
- renaming or moving the project within the filesystem does not break the Project Library reference;
- permanently deleting the referenced project makes the entry unavailable rather than silently creating/substituting data;
- **Find Project** can reconnect the library entry to an independently copied, byte-identical `.ecproject`;
- selecting a different project as the replacement is rejected by the project/fingerprint identity checks;
- the recovered link remains valid after another complete quit/relaunch.

This means additional security-scoped-bookmark work is **not currently justified on macOS**. Retain it as a fallback if physical-device, Files/iCloud Drive or other document-provider testing exposes a persistence/access problem.

**Purpose of Find Project:** this is an exceptional recovery/migration mechanism, not a normal move/rename workflow. It is useful when the original referenced file has been deleted or become inaccessible but an identical/restored copy exists elsewhere.

## Resume here — next validation phase

1. Confirm branch `feature/portable-calculation-documents`.
2. Run `git pull`, `git status`, and `git branch --show-current`.
3. Run the complete Xcode suite with **⌘U**. Expected baseline: **183/183**.
4. Install/run the current build on a physical iPhone.
5. Exercise Project Library layout/navigation and create/save/open workflows at phone size.
6. Test `.eccalc` and `.ecproject` through Files/iCloud Drive/document picker.
7. Test project-owned calculation open → edit → update → save → terminate → relaunch → reopen.
8. Verify embedded project materials remain authoritative and do not silently overwrite the global Material Library.
9. Test Mac → iPhone and iPhone → Mac portability, preferably including iCloud Drive.
10. Only add security-scoped-bookmark hardening if these real document-provider tests demonstrate that it is required.

Do not begin the deferred calculator roadmap before the portable project/document lifecycle is validated across the target platforms.

## Architecture principles

### Material validation

Calculators explicitly declare the material properties they require. Missing or unresolvable required engineering data must produce an actionable warning and block the result; it must not be silently replaced with zero or an arbitrary default.

### Portable documents

A transferred standalone calculation or project must reproduce its saved engineering state without access to the originating material library. Embedded material definitions form part of the saved engineering record. Opening a historical document must not silently replace its embedded definition with a changed local-library definition.

Standalone calculations use `.eccalc`; projects use `.ecproject`.

### Project identity and authority

The persistent project UUID is authoritative identity. Filename, displayed title and URL/location are mutable metadata. The `.ecproject` file is authoritative project data; Project Library is a catalogue/locator rather than a second copy of the project.

## Development workflow

At the start of the next session:

```bash
git pull
git status
git branch --show-current
```

Expected branch:

```text
feature/portable-calculation-documents
```

Run the complete regression suite with **⌘U** before substantial new changes. Current expected result:

```text
183 tests passed, 0 failures
```

When a tested local change needs committing manually:

```bash
git status
git add .
git commit -m "Description of changes"
git push
```

For the detailed checkpoint, architecture decisions, exact automated/manual test status and roadmap, see `DEVELOPMENT_STATUS.md`.
