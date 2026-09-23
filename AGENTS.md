# Engineering Calculator — Development Working Directives

This file defines the persistent working rules for development of the Engineering Calculator project. It describes **how development should be carried out**. The current project state, completed work, known issues, test baseline and roadmap belong in `DEVELOPMENT_STATUS.md`.

## Mandatory session startup / refresh procedure

At the beginning of an Engineering Calculator development session, and **whenever the user says `refresh`**, do the following before proposing or making development changes:

1. Read this `AGENTS.md` file.
2. Read the current `DEVELOPMENT_STATUS.md` from the active GitHub branch.
3. Confirm the active development branch and use the current GitHub repository state as the source of truth.
4. Establish the last tested checkpoint, known issues, current test baseline and exact next task from `DEVELOPMENT_STATUS.md`.
5. Do not reconstruct project state from old chat excerpts when current repository information is available.

Repository: `AndrewLindsay/EngineeringCalculator`

The active branch may change over time. `DEVELOPMENT_STATUS.md` should state the branch currently in use. Do not assume stale `main` or another branch is authoritative when a feature branch is documented as active.

## Source of truth and repository workflow

- GitHub is the authoritative development source for this project.
- Work from the latest files on the active branch before modifying code.
- Preserve the existing project and its history through incremental commits; do not replace the project with a newly generated project unless explicitly required.
- When repository access is available, make requested code changes directly in GitHub rather than asking the user to paste large replacement files into Xcode.
- Use meaningful commit messages that describe the actual feature, fix or documentation change.
- The user normally pulls the committed changes locally and tests them before a feature is declared complete.
- Do not declare a UI or functional change complete merely because it compiles; use the user's local test results as the acceptance checkpoint when manual behaviour is involved.
- At stable checkpoints, the local working tree should ideally be clean and synchronized with the remote branch.

Typical local synchronization:

```bash
git pull
git branch --show-current
git status
```

Typical manual commit workflow when the user has local changes:

```bash
git status
git add .
git commit -m "Description of changes"
git push
```

## DEVELOPMENT_STATUS.md is mandatory

`DEVELOPMENT_STATUS.md` is the project handover, development history and forward roadmap.

Update it at **every significant checkpoint**, including when:

- a development phase or substantial sub-phase is completed;
- a significant feature is implemented and tested;
- the architecture or data model changes materially;
- an important UI design is accepted;
- a significant bug is resolved;
- a development approach is rejected and is worth recording so it is not repeated;
- the automated test baseline changes;
- the active branch or restart procedure changes;
- priorities or the development path ahead change;
- development is about to switch to another project or focus for a meaningful period.

A checkpoint update should record, as applicable:

- date;
- active branch;
- what was implemented;
- what was tested and on which platform;
- automated test count/baseline and whether it passed;
- relevant manual acceptance testing;
- important architecture/design decisions;
- known limitations or unresolved issues;
- rejected approaches worth remembering;
- relevant commits/checkpoints;
- the exact next development task and its intended order.

The document should contain enough information that development can stop for weeks or months and later resume without needing the previous ChatGPT conversation.

## README responsibility

`README.md` is the concise project overview. Keep it useful for understanding the application, major capabilities, build/development basics and where to find further information.

Do not turn the README into the detailed development diary. Detailed project state and roadmap belong in `DEVELOPMENT_STATUS.md`; persistent working rules belong here in `AGENTS.md`.

## Testing and validation

- Run the regression suite before and after substantial framework/calculation changes where practical.
- Maintain deterministic unit tests for calculation and material-property logic.
- Add automated tests when a behaviour can be reliably tested in code instead of relying only on manual UI checks.
- Preserve established tests unless requirements intentionally change; update tests and documentation together when expected behaviour changes.
- Engineering validation fixtures should use predetermined values with analytically checkable results wherever possible.
- A significant feature is not considered complete until relevant automated tests pass and required manual UI/behaviour checks have been performed.
- Record the confirmed test baseline in `DEVELOPMENT_STATUS.md`.

## Engineering architecture principles

