import Foundation
import CryptoKit

/// Canonical, versioned fingerprint for a complete engineering-material definition.
/// UUID/editor identity and local `isBuiltIn` status are deliberately excluded.
enum MaterialFingerprint {
    static let algorithmVersion = 1
    static let algorithmName = "sha256-material-v1"

    static func make(for material: EngineeringMaterial) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(CanonicalMaterial(material))
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private struct CanonicalMaterial: Codable {
        var name: String
        var category: String
        var densityKgM3: Double?
        var grade: String?
        var thermalConductivityWMK: Double?
        var specificHeatCapacityJkgK: Double?
        var thermalExpansionMicrostrainPerK: Double?
        var minimumServiceTemperatureC: Double?
        var maximumServiceTemperatureC: Double?
        var youngsModulusGPa: Double?
        var poissonsRatio: Double?
        var yieldStrengthMPa: Double?
        var ultimateTensileStrengthMPa: Double?
        var shearModulusGPa: Double?
        var compressiveStrengthMPa: Double?
        var electricalResistivityOhmM: Double?
        var source: String?
        var notes: String?
        var unsDesignation: String?
        var standardDesignation: String?
        var productForm: String?
        var materialCondition: String?
        var smysMPa: Double?
        var smtsMPa: Double?
        var thermalConductivitySeries: CanonicalSeries?
        var specificHeatCapacitySeries: CanonicalSeries?
        var thermalExpansionSeries: CanonicalSeries?
        var youngsModulusSeries: CanonicalSeries?
        var poissonsRatioSeries: CanonicalSeries?
        var yieldStrengthSeries: CanonicalSeries?
        var ultimateTensileStrengthSeries: CanonicalSeries?
        var shearModulusSeries: CanonicalSeries?
        var electricalResistivitySeries: CanonicalSeries?

        init(_ material: EngineeringMaterial) {
            name = material.name
            category = material.category
            densityKgM3 = material.densityKgM3
            grade = material.grade
            thermalConductivityWMK = material.thermalConductivityWMK
            specificHeatCapacityJkgK = material.specificHeatCapacityJkgK
            thermalExpansionMicrostrainPerK = material.thermalExpansionMicrostrainPerK
            minimumServiceTemperatureC = material.minimumServiceTemperatureC
            maximumServiceTemperatureC = material.maximumServiceTemperatureC
            youngsModulusGPa = material.youngsModulusGPa
            poissonsRatio = material.poissonsRatio
            yieldStrengthMPa = material.yieldStrengthMPa
            ultimateTensileStrengthMPa = material.ultimateTensileStrengthMPa
            shearModulusGPa = material.shearModulusGPa
            compressiveStrengthMPa = material.compressiveStrengthMPa
            electricalResistivityOhmM = material.electricalResistivityOhmM
            source = material.source
            notes = material.notes
            unsDesignation = material.unsDesignation
            standardDesignation = material.standardDesignation
            productForm = material.productForm
            materialCondition = material.materialCondition
            smysMPa = material.smysMPa
            smtsMPa = material.smtsMPa
            thermalConductivitySeries = material.thermalConductivitySeries.map(CanonicalSeries.init)
            specificHeatCapacitySeries = material.specificHeatCapacitySeries.map(CanonicalSeries.init)
            thermalExpansionSeries = material.thermalExpansionSeries.map(CanonicalSeries.init)
            youngsModulusSeries = material.youngsModulusSeries.map(CanonicalSeries.init)
            poissonsRatioSeries = material.poissonsRatioSeries.map(CanonicalSeries.init)
            yieldStrengthSeries = material.yieldStrengthSeries.map(CanonicalSeries.init)
            ultimateTensileStrengthSeries = material.ultimateTensileStrengthSeries.map(CanonicalSeries.init)
            shearModulusSeries = material.shearModulusSeries.map(CanonicalSeries.init)
            electricalResistivitySeries = material.electricalResistivitySeries.map(CanonicalSeries.init)
        }
    }

    private struct CanonicalSeries: Codable {
        var referenceValue: Double?
        var referenceTemperatureC: Double?
        var temperatureTable: [CanonicalPoint]
        var equation: CanonicalEquation?
        var source: String?
        var basis: String?

        init(_ series: MaterialPropertySeries) {
            referenceValue = series.referenceValue
            referenceTemperatureC = series.referenceTemperatureC
            temperatureTable = series.temperatureTable.map { CanonicalPoint(temperatureC: $0.temperatureC, value: $0.value) }
            equation = series.equation.map(CanonicalEquation.init)
            source = series.source
            basis = series.basis
        }
    }

    private struct CanonicalPoint: Codable {
        var temperatureC: Double
        var value: Double
    }

    private struct CanonicalEquation: Codable {
        var a: Double
        var b: Double
        var c: Double
        var d: Double
        var minimumTemperatureC: Double?
        var maximumTemperatureC: Double?
        var allowsExtrapolation: Bool
        var kind: MaterialEquationKind?
        var referenceValue: Double?
        var referenceTemperatureC: Double?
        var slope: Double?
        var temperatureCoefficient: Double?

        init(_ equation: MaterialPropertyEquation) {
            a = equation.a
            b = equation.b
            c = equation.c
            d = equation.d
            minimumTemperatureC = equation.minimumTemperatureC
            maximumTemperatureC = equation.maximumTemperatureC
            allowsExtrapolation = equation.allowsExtrapolation
            kind = equation.kind
            referenceValue = equation.referenceValue
            referenceTemperatureC = equation.referenceTemperatureC
            slope = equation.slope
            temperatureCoefficient = equation.temperatureCoefficient
        }
    }
}
