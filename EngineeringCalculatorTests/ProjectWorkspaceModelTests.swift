import XCTest
@testable import EngineeringCalculator

final class ProjectWorkspaceModelTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private let t1 = Date(timeIntervalSince1970: 1_800_000_100)

    private func calculation(_ name: String, id: UUID, calculatorID: String = "pipeWeightBuoyancy") -> SavedCalculation {
        SavedCalculation(
            id: id,
            name: name,
            calculatorID: calculatorID,
            createdAt: t0,
            modifiedAt: t0,
            inputs: [SavedCalculationInput(id: "input", displayName: "Input", source: .literal(.number(12.5)))],
            outputs: [SavedCalculationOutput(id: "output", displayName: "Output", value: .number(42.0))],
            assumptions: ["Regression fixture"],
            notes: "Original notes"
        )
    }

    func testNewWorkspaceCreatesEmptyProjectDocument() {
        let workspace = ProjectWorkspaceModel(title: "Pipeline Study", now: t0)
        XCTAssertEqual(workspace.document.kind, .project)
        XCTAssertEqual(workspace.title, "Pipeline Study")
        XCTAssertTrue(workspace.calculations.isEmpty)
        XCTAssertEqual(workspace.document.createdAt, t0)
        XCTAssertEqual(workspace.document.modifiedAt, t0)
    }

    func testStandaloneDocumentCannotBeOpenedAsProjectWorkspace() {
        let calc = calculation("Standalone", id: UUID())
        let standalone = CalculationDocument.standalone(calc)
        XCTAssertThrowsError(try ProjectWorkspaceModel(document: standalone)) { error in
            XCTAssertEqual(error as? ProjectWorkspaceError, .notAProject)
        }
    }

    func testAddRenameDuplicateDeleteAndReorderCalculations() throws {
        let a = UUID(uuidString: "A1000000-0000-0000-0000-000000000001")!
        let b = UUID(uuidString: "A1000000-0000-0000-0000-000000000002")!
        let c = UUID(uuidString: "A1000000-0000-0000-0000-000000000003")!
        let duplicateID = UUID(uuidString: "A1000000-0000-0000-0000-000000000004")!
        var workspace = ProjectWorkspaceModel(title: "Study", now: t0)
        try workspace.addCalculation(calculation("A", id: a), now: t0)
        try workspace.addCalculation(calculation("B", id: b, calculatorID: "pipeHeatTransfer"), now: t0)
        try workspace.addCalculation(calculation("C", id: c), now: t0)

        try workspace.renameCalculation(id: b, to: "Heat Transfer Case", now: t1)
        let copiedID = try workspace.duplicateCalculation(id: a, newID: duplicateID, now: t1)
        XCTAssertEqual(copiedID, duplicateID)
        XCTAssertEqual(workspace.calculations.map(\.name), ["A", "A Copy", "Heat Transfer Case", "C"])
        XCTAssertEqual(workspace.calculations[1].inputs, workspace.calculations[0].inputs)
        XCTAssertEqual(workspace.calculations[1].outputs, workspace.calculations[0].outputs)

        try workspace.deleteCalculation(id: c, now: t1)
        try workspace.moveCalculation(from: 2, to: 0, now: t1)
        XCTAssertEqual(workspace.calculations.map(\.name), ["Heat Transfer Case", "A", "A Copy"])
        XCTAssertEqual(workspace.document.modifiedAt, t1)
    }

    func testDuplicateCalculationIDIsRejected() throws {
        let id = UUID(uuidString: "A2000000-0000-0000-0000-000000000001")!
        var workspace = ProjectWorkspaceModel(title: "Study", now: t0)
        try workspace.addCalculation(calculation("A", id: id), now: t0)
        XCTAssertThrowsError(try workspace.addCalculation(calculation("Duplicate", id: id), now: t1)) { error in
            XCTAssertEqual(error as? ProjectWorkspaceError, .duplicateCalculationID(id))
        }
    }

    func testEmbeddedMaterialMergeDeduplicatesByEngineeringFingerprint() throws {
        let first = EngineeringMaterial(
            id: UUID(uuidString: "A3000000-0000-0000-0000-000000000001")!,
            name: "Project Steel", category: "Steel", densityKgM3: 7850, thermalConductivityWMK: 45
        )
        let sameEngineeringContentDifferentID = EngineeringMaterial(
            id: UUID(uuidString: "A3000000-0000-0000-0000-000000000002")!,
            name: "Project Steel", category: "Steel", densityKgM3: 7850, thermalConductivityWMK: 45
        )
        var workspace = ProjectWorkspaceModel(title: "Study", now: t0)
        try workspace.mergeEmbeddedMaterials([
            try .fingerprinted(first),
            try .fingerprinted(sameEngineeringContentDifferentID)
        ], now: t1)
        XCTAssertEqual(workspace.embeddedMaterials.count, 1)
    }

    func testEmbeddedMaterialSameIDDifferentContentIsRejected() throws {
        let id = UUID(uuidString: "A4000000-0000-0000-0000-000000000001")!
        let first = EngineeringMaterial(id: id, name: "Project Material", category: "Test", densityKgM3: 1000)
        let conflicting = EngineeringMaterial(id: id, name: "Project Material", category: "Test", densityKgM3: 2000)
        var workspace = ProjectWorkspaceModel(title: "Study", now: t0)
        try workspace.mergeEmbeddedMaterials([try .fingerprinted(first)], now: t0)
        XCTAssertThrowsError(try workspace.mergeEmbeddedMaterials([try .fingerprinted(conflicting)], now: t1)) { error in
            XCTAssertEqual(error as? ProjectWorkspaceError, .materialIDConflict(id))
        }
    }

    func testEditedWorkspaceRoundTripsAsEcproject() throws {
        let firstID = UUID(uuidString: "A5000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "A5000000-0000-0000-0000-000000000002")!
        var workspace = ProjectWorkspaceModel(title: "Pipeline Study", now: t0)
        try workspace.addCalculation(calculation("Weight", id: firstID), now: t0)
        try workspace.addCalculation(calculation("Heat", id: secondID, calculatorID: "pipeHeatTransfer"), now: t1)
        try workspace.renameProject("Pipeline Build Comparison", now: t1)

        let data = try CalculationDocumentFileIO.data(for: workspace.document)
        let restoredDocument = try CalculationDocumentFileIO.document(from: data)
        let restoredWorkspace = try ProjectWorkspaceModel(document: restoredDocument)

        XCTAssertEqual(restoredWorkspace, workspace)
        XCTAssertEqual(CalculationDocumentFileType.suggestedFilename(for: restoredWorkspace.document), "Pipeline Build Comparison.ecproject")
    }
}
