import XCTest
@testable import EngineeringCalculator

final class MaterialReconciliationTests: XCTestCase {
    private let sharedID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!

    private func material(id: UUID? = nil, density: Double = 7850, builtIn: Bool = false) -> EngineeringMaterial {
        EngineeringMaterial(
            id: id ?? sharedID,
            name: "Reconciliation Steel",
            category: "Steel",
            densityKgM3: density,
            thermalConductivityWMK: 45,
            source: "Reconciliation fixture",
            isBuiltIn: builtIn
        )
    }

    func testAbsentUUIDIsClassifiedAsNew() throws {
        let embedded = try EmbeddedMaterial.fingerprinted(material())
        let summary = try MaterialReconciler.reconcile(embeddedMaterials: [embedded], localMaterials: [])
        XCTAssertEqual(summary.results.count, 1)
        XCTAssertEqual(summary.results[0].status, .newMaterial)
        XCTAssertNil(summary.results[0].localMaterial)
    }

    func testSameUUIDAndFingerprintIsIdentical() throws {
        let local = material()
        let embedded = try EmbeddedMaterial.fingerprinted(local)
        let summary = try MaterialReconciler.reconcile(embeddedMaterials: [embedded], localMaterials: [local])
        XCTAssertEqual(summary.results[0].status, .identical)
        XCTAssertEqual(summary.identicalMaterials.count, 1)
        XCTAssertFalse(summary.hasConflicts)
    }

    func testSameUUIDWithChangedEngineeringContentIsConflict() throws {
        let embeddedMaterial = material(density: 7850)
        let local = material(density: 7800)
        let embedded = try EmbeddedMaterial.fingerprinted(embeddedMaterial)
        let summary = try MaterialReconciler.reconcile(embeddedMaterials: [embedded], localMaterials: [local])
        XCTAssertEqual(summary.results[0].status, .conflict)
        XCTAssertNotEqual(summary.results[0].embeddedFingerprint, summary.results[0].localFingerprint)
        XCTAssertTrue(summary.hasConflicts)
    }

    func testDifferentUUIDWithSameContentIsNewMaterial() throws {
        let embeddedMaterial = material(id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!)
        let local = material(id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!)
        let embedded = try EmbeddedMaterial.fingerprinted(embeddedMaterial)
        XCTAssertEqual(try MaterialFingerprint.make(for: embeddedMaterial), try MaterialFingerprint.make(for: local))
        let summary = try MaterialReconciler.reconcile(embeddedMaterials: [embedded], localMaterials: [local])
        XCTAssertEqual(summary.results[0].status, .newMaterial)
    }

    func testLegacyEmbeddedMaterialWithoutStoredFingerprintStillReconciles() throws {
        let source = material()
        let embedded = EmbeddedMaterial(material: source)
        let summary = try MaterialReconciler.reconcile(embeddedMaterials: [embedded], localMaterials: [source])
        XCTAssertEqual(summary.results[0].status, .identical)
        XCTAssertEqual(summary.results[0].embeddedFingerprint, try MaterialFingerprint.make(for: source))
    }

    func testBuiltInStatusDifferenceDoesNotCreateConflict() throws {
        let embeddedSource = material(builtIn: false)
        let local = material(builtIn: true)
        let embedded = try EmbeddedMaterial.fingerprinted(embeddedSource)
        let summary = try MaterialReconciler.reconcile(embeddedMaterials: [embedded], localMaterials: [local])
        XCTAssertEqual(summary.results[0].status, .identical)
    }

    func testAutomaticImportReturnsOnlyNewUUIDs() throws {
        let newID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let identicalID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let conflictID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

        let newMaterial = material(id: newID)
        let identical = material(id: identicalID)
        let conflictEmbedded = material(id: conflictID, density: 7850)
        let conflictLocal = material(id: conflictID, density: 7800)

        let embedded = try [newMaterial, identical, conflictEmbedded].map(EmbeddedMaterial.fingerprinted)
        let summary = try MaterialReconciler.reconcile(
            embeddedMaterials: embedded,
            localMaterials: [identical, conflictLocal]
        )
        let imports = MaterialReconciler.materialsEligibleForAutomaticImport(from: summary)

        XCTAssertEqual(imports.map(\.id), [newID])
        XCTAssertEqual(summary.identicalMaterials.map(\.id), [identicalID])
        XCTAssertEqual(summary.conflicts.map(\.id), [conflictID])
    }

    func testAutomaticImportPreservesUUIDButStripsBuiltInProtection() throws {
        let source = material(builtIn: true)
        let embedded = try EmbeddedMaterial.fingerprinted(source)
        let summary = try MaterialReconciler.reconcile(embeddedMaterials: [embedded], localMaterials: [])
        let imported = try XCTUnwrap(MaterialReconciler.materialsEligibleForAutomaticImport(from: summary).first)
        XCTAssertEqual(imported.id, source.id)
        XCTAssertFalse(imported.isBuiltIn)
        XCTAssertEqual(try MaterialFingerprint.make(for: imported), try MaterialFingerprint.make(for: source))
    }

    func testReconciliationDoesNotMutateLocalOrEmbeddedDefinitions() throws {
        let embeddedSource = material(density: 7850)
        let local = material(density: 7800)
        let embedded = try EmbeddedMaterial.fingerprinted(embeddedSource)
        let originalEmbedded = embedded
        let originalLocal = local

        _ = try MaterialReconciler.reconcile(embeddedMaterials: [embedded], localMaterials: [local])

        XCTAssertEqual(embedded, originalEmbedded)
        XCTAssertEqual(local, originalLocal)
    }

    func testMixedDocumentProducesExpectedSummaryCounts() throws {
        let newMaterial = material(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
        let identical = material(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!)
        let conflictEmbedded = material(id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, density: 7850)
        let conflictLocal = material(id: conflictEmbedded.id, density: 7700)

        let summary = try MaterialReconciler.reconcile(
            embeddedMaterials: try [newMaterial, identical, conflictEmbedded].map(EmbeddedMaterial.fingerprinted),
            localMaterials: [identical, conflictLocal]
        )

        XCTAssertEqual(summary.newMaterials.count, 1)
        XCTAssertEqual(summary.identicalMaterials.count, 1)
        XCTAssertEqual(summary.conflicts.count, 1)
        XCTAssertEqual(summary.results.count, 3)
    }
}
