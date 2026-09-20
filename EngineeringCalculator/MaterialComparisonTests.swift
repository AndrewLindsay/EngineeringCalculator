import XCTest
@testable import EngineeringCalculator

final class MaterialComparisonTests: XCTestCase {
    private func material(
        id: UUID = UUID(),
        name: String,
        density: Double? = 7850,
        conductivity: Double? = nil,
        conductivitySeries: MaterialPropertySeries? = nil
    ) -> EngineeringMaterial {
        EngineeringMaterial(
            id: id,
            name: name,
            category: "Validation",
            densityKgM3: density,
            thermalConductivityWMK: conductivity,
            thermalConductivitySeries: conductivitySeries,
            isBuiltIn: false
        )
    }

    private func row(_ id: String, in comparison: MaterialComparison, file: StaticString = #filePath, line: UInt = #line) -> MaterialComparisonRow {
        guard let row = comparison.rows.first(where: { $0.id == id }) else {
            XCTFail("Missing comparison row: \(id)", file: file, line: line)
            return MaterialComparisonRow(id: id, section: .physical, label: id, cells: [])
        }
        return row
    }

    func test01DensityDifferenceAndPercentage() throws {
        let reference = material(name: "Reference", density: 7850)
        let project = material(name: "Project", density: 8000)
        let comparison = MaterialComparisonEngine.compare([reference, project])
        let density = row("density", in: comparison)

        XCTAssertFalse(density.cells[0].differsFromReference)
        XCTAssertTrue(density.cells[1].differsFromReference)
        XCTAssertEqual(try XCTUnwrap(density.cells[1].absoluteDifference), 150, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(density.cells[1].percentageDifference), 150.0 / 7850.0 * 100.0, accuracy: 1e-12)
        XCTAssertTrue(density.hasDifference)
    }

    func test02IdenticalNumericValuesAreNotDifferent() {
        let a = material(name: "A", density: 7850)
        let b = material(name: "B", density: 7850)
        let density = row("density", in: MaterialComparisonEngine.compare([a, b]))

        XCTAssertFalse(density.hasDifference)
        XCTAssertNil(density.cells[1].absoluteDifference)
        XCTAssertNil(density.cells[1].percentageDifference)
    }

    func test03MissingPropertyIsDifferentFromPresentProperty() {
        let reference = material(name: "Reference", density: 7850, conductivity: 45)
        let project = material(name: "Project", density: 7850, conductivity: nil)
        let conductivity = row("thermalConductivity", in: MaterialComparisonEngine.compare([reference, project]))

        XCTAssertTrue(conductivity.cells[1].differsFromReference)
        XCTAssertEqual(conductivity.cells[1].value, .missing)
        XCTAssertNil(conductivity.cells[1].absoluteDifference)
        XCTAssertNil(conductivity.cells[1].percentageDifference)
    }

    func test04ThreeMaterialsCompareAgainstFirstReference() throws {
        let reference = material(name: "Reference", density: 1000)
        let same = material(name: "Same", density: 1000)
        let changed = material(name: "Changed", density: 1100)
        let density = row("density", in: MaterialComparisonEngine.compare([reference, same, changed]))

        XCTAssertEqual(density.cells.count, 3)
        XCTAssertFalse(density.cells[1].differsFromReference)
        XCTAssertTrue(density.cells[2].differsFromReference)
        XCTAssertEqual(try XCTUnwrap(density.cells[2].percentageDifference), 10, accuracy: 1e-12)
    }

    func test05ExplicitReferenceIsMovedFirstAndUsedForDifferences() throws {
        let a = material(name: "A", density: 1000)
        let b = material(name: "B", density: 1200)
        let c = material(name: "C", density: 900)
        let comparison = MaterialComparisonEngine.compare([a, b, c], referenceMaterialID: b.id)
        let density = row("density", in: comparison)

        XCTAssertEqual(comparison.referenceMaterialID, b.id)
        XCTAssertEqual(comparison.materials.map(\.id), [b.id, a.id, c.id])
        XCTAssertEqual(try XCTUnwrap(density.cells[1].absoluteDifference), -200, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(density.cells[2].absoluteDifference), -300, accuracy: 1e-12)
    }

