# Engineering Calculator v0.1

A modular SwiftUI engineering-calculation app for iOS and macOS.

## v0.1
- Rearrangeable calculation landing page
- Persistent calculator order using AppStorage
- Pipe Weight & Buoyancy calculator
- Internal diameter or radius input
- Pipe wall plus optional concentric coating/weight layers
- Dry pipe mass and weight per metre
- Internal contents mass
- External-fluid displacement
- Net submerged mass equivalent and submerged weight
- XCTest calculation tests

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

## Git
After opening the project, initialize Git from Terminal:

    cd /path/to/EngineeringCalculator_v0_1
    git init
    git add .
    git commit -m "Engineering Calculator v0.1"

Then create an empty GitHub repository and add its remote.
