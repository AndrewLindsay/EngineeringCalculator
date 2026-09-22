import XCTest
@testable import EngineeringCalculator

@MainActor
final class MaterialLibraryPortableCalculationImportTests: XCTestCase {
    private func material(id: UUID, name: String, density: Double = 7850, builtIn: Bool = false) -> EngineeringMaterial {
        EngineeringMaterial(id: id, name: name, category: "Test Portable Import", densityKgM3: density, thermalConductivityWMK: 45, source: "Portable calculation import fixture", isBuiltIn: builtIn)
    }

    private func document(_ materials: [EngineeringMaterial]) throws -> CalculationDocument {
        let calculation = SavedCalculation(name: "Import test", calculatorID: "test")
        return CalculationDocument.standalone(calculation, embeddedMaterials: try materials.map(EmbeddedMaterial.fingerprinted))
    }

    func testImportsOnlyNewUUIDAndPreservesIdentity() throws {
        let store = MaterialLibraryStore()
        let beforeIDs = Set(store.allMaterials.map(\.id))
        let id = UUID(uuidString: "A1000000-0000-0000-0000-000000000001")!
        XCTAssertFalse(beforeIDs.contains(id))
        let source = material(id: id, name: "Portable New Material")
        let report = try store.importNewMaterials(from: document([source]))
        XCTAssertEqual(report.importedCount, 1)
        XCTAssertEqual(report.importedMaterialIDs, [id])
        XCTAssertEqual(store.userMaterials.filter { $0.id == id }.count, 1)
        XCTAssertEqual(store.userMaterials.first { $0.id == id }?.name, source.name)
    }

    func testOpeningSameDocumentTwiceIsIdempotent() throws {
        let store = MaterialLibraryStore()
        let id = UUID(uuidString: "A2000000-0000-0000-0000-000000000002")!
        let doc = try document([material(id: id, name: "Idempotent Portable Material")])
        let first = try store.importNewMaterials(from: doc)
        let countAfterFirst = store.userMaterials.filter { $0.id == id }.count
        let second = try store.importNewMaterials(from: doc)
        let countAfterSecond = store.userMaterials.filter { $0.id == id }.count
        XCTAssertEqual(first.importedCount, 1)
        XCTAssertEqual(second.importedCount, 0)
        XCTAssertEqual(second.identicalCount, 1)
        XCTAssertEqual(countAfterFirst, 1)
        XCTAssertEqual(countAfterSecond, 1)
    }

    func testSameNameDifferentUUIDsRemainIndependentMaterials() throws {
        let store = MaterialLibraryStore()
        let id1 = UUID(uuidString: "A3000000-0000-0000-0000-000000000003")!
        let id2 = UUID(uuidString: "A3000000-0000-0000-0000-000000000004")!
        let sameName = "Project Carbon Steel"
        let report = try store.importNewMaterials(from: document([
            material(id: id1, name: sameName),
            material(id: id2, name: sameName)
        ]))
        XCTAssertEqual(report.importedCount, 2)
        XCTAssertEqual(store.userMaterials.filter { $0.id == id1 }.count, 1)
        XCTAssertEqual(store.userMaterials.filter { $0.id == id2 }.count, 1)
        XCTAssertEqual(store.userMaterials.first { $0.id == id1 }?.name, sameName)
        XCTAssertEqual(store.userMaterials.first { $0.id == id2 }?.name, sameName)
    }

    func testSameFingerprintDifferentUUIDsAreBothImported() throws {
        let store = MaterialLibraryStore()
        let id1 = UUID(uuidString: "A4000000-0000-0000-0000-000000000005")!
        let id2 = UUID(uuidString: "A4000000-0000-0000-0000-000000000006")!
        let first = material(id: id1, name: "Generic Project Steel")
        var second = first
        second.id = id2
        XCTAssertEqual(try MaterialFingerprint.make(for: first), try MaterialFingerprint.make(for: second))
        let report = try store.importNewMaterials(from: document([first, second]))
        XCTAssertEqual(report.importedCount, 2)
        XCTAssertNotNil(store.userMaterials.first { $0.id == id1 })
        XCTAssertNotNil(store.userMaterials.first { $0.id == id2 })
    }

    func testImportedBuiltInClaimIsStripped() throws {
        let store = MaterialLibraryStore()
        let id = UUID(uuidString: "A5000000-0000-0000-0000-000000000007")!
        let report = try store.importNewMaterials(from: document([material(id: id, name: "Transported Built-In Claim", builtIn: true)]))
        XCTAssertEqual(report.importedCount, 1)
        XCTAssertEqual(store.userMaterials.first { $0.id == id }?.isBuiltIn, false)
    }

    func testConflictIsReportedAndLocalMaterialIsNotOverwritten() throws {
        let store = MaterialLibraryStore()
        let id = UUID(uuidString: "A6000000-0000-0000-0000-000000000008")!
        let local = material(id: id, name: "Conflict Material", density: 7800)
        store.add(local)
        let embedded = material(id: id, name: "Conflict Material", density: 7850)
        let report = try store.importNewMaterials(from: document([embedded]))
        XCTAssertEqual(report.importedCount, 0)
        XCTAssertEqual(report.conflictCount, 1)
        XCTAssertEqual(store.userMaterials.filter { $0.id == id }.count, 1)
        XCTAssertEqual(store.userMaterials.first { $0.id == id }?.densityKgM3, 7800)
    }

    func testMixedDocumentImportsNewOnlyWithoutDuplicatingOrOverwriting() throws {
        let store = MaterialLibraryStore()
        let identicalID = UUID(uuidString: "A7000000-0000-0000-0000-000000000009")!
        let conflictID = UUID(uuidString: "A7000000-0000-0000-0000-000000000010")!
        let newID = UUID(uuidString: "A7000000-0000-0000-0000-000000000011")!
        let identical = material(id: identicalID, name: "Identical")
        let localConflict = material(id: conflictID, name: "Conflict", density: 7700)
        store.add(identical)
        store.add(localConflict)
        let embeddedConflict = material(id: conflictID, name: "Conflict", density: 7850)
        let newMaterial = material(id: newID, name: "New")
        let report = try store.importNewMaterials(from: document([identical, embeddedConflict, newMaterial]))
        XCTAssertEqual(report.importedCount, 1)
        XCTAssertEqual(report.identicalCount, 1)
        XCTAssertEqual(report.conflictCount, 1)
        XCTAssertEqual(store.userMaterials.filter { $0.id == identicalID }.count, 1)
        XCTAssertEqual(store.userMaterials.filter { $0.id == conflictID }.count, 1)
        XCTAssertEqual(store.userMaterials.filter { $0.id == newID }.count, 1)
        XCTAssertEqual(store.userMaterials.first { $0.id == conflictID }?.densityKgM3, 7700)
    }
}
