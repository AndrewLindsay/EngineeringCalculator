import Foundation

enum MaterialComparisonSection: String, CaseIterable, Identifiable, Codable {
    case identity = "Identity & Traceability"
    case physical = "Physical"
    case thermal = "Thermal"
    case mechanical = "Mechanical"
    case electrical = "Electrical"
    case serviceLimits = "Service Limits"

    var id: Self { self }
}

enum MaterialComparisonValue: Hashable {
    case text(String)
    case number(Double, unit: String?)
    case propertySeries(MaterialPropertySeries)
    case missing
}

struct MaterialComparisonCell: Identifiable, Hashable {
    let materialID: UUID
    let value: MaterialComparisonValue
    let differsFromReference: Bool
    let absoluteDifference: Double?
    let percentageDifference: Double?

    var id: UUID { materialID }
}

struct MaterialComparisonRow: Identifiable, Hashable {
    let id: String
    let section: MaterialComparisonSection
    let label: String
    let cells: [MaterialComparisonCell]

    var hasDifference: Bool { cells.dropFirst().contains(where: \.differsFromReference) }
}

struct MaterialComparison: Hashable {
    let materials: [EngineeringMaterial]
    let referenceMaterialID: UUID
    let rows: [MaterialComparisonRow]

    var referenceMaterial: EngineeringMaterial? {
        materials.first { $0.id == referenceMaterialID }
    }

    var differingRows: [MaterialComparisonRow] { rows.filter(\.hasDifference) }
    func rows(in section: MaterialComparisonSection) -> [MaterialComparisonRow] { rows.filter { $0.section == section } }
}

enum MaterialComparisonEngine {
    /// Relative tolerance used for engineering numeric equality. This avoids
    /// reporting changes caused only by floating-point representation noise.
    static let relativeTolerance = 1e-9
    static let absoluteTolerance = 1e-12

    static func compare(_ materials: [EngineeringMaterial], referenceMaterialID: UUID? = nil) -> MaterialComparison {
        guard !materials.isEmpty else {
            return MaterialComparison(materials: [], referenceMaterialID: UUID(), rows: [])
        }

        let referenceID = referenceMaterialID.flatMap { requested in
            materials.contains(where: { $0.id == requested }) ? requested : nil
        } ?? materials[0].id

        // Keep the reference first. This makes every row/report deterministic
        // and allows later UI reordering without changing comparison semantics.
        let ordered = materials.first(where: { $0.id == referenceID }).map { reference in
            [reference] + materials.filter { $0.id != referenceID }
        } ?? materials

        var rows: [MaterialComparisonRow] = []

        func textRow(_ id: String, _ section: MaterialComparisonSection, _ label: String, _ value: (EngineeringMaterial) -> String?) {
            rows.append(makeRow(id: id, section: section, label: label, materials: ordered) { material in
                value(material).map(MaterialComparisonValue.text) ?? .missing
            })
        }

        func numberRow(_ id: String, _ section: MaterialComparisonSection, _ label: String, unit: String?, _ value: (EngineeringMaterial) -> Double?) {
            rows.append(makeRow(id: id, section: section, label: label, materials: ordered) { material in
                value(material).map { .number($0, unit: unit) } ?? .missing
            })
        }

        func seriesRow(_ id: String, _ section: MaterialComparisonSection, _ label: String, _ value: (EngineeringMaterial) -> MaterialPropertySeries?) {
            rows.append(makeRow(id: id, section: section, label: label, materials: ordered) { material in
                value(material).map(MaterialComparisonValue.propertySeries) ?? .missing
            })
        }

        textRow("category", .identity, "Category", \.category)
        textRow("grade", .identity, "Grade", \.grade)
        textRow("unsDesignation", .identity, "UNS designation", \.unsDesignation)
        textRow("standardDesignation", .identity, "Standard designation", \.standardDesignation)
        textRow("productForm", .identity, "Product form", \.productForm)
        textRow("materialCondition", .identity, "Material condition", \.materialCondition)
        textRow("source", .identity, "Source", \.source)
        textRow("notes", .identity, "Notes", \.notes)

        numberRow("density", .physical, "Density", unit: "kg/m³", \.densityKgM3)

        numberRow("thermalConductivity", .thermal, "Thermal conductivity", unit: "W/(m·K)", \.thermalConductivityWMK)
        seriesRow("thermalConductivityModel", .thermal, "Thermal conductivity model", \.thermalConductivitySeries)
        numberRow("specificHeatCapacity", .thermal, "Specific heat capacity", unit: "J/(kg·K)", \.specificHeatCapacityJkgK)
        seriesRow("specificHeatCapacityModel", .thermal, "Specific heat capacity model", \.specificHeatCapacitySeries)
        numberRow("thermalExpansion", .thermal, "Thermal expansion", unit: "µm/(m·K)", \.thermalExpansionMicrostrainPerK)
        seriesRow("thermalExpansionModel", .thermal, "Thermal expansion model", \.thermalExpansionSeries)

        numberRow("youngsModulus", .mechanical, "Young's modulus", unit: "GPa", \.youngsModulusGPa)
        seriesRow("youngsModulusModel", .mechanical, "Young's modulus model", \.youngsModulusSeries)
        numberRow("poissonsRatio", .mechanical, "Poisson's ratio", unit: nil, \.poissonsRatio)
        seriesRow("poissonsRatioModel", .mechanical, "Poisson's ratio model", \.poissonsRatioSeries)
        numberRow("yieldStrength", .mechanical, "Yield strength", unit: "MPa", \.yieldStrengthMPa)
        seriesRow("yieldStrengthModel", .mechanical, "Yield strength model", \.yieldStrengthSeries)
        numberRow("ultimateTensileStrength", .mechanical, "Ultimate tensile strength", unit: "MPa", \.ultimateTensileStrengthMPa)
        seriesRow("ultimateTensileStrengthModel", .mechanical, "Ultimate tensile strength model", \.ultimateTensileStrengthSeries)
        numberRow("shearModulus", .mechanical, "Shear modulus", unit: "GPa", \.shearModulusGPa)
        seriesRow("shearModulusModel", .mechanical, "Shear modulus model", \.shearModulusSeries)
        numberRow("compressiveStrength", .mechanical, "Compressive strength", unit: "MPa", \.compressiveStrengthMPa)
        numberRow("smys", .mechanical, "SMYS", unit: "MPa", \.smysMPa)
        numberRow("smts", .mechanical, "SMTS", unit: "MPa", \.smtsMPa)

        numberRow("electricalResistivity", .electrical, "Electrical resistivity", unit: "Ω·m", \.electricalResistivityOhmM)
        seriesRow("electricalResistivityModel", .electrical, "Electrical resistivity model", \.electricalResistivitySeries)

        numberRow("minimumServiceTemperature", .serviceLimits, "Minimum service temperature", unit: "°C", \.minimumServiceTemperatureC)
        numberRow("maximumServiceTemperature", .serviceLimits, "Maximum service temperature", unit: "°C", \.maximumServiceTemperatureC)

        return MaterialComparison(materials: ordered, referenceMaterialID: referenceID, rows: rows)
    }

