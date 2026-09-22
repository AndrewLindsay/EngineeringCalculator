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
