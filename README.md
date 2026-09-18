# Engineering Calculator v0.2

A modular SwiftUI engineering-calculation app for iOS and macOS.

## v0.2 changes
- Added calculated layer-stack summary from the same intermediate values used by the calculation engine.
- Layer table shows layer number, name, ID, thickness, OD, density, area and mass per metre.
- Added external-layer reordering and direct deletion.
- Pipe wall remains fixed as the innermost Layer 1.
- Added app-wide Interface Density setting: Compact, Standard and Comfortable.
- Compact is the default and reduces engineering-form text, row spacing, controls and data-table density.
- Interface setting persists using AppStorage and is available from the landing-page gear button.
- Text uses scalable SwiftUI fonts so iOS accessibility text scaling remains available.
- Added generated iOS launch-screen configuration and explicit supported orientations.
- Expanded unit tests for layer continuity, total mass and reordering.

## Calculation convention
Dry pipe mass/weight excludes internal contents and buoyancy.

Submerged weight is:

`(pipe mass + internal contents mass - displaced external-fluid mass) × g`

with `g = 9.80665 m/s²`.
