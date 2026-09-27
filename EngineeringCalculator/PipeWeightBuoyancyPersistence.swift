import Foundation

enum PipeWeightBuoyancyPersistence {
    static let calculatorID = "pipe-weight-buoyancy"
    static let schemaVersion = 1

    enum RestoreError: Error, Equatable { case wrongCalculator(String), missingInput(String), invalidValue(String), missingMaterial(UUID) }
    struct RestoredCase: Hashable { var construction: PipeConstruction; var storedOutputs: [SavedCalculationOutput] }

    static func makeDocument(name: String, construction: PipeConstruction, result: PipeWeightBuoyancyResult, createdAt: Date = Date()) throws -> CalculationDocument {
        let materialIDs = construction.layers.map { $0.material.id }
        let uniqueMaterials = materialIDs.reduce(into: [EngineeringMaterial]()) { partial, id in
            guard !partial.contains(where: { $0.id == id }), let material = construction.layers.first(where: { $0.material.id == id })?.material else { return }
            partial.append(material)
        }
        let embedded = try uniqueMaterials.map(EmbeddedMaterial.fingerprinted)
        let calculation = SavedCalculation(name: name, calculatorID: calculatorID, calculatorSchemaVersion: schemaVersion, createdAt: createdAt, modifiedAt: createdAt, inputs: inputs(for: construction), outputs: outputs(for: result), notes: "Pipe Weight & Buoyancy portable regression case")
        return CalculationDocument(kind: .standaloneCalculation, title: name, createdAt: createdAt, modifiedAt: createdAt, calculations: [calculation], embeddedMaterials: embedded)
    }

    static func restore(from document: CalculationDocument) throws -> RestoredCase {
        guard let calculation = document.calculations.first else { throw RestoreError.missingInput("calculation") }
        guard calculation.calculatorID == calculatorID else { throw RestoreError.wrongCalculator(calculation.calculatorID) }
        let embeddedByID = Dictionary(uniqueKeysWithValues: document.embeddedMaterials.map { ($0.id, $0.material) })
        let layerCount = try integer("layer.count", in: calculation)
        var layers: [PipeLayer] = []
        for index in 0..<layerCount {
            let prefix = "layer.\(index)."
            let materialID = try uuid(prefix + "materialID", in: calculation)
            guard let material = embeddedByID[materialID] else { throw RestoreError.missingMaterial(materialID) }
            layers.append(PipeLayer(id: try uuid(prefix + "id", in: calculation), name: try string(prefix + "name", in: calculation), thicknessM: try number(prefix + "thicknessM", in: calculation), material: material))
        }
        return RestoredCase(construction: PipeConstruction(id: try uuid("construction.id", in: calculation), name: try string("construction.name", in: calculation), internalDiameterM: try number("internalDiameterM", in: calculation), layers: layers, internalFluid: FluidDefinition(id: try uuid("internalFluid.id", in: calculation), name: try string("internalFluid.name", in: calculation), densityKgM3: try number("internalFluid.densityKgM3", in: calculation)), externalFluid: FluidDefinition(id: try uuid("externalFluid.id", in: calculation), name: try string("externalFluid.name", in: calculation), densityKgM3: try number("externalFluid.densityKgM3", in: calculation))), storedOutputs: calculation.outputs)
    }

    static func compareStoredOutputs(_ stored: [SavedCalculationOutput], with result: PipeWeightBuoyancyResult, relativeTolerance: Double = 1e-10) -> [CalculationFieldID] {
        let current = Dictionary(uniqueKeysWithValues: outputs(for: result).map { ($0.id, $0) })
        return stored.compactMap { old in
            guard let now = current[old.id], case let .number(oldValue) = old.value, case let .number(newValue) = now.value else { return old.id }
            let scale = max(1.0, abs(oldValue), abs(newValue))
            return abs(oldValue - newValue) <= relativeTolerance * scale ? nil : old.id
        }
    }