    private static func makeRow(
        id: String,
        section: MaterialComparisonSection,
        label: String,
        materials: [EngineeringMaterial],
        value: (EngineeringMaterial) -> MaterialComparisonValue
    ) -> MaterialComparisonRow {
        let values = materials.map(value)
        let reference = values.first ?? .missing
        let cells = zip(materials, values).enumerated().map { index, pair in
            let (material, current) = pair
            let differs = index == 0 ? false : !equivalent(reference, current)
            let differences = numericDifferences(reference: reference, current: current)
            return MaterialComparisonCell(
                materialID: material.id,
                value: current,
                differsFromReference: differs,
                absoluteDifference: differs ? differences.absolute : nil,
                percentageDifference: differs ? differences.percentage : nil
            )
        }
        return MaterialComparisonRow(id: id, section: section, label: label, cells: cells)
    }

    private static func numericDifferences(reference: MaterialComparisonValue, current: MaterialComparisonValue) -> (absolute: Double?, percentage: Double?) {
        guard case let .number(referenceValue, _) = reference,
              case let .number(currentValue, _) = current else { return (nil, nil) }
        let delta = currentValue - referenceValue
        let percentage = approximatelyEqual(referenceValue, 0) ? nil : delta / referenceValue * 100
        return (delta, percentage)
    }

    private static func equivalent(_ lhs: MaterialComparisonValue, _ rhs: MaterialComparisonValue) -> Bool {
        switch (lhs, rhs) {
        case (.missing, .missing): return true
        case let (.text(a), .text(b)): return a == b
        case let (.number(a, unitA), .number(b, unitB)): return unitA == unitB && approximatelyEqual(a, b)
        case let (.propertySeries(a), .propertySeries(b)): return equivalent(a, b)
        default: return false
        }
    }

    private static func equivalent(_ lhs: MaterialPropertySeries, _ rhs: MaterialPropertySeries) -> Bool {
        optionalApproximatelyEqual(lhs.referenceValue, rhs.referenceValue) &&
        optionalApproximatelyEqual(lhs.referenceTemperatureC, rhs.referenceTemperatureC) &&
        pointsEquivalent(lhs.temperatureTable, rhs.temperatureTable) &&
        equationsEquivalent(lhs.equation, rhs.equation) &&
        lhs.source == rhs.source &&
        lhs.basis == rhs.basis
    }

    private static func pointsEquivalent(_ lhs: [MaterialPropertyPoint], _ rhs: [MaterialPropertyPoint]) -> Bool {
        let a = lhs.sorted { $0.temperatureC < $1.temperatureC }
        let b = rhs.sorted { $0.temperatureC < $1.temperatureC }
        guard a.count == b.count else { return false }
        return zip(a, b).allSatisfy { approximatelyEqual($0.temperatureC, $1.temperatureC) && approximatelyEqual($0.value, $1.value) }
    }

    private static func equationsEquivalent(_ lhs: MaterialPropertyEquation?, _ rhs: MaterialPropertyEquation?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): return true
        case let (a?, b?):
            return a.effectiveKind == b.effectiveKind &&
                approximatelyEqual(a.a, b.a) && approximatelyEqual(a.b, b.b) &&
                approximatelyEqual(a.c, b.c) && approximatelyEqual(a.d, b.d) &&
                optionalApproximatelyEqual(a.minimumTemperatureC, b.minimumTemperatureC) &&
                optionalApproximatelyEqual(a.maximumTemperatureC, b.maximumTemperatureC) &&
                a.allowsExtrapolation == b.allowsExtrapolation &&
                optionalApproximatelyEqual(a.referenceValue, b.referenceValue) &&
                optionalApproximatelyEqual(a.referenceTemperatureC, b.referenceTemperatureC) &&
                optionalApproximatelyEqual(a.slope, b.slope) &&
                optionalApproximatelyEqual(a.temperatureCoefficient, b.temperatureCoefficient)
        default: return false
        }
    }

    private static func optionalApproximatelyEqual(_ lhs: Double?, _ rhs: Double?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): return true
        case let (a?, b?): return approximatelyEqual(a, b)
        default: return false
        }
    }

    private static func approximatelyEqual(_ lhs: Double, _ rhs: Double) -> Bool {
        let scale = max(abs(lhs), abs(rhs), 1)
        return abs(lhs - rhs) <= max(absoluteTolerance, relativeTolerance * scale)
    }
}
