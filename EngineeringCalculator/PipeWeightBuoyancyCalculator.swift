import Foundation

struct PipeLayer: Identifiable, Hashable {
    let id: UUID
    var name: String
    var thicknessM: Double
    var densityKgM3: Double

    init(id: UUID = UUID(), name: String, thicknessM: Double, densityKgM3: Double) {
        self.id = id
        self.name = name
        self.thicknessM = thicknessM
        self.densityKgM3 = densityKgM3
    }
}

struct PipeWeightBuoyancyResult {
    let finalOuterDiameterM: Double
    let pipeMassKgPerM: Double
    let pipeWeightKNPerM: Double
    let contentsMassKgPerM: Double
    let displacedMassKgPerM: Double
    let submergedEquivalentMassKgPerM: Double
    let submergedWeightKNPerM: Double
}

enum PipeWeightBuoyancyCalculator {
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
        var pipeMass = 0.0

        for layer in layers {
            let outerDiameter = currentDiameter + 2.0 * max(0, layer.thicknessM)
            let area = .pi / 4.0 * (outerDiameter * outerDiameter - currentDiameter * currentDiameter)
            pipeMass += area * max(0, layer.densityKgM3)
            currentDiameter = outerDiameter
        }

        let internalArea = .pi / 4.0 * internalDiameterM * internalDiameterM
        let displacedArea = .pi / 4.0 * currentDiameter * currentDiameter

        let contentsMass = internalArea * max(0, internalFluidDensityKgM3)
        let displacedMass = displacedArea * max(0, externalFluidDensityKgM3)
        let submergedEquivalentMass = pipeMass + contentsMass - displacedMass

        return PipeWeightBuoyancyResult(
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
