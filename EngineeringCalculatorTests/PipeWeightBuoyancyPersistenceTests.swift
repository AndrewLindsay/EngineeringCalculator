import XCTest
@testable import EngineeringCalculator

final class PipeWeightBuoyancyPersistenceTests: XCTestCase {
    private let steelID = UUID(uuidString: "B1000000-0000-0000-0000-000000000001")!
    private let coatingID = UUID(uuidString: "B1000000-0000-0000-0000-000000000002")!

    private func construction() -> PipeConstruction {
        let steel = EngineeringMaterial(id: steelID, name: "Regression Steel", category: "Steel", densityKgM3: 7850, source: "Regression fixture")
        let coating = EngineeringMaterial(id: coatingID, name: "Regression Coating", category: "Coating", densityKgM3: 1200, source: "Regression fixture")
        return PipeConstruction(
            id: UUID(uuidString: "B2000000-0000-0000-0000-000000000001")!,
            name: "Build Comparison Pipe",
            internalDiameterM: 0.300,
            layers: [
                PipeLayer(id: UUID(uuidString: "B3000000-0000-0000-0000-000000000001")!, name: "Steel", thicknessM: 0.020, material: steel),
                PipeLayer(id: UUID(uuidString: "B3000000-0000-0000-0000-000000000002")!, name: "Coating", thicknessM: 0.005, material: coating)
            ],
            internalFluid: FluidDefinition(id: UUID(uuidString: "B4000000-0000-0000-0000-000000000001")!, name: "Contents", densityKgM3: 850),
            externalFluid: FluidDefinition(id: UUID(uuidString: "B4000000-0000-0000-0000-000000000002")!, name: "Seawater", densityKgM3: 1025)
        )
    }

    func testAdapterCreatesPortableStandaloneDocumentWithUsedMaterialsOnly() throws {
        let source = construction()
        let result = PipeWeightBuoyancyCalculator.calculate(construction: source)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let document = try PipeWeightBuoyancyPersistence.makeDocument(name: "Baseline", construction: source, result: result, createdAt: date)
        XCTAssertEqual(document.kind, .standaloneCalculation)
        XCTAssertEqual(document.calculations.count, 1)
        XCTAssertEqual(document.calculations[0].calculatorID, PipeWeightBuoyancyPersistence.calculatorID)
        XCTAssertEqual(Set(document.embeddedMaterials.map(\.id)), Set([steelID, coatingID]))
        XCTAssertEqual(document.embeddedMaterials.count, 2)
    }

    func testRestoreReconstructsExactEngineeringInputsAndMaterialIdentities() throws {
        let source = construction()
        let result = PipeWeightBuoyancyCalculator.calculate(construction: source)
        let document = try PipeWeightBuoyancyPersistence.makeDocument(name: "Baseline", construction: source, result: result)
        let restored = try PipeWeightBuoyancyPersistence.restore(from: document)
        XCTAssertEqual(restored.construction, source)
        XCTAssertEqual(restored.construction.layers.map { $0.material.id }, [steelID, coatingID])
    }

    func testFileRoundTripRestoresAndRecalculatesSameOutputs() throws {
        let source = construction()
        let originalResult = PipeWeightBuoyancyCalculator.calculate(construction: source)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let document = try PipeWeightBuoyancyPersistence.makeDocument(name: "Build Baseline", construction: source, result: originalResult, createdAt: date)
        let data = try CalculationDocumentFileIO.data(for: document)
        let decoded = try CalculationDocumentFileIO.document(from: data)
        let restored = try PipeWeightBuoyancyPersistence.restore(from: decoded)
        let recalculated = PipeWeightBuoyancyCalculator.calculate(construction: restored.construction)
        XCTAssertTrue(PipeWeightBuoyancyPersistence.compareStoredOutputs(restored.storedOutputs, with: recalculated).isEmpty)
        XCTAssertEqual(recalculated.pipeMassKgPerM, originalResult.pipeMassKgPerM, accuracy: 1e-12)
        XCTAssertEqual(recalculated.submergedWeightKNPerM, originalResult.submergedWeightKNPerM, accuracy: 1e-12)
    }

    func testChangedCalculationResultIsDetectedAgainstStoredBaseline() throws {
        let source = construction()
        let baseline = PipeWeightBuoyancyCalculator.calculate(construction: source)
        let document = try PipeWeightBuoyancyPersistence.makeDocument(name: "Baseline", construction: source, result: baseline)
        let restored = try PipeWeightBuoyancyPersistence.restore(from: document)
        var changed = restored.construction
        changed.internalDiameterM += 0.010
        let changedResult = PipeWeightBuoyancyCalculator.calculate(construction: changed)
        let differences = PipeWeightBuoyancyPersistence.compareStoredOutputs(restored.storedOutputs, with: changedResult)
        XCTAssertFalse(differences.isEmpty)
        XCTAssertTrue(differences.contains("pipeMassKgPerM"))
    }

    func testSameMaterialUsedByMultipleLayersIsEmbeddedOnlyOnce() throws {
        var source = construction()
        let shared = source.layers[0].material
        source.layers.append(PipeLayer(name: "Second Steel Layer", thicknessM: 0.002, material: shared))
        let result = PipeWeightBuoyancyCalculator.calculate(construction: source)
        let document = try PipeWeightBuoyancyPersistence.makeDocument(name: "Shared Material", construction: source, result: result)
        XCTAssertEqual(document.embeddedMaterials.filter { $0.id == steelID }.count, 1)
        XCTAssertEqual(document.calculations[0].materialReferences.filter { $0 == steelID }.count, 2)
    }

    func testRestoreUsesEmbeddedSnapshotRatherThanCurrentLibraryDefinition() throws {
        let source = construction()
        let result = PipeWeightBuoyancyCalculator.calculate(construction: source)
        let document = try PipeWeightBuoyancyPersistence.makeDocument(name: "Snapshot", construction: source, result: result)
        let restored = try PipeWeightBuoyancyPersistence.restore(from: document)
        XCTAssertEqual(restored.construction.layers[0].material.densityKgM3, 7850)
        XCTAssertEqual(restored.construction.layers[0].material.source, "Regression fixture")
    }
}
