import XCTest
@testable import EngineeringCalculator

final class PipeWeightBuoyancyCalculatorTests: XCTestCase {
    func testBareSteelPipe() {
        let result = PipeWeightBuoyancyCalculator.calculate(
            internalDiameterM: 0.300,
            layers: [PipeLayer(name: "Steel", thicknessM: 0.020, densityKgM3: 7850)],
            internalFluidDensityKgM3: 1000,
            externalFluidDensityKgM3: 1025
        )
        XCTAssertEqual(result.finalOuterDiameterM, 0.340, accuracy: 1e-12)
        XCTAssertEqual(result.layers.count, 1)
        XCTAssertEqual(result.layers[0].innerDiameterM, 0.300, accuracy: 1e-12)
        XCTAssertEqual(result.layers[0].outerDiameterM, 0.340, accuracy: 1e-12)
        XCTAssertGreaterThan(result.pipeMassKgPerM, 0)
    }

    func testCalculatedLayerStackIsContinuous() {
        let result = PipeWeightBuoyancyCalculator.calculate(
            internalDiameterM: 0.300,
            layers: [
                PipeLayer(name: "Steel", thicknessM: 0.020, densityKgM3: 7850),
                PipeLayer(name: "Coating", thicknessM: 0.003, densityKgM3: 1250),
                PipeLayer(name: "Concrete", thicknessM: 0.050, densityKgM3: 3040)
            ],
            internalFluidDensityKgM3: 1000,
            externalFluidDensityKgM3: 1025
        )
        XCTAssertEqual(result.layers.count, 3)
        XCTAssertEqual(result.layers[0].outerDiameterM, result.layers[1].innerDiameterM, accuracy: 1e-12)
        XCTAssertEqual(result.layers[1].outerDiameterM, result.layers[2].innerDiameterM, accuracy: 1e-12)
        XCTAssertEqual(result.finalOuterDiameterM, 0.446, accuracy: 1e-12)
    }

    func testPipeMassEqualsSumOfLayerMasses() {
        let result = PipeWeightBuoyancyCalculator.calculate(
            internalDiameterM: 0.250,
            layers: [
                PipeLayer(name: "Steel", thicknessM: 0.015, densityKgM3: 7850),
                PipeLayer(name: "Coating", thicknessM: 0.004, densityKgM3: 1200)
            ],
            internalFluidDensityKgM3: 900,
            externalFluidDensityKgM3: 1025
        )
        let sum = result.layers.reduce(0) { $0 + $1.massKgPerM }
        XCTAssertEqual(result.pipeMassKgPerM, sum, accuracy: 1e-12)
    }

    func testReorderingDifferentDensityLayersChangesMassDistributionButNotFinalOD() {
        let a = PipeLayer(name: "A", thicknessM: 0.010, densityKgM3: 1000)
        let b = PipeLayer(name: "B", thicknessM: 0.020, densityKgM3: 3000)
        let first = PipeWeightBuoyancyCalculator.calculate(internalDiameterM: 0.300, layers: [a, b], internalFluidDensityKgM3: 0, externalFluidDensityKgM3: 1025)
        let second = PipeWeightBuoyancyCalculator.calculate(internalDiameterM: 0.300, layers: [b, a], internalFluidDensityKgM3: 0, externalFluidDensityKgM3: 1025)
        XCTAssertEqual(first.finalOuterDiameterM, second.finalOuterDiameterM, accuracy: 1e-12)
        XCTAssertNotEqual(first.pipeMassKgPerM, second.pipeMassKgPerM)
    }
}

