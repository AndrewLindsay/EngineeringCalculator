import Foundation

enum PipeHeatTransferPersistence {
    static let calculatorID = "pipe-heat-transfer"
    static let schemaVersion = 1

    enum RestoreError: Error, Equatable { case wrongCalculator(String), missingInput(String), invalidValue(String), missingMaterial(UUID) }
    struct RestoredCase: Hashable { var input: PipeHeatTransferInput; var storedOutputs: [SavedCalculationOutput] }

    static func makeDocument(name: String, input: PipeHeatTransferInput, result: PipeHeatTransferResult, createdAt: Date = Date()) throws -> CalculationDocument {
        var seen = Set<UUID>()
        let materials = input.layers.compactMap { layer -> EngineeringMaterial? in seen.insert(layer.material.id).inserted ? layer.material : nil }
        let embedded = try materials.map(EmbeddedMaterial.fingerprinted)
        let calculation = SavedCalculation(name: name, calculatorID: calculatorID, calculatorSchemaVersion: schemaVersion, createdAt: createdAt, modifiedAt: createdAt, inputs: inputs(for: input), outputs: outputs(for: result), notes: "Pipe Heat Transfer portable regression case")
        return CalculationDocument(kind: .standaloneCalculation, title: name, createdAt: createdAt, modifiedAt: createdAt, calculations: [calculation], embeddedMaterials: embedded)
    }

    static func restore(from document: CalculationDocument) throws -> RestoredCase {
        guard let calculation = document.calculations.first else { throw RestoreError.missingInput("calculation") }
        guard calculation.calculatorID == calculatorID else { throw RestoreError.wrongCalculator(calculation.calculatorID) }
        let embedded = Dictionary(uniqueKeysWithValues: document.embeddedMaterials.map { ($0.id, $0.material) })
        let count = try integer("layer.count", in: calculation)
        var layers: [PipeHeatTransferLayer] = []
        for index in 0..<count {
            let p = "layer.\(index)."
            let materialID = try uuid(p + "materialID", in: calculation)
            guard let material = embedded[materialID] else { throw RestoreError.missingMaterial(materialID) }
            layers.append(.init(id: try uuid(p + "id", in: calculation), name: try string(p + "name", in: calculation), thicknessM: try number(p + "thicknessM", in: calculation), material: material))
        }
        return RestoredCase(input: .init(internalDiameterM: try number("internalDiameterM", in: calculation), layers: layers, insideBoundaryTemperatureC: try number("insideBoundaryTemperatureC", in: calculation), outsideBoundaryTemperatureC: try number("outsideBoundaryTemperatureC", in: calculation), lengthM: try number("lengthM", in: calculation)), storedOutputs: calculation.outputs)
    }

    static func compareStoredOutputs(_ stored: [SavedCalculationOutput], with result: PipeHeatTransferResult, relativeTolerance: Double = 1e-8) -> [CalculationFieldID] {
        let current = Dictionary(uniqueKeysWithValues: outputs(for: result).map { ($0.id, $0) })
        return stored.compactMap { old in
            guard let now = current[old.id] else { return old.id }
            switch (old.value, now.value) {
            case let (.number(a), .number(b)):
                let scale = max(1.0, abs(a), abs(b)); return abs(a-b) <= relativeTolerance*scale ? nil : old.id
            case let (.integer(a), .integer(b)): return a == b ? nil : old.id
            default: return old.value == now.value ? nil : old.id
            }
        }
    }