    func test06FloatingPointNoiseDoesNotCreateFalseDifference() {
        let a = material(name: "A", density: 7850)
        let b = material(name: "B", density: 7850 + 1e-7)
        let density = row("density", in: MaterialComparisonEngine.compare([a, b]))

        XCTAssertFalse(density.hasDifference)
    }

    func test07TemperatureModelCoefficientChangeIsDetected() {
        let seriesA = MaterialPropertySeries(
            referenceValue: 10,
            referenceTemperatureC: 20,
            equation: MaterialPropertyEquation(a: 10, b: 0.1, c: 0.001, d: 0, minimumTemperatureC: 0, maximumTemperatureC: 200, allowsExtrapolation: false, kind: .polynomial),
            source: "Validation source",
            basis: "Validation basis"
        )
        let seriesB = MaterialPropertySeries(
            referenceValue: 10,
            referenceTemperatureC: 20,
            equation: MaterialPropertyEquation(a: 10, b: 0.2, c: 0.001, d: 0, minimumTemperatureC: 0, maximumTemperatureC: 200, allowsExtrapolation: false, kind: .polynomial),
            source: "Validation source",
            basis: "Validation basis"
        )
        let a = material(name: "A", conductivity: 10, conductivitySeries: seriesA)
        let b = material(name: "B", conductivity: 10, conductivitySeries: seriesB)
        let comparison = MaterialComparisonEngine.compare([a, b])

        XCTAssertFalse(row("thermalConductivity", in: comparison).hasDifference, "Equal reference scalar values should remain equal.")
        XCTAssertTrue(row("thermalConductivityModel", in: comparison).hasDifference, "A changed equation must be detected even when the reference scalar is unchanged.")
    }

    func test08TemperatureTableOrderDoesNotCreateFalseDifference() {
        let points = [
            MaterialPropertyPoint(temperatureC: 20, value: 10),
            MaterialPropertyPoint(temperatureC: 100, value: 12),
            MaterialPropertyPoint(temperatureC: 200, value: 15)
        ]
        let aSeries = MaterialPropertySeries(referenceValue: 10, referenceTemperatureC: 20, temperatureTable: points, source: "Table", basis: "Test")
        let bSeries = MaterialPropertySeries(referenceValue: 10, referenceTemperatureC: 20, temperatureTable: points.reversed(), source: "Table", basis: "Test")
        let a = material(name: "A", conductivity: 10, conductivitySeries: aSeries)
        let b = material(name: "B", conductivity: 10, conductivitySeries: bSeries)

        XCTAssertFalse(row("thermalConductivityModel", in: MaterialComparisonEngine.compare([a, b])).hasDifference)
    }

    func test09DifferencesOnlyRowsContainChangedProperties() {
        let a = material(name: "A", density: 7850, conductivity: 45)
        let b = material(name: "B", density: 8000, conductivity: 45)
        let comparison = MaterialComparisonEngine.compare([a, b])

        XCTAssertTrue(comparison.differingRows.contains(where: { $0.id == "density" }))
        XCTAssertFalse(comparison.differingRows.contains(where: { $0.id == "thermalConductivity" }))
    }

    func test10ZeroReferenceHasAbsoluteButNoPercentageDifference() throws {
        let reference = material(name: "Reference", density: 0)
        let changed = material(name: "Changed", density: 10)
        let density = row("density", in: MaterialComparisonEngine.compare([reference, changed]))

        XCTAssertEqual(try XCTUnwrap(density.cells[1].absoluteDifference), 10, accuracy: 1e-12)
        XCTAssertNil(density.cells[1].percentageDifference)
    }
}
