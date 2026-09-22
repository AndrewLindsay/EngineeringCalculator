import Foundation

struct PipeHeatTransferLayer: Identifiable, Hashable {
    let id: UUID
    var name: String
    var thicknessM: Double
    var material: EngineeringMaterial

    init(id: UUID = UUID(), name: String? = nil, thicknessM: Double, material: EngineeringMaterial) {
        self.id = id
        self.name = name ?? material.name
        self.thicknessM = thicknessM
        self.material = material
    }
}

struct PipeHeatTransferInput: Hashable {
    var internalDiameterM: Double
    var layers: [PipeHeatTransferLayer]
    var insideBoundaryTemperatureC: Double
    var outsideBoundaryTemperatureC: Double
    var lengthM: Double = 1.0
}

struct CalculatedPipeHeatTransferLayer: Identifiable, Hashable {
    let id: UUID
    let name: String
    let materialName: String
    let innerRadiusM: Double
    let outerRadiusM: Double
    let evaluationTemperatureC: Double
    let thermalConductivityWMK: Double
    let conductivityMethod: MaterialPropertyResolutionMethod?
    let resistanceKPerW: Double
    let temperatureDropC: Double
    let innerBoundaryTemperatureC: Double
    let outerBoundaryTemperatureC: Double
}

struct PipeHeatTransferResult: Hashable {
    let layers: [CalculatedPipeHeatTransferLayer]
    let finalOuterDiameterM: Double
    let totalResistanceKPerW: Double
    let heatRateW: Double
    let heatRatePerLengthWM: Double
}

struct PipeHeatTransferLayerValidation: Identifiable, Hashable {
    let id: UUID
    let layerName: String
    let materialName: String
    let evaluationTemperatureC: Double
    let result: MaterialValidationResult
    var canCalculate: Bool { result.canCalculate }
}

struct PipeHeatTransferValidation: Hashable {
    let layers: [PipeHeatTransferLayerValidation]
    var issues: [MaterialValidationIssue] { layers.flatMap { $0.result.issues } }
    var errors: [MaterialValidationIssue] { issues.filter { $0.severity == .error } }
    var canCalculate: Bool { errors.isEmpty }
}

struct ValidatedPipeHeatTransferResult {
    let validation: PipeHeatTransferValidation
    let result: PipeHeatTransferResult?
    var canCalculate: Bool { validation.canCalculate && result != nil }
}

enum PipeHeatTransferCalculator {
    static let requirements = MaterialRequirementSet(
        id: "pipe-radial-conduction",
        name: "Multilayer pipe radial heat transfer",
        requirements: [.init(.thermalConductivity, purpose: "Radial heat conduction")]
    )

    /// First-pass property temperature for each layer. Constant-k materials ignore it;
    /// temperature-dependent materials are evaluated at the arithmetic mean of the two
    /// specified boundary temperatures. A later iterative model can refine layer mean temperatures.
    static func propertyEvaluationTemperatureC(for input: PipeHeatTransferInput) -> Double {
        (input.insideBoundaryTemperatureC + input.outsideBoundaryTemperatureC) / 2.0
    }

    static func validateMaterials(input: PipeHeatTransferInput) -> PipeHeatTransferValidation {
        let temperature = propertyEvaluationTemperatureC(for: input)
        return PipeHeatTransferValidation(layers: input.layers.map { layer in
            PipeHeatTransferLayerValidation(
                id: layer.id,
                layerName: layer.name,
                materialName: layer.material.name,
                evaluationTemperatureC: temperature,
                result: MaterialRequirementValidator.validate(
                    material: layer.material,
                    against: requirements,
                    calculationTemperatureC: temperature
                )
            )
        })
    }

    /// Safe public calculation path: validates every material before resolving k and calculating.
    static func validatedCalculate(input: PipeHeatTransferInput) -> ValidatedPipeHeatTransferResult {
        let validation = validateMaterials(input: input)
        guard validation.canCalculate,
              input.internalDiameterM > 0,
              input.lengthM > 0,
              !input.layers.isEmpty,
              input.layers.allSatisfy({ $0.thicknessM > 0 }) else {
            return ValidatedPipeHeatTransferResult(validation: validation, result: nil)
        }

        let propertyTemperature = propertyEvaluationTemperatureC(for: input)
        var radius = input.internalDiameterM / 2.0
        var resolved: [(PipeHeatTransferLayer, Double, Double, Double, MaterialPropertyResolutionMethod?)] = []

        for layer in input.layers {
            let inner = radius
            let outer = inner + layer.thicknessM
            let resolution = MaterialPropertyResolver.resolve(.thermalConductivity, in: layer.material, atTemperatureC: propertyTemperature)
            guard let k = resolution.value, k > 0 else {
                return ValidatedPipeHeatTransferResult(validation: validation, result: nil)
            }
            let resistance = log(outer / inner) / (2.0 * Double.pi * k * input.lengthM)
            resolved.append((layer, inner, outer, resistance, resolution.method))
            radius = outer
        }

        let totalResistance = resolved.reduce(0.0) { $0 + $1.3 }
        guard totalResistance > 0 else { return ValidatedPipeHeatTransferResult(validation: validation, result: nil) }
        let deltaT = input.insideBoundaryTemperatureC - input.outsideBoundaryTemperatureC
        let heatRate = deltaT / totalResistance

        var currentTemperature = input.insideBoundaryTemperatureC
        var calculated: [CalculatedPipeHeatTransferLayer] = []
        for item in resolved {
            let drop = heatRate * item.3
            let outerTemperature = currentTemperature - drop
            let conductivity = MaterialPropertyResolver.resolve(.thermalConductivity, in: item.0.material, atTemperatureC: propertyTemperature).value!
            calculated.append(CalculatedPipeHeatTransferLayer(
                id: item.0.id,
                name: item.0.name,
                materialName: item.0.material.name,
                innerRadiusM: item.1,
                outerRadiusM: item.2,
                evaluationTemperatureC: propertyTemperature,
                thermalConductivityWMK: conductivity,
                conductivityMethod: item.4,
                resistanceKPerW: item.3,
                temperatureDropC: drop,
                innerBoundaryTemperatureC: currentTemperature,
                outerBoundaryTemperatureC: outerTemperature
            ))
            currentTemperature = outerTemperature
        }

        return ValidatedPipeHeatTransferResult(
            validation: validation,
            result: PipeHeatTransferResult(
                layers: calculated,
                finalOuterDiameterM: 2.0 * radius,
                totalResistanceKPerW: totalResistance,
                heatRateW: heatRate,
                heatRatePerLengthWM: heatRate / input.lengthM
            )
        )
    }
}
