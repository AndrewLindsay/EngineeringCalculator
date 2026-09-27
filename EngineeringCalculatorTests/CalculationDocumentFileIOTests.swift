import XCTest
@testable import EngineeringCalculator

final class CalculationDocumentFileIOTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)

    private func calculation(name: String = "Build Comparison Case") -> SavedCalculation {
        SavedCalculation(
            id: UUID(uuidString: "F0000000-0000-0000-0000-000000000001")!,
            name: name,
            calculatorID: "testCalculator",
            createdAt: fixedDate,
            modifiedAt: fixedDate,
            inputs: [
                SavedCalculationInput(id: "pressure", displayName: "Pressure", source: .literal(.number(128)), unitSymbol: "bar(a)"),
                SavedCalculationInput(id: "temperature", displayName: "Temperature", source: .literal(.number(80)), unitSymbol: "°C")
            ],
            outputs: [
                SavedCalculationOutput(id: "result", displayName: "Result", value: .number(42.0), unitSymbol: "kg/m")
            ]
        )
    }

    private func material() -> EngineeringMaterial {
        EngineeringMaterial(
            id: UUID(uuidString: "F1000000-0000-0000-0000-000000000001")!,
            name: "File I/O Test Steel",
            category: "Steel",
            densityKgM3: 7850,
            thermalConductivityWMK: 45,
            source: "File I/O regression fixture"
        )
    }

    private func standalone() throws -> CalculationDocument {
        let calc = calculation()
        return CalculationDocument(
            id: UUID(uuidString: "F2000000-0000-0000-0000-000000000001")!,
            kind: .standaloneCalculation,
            title: calc.name,
            createdAt: fixedDate,
            modifiedAt: fixedDate,
            calculations: [calc],
            embeddedMaterials: [try EmbeddedMaterial.fingerprinted(material())]
        )
    }

    private func project() -> CalculationDocument {
        CalculationDocument(
            id: UUID(uuidString: "F3000000-0000-0000-0000-000000000001")!,
            kind: .project,
            title: "Pipeline Study",
            createdAt: fixedDate,
            modifiedAt: fixedDate,
            calculations: [calculation(), calculation(name: "Second Case")]
        )
    }

    private func temporaryURL(_ filename: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(filename)
    }

    private func createParentDirectory(for url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    func testStandaloneSuggestedFilenameUsesEccalcExtension() throws {
        XCTAssertEqual(CalculationDocumentFileType.suggestedFilename(for: try standalone()), "Build Comparison Case.eccalc")
    }

    func testSuggestedFilenameSanitizesUnsafeCharacters() {
        let calc = calculation(name: "Case 1 / 128 bar: baseline")
        let document = CalculationDocument(kind: .standaloneCalculation, title: calc.name, createdAt: fixedDate, modifiedAt: fixedDate, calculations: [calc])
        XCTAssertEqual(CalculationDocumentFileType.suggestedFilename(for: document), "Case 1 - 128 bar- baseline.eccalc")
    }

    func testStandaloneDataRoundTripPreservesExactInputsOutputsAndMaterials() throws {
        let original = try standalone()
        let restored = try CalculationDocumentFileIO.document(from: CalculationDocumentFileIO.data(for: original))
        XCTAssertEqual(restored, original)
        XCTAssertEqual(restored.calculations[0].inputs, original.calculations[0].inputs)
        XCTAssertEqual(restored.calculations[0].outputs, original.calculations[0].outputs)
        XCTAssertEqual(restored.embeddedMaterials, original.embeddedMaterials)
    }

    func testStandaloneDiskRoundTripPreservesExactDocument() throws {
        let original = try standalone()
        let url = temporaryURL("comparison.eccalc")
        try createParentDirectory(for: url)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try CalculationDocumentFileIO.write(original, to: url)
        XCTAssertEqual(try CalculationDocumentFileIO.read(from: url), original)
    }

    func testWritingStandaloneWithWrongExtensionIsRejected() throws {
        let url = temporaryURL("wrong.ecproject")
        XCTAssertThrowsError(try CalculationDocumentFileIO.write(standalone(), to: url)) { error in
            XCTAssertEqual(error as? CalculationDocumentFileError, .fileKindDoesNotMatchExtension(expected: .standaloneCalculation, actualExtension: "ecproject"))
        }
    }

    func testUnsupportedExtensionIsRejected() throws {
        let url = temporaryURL("wrong.json")
        XCTAssertThrowsError(try CalculationDocumentFileIO.write(standalone(), to: url)) { error in
            XCTAssertEqual(error as? CalculationDocumentFileError, .unsupportedFileExtension("json"))
        }
    }

    func testProjectUsesEcprojectExtensionAndRoundTrips() throws {
        let original = project()
        XCTAssertEqual(CalculationDocumentFileType.suggestedFilename(for: original), "Pipeline Study.ecproject")
        let url = temporaryURL("Pipeline Study.ecproject")
        try createParentDirectory(for: url)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try CalculationDocumentFileIO.write(original, to: url)
        XCTAssertEqual(try CalculationDocumentFileIO.read(from: url), original)
    }

    func testProjectRoundTripPreservesCalculationOrderAndPerCaseMetadata() throws {
        let firstID = UUID(uuidString: "F4000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "F4000000-0000-0000-0000-000000000002")!
        let first = SavedCalculation(
            id: firstID, name: "Weight Case", calculatorID: "pipeWeightBuoyancy", calculatorSchemaVersion: 3,
            createdAt: fixedDate, modifiedAt: fixedDate,
            inputs: [SavedCalculationInput(id: "diameter", displayName: "Diameter", source: .literal(.number(300)), unitSymbol: "mm")],
            outputs: [SavedCalculationOutput(id: "mass", displayName: "Mass", value: .number(299.464), unitSymbol: "kg/m")],
            assumptions: ["Fully flooded"], notes: "Baseline weight case"
        )
        let second = SavedCalculation(
            id: secondID, name: "Heat Case", calculatorID: "pipeHeatTransfer", calculatorSchemaVersion: 2,
            createdAt: fixedDate, modifiedAt: fixedDate,
            inputs: [SavedCalculationInput(id: "temperature", displayName: "Temperature", source: .literal(.number(80)), unitSymbol: "°C")],
            outputs: [SavedCalculationOutput(id: "heatLoss", displayName: "Heat Loss", value: .number(125.5), unitSymbol: "W/m")],
            assumptions: ["Steady state"], notes: "Thermal comparison case"
        )
        let original = CalculationDocument(kind: .project, title: "Mixed Calculator Project", createdAt: fixedDate, modifiedAt: fixedDate, calculations: [first, second])
        let restored = try CalculationDocumentFileIO.document(from: CalculationDocumentFileIO.data(for: original))

        XCTAssertEqual(restored.calculations.map(\.id), [firstID, secondID])
        XCTAssertEqual(restored.calculations.map(\.calculatorID), ["pipeWeightBuoyancy", "pipeHeatTransfer"])
        XCTAssertEqual(restored.calculations.map(\.calculatorSchemaVersion), [3, 2])
        XCTAssertEqual(restored.calculations.map(\.notes), ["Baseline weight case", "Thermal comparison case"])
        XCTAssertEqual(restored.calculations[0].inputs, first.inputs)
        XCTAssertEqual(restored.calculations[1].outputs, second.outputs)
    }

    func testProjectStoresSharedEmbeddedMaterialOnce() throws {
        let shared = try EmbeddedMaterial.fingerprinted(material())
        let original = CalculationDocument(kind: .project, title: "Shared Material Project", createdAt: fixedDate, modifiedAt: fixedDate,
                                           calculations: [calculation(), calculation(name: "Second Case")], embeddedMaterials: [shared])
        let restored = try CalculationDocumentFileIO.document(from: CalculationDocumentFileIO.data(for: original))

        XCTAssertEqual(restored.embeddedMaterials.count, 1)
        XCTAssertEqual(restored.embeddedMaterials[0], shared)
        XCTAssertEqual(restored.calculations.count, 2)
    }

    func testProjectAllowsDifferentMaterialsWithSameDisplayName() throws {
        let first = EngineeringMaterial(
            id: UUID(uuidString: "F5000000-0000-0000-0000-000000000001")!, name: "Project Test Material", category: "Test",
            densityKgM3: 2400, thermalConductivityWMK: 1.5, source: "Fixture A"
        )
        let second = EngineeringMaterial(
            id: UUID(uuidString: "F5000000-0000-0000-0000-000000000002")!, name: "Project Test Material", category: "Test",
            densityKgM3: 3000, thermalConductivityWMK: 2.0, source: "Fixture B"
        )
        let original = CalculationDocument(kind: .project, title: "Same Name Materials", createdAt: fixedDate, modifiedAt: fixedDate,
                                           calculations: [calculation()], embeddedMaterials: [try .fingerprinted(first), try .fingerprinted(second)])
        let restored = try CalculationDocumentFileIO.document(from: CalculationDocumentFileIO.data(for: original))

        XCTAssertEqual(restored.embeddedMaterials.count, 2)
        XCTAssertEqual(Set(restored.embeddedMaterials.map(\.id)), Set([first.id, second.id]))
        XCTAssertEqual(restored.embeddedMaterials.map { $0.material.name }, ["Project Test Material", "Project Test Material"])
        XCTAssertEqual(restored.embeddedMaterials.map { $0.material.densityKgM3 }, [2400, 3000])
    }

    func testProjectRoundTripPreservesCrossCalculationAndProjectParameterSources() throws {
        let sourceID = UUID(uuidString: "F6000000-0000-0000-0000-000000000001")!
        let consumerID = UUID(uuidString: "F6000000-0000-0000-0000-000000000002")!
        let parameterID = UUID(uuidString: "F6000000-0000-0000-0000-000000000003")!
        let source = SavedCalculation(
            id: sourceID, name: "Source", calculatorID: "sourceCalculator", createdAt: fixedDate, modifiedAt: fixedDate,
            outputs: [SavedCalculationOutput(id: "outsideDiameter", displayName: "Outside Diameter", value: .number(426), unitSymbol: "mm")]
        )
        let consumer = SavedCalculation(
            id: consumerID, name: "Consumer", calculatorID: "consumerCalculator", createdAt: fixedDate, modifiedAt: fixedDate,
            inputs: [
                SavedCalculationInput(id: "diameter", displayName: "Diameter", source: .calculationOutput(calculationID: sourceID, outputID: "outsideDiameter"), unitSymbol: "mm"),
                SavedCalculationInput(id: "ambientTemperature", displayName: "Ambient Temperature", source: .projectParameter(parameterID), unitSymbol: "°C")
            ]
        )
        let original = CalculationDocument(kind: .project, title: "Linked Project", createdAt: fixedDate, modifiedAt: fixedDate, calculations: [source, consumer])
        let restored = try CalculationDocumentFileIO.document(from: CalculationDocumentFileIO.data(for: original))

        XCTAssertEqual(restored.calculations[1].inputs, consumer.inputs)
    }

    func testProjectSaveReopenResaveIsDeterministic() throws {
        let original = CalculationDocument(kind: .project, title: "Deterministic Project", createdAt: fixedDate, modifiedAt: fixedDate,
                                           calculations: [calculation(), calculation(name: "Second Case")],
                                           embeddedMaterials: [try EmbeddedMaterial.fingerprinted(material())], notes: "Regression fixture")
        let firstEncoding = try CalculationDocumentFileIO.data(for: original)
        let reopened = try CalculationDocumentFileIO.document(from: firstEncoding)
        let secondEncoding = try CalculationDocumentFileIO.data(for: reopened)

        XCTAssertEqual(secondEncoding, firstEncoding)
        XCTAssertEqual(reopened, original)
    }

    func testReadingContentWithMismatchedExtensionIsRejected() throws {
        let original = project()
        let url = temporaryURL("pretending-to-be-calculation.eccalc")
        try createParentDirectory(for: url)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try CalculationDocumentFileIO.data(for: original).write(to: url)
        XCTAssertThrowsError(try CalculationDocumentFileIO.read(from: url)) { error in
            XCTAssertEqual(error as? CalculationDocumentFileError, .fileKindDoesNotMatchExtension(expected: .project, actualExtension: "eccalc"))
        }
    }
}
