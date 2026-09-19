import Foundation

/// Versioned, portable engineering data types. These are deliberately Codable and
/// independent of SwiftData/Core Data so they can later be embedded in .ecproj files.
enum EngineeringDataSchema {
    static let currentVersion = 3
}

/// A temperature/value point used by sourced material-property tables.
struct MaterialPropertyPoint: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var temperatureC: Double
    var value: Double
}

/// A material property may be represented by a reference/room-temperature value and,
/// where the source provides it, a temperature-dependent table. No interpolation is
/// implied by storage alone; calculators can choose the appropriate interpolation rule.
struct MaterialPropertySeries: Hashable, Codable {
    var referenceValue: Double?
    var referenceTemperatureC: Double?
    var temperatureTable: [MaterialPropertyPoint]
    var source: String?
    var basis: String?

    init(referenceValue: Double? = nil,
         referenceTemperatureC: Double? = nil,
         temperatureTable: [MaterialPropertyPoint] = [],
         source: String? = nil,
         basis: String? = nil) {
        self.referenceValue = referenceValue
        self.referenceTemperatureC = referenceTemperatureC
        self.temperatureTable = temperatureTable
        self.source = source
        self.basis = basis
    }
}

struct EngineeringMaterial: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var category: String
    var densityKgM3: Double?
    var grade: String?
    var isBuiltIn: Bool

    // Material identity / applicability
    var unsDesignation: String?
    var standardDesignation: String?
    var productForm: String?
    var materialCondition: String?

    // Simple/reference values retained for backwards compatibility and quick calculators.
    // Advanced sourced series below provide temperature dependence where available.
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

    // Pipeline/code strength fields where applicable.
    var smysMPa: Double?
    var smtsMPa: Double?

    // Temperature-dependent/sourced property data.
    var thermalConductivitySeries: MaterialPropertySeries?
    var specificHeatCapacitySeries: MaterialPropertySeries?
    var thermalExpansionSeries: MaterialPropertySeries?
    var youngsModulusSeries: MaterialPropertySeries?
    var poissonsRatioSeries: MaterialPropertySeries?
    var yieldStrengthSeries: MaterialPropertySeries?
    var ultimateTensileStrengthSeries: MaterialPropertySeries?
    var shearModulusSeries: MaterialPropertySeries?
    var electricalResistivitySeries: MaterialPropertySeries?

    // Traceability
    var source: String?
    var notes: String?

    init(
        id: UUID = UUID(), name: String, category: String = "General",
        densityKgM3: Double? = nil, grade: String? = nil,
        thermalConductivityWMK: Double? = nil, specificHeatCapacityJkgK: Double? = nil,
        thermalExpansionMicrostrainPerK: Double? = nil,
        minimumServiceTemperatureC: Double? = nil, maximumServiceTemperatureC: Double? = nil,
        youngsModulusGPa: Double? = nil, poissonsRatio: Double? = nil,
        yieldStrengthMPa: Double? = nil, ultimateTensileStrengthMPa: Double? = nil,
        shearModulusGPa: Double? = nil, compressiveStrengthMPa: Double? = nil,
        electricalResistivityOhmM: Double? = nil,
        source: String? = nil, notes: String? = nil, isBuiltIn: Bool = false,
        unsDesignation: String? = nil, standardDesignation: String? = nil,
        productForm: String? = nil, materialCondition: String? = nil,
        smysMPa: Double? = nil, smtsMPa: Double? = nil,
        thermalConductivitySeries: MaterialPropertySeries? = nil,
        specificHeatCapacitySeries: MaterialPropertySeries? = nil,
        thermalExpansionSeries: MaterialPropertySeries? = nil,
        youngsModulusSeries: MaterialPropertySeries? = nil,
        poissonsRatioSeries: MaterialPropertySeries? = nil,
        yieldStrengthSeries: MaterialPropertySeries? = nil,
        ultimateTensileStrengthSeries: MaterialPropertySeries? = nil,
        shearModulusSeries: MaterialPropertySeries? = nil,
        electricalResistivitySeries: MaterialPropertySeries? = nil
    ) {
        self.id = id; self.name = name; self.category = category; self.densityKgM3 = densityKgM3
        self.grade = grade; self.isBuiltIn = isBuiltIn
        self.unsDesignation = unsDesignation; self.standardDesignation = standardDesignation
        self.productForm = productForm; self.materialCondition = materialCondition
        self.thermalConductivityWMK = thermalConductivityWMK
        self.specificHeatCapacityJkgK = specificHeatCapacityJkgK
        self.thermalExpansionMicrostrainPerK = thermalExpansionMicrostrainPerK
        self.minimumServiceTemperatureC = minimumServiceTemperatureC
        self.maximumServiceTemperatureC = maximumServiceTemperatureC
        self.youngsModulusGPa = youngsModulusGPa; self.poissonsRatio = poissonsRatio
        self.yieldStrengthMPa = yieldStrengthMPa; self.ultimateTensileStrengthMPa = ultimateTensileStrengthMPa
        self.shearModulusGPa = shearModulusGPa; self.compressiveStrengthMPa = compressiveStrengthMPa
        self.electricalResistivityOhmM = electricalResistivityOhmM
        self.smysMPa = smysMPa; self.smtsMPa = smtsMPa
        self.thermalConductivitySeries = thermalConductivitySeries
        self.specificHeatCapacitySeries = specificHeatCapacitySeries
        self.thermalExpansionSeries = thermalExpansionSeries
        self.youngsModulusSeries = youngsModulusSeries
        self.poissonsRatioSeries = poissonsRatioSeries
        self.yieldStrengthSeries = yieldStrengthSeries
        self.ultimateTensileStrengthSeries = ultimateTensileStrengthSeries
        self.shearModulusSeries = shearModulusSeries
        self.electricalResistivitySeries = electricalResistivitySeries
        self.source = source; self.notes = notes
    }
}

