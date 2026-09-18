# Engineering Calculator v0.2

A modular SwiftUI engineering-calculation app for iOS and macOS.

## v0.2 changes
- Added an auditable layer-stack summary generated from the actual calculation intermediates.
- Table shows layer number, name, ID, thickness, OD, density, cross-sectional area and mass per metre.
- Added per-layer calculated result model.
- Added Move Up / Move Down controls for external layers.
- Added direct layer deletion using a trash control.
- Pipe wall is always the fixed innermost Layer 1 and cannot be deleted or moved.
- Added editable pipe-layer name.
- Expanded unit tests for layer continuity, total mass and reordering.
- Retains the v0.1 modular landing page and persistent calculator ordering.

## Calculation convention
The dry pipe result excludes internal contents and buoyancy.

The submerged result is:

`(pipe mass + internal contents mass - displaced external-fluid mass) × g`

with `g = 9.80665 m/s²`.

## Adding another calculator
1. Add its pure-Swift calculation/model file.
2. Add its SwiftUI view.
3. Add a `CalculationDefinition` to `CalculationRegistry.all`.
4. Add its destination to the switch in `HomeView`.
5. Add unit tests for the equations.