extension PipeWeightBuoyancyCalculatorTests {
    func testSharedPipeConstructionMatchesLegacyInputs() {
        let layers = [
            PipeLayer(name: "Steel", thicknessM: 0.020, densityKgM3: 7850),
            PipeLayer(name: "Coating", thicknessM: 0.003, densityKgM3: 1250)
        ]
        let legacy = PipeWeightBuoyancyCalculator.calculate(internalDiameterM: 0.300, layers: layers, internalFluidDensityKgM3: 1000, externalFluidDensityKgM3: 1025)
        let construction = PipeConstruction(name: "Regression Pipe", internalDiameterM: 0.300, layers: layers, internalFluid: FluidDefinition(name: "Water", densityKgM3: 1000), externalFluid: FluidDefinition(name: "Seawater", densityKgM3: 1025))
        let shared = PipeWeightBuoyancyCalculator.calculate(construction: construction)
        XCTAssertEqual(shared.finalOuterDiameterM, legacy.finalOuterDiameterM, accuracy: 1e-12)
        XCTAssertEqual(shared.pipeMassKgPerM, legacy.pipeMassKgPerM, accuracy: 1e-12)
        XCTAssertEqual(shared.contentsMassKgPerM, legacy.contentsMassKgPerM, accuracy: 1e-12)
        XCTAssertEqual(shared.displacedMassKgPerM, legacy.displacedMassKgPerM, accuracy: 1e-12)
        XCTAssertEqual(shared.submergedWeightKNPerM, legacy.submergedWeightKNPerM, accuracy: 1e-12)
    }