    private static func inputs(for construction: PipeConstruction) -> [SavedCalculationInput] {
        var values: [SavedCalculationInput] = [
            input("construction.id", "Construction ID", .uuid(construction.id)), input("construction.name", "Construction Name", .text(construction.name)), input("internalDiameterM", "Internal Diameter", .number(construction.internalDiameterM), "m"),
            input("internalFluid.id", "Internal Fluid ID", .uuid(construction.internalFluid.id)), input("internalFluid.name", "Internal Fluid", .text(construction.internalFluid.name)), input("internalFluid.densityKgM3", "Internal Fluid Density", .number(construction.internalFluid.densityKgM3), "kg/m³"),
            input("externalFluid.id", "External Fluid ID", .uuid(construction.externalFluid.id)), input("externalFluid.name", "External Fluid", .text(construction.externalFluid.name)), input("externalFluid.densityKgM3", "External Fluid Density", .number(construction.externalFluid.densityKgM3), "kg/m³"), input("layer.count", "Layer Count", .integer(construction.layers.count))]
        for (index, layer) in construction.layers.enumerated() { let p = "layer.\(index)."; values += [input(p+"id", "Layer \(index+1) ID", .uuid(layer.id)), input(p+"name", "Layer \(index+1) Name", .text(layer.name)), input(p+"thicknessM", "Layer \(index+1) Thickness", .number(layer.thicknessM), "m"), input(p+"materialID", "Layer \(index+1) Material ID", .uuid(layer.material.id))] }
        return values
    }

    private static func outputs(for result: PipeWeightBuoyancyResult) -> [SavedCalculationOutput] {[
        output("finalOuterDiameterM", "Final Outer Diameter", result.finalOuterDiameterM, "m"), output("pipeMassKgPerM", "Pipe Mass", result.pipeMassKgPerM, "kg/m"), output("pipeWeightKNPerM", "Pipe Weight", result.pipeWeightKNPerM, "kN/m"), output("contentsMassKgPerM", "Contents Mass", result.contentsMassKgPerM, "kg/m"), output("displacedMassKgPerM", "Displaced Mass", result.displacedMassKgPerM, "kg/m"), output("submergedEquivalentMassKgPerM", "Submerged Equivalent Mass", result.submergedEquivalentMassKgPerM, "kg/m"), output("submergedWeightKNPerM", "Submerged Weight", result.submergedWeightKNPerM, "kN/m") ]}

    private static func field(_ value: String) -> CalculationFieldID { CalculationFieldID(rawValue: value) }
    private static func input(_ id: String, _ name: String, _ value: PersistedValue, _ unit: String? = nil) -> SavedCalculationInput { SavedCalculationInput(id: field(id), displayName: name, source: .literal(value), unitSymbol: unit) }
    private static func output(_ id: String, _ name: String, _ value: Double, _ unit: String) -> SavedCalculationOutput { SavedCalculationOutput(id: field(id), displayName: name, value: .number(value), unitSymbol: unit) }
    private static func persisted(_ id: String, in calculation: SavedCalculation) throws -> PersistedValue { guard let item = calculation.inputs.first(where: { $0.id == field(id) }), case let .literal(value) = item.source else { throw RestoreError.missingInput(id) }; return value }
    private static func number(_ id: String, in calculation: SavedCalculation) throws -> Double { guard case let .number(value) = try persisted(id, in: calculation) else { throw RestoreError.invalidValue(id) }; return value }
    private static func integer(_ id: String, in calculation: SavedCalculation) throws -> Int { guard case let .integer(value) = try persisted(id, in: calculation) else { throw RestoreError.invalidValue(id) }; return value }
    private static func string(_ id: String, in calculation: SavedCalculation) throws -> String { guard case let .text(value) = try persisted(id, in: calculation) else { throw RestoreError.invalidValue(id) }; return value }
    private static func uuid(_ id: String, in calculation: SavedCalculation) throws -> UUID { guard case let .uuid(value) = try persisted(id, in: calculation) else { throw RestoreError.invalidValue(id) }; return value }
}
