import Foundation

/// Versioned, portable engineering data types. These are deliberately Codable and
/// independent of SwiftData/Core Data so they can later be embedded in .ecproj files.
enum EngineeringDataSchema {
    static let currentVersion = 1
}

struct EngineeringMaterial: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var category: String
    var densityKgM3: Double?
    var grade: String?
    var isBuiltIn: Bool
    var thermalConductivityWMK: Double?
    var specificHeatCapacityJkgK: Double?
    var source: String?
    var notes: String?

    init(
        id: UUID = UUID(),
        name: String,
        category: String = "General",
        densityKgM3: Double? = nil,
        grade: String? = nil,
        thermalConductivityWMK: Double? = nil,
        specificHeatCapacityJkgK: Double? = nil,
        source: String? = nil,
        notes: String? = nil,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.densityKgM3 = densityKgM3
        self.grade = grade
        self.isBuiltIn = isBuiltIn
        self.thermalConductivityWMK = thermalConductivityWMK
        self.specificHeatCapacityJkgK = specificHeatCapacityJkgK
        self.source = source
        self.notes = notes
    }
}

struct FluidDefinition: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var densityKgM3: Double
    var thermalConductivityWMK: Double?
    var specificHeatCapacityJkgK: Double?

    init(
        id: UUID = UUID(),
        name: String,
        densityKgM3: Double,
        thermalConductivityWMK: Double? = nil,
        specificHeatCapacityJkgK: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.densityKgM3 = densityKgM3
        self.thermalConductivityWMK = thermalConductivityWMK
        self.specificHeatCapacityJkgK = specificHeatCapacityJkgK
    }
}

struct PipeLayer: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var thicknessM: Double
    var material: EngineeringMaterial

    /// Compatibility initializer for existing calculators and tests.
    init(id: UUID = UUID(), name: String, thicknessM: Double, densityKgM3: Double) {
        self.id = id
        self.name = name
        self.thicknessM = thicknessM
        self.material = EngineeringMaterial(
            name: name,
            densityKgM3: densityKgM3
        )
    }

    init(id: UUID = UUID(), name: String, thicknessM: Double, material: EngineeringMaterial) {
        self.id = id
        self.name = name
        self.thicknessM = thicknessM
        self.material = material
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

    init(
        id: UUID = UUID(),
        name: String = "Untitled Pipe",
        internalDiameterM: Double,
        layers: [PipeLayer],
        internalFluid: FluidDefinition,
        externalFluid: FluidDefinition
    ) {
        self.id = id
        self.name = name
        self.internalDiameterM = internalDiameterM
        self.layers = layers
        self.internalFluid = internalFluid
        self.externalFluid = externalFluid
    }
}