- Keep engineering/calculation/business logic separate from SwiftUI presentation.
- Prefer reusable pure-Swift models, engines and resolvers that can be unit tested independently.
- UI views should consume structured results rather than becoming the source of engineering truth.
- Reporting/export should consume underlying comparison/calculation models rather than scraping or screenshotting UI views.
- Preserve raw engineering values and units separately from display formatting.
- Never silently treat a missing engineering property as zero.
- Use engineering-aware numerical tolerances where equality/comparison requires them rather than formatted-string equality.
- Preserve source, basis, applicability, product form, condition, units, temperature ranges and other traceability information where relevant.
- Avoid implying precision or applicability that is not supported by the underlying engineering source.

## Material-property framework principles

The reusable material/property framework is foundational infrastructure for subsequent calculators.

- Stabilize and validate the material-property framework before expanding substantially into new calculators.
- Built-in and user materials should use the same shared engineering material model wherever possible.
- Temperature-dependent properties must retain their underlying representation and metadata, including tables/equations, coefficients, reference values/temperatures, valid ranges, extrapolation rules and traceability.
- Material persistence/import/export must preserve engineering meaning across round trips.
- Protected built-in data must not accidentally become editable/protected user data through import/export operations.
- Calculators should obtain material values through the shared resolver rather than duplicating material-property logic.

## Cross-platform approach

- Maintain one multiplatform SwiftUI project/codebase for macOS and iOS where practical.
- Share engineering models, calculations, persistence and tests across platforms.
- Platform-specific UI is acceptable and encouraged when desktop and phone interaction requirements differ.
- Do not force a desktop interaction model onto iPhone merely for code uniformity.
- macOS can use desktop-appropriate features such as resizable windows, adjustable/frozen table columns, menus and printing.
- iOS should use compact/adaptive presentation appropriate to the available screen.
- Platform conditionals should primarily isolate genuine platform-specific presentation/integration rather than duplicate engineering logic.

## UI development principles

- Preserve existing working functionality while adding new features unless behaviour is deliberately being changed.
- Prefer adaptive layouts over hard-coded layouts where practical.
- For engineering tables, prioritize readability, traceability and useful data density over decorative presentation.
- Long engineering text, units and multiline headings must remain readable on supported platforms.
- **Every interactive button and icon should have concise explanatory help text as a standard UI feature.** On macOS/iPadOS pointer environments, provide meaningful hover/tool-tip help (for SwiftUI controls, normally `.help(...)`); do not rely on the SF Symbol alone when its meaning could be ambiguous. Prefer action-oriented wording such as `Update Project Case`, `Open Calculation`, `Delete Material`, or `Move Up`. Where hover is unavailable, retain an appropriate accessibility label/description so icon-only controls remain understandable to assistive technologies.
- When an implementation proves structurally unsuitable, replace the problematic architecture rather than indefinitely layering compensating offsets/workarounds on top of it.
- Record important rejected approaches in `DEVELOPMENT_STATUS.md` when doing so will prevent the same dead end being repeated later.

## Change discipline

Before making a substantial change:

1. Read the relevant current repository files.
2. Check `DEVELOPMENT_STATUS.md` for dependencies, known issues and prior decisions.
3. Preserve tested behaviour not involved in the requested change.
4. Keep the change as focused as reasonably possible.
5. Add/update tests where appropriate.

After making a substantial change:

1. Commit it to the active branch with a descriptive message.
2. Tell the user what changed and provide the appropriate `git pull` workflow.
3. Ask the user to build/test the behaviours that cannot be conclusively validated through repository tooling alone.
4. Resolve test/build/UI regressions before declaring the checkpoint complete.
5. Update `DEVELOPMENT_STATUS.md` once the significant checkpoint is confirmed.

## Significant checkpoint definition

A significant checkpoint is not every small corrective commit. It is a point at which the project has gained a tested capability, completed a planned development step, made an architectural decision, or reached a stable state worth returning to later.

Multiple small build fixes made while converging on one feature may be summarized together in the status document once the feature is tested and accepted.

## Project resumption rule

When returning after working on another project, do not rely on conversational memory to decide what to do next.

Read, in this order:

1. `AGENTS.md` — development rules.
2. `DEVELOPMENT_STATUS.md` — current checkpoint and roadmap.
3. `README.md` — project overview as needed.
4. Relevant current source/tests on the active branch.

Then continue from the documented **next task** unless the user explicitly changes priorities.
