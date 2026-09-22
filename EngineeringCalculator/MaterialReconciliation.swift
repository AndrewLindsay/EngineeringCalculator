import Foundation

enum MaterialReconciliationStatus: String, Codable, Hashable {
    case newMaterial
    case identical
    case conflict
}

struct MaterialReconciliationResult: Identifiable, Hashable {
    let embedded: EmbeddedMaterial
    let localMaterial: EngineeringMaterial?
    let status: MaterialReconciliationStatus
    let embeddedFingerprint: String
    let localFingerprint: String?

    var id: UUID { embedded.id }
}

struct MaterialReconciliationSummary: Hashable {
    var results: [MaterialReconciliationResult]

    var newMaterials: [MaterialReconciliationResult] { results.filter { $0.status == .newMaterial } }
    var identicalMaterials: [MaterialReconciliationResult] { results.filter { $0.status == .identical } }
    var conflicts: [MaterialReconciliationResult] { results.filter { $0.status == .conflict } }
    var hasConflicts: Bool { !conflicts.isEmpty }
}

/// Pure comparison service. Reconciliation never mutates the material library.
/// The embedded definition remains authoritative for reproducing the saved calculation.
enum MaterialReconciler {
    static func reconcile(
        embeddedMaterials: [EmbeddedMaterial],
        localMaterials: [EngineeringMaterial]
    ) throws -> MaterialReconciliationSummary {
        let localByID = Dictionary(localMaterials.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let results = try embeddedMaterials.map { embedded in
            let embeddedFingerprint = try embedded.verifiedFingerprint()

            guard let local = localByID[embedded.id] else {
                return MaterialReconciliationResult(
                    embedded: embedded,
                    localMaterial: nil,
                    status: .newMaterial,
                    embeddedFingerprint: embeddedFingerprint,
                    localFingerprint: nil
                )
            }

            let localFingerprint = try MaterialFingerprint.make(for: local)
            return MaterialReconciliationResult(
                embedded: embedded,
                localMaterial: local,
                status: embeddedFingerprint == localFingerprint ? .identical : .conflict,
                embeddedFingerprint: embeddedFingerprint,
                localFingerprint: localFingerprint
            )
        }

        return MaterialReconciliationSummary(results: results)
    }

    /// Returns safe candidates for automatic import. Existing UUIDs are never returned,
    /// whether identical or conflicting. Imported materials are stripped of protected
    /// built-in status because that status belongs only to the receiving installation.
    static func materialsEligibleForAutomaticImport(
        from summary: MaterialReconciliationSummary
    ) -> [EngineeringMaterial] {
        summary.newMaterials.map { result in
            var material = result.embedded.material
            material.isBuiltIn = false
            return material
        }
    }
}