    private static func inputs(for model: PipeHeatTransferInput) -> [SavedCalculationInput] {
        var values = [input("internalDiameterM", "Internal Diameter", .number(model.internalDiameterM), "m"), input("insideBoundaryTemperatureC", "Inside Boundary Temperature", .number(model.insideBoundaryTemperatureC), "°C"), input("outsideBoundaryTemperatureC", "Outside Boundary Temperature", .number(model.outsideBoundaryTemperatureC), "°C"), input("lengthM", "Length", .number(model.lengthM), "m"), input("layer.count", "Layer Count", .integer(model.layers.count))]
        for (index, layer) in model.layers.enumerated() { let p="layer.\(index)."; values += [input(p+"id", "Layer \(index+1) ID", .uuid(layer.id)), input(p+"name", "Layer \(index+1) Name", .text(layer.name)), input(p+"thicknessM", "Layer \(index+1) Thickness", .number(layer.thicknessM), "m"), input(p+"materialID", "Layer \(index+1) Material ID", .uuid(layer.material.id))] }
        return values
    }

    private static func outputs(for result: PipeHeatTransferResult) -> [SavedCalculationOutput] {
        var values = [output("finalOuterDiameterM", "Final Outer Diameter", result.finalOuterDiameterM, "m"), output("totalResistanceKPerW", "Total Resistance", result.totalResistanceKPerW, "K/W"), output("heatRateW", "Heat Rate", result.heatRateW, "W"), output("heatRatePerLengthWM", "Heat Rate per Length", result.heatRatePerLengthWM, "W/m"), integerOutput("refinementPasses", "Refinement Passes", result.refinementPasses), integerOutput("totalComputationalCells", "Computational Cells", result.totalComputationalCells), output("heatRateConvergenceFraction", "Heat Rate Convergence Fraction", result.heatRateConvergenceFraction, nil)]
        for (index, layer) in result.layers.enumerated() { let p="layer.\(index)."; values += [output(p+"evaluationTemperatureC", "Layer \(index+1) Evaluation Temperature", layer.evaluationTemperatureC, "°C"), output(p+"thermalConductivityWMK", "Layer \(index+1) Conductivity", layer.thermalConductivityWMK, "W/(m·K)"), output(p+"resistanceKPerW", "Layer \(index+1) Resistance", layer.resistanceKPerW, "K/W"), output(p+"innerBoundaryTemperatureC", "Layer \(index+1) Inner Temperature", layer.innerBoundaryTemperatureC, "°C"), output(p+"outerBoundaryTemperatureC", "Layer \(index+1) Outer Temperature", layer.outerBoundaryTemperatureC, "°C"), integerOutput(p+"computationalCellCount", "Layer \(index+1) Cells", layer.computationalCellCount)] }
        return values
    }

    private static func field(_ s:String)->CalculationFieldID{.init(rawValue:s)}
    private static func input(_ id:String,_ name:String,_ value:PersistedValue,_ unit:String?=nil)->SavedCalculationInput{.init(id:field(id),displayName:name,source:.literal(value),unitSymbol:unit)}
    private static func output(_ id:String,_ name:String,_ value:Double,_ unit:String?)->SavedCalculationOutput{.init(id:field(id),displayName:name,value:.number(value),unitSymbol:unit)}
    private static func integerOutput(_ id:String,_ name:String,_ value:Int)->SavedCalculationOutput{.init(id:field(id),displayName:name,value:.integer(value))}
    private static func persisted(_ id:String,in c:SavedCalculation)throws->PersistedValue{guard let i=c.inputs.first(where:{$0.id==field(id)}),case let .literal(v)=i.source else{throw RestoreError.missingInput(id)};return v}
    private static func number(_ id:String,in c:SavedCalculation)throws->Double{guard case let .number(v)=try persisted(id,in:c) else{throw RestoreError.invalidValue(id)};return v}
    private static func integer(_ id:String,in c:SavedCalculation)throws->Int{guard case let .integer(v)=try persisted(id,in:c) else{throw RestoreError.invalidValue(id)};return v}
    private static func string(_ id:String,in c:SavedCalculation)throws->String{guard case let .text(v)=try persisted(id,in:c) else{throw RestoreError.invalidValue(id)};return v}
    private static func uuid(_ id:String,in c:SavedCalculation)throws->UUID{guard case let .uuid(v)=try persisted(id,in:c) else{throw RestoreError.invalidValue(id)};return v}
}
