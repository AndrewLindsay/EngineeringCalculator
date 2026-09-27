# Material Requirement Validation

This phase introduces a common API for calculators to declare which material properties they require before a calculation is allowed to proceed.

## Implemented

- `MaterialPropertyRequirement` declares a property, required/optional level, optional fixed temperature, and purpose.
- `MaterialRequirementSet` groups requirements for a calculation.
- `MaterialRequirementValidator` validates one or many materials through the existing `MaterialPropertyResolver`.
- Required unresolved properties produce errors and block calculation (`canCalculate == false`).
- Optional unresolved properties produce warnings but do not block calculation.
- Validation preserves the material name, property, requested temperature and failure reason for UI reporting.
- Standard requirement sets currently cover mass/weight, steady-state conduction, transient thermal calculations and linear elasticity.

## Deterministic validation materials

Synthetic materials are deliberately kept in the test target rather than the production material library. Fixtures include:

- complete thermal/mechanical material
- density-only material
- missing-density material
- missing-conductivity material
- missing-heat-capacity material
- empty material
- tabulated conductivity material (0–100 °C)
- bounded polynomial conductivity material (0–100 °C)
- extrapolating polynomial conductivity material

These fixtures provide known behaviour and should be expanded as calculators are added.

## Automated checks

The test target now checks:

1. complete transient-thermal material passes
2. missing density blocks calculation
3. missing thermal conductivity blocks calculation
4. missing heat capacity blocks calculation
5. multiple missing properties are reported together
6. temperature-required state is reported
7. tabulated property inside range passes
8. tabulated property outside range blocks calculation
9. bounded equation inside range passes
10. bounded equation outside range blocks calculation
11. permitted equation extrapolation passes
12. missing optional property warns but does not block
13. multi-material validation identifies only the invalid material
14. linear-elastic requirements enforce Young's modulus and Poisson's ratio

## Local test procedure

Checkout and update the branch:

```bash
git fetch origin
git switch feature/material-requirement-validation
git pull
```

In Xcode select the EngineeringCalculator scheme and run **Product > Test** (Command-U). Review the Test navigator and confirm all existing tests plus the material requirement validation tests pass.

The next integration step is to make the first production calculator declare a `MaterialRequirementSet`, validate selected materials before calculating, and display `MaterialValidationIssue.message` to the user when data are unavailable.
