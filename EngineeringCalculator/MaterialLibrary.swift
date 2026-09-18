import Foundation
import SwiftUI

/// A scalar engineering property that can later be extended to tabulated/correlated data
/// without changing the material-library file format.
enum EngineeringPropertyValue: Hashable, Codable {
    case constant(Double)
    case temperatureTable([TemperaturePropertyPoint])

    private enum CodingKeys: String, CodingKey { case kind, value, points }
    private enum Kind: String, Codable { case constant, temperatureTable }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .constant:
            self = .constant(try c.decode(Double.self, forKey: .value))
        case .temperatureTable:
            self = .temperatureTable(try c.decode([TemperaturePropertyPoint].self, forKey: .points))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .constant(let value):
            try c.encode(Kind.constant, forKey: .kind)
            try c.encode(value, forKey: .value)
        case .temperatureTable(let points):
            try c.encode(Kind.temperatureTable, forKey: .kind)
            try c.encode(points, forKey: .points)
        }
    }

    var constantValue: Double? {
        if case .constant(let value) = self { return value }
        return nil
    }
}

struct TemperaturePropertyPoint: Hashable, Codable, Identifiable {
    var id: UUID = UUID()
    var temperatureC: Double
    var value: Double
}

struct MaterialLibraryDocument: Hashable, Codable {
    var format: String = "EngineeringCalculatorMaterialLibrary"
    var formatVersion: Int = 1
    var materials: [EngineeringMaterial]
}

@MainActor
final class MaterialLibraryStore: ObservableObject {
    @Published private(set) var userMaterials: [EngineeringMaterial] = []
    @Published var lastError: String?

    let builtInMaterials: [EngineeringMaterial] = [
        EngineeringMaterial(name: "Carbon Steel", category: "Metals", densityKgM3: 7850,
                            thermalConductivityWMK: 45, specificHeatCapacityJkgK: 475,
                            source: "Generic engineering reference values; verify for the selected grade and temperature.",
                            notes: "Thermal properties vary with composition and temperature.", isBuiltIn: true),
        EngineeringMaterial(name: "Concrete", category: "Cementitious", densityKgM3: 2400,
                            thermalConductivityWMK: 1.7, specificHeatCapacityJkgK: 880,
                            source: "Generic engineering reference values; verify for the selected mix and condition.",
                            notes: "Density and thermal properties vary substantially with mix and moisture content.", isBuiltIn: true),
        EngineeringMaterial(name: "Polypropylene", category: "Polymers", densityKgM3: 900,
                            thermalConductivityWMK: 0.22, specificHeatCapacityJkgK: 1900,
                            source: "Generic engineering reference values; verify against the product datasheet.",
                            notes: "Use manufacturer data for insulation-system calculations.", isBuiltIn: true)
    ]

    var allMaterials: [EngineeringMaterial] { builtInMaterials + userMaterials }

    init() { load() }

    func add(_ material: EngineeringMaterial) {
        var copy = material
        copy.isBuiltIn = false
        userMaterials.append(copy)
        save()
    }

    func update(_ material: EngineeringMaterial) {
        guard !material.isBuiltIn, let i = userMaterials.firstIndex(where: { $0.id == material.id }) else { return }
        userMaterials[i] = material
        save()
    }

    func duplicate(_ material: EngineeringMaterial) {
        var copy = material
        copy.id = UUID()
        copy.name += " Copy"
        copy.isBuiltIn = false
        userMaterials.append(copy)
        save()
    }

    func delete(at offsets: IndexSet) {
        userMaterials.remove(atOffsets: offsets)
        save()
    }

    private var fileURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("EngineeringCalculator", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("MaterialLibrary.json")
    }

    private func load() {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return }
        do { userMaterials = try JSONDecoder().decode(MaterialLibraryDocument.self, from: data).materials }
        catch { lastError = "Could not read the material library: \(error.localizedDescription)" }
    }

    private func save() {
        guard let url = fileURL else { return }
        do {
            let data = try JSONEncoder.pretty.encode(MaterialLibraryDocument(materials: userMaterials))
            try data.write(to: url, options: .atomic)
        } catch { lastError = "Could not save the material library: \(error.localizedDescription)" }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e
    }
}
