import Foundation
import SwiftUI

/// A material property may be a fixed value, a temperature/value table, or a polynomial
/// correlation. Temperature is the first supported independent variable; the model is
/// intentionally isolated so other variables can be added later without changing materials.
enum EngineeringPropertyValue: Hashable, Codable {
    case constant(Double)
    case temperatureTable([TemperaturePropertyPoint])
    case temperatureEquation(TemperatureEquation)

    private enum CodingKeys: String, CodingKey { case kind, value, points, equation }
    private enum Kind: String, Codable { case constant, temperatureTable, temperatureEquation }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .constant:
            self = .constant(try c.decode(Double.self, forKey: .value))
        case .temperatureTable:
            self = .temperatureTable(try c.decode([TemperaturePropertyPoint].self, forKey: .points))
        case .temperatureEquation:
            self = .temperatureEquation(try c.decode(TemperatureEquation.self, forKey: .equation))
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
        case .temperatureEquation(let equation):
            try c.encode(Kind.temperatureEquation, forKey: .kind)
            try c.encode(equation, forKey: .equation)
        }
    }

    var constantValue: Double? {
        if case .constant(let value) = self { return value }
        return nil
    }

    /// Returns nil outside the defined range unless extrapolation has explicitly been enabled.
    func value(atTemperatureC temperatureC: Double) -> Double? {
        switch self {
        case .constant(let value):
            return value

        case .temperatureTable(let unsortedPoints):
            let points = unsortedPoints.sorted { $0.temperatureC < $1.temperatureC }
            guard let first = points.first, let last = points.last else { return nil }
            if points.count == 1 { return temperatureC == first.temperatureC ? first.value : nil }
            guard temperatureC >= first.temperatureC, temperatureC <= last.temperatureC else { return nil }
            if temperatureC == first.temperatureC { return first.value }
            if temperatureC == last.temperatureC { return last.value }
            guard let upperIndex = points.firstIndex(where: { $0.temperatureC >= temperatureC }), upperIndex > 0 else { return nil }
            let lower = points[upperIndex - 1]
            let upper = points[upperIndex]
            let span = upper.temperatureC - lower.temperatureC
            guard span != 0 else { return lower.value }
            let fraction = (temperatureC - lower.temperatureC) / span
            return lower.value + fraction * (upper.value - lower.value)

        case .temperatureEquation(let equation):
            return equation.value(atTemperatureC: temperatureC)
        }
    }
}

struct TemperaturePropertyPoint: Hashable, Codable, Identifiable {
    var id: UUID = UUID()
    var temperatureC: Double
    var value: Double
}

/// Polynomial y(T) = a + bT + cT² + dT³, with T in degrees Celsius.
struct TemperatureEquation: Hashable, Codable {
    var a: Double
    var b: Double
    var c: Double
    var d: Double
    var minimumTemperatureC: Double?
    var maximumTemperatureC: Double?
    var allowsExtrapolation: Bool = false

    func value(atTemperatureC temperatureC: Double) -> Double? {
        if !allowsExtrapolation {
            if let minimumTemperatureC, temperatureC < minimumTemperatureC { return nil }
            if let maximumTemperatureC, temperatureC > maximumTemperatureC { return nil }
        }
        return a + b * temperatureC + c * temperatureC * temperatureC + d * temperatureC * temperatureC * temperatureC
    }
}

struct MaterialLibraryDocument: Hashable, Codable {
    var format: String = "EngineeringCalculatorMaterialLibrary"
    var formatVersion: Int = 2
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
