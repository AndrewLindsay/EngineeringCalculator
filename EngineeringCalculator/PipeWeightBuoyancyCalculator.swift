import Foundation

struct CalculatedPipeLayer: Identifiable, Hashable {
    let id: UUID
    let name: String
    let innerDiameterM: Double
    let thicknessM: Double
    let outerDiameterM: Double
    let densityKgM3: Double
    let areaM2: Double
    let massKgPerM: Double
    let weightKNPerM: Double
}

struct PipeWeightBuoyancyResult {
    let layers: [CalculatedPipeLayer]
    let finalOuterDiameterM: Double
    let pipeMassKgPerM: Double
    let pipeWeightKNPerM: Double
    let contentsMassKgPerM: Double
    let displacedMassKgPerM: Double
    let submergedEquivalentMassKgPerM: Double
    let submergedWeightKNPerM: Double
}

struct PipeLayerMaterialValidation: Identifiable, Hashable {
    let id: UUID
    let layerName: String
    let materialName: String
    let result: MaterialValidationResult
    var canCalculate: Bool { result.canCalculate }
}

struct PipeWeightMaterialValidation: Hashable {
    let layers: [PipeLayerMaterialValidation]
    var issues: [MaterialValidationIssue] { layers.flatMap { $0.result.issues } }
    var errors: [MaterialValidationIssue] { issues.filter { $0.severity == .error } }
    var warnings: [MaterialValidationIssue] { issues.filter { $0.severity == .warning } }
    var canCalculate: Bool { errors.isEmpty }
}

enum PipeWeightBuoyancyCalculator {
    /// Pipe weight requires a valid density for every solid layer.
    static func validateMaterials(construction: PipeConstruction) -> PipeWeightMaterialValidation {
        let validations = construction.layers.map { layer in
            PipeLayerMaterialValidation(
                id: layer.id,
                layerName: layer.name,
                materialName: layer.material.name,
                result: MaterialRequirementValidator.validate(
                    material: layer.material,
                    against: StandardMaterialRequirementSets.mass
                )
            )
        }
        return PipeWeightMaterialValidation(layers: validations)
    }

    static func calculate(
        construction: PipeConstruction,
        gravity: Double = 9.80665
    ) -> PipeWeightBuoyancyResult {
        calculate(
            internalDiameterM: construction.internalDiameterM,
            layers: construction.layers,
            internalFluidDensityKgM3: construction.internalFluid.densityKgM3,
            externalFluidDensityKgM3: construction.externalFluid.densityKgM3,
            gravity: gravity
        )
    }

    static func calculate(
        internalDiameterM: Double,
        layers: [PipeLayer],
        internalFluidDensityKgM3: Double,
        externalFluidDensityKgM3: Double,
        gravity: Double = 9.80665
    ) -> PipeWeightBuoyancyResult {
        precondition(internalDiameterM >= 0)
        precondition(gravity > 0)

        var currentDiameter = internalDiameterM
        var calculatedLayers: [CalculatedPipeLayer] = []

        for layer in layers {
            let thickness = max(0, layer.thicknessM)
            let density = max(0, layer.densityKgM3)
            let outerDiameter = currentDiameter + 2.0 * thickness
            let area = .pi / 4.0 * (
                outerDiameter * outerDiameter - currentDiameter * currentDiameter
            )
            let mass = area * density

            calculatedLayers.append(
                CalculatedPipeLayer(
                    id: layer.id,
                    name: layer.name,
                    innerDiameterM: currentDiameter,
                    thicknessM: thickness,
                    outerDiameterM: outerDiameter,
                    densityKgM3: density,
                    areaM2: area,
                    massKgPerM: mass,
                    weightKNPerM: mass * gravity / 1000.0
                )
            )
            currentDiameter = outerDiameter
        }

        let pipeMass = calculatedLayers.reduce(0) { $0 + $1.massKgPerM }
        let internalArea = .pi / 4.0 * internalDiameterM * internalDiameterM
        let displacedArea = .pi / 4.0 * currentDiameter * currentDiameter
        let contentsMass = internalArea * max(0, internalFluidDensityKgM3)
        let displacedMass = displacedArea * max(0, externalFluidDensityKgM3)
        let submergedEquivalentMass = pipeMass + contentsMass - displacedMass

        return PipeWeightBuoyancyResult(
            layers: calculatedLayers,
            finalOuterDiameterM: currentDiameter,
            pipeMassKgPerM: pipeMass,
            pipeWeightKNPerM: pipeMass * gravity / 1000.0,
            contentsMassKgPerM: contentsMass,
            displacedMassKgPerM: displacedMass,
            submergedEquivalentMassKgPerM: submergedEquivalentMass,
            submergedWeightKNPerM: submergedEquivalentMass * gravity / 1000.0
        )
    }
}