    func testPipeConstructionRoundTripsThroughJSON() throws {
        let steel = EngineeringMaterial(name: "Carbon Steel", category: "Metal", densityKgM3: 7850, thermalConductivityWMK: 45, specificHeatCapacityJkgK: 475, source: "Editable engineering default")
        let original = PipeConstruction(name: "12-inch Flowline", internalDiameterM: 0.300, layers: [PipeLayer(name: "Steel Pipe", thicknessM: 0.020, material: steel)], internalFluid: FluidDefinition(name: "Process Fluid", densityKgM3: 900, thermalConductivityWMK: 0.12, specificHeatCapacityJkgK: 2200), externalFluid: FluidDefinition(name: "Seawater", densityKgM3: 1025, thermalConductivityWMK: 0.60, specificHeatCapacityJkgK: 3990))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PipeConstruction.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

// MARK: - Deterministic material-property validation fixtures

private enum MaterialValidationFixtures {
    static let constant = EngineeringMaterial(
        name: "TEST – Constant",
        category: "Validation",
        densityKgM3: 8000,
        source: "Deterministic automated-test fixture"
    )

    static let table = EngineeringMaterial(
        name: "TEST – Linear Table",
        category: "Validation",
        youngsModulusSeries: MaterialPropertySeries(
            referenceValue: 200,
            referenceTemperatureC: 0,
            temperatureTable: [
                MaterialPropertyPoint(temperatureC: 0, value: 200),
                MaterialPropertyPoint(temperatureC: 100, value: 180),
                MaterialPropertyPoint(temperatureC: 200, value: 160)
            ],
            source: "Deterministic automated-test fixture",
            basis: "E(T) decreases linearly by 20 GPa per 100 °C."
        )
    )

    static let polynomial = EngineeringMaterial(
        name: "TEST – Polynomial",
        category: "Validation",
        thermalConductivitySeries: MaterialPropertySeries(
            equation: MaterialPropertyEquation(
                a: 10, b: 0.1, c: 0.001, d: 0,
                minimumTemperatureC: 0,
                maximumTemperatureC: 200,
                allowsExtrapolation: false,
                kind: .polynomial
            ),
            source: "Deterministic automated-test fixture",
            basis: "k(T) = 10 + 0.1T + 0.001T²"
        )
    )

    static let tcr = EngineeringMaterial(
        name: "TEST – Relative Linear / TCR",
        category: "Validation",
        electricalResistivitySeries: MaterialPropertySeries(
            referenceValue: 1.0e-6,
            referenceTemperatureC: 20,
            equation: MaterialPropertyEquation(
                minimumTemperatureC: -50,
                maximumTemperatureC: 250,
                allowsExtrapolation: false,
                kind: .relativeLinear,
                referenceValue: 1.0e-6,
                referenceTemperatureC: 20,
                temperatureCoefficient: 0.004
            ),
            source: "Deterministic automated-test fixture",
            basis: "ρ(T) = 1e-6[1 + 0.004(T - 20)] Ω·m"
        )
    )

    static let missing = EngineeringMaterial(
        name: "TEST – Missing Data",
        category: "Validation"
    )

    static let multiProperty = EngineeringMaterial(
        name: "TEST – Multi Property",
        category: "Validation",
        densityKgM3: 7777,
        poissonsRatio: 0.30,
        youngsModulusSeries: MaterialPropertySeries(
            temperatureTable: [
                MaterialPropertyPoint(temperatureC: 0, value: 210),
                MaterialPropertyPoint(temperatureC: 100, value: 190)
            ]
        )
    )
}

// MARK: - Material property tests 1–15

final class MaterialPropertyResolverTests: XCTestCase {
    private let tolerance = 1e-12

    // 1. Constant property: temperature must not alter a scalar value.
    func test01ConstantPropertyIsTemperatureIndependent() {
        let at20 = MaterialPropertyResolver.resolve(.density, in: MaterialValidationFixtures.constant, atTemperatureC: 20)
        let at100 = MaterialPropertyResolver.resolve(.density, in: MaterialValidationFixtures.constant, atTemperatureC: 100)
        XCTAssertEqual(at20.value ?? .nan, 8000, accuracy: tolerance)
        XCTAssertEqual(at100.value ?? .nan, 8000, accuracy: tolerance)
        XCTAssertEqual(at20.method, .constant)
        XCTAssertEqual(at20.status, .resolved)
    }

    // 2. Exact table point.
    func test02ExactTabulatedPoint() {
        let r = MaterialPropertyResolver.resolve(.youngsModulus, in: MaterialValidationFixtures.table, atTemperatureC: 100)
        XCTAssertEqual(r.value ?? .nan, 180, accuracy: tolerance)
        XCTAssertEqual(r.method, .tableExact)
        XCTAssertEqual(r.status, .resolved)
    }

    // 3. Linear interpolation: halfway from 200 to 180 GPa must be 190 GPa.
    func test03LinearInterpolation() {
        let r = MaterialPropertyResolver.resolve(.youngsModulus, in: MaterialValidationFixtures.table, atTemperatureC: 50)
        XCTAssertEqual(r.value ?? .nan, 190, accuracy: tolerance)
        XCTAssertEqual(r.method, .linearInterpolation)
        XCTAssertEqual(r.lowerPoint?.temperatureC ?? .nan, 0, accuracy: tolerance)
        XCTAssertEqual(r.upperPoint?.temperatureC ?? .nan, 100, accuracy: tolerance)
    }

    // 4. Below table range: interpolation must not silently extrapolate.
    func test04BelowTableRangeIsRejected() {
        let r = MaterialPropertyResolver.resolve(.youngsModulus, in: MaterialValidationFixtures.table, atTemperatureC: -1)
        XCTAssertNil(r.value)
        XCTAssertEqual(r.status, .outsideAvailableRange(minimumC: 0, maximumC: 200))
    }

    // 5. Above table range.
    func test05AboveTableRangeIsRejected() {
        let r = MaterialPropertyResolver.resolve(.youngsModulus, in: MaterialValidationFixtures.table, atTemperatureC: 201)
        XCTAssertNil(r.value)
        XCTAssertEqual(r.status, .outsideAvailableRange(minimumC: 0, maximumC: 200))
    }

    // 6. Polynomial: at 100 °C, 10 + 10 + 10 = 30 W/(m·K).
    func test06PolynomialEvaluation() {
        let r = MaterialPropertyResolver.resolve(.thermalConductivity, in: MaterialValidationFixtures.polynomial, atTemperatureC: 100)
        XCTAssertEqual(r.value ?? .nan, 30, accuracy: tolerance)
        XCTAssertEqual(r.method, .equation)
        XCTAssertEqual(r.status, .resolved)
    }

    // 7. Polynomial validity boundaries are inclusive.
    func test07PolynomialBoundariesAreIncluded() {
        let low = MaterialPropertyResolver.resolve(.thermalConductivity, in: MaterialValidationFixtures.polynomial, atTemperatureC: 0)
        let high = MaterialPropertyResolver.resolve(.thermalConductivity, in: MaterialValidationFixtures.polynomial, atTemperatureC: 200)
        XCTAssertEqual(low.value ?? .nan, 10, accuracy: tolerance)
        XCTAssertEqual(high.value ?? .nan, 70, accuracy: tolerance)
        XCTAssertEqual(low.status, .resolved)
        XCTAssertEqual(high.status, .resolved)
    }

    // 8. Polynomial outside its stated range must not extrapolate when disabled.
    func test08PolynomialOutsideRangeIsRejected() {
        for temperature in [-0.001, 200.001] {
            let r = MaterialPropertyResolver.resolve(.thermalConductivity, in: MaterialValidationFixtures.polynomial, atTemperatureC: temperature)
            XCTAssertNil(r.value)
            XCTAssertEqual(r.status, .outsideEquationRange(minimumC: 0, maximumC: 200))
        }
    }

    // 9. TCR at reference temperature must equal rho0 exactly.
    func test09TCRAtReferenceTemperature() {
        let r = MaterialPropertyResolver.resolve(.electricalResistivity, in: MaterialValidationFixtures.tcr, atTemperatureC: 20)
        XCTAssertEqual(r.value ?? .nan, 1.0e-6, accuracy: 1e-15)
        XCTAssertEqual(r.method, .equation)
        XCTAssertFalse(r.isExtrapolated)
    }

    // 10. TCR away from reference: at 120 °C rho = 1.4e-6 ohm.m.
    func test10TCRAwayFromReferenceTemperature() {
        let r = MaterialPropertyResolver.resolve(.electricalResistivity, in: MaterialValidationFixtures.tcr, atTemperatureC: 120)
        XCTAssertEqual(r.value ?? .nan, 1.4e-6, accuracy: 1e-15)
        XCTAssertEqual(r.status, .resolved)
    }

    // 11. Missing/invalid temperature reaches the resolver as nil and must request temperature.
    func test11EquationRequiresTemperature() {
        let r = MaterialPropertyResolver.resolve(.electricalResistivity, in: MaterialValidationFixtures.tcr, atTemperatureC: nil)
        XCTAssertNil(r.value)
        XCTAssertEqual(r.status, .temperatureRequired)
    }

    // 12. A genuinely undefined property must report missing, never zero.
    func test12MissingPropertyReportsMissing() {
        let r = MaterialPropertyResolver.resolve(.yieldStrength, in: MaterialValidationFixtures.missing, atTemperatureC: 20)
        XCTAssertNil(r.value)
        XCTAssertEqual(r.status, .missing)
        XCTAssertFalse(r.isResolved)
    }

    // 13. Available-property discovery must expose only populated properties.
    func test13AvailablePropertiesMatchMaterialData() {
        let properties = Set(MaterialPropertyResolver.availableProperties(in: MaterialValidationFixtures.multiProperty))
        XCTAssertEqual(properties, Set([.density, .youngsModulus, .poissonsRatio]))
    }

    // 14. Resolving one material must never leak state into another material.
    func test14SwitchingMaterialsProducesIndependentResults() {
        let first = MaterialPropertyResolver.resolve(.density, in: MaterialValidationFixtures.constant, atTemperatureC: 20)
        let second = MaterialPropertyResolver.resolve(.density, in: MaterialValidationFixtures.multiProperty, atTemperatureC: 20)
        let again = MaterialPropertyResolver.resolve(.density, in: MaterialValidationFixtures.constant, atTemperatureC: 20)
        XCTAssertEqual(first.value ?? .nan, 8000, accuracy: tolerance)
        XCTAssertEqual(second.value ?? .nan, 7777, accuracy: tolerance)
        XCTAssertEqual(again.value ?? .nan, 8000, accuracy: tolerance)
    }

    // 15. Portable-file foundation: all fixture data must survive Codable round-trip.
    func test15ValidationMaterialsRoundTripThroughJSON() throws {
        let originals = [
            MaterialValidationFixtures.constant,
            MaterialValidationFixtures.table,
            MaterialValidationFixtures.polynomial,
            MaterialValidationFixtures.tcr,
            MaterialValidationFixtures.missing,
            MaterialValidationFixtures.multiProperty
        ]
        let data = try JSONEncoder().encode(originals)
        let decoded = try JSONDecoder().decode([EngineeringMaterial].self, from: data)
        XCTAssertEqual(decoded, originals)
    }
}
