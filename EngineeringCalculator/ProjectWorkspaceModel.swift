import Foundation

/// Mutable project-level editing model kept separate from SwiftUI so project behaviour can
/// be regression tested before the workspace UI is introduced.
struct ProjectWorkspaceModel: Equatable {
    private(set) var document: CalculationDocument

    init(title: String = "Untitled Project", now: Date = Date()) {
        document = CalculationDocument(
            kind: .project,
            title: title,
            createdAt: now,
            modifiedAt: now,
            calculations: []
        )
    }

    init(document: CalculationDocument) throws {
        guard document.kind == .project else { throw ProjectWorkspaceError.notAProject }
        self.document = document
    }

    var title: String { document.title }
    var calculations: [SavedCalculation] { document.calculations }
    var embeddedMaterials: [EmbeddedMaterial] { document.embeddedMaterials }

    mutating func renameProject(_ title: String, now: Date = Date()) throws {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw ProjectWorkspaceError.emptyName }
        document.title = cleaned
        document.modifiedAt = now
    }

    mutating func addCalculation(_ calculation: SavedCalculation, now: Date = Date()) throws {
        guard !document.calculations.contains(where: { $0.id == calculation.id }) else { throw ProjectWorkspaceError.duplicateCalculationID(calculation.id) }
        document.calculations.append(calculation)
        document.modifiedAt = now
    }

    /// Imports one complete standalone portable calculation transactionally. The project is
    /// changed only after every embedded material has been validated and merged successfully.
    mutating func addPortableCalculation(from standalone: CalculationDocument, now: Date = Date()) throws {
        guard standalone.kind == .standaloneCalculation else { throw ProjectWorkspaceError.notAStandaloneCalculation }
        guard standalone.calculations.count == 1, let calculation = standalone.calculations.first else {
            throw ProjectWorkspaceError.invalidStandaloneCalculationCount(standalone.calculations.count)
        }
        guard !document.calculations.contains(where: { $0.id == calculation.id }) else { throw ProjectWorkspaceError.duplicateCalculationID(calculation.id) }

        var staged = self
        try staged.mergeEmbeddedMaterials(standalone.embeddedMaterials, now: now)
        try staged.addCalculation(calculation, now: now)
        self = staged
    }

    mutating func renameCalculation(id: UUID, to name: String, now: Date = Date()) throws {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw ProjectWorkspaceError.emptyName }
        guard let index = document.calculations.firstIndex(where: { $0.id == id }) else { throw ProjectWorkspaceError.calculationNotFound(id) }
        document.calculations[index].name = cleaned
        document.calculations[index].modifiedAt = now
        document.modifiedAt = now
    }

    @discardableResult
    mutating func duplicateCalculation(id: UUID, newID: UUID = UUID(), now: Date = Date()) throws -> UUID {
        guard !document.calculations.contains(where: { $0.id == newID }) else { throw ProjectWorkspaceError.duplicateCalculationID(newID) }
        guard let sourceIndex = document.calculations.firstIndex(where: { $0.id == id }) else { throw ProjectWorkspaceError.calculationNotFound(id) }
        let source = document.calculations[sourceIndex]
        var copy = SavedCalculation(id: newID, name: "\(source.name) Copy", calculatorID: source.calculatorID, calculatorSchemaVersion: source.calculatorSchemaVersion, createdAt: now, modifiedAt: now, inputs: source.inputs, outputs: source.outputs, assumptions: source.assumptions, validationMessages: source.validationMessages, notes: source.notes)
        copy.name = "\(source.name) Copy"
        document.calculations.insert(copy, at: sourceIndex + 1)
        document.modifiedAt = now
        return newID
    }

    mutating func deleteCalculation(id: UUID, now: Date = Date()) throws {
        guard let index = document.calculations.firstIndex(where: { $0.id == id }) else { throw ProjectWorkspaceError.calculationNotFound(id) }
        document.calculations.remove(at: index)
        document.modifiedAt = now
    }

    mutating func moveCalculation(from source: Int, to destination: Int, now: Date = Date()) throws {
        guard document.calculations.indices.contains(source) else { throw ProjectWorkspaceError.invalidIndex(source) }
        guard destination >= 0 && destination <= document.calculations.count else { throw ProjectWorkspaceError.invalidIndex(destination) }
        if source == destination || source + 1 == destination { return }
        let item = document.calculations.remove(at: source)
        let adjustedDestination = destination > source ? destination - 1 : destination
        document.calculations.insert(item, at: adjustedDestination)
        document.modifiedAt = now
    }

    mutating func mergeEmbeddedMaterials(_ materials: [EmbeddedMaterial], now: Date = Date()) throws {
        var existingByID = Dictionary(uniqueKeysWithValues: document.embeddedMaterials.map { ($0.id, $0) })
        var fingerprints = try Set(document.embeddedMaterials.map { try $0.verifiedFingerprint() })

        for candidate in materials {
            let fingerprint = try candidate.verifiedFingerprint()
            if let existing = existingByID[candidate.id] {
                let existingFingerprint = try existing.verifiedFingerprint()
                guard existingFingerprint == fingerprint else { throw ProjectWorkspaceError.materialIDConflict(candidate.id) }
                continue
            }
            if fingerprints.contains(fingerprint) { continue }
            document.embeddedMaterials.append(candidate)
            existingByID[candidate.id] = candidate
            fingerprints.insert(fingerprint)
        }
        document.modifiedAt = now
    }
}

enum ProjectWorkspaceError: Error, Equatable, LocalizedError {
    case notAProject
    case notAStandaloneCalculation
    case invalidStandaloneCalculationCount(Int)
    case emptyName
    case calculationNotFound(UUID)
    case duplicateCalculationID(UUID)
    case invalidIndex(Int)
    case materialIDConflict(UUID)

    var errorDescription: String? {
        switch self {
        case .notAProject: return "This document is not an Engineering Calculator project."
        case .notAStandaloneCalculation: return "Only a standalone Engineering Calculator calculation can be added to a project."
        case let .invalidStandaloneCalculationCount(count): return "A standalone calculation must contain exactly one calculation; this document contains \(count)."
        case .emptyName: return "Project and calculation names cannot be empty."
        case let .calculationNotFound(id): return "Calculation \(id.uuidString) was not found in the project."
        case let .duplicateCalculationID(id): return "Calculation UUID \(id.uuidString) already exists in the project."
        case let .invalidIndex(index): return "Project calculation index \(index) is invalid."
        case let .materialIDConflict(id): return "Material UUID \(id.uuidString) has a different engineering definition in this project."
        }
    }
}