struct FluidDefinition: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var densityKgM3: Double
    var thermalConductivityWMK: Double?
    var specificHeatCapacityJkgK: Double?

    init(id: UUID = UUID(), name: String, densityKgM3: Double,
         thermalConductivityWMK: Double? = nil, specificHeatCapacityJkgK: Double? = nil) {
        self.id = id; self.name = name; self.densityKgM3 = densityKgM3
        self.thermalConductivityWMK = thermalConductivityWMK
        self.specificHeatCapacityJkgK = specificHeatCapacityJkgK
    }
}

struct PipeLayer: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var thicknessM: Double
    var material: EngineeringMaterial

    init(id: UUID = UUID(), name: String, thicknessM: Double, densityKgM3: Double) {
        self.id = id; self.name = name; self.thicknessM = thicknessM
        self.material = EngineeringMaterial(name: name, densityKgM3: densityKgM3)
    }
    init(id: UUID = UUID(), name: String, thicknessM: Double, material: EngineeringMaterial) {
        self.id = id; self.name = name; self.thicknessM = thicknessM; self.material = material
    }
    var densityKgM3: Double { material.densityKgM3 ?? 0 }
    var thermalConductivityWMK: Double? { material.thermalConductivityWMK }
    var specificHeatCapacityJkgK: Double? { material.specificHeatCapacityJkgK }
}

struct PipeConstruction: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var internalDiameterM: Double
    var layers: [PipeLayer]
    var internalFluid: FluidDefinition
    var externalFluid: FluidDefinition

    init(id: UUID = UUID(), name: String = "Untitled Pipe", internalDiameterM: Double,
         layers: [PipeLayer], internalFluid: FluidDefinition, externalFluid: FluidDefinition) {
        self.id = id; self.name = name; self.internalDiameterM = internalDiameterM
        self.layers = layers; self.internalFluid = internalFluid; self.externalFluid = externalFluid
    }
}
