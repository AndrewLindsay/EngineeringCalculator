import SwiftUI
#if os(macOS)
import AppKit
#endif

enum MaterialComparisonSection: String, CaseIterable, Identifiable, Codable {
    case identity = "Identity & Traceability"
    case physical = "Physical"
    case thermal = "Thermal"
    case mechanical = "Mechanical"
    case electrical = "Electrical"
    case serviceLimits = "Service Limits"
    var id: Self { self }
}

enum MaterialComparisonValue: Hashable { case text(String); case number(Double, unit: String?); case propertySeries(MaterialPropertySeries); case missing }
struct MaterialComparisonCell: Identifiable, Hashable { let materialID: UUID; let value: MaterialComparisonValue; let differsFromReference: Bool; let absoluteDifference: Double?; let percentageDifference: Double?; var id: UUID { materialID } }
struct MaterialComparisonRow: Identifiable, Hashable { let id: String; let section: MaterialComparisonSection; let label: String; let cells: [MaterialComparisonCell]; var hasDifference: Bool { cells.dropFirst().contains(where: \.differsFromReference) } }
struct MaterialComparison: Hashable { let materials: [EngineeringMaterial]; let referenceMaterialID: UUID; let rows: [MaterialComparisonRow]; var referenceMaterial: EngineeringMaterial? { materials.first { $0.id == referenceMaterialID } }; var differingRows: [MaterialComparisonRow] { rows.filter(\.hasDifference) }; func rows(in section: MaterialComparisonSection) -> [MaterialComparisonRow] { rows.filter { $0.section == section } } }

enum MaterialComparisonEngine {
    static let relativeTolerance = 1e-9
    static let absoluteTolerance = 1e-12
    static func compare(_ materials: [EngineeringMaterial], referenceMaterialID: UUID? = nil) -> MaterialComparison {
        guard !materials.isEmpty else { return MaterialComparison(materials: [], referenceMaterialID: UUID(), rows: []) }
        let referenceID = referenceMaterialID.flatMap { requested in materials.contains(where: { $0.id == requested }) ? requested : nil } ?? materials[0].id
        let ordered = materials.first(where: { $0.id == referenceID }).map { reference in [reference] + materials.filter { $0.id != referenceID } } ?? materials
        var rows: [MaterialComparisonRow] = []
        func textRow(_ id: String, _ section: MaterialComparisonSection, _ label: String, _ value: (EngineeringMaterial) -> String?) { rows.append(makeRow(id: id, section: section, label: label, materials: ordered) { material in value(material).map(MaterialComparisonValue.text) ?? .missing }) }
        func numberRow(_ id: String, _ section: MaterialComparisonSection, _ label: String, unit: String?, _ value: (EngineeringMaterial) -> Double?) { rows.append(makeRow(id: id, section: section, label: label, materials: ordered) { material in value(material).map { .number($0, unit: unit) } ?? .missing }) }
        func seriesRow(_ id: String, _ section: MaterialComparisonSection, _ label: String, _ value: (EngineeringMaterial) -> MaterialPropertySeries?) { rows.append(makeRow(id: id, section: section, label: label, materials: ordered) { material in value(material).map(MaterialComparisonValue.propertySeries) ?? .missing }) }
        textRow("category", .identity, "Category", \.category); textRow("grade", .identity, "Grade", \.grade); textRow("unsDesignation", .identity, "UNS designation", \.unsDesignation); textRow("standardDesignation", .identity, "Standard designation", \.standardDesignation); textRow("productForm", .identity, "Product form", \.productForm); textRow("materialCondition", .identity, "Material condition", \.materialCondition); textRow("source", .identity, "Source", \.source); textRow("notes", .identity, "Notes", \.notes)
        numberRow("density", .physical, "Density", unit: "kg/m³", \.densityKgM3)
        numberRow("thermalConductivity", .thermal, "Thermal conductivity", unit: "W/(m·K)", \.thermalConductivityWMK); seriesRow("thermalConductivityModel", .thermal, "Thermal conductivity model", \.thermalConductivitySeries); numberRow("specificHeatCapacity", .thermal, "Specific heat capacity", unit: "J/(kg·K)", \.specificHeatCapacityJkgK); seriesRow("specificHeatCapacityModel", .thermal, "Specific heat capacity model", \.specificHeatCapacitySeries); numberRow("thermalExpansion", .thermal, "Thermal expansion", unit: "µm/(m·K)", \.thermalExpansionMicrostrainPerK); seriesRow("thermalExpansionModel", .thermal, "Thermal expansion model", \.thermalExpansionSeries)
        numberRow("youngsModulus", .mechanical, "Young's modulus", unit: "GPa", \.youngsModulusGPa); seriesRow("youngsModulusModel", .mechanical, "Young's modulus model", \.youngsModulusSeries); numberRow("poissonsRatio", .mechanical, "Poisson's ratio", unit: nil, \.poissonsRatio); seriesRow("poissonsRatioModel", .mechanical, "Poisson's ratio model", \.poissonsRatioSeries); numberRow("yieldStrength", .mechanical, "Yield strength", unit: "MPa", \.yieldStrengthMPa); seriesRow("yieldStrengthModel", .mechanical, "Yield strength model", \.yieldStrengthSeries); numberRow("ultimateTensileStrength", .mechanical, "Ultimate tensile strength", unit: "MPa", \.ultimateTensileStrengthMPa); seriesRow("ultimateTensileStrengthModel", .mechanical, "Ultimate tensile strength model", \.ultimateTensileStrengthSeries); numberRow("shearModulus", .mechanical, "Shear modulus", unit: "GPa", \.shearModulusGPa); seriesRow("shearModulusModel", .mechanical, "Shear modulus model", \.shearModulusSeries); numberRow("compressiveStrength", .mechanical, "Compressive strength", unit: "MPa", \.compressiveStrengthMPa); numberRow("smys", .mechanical, "SMYS", unit: "MPa", \.smysMPa); numberRow("smts", .mechanical, "SMTS", unit: "MPa", \.smtsMPa)
        numberRow("electricalResistivity", .electrical, "Electrical resistivity", unit: "Ω·m", \.electricalResistivityOhmM); seriesRow("electricalResistivityModel", .electrical, "Electrical resistivity model", \.electricalResistivitySeries)
        numberRow("minimumServiceTemperature", .serviceLimits, "Minimum service temperature", unit: "°C", \.minimumServiceTemperatureC); numberRow("maximumServiceTemperature", .serviceLimits, "Maximum service temperature", unit: "°C", \.maximumServiceTemperatureC)
        return MaterialComparison(materials: ordered, referenceMaterialID: referenceID, rows: rows)
    }
    private static func makeRow(id: String, section: MaterialComparisonSection, label: String, materials: [EngineeringMaterial], value: (EngineeringMaterial) -> MaterialComparisonValue) -> MaterialComparisonRow { let values = materials.map(value); let reference = values.first ?? .missing; let cells = zip(materials, values).enumerated().map { index, pair in let (material, current) = pair; let differs = index == 0 ? false : !equivalent(reference, current); let differences = numericDifferences(reference: reference, current: current); return MaterialComparisonCell(materialID: material.id, value: current, differsFromReference: differs, absoluteDifference: differs ? differences.absolute : nil, percentageDifference: differs ? differences.percentage : nil) }; return MaterialComparisonRow(id: id, section: section, label: label, cells: cells) }
    private static func numericDifferences(reference: MaterialComparisonValue, current: MaterialComparisonValue) -> (absolute: Double?, percentage: Double?) { guard case let .number(referenceValue, _) = reference, case let .number(currentValue, _) = current else { return (nil, nil) }; let delta = currentValue - referenceValue; let percentage = approximatelyEqual(referenceValue, 0) ? nil : delta / referenceValue * 100; return (delta, percentage) }
    private static func equivalent(_ lhs: MaterialComparisonValue, _ rhs: MaterialComparisonValue) -> Bool { switch (lhs, rhs) { case (.missing, .missing): return true; case let (.text(a), .text(b)): return a == b; case let (.number(a, unitA), .number(b, unitB)): return unitA == unitB && approximatelyEqual(a, b); case let (.propertySeries(a), .propertySeries(b)): return equivalent(a, b); default: return false } }
    private static func equivalent(_ lhs: MaterialPropertySeries, _ rhs: MaterialPropertySeries) -> Bool { optionalApproximatelyEqual(lhs.referenceValue, rhs.referenceValue) && optionalApproximatelyEqual(lhs.referenceTemperatureC, rhs.referenceTemperatureC) && pointsEquivalent(lhs.temperatureTable, rhs.temperatureTable) && equationsEquivalent(lhs.equation, rhs.equation) && lhs.source == rhs.source && lhs.basis == rhs.basis }
    private static func pointsEquivalent(_ lhs: [MaterialPropertyPoint], _ rhs: [MaterialPropertyPoint]) -> Bool { let a = lhs.sorted { $0.temperatureC < $1.temperatureC }; let b = rhs.sorted { $0.temperatureC < $1.temperatureC }; guard a.count == b.count else { return false }; return zip(a, b).allSatisfy { approximatelyEqual($0.temperatureC, $1.temperatureC) && approximatelyEqual($0.value, $1.value) } }
    private static func equationsEquivalent(_ lhs: MaterialPropertyEquation?, _ rhs: MaterialPropertyEquation?) -> Bool { switch (lhs, rhs) { case (nil, nil): return true; case let (a?, b?): return a.effectiveKind == b.effectiveKind && approximatelyEqual(a.a, b.a) && approximatelyEqual(a.b, b.b) && approximatelyEqual(a.c, b.c) && approximatelyEqual(a.d, b.d) && optionalApproximatelyEqual(a.minimumTemperatureC, b.minimumTemperatureC) && optionalApproximatelyEqual(a.maximumTemperatureC, b.maximumTemperatureC) && a.allowsExtrapolation == b.allowsExtrapolation && optionalApproximatelyEqual(a.referenceValue, b.referenceValue) && optionalApproximatelyEqual(a.referenceTemperatureC, b.referenceTemperatureC) && optionalApproximatelyEqual(a.slope, b.slope) && optionalApproximatelyEqual(a.temperatureCoefficient, b.temperatureCoefficient); default: return false } }
    private static func optionalApproximatelyEqual(_ lhs: Double?, _ rhs: Double?) -> Bool { switch (lhs, rhs) { case (nil, nil): return true; case let (a?, b?): return approximatelyEqual(a, b); default: return false } }
    private static func approximatelyEqual(_ lhs: Double, _ rhs: Double) -> Bool { let scale = max(abs(lhs), abs(rhs), 1); return abs(lhs - rhs) <= max(absoluteTolerance, relativeTolerance * scale) }
}

struct MaterialComparisonView: View {
    @EnvironmentObject private var store: MaterialLibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: Set<UUID>
    @State private var selectionOrder: [UUID]
    @State private var referenceID: UUID?
    @State private var differencesOnly = false
    @State private var showingComparison: Bool
    private let standaloneWindow: Bool

    private let propertyColumnWidth: CGFloat = 220
    private let materialColumnWidth: CGFloat = 190

    init(initialSelectionOrder: [UUID] = [], referenceID: UUID? = nil, showingComparison: Bool = false, standaloneWindow: Bool = false) {
        _selectedIDs = State(initialValue: Set(initialSelectionOrder))
        _selectionOrder = State(initialValue: initialSelectionOrder)
        _referenceID = State(initialValue: referenceID ?? initialSelectionOrder.first)
        _showingComparison = State(initialValue: showingComparison)
        self.standaloneWindow = standaloneWindow
    }

    private var allMaterials: [EngineeringMaterial] { store.allMaterials.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending } }
    private var selectedMaterials: [EngineeringMaterial] { selectionOrder.compactMap { id in allMaterials.first { $0.id == id } } }
    private var comparison: MaterialComparison? { guard showingComparison, selectedMaterials.count >= 2 else { return nil }; return MaterialComparisonEngine.compare(selectedMaterials, referenceMaterialID: referenceID) }

    var body: some View {
        NavigationStack {
            Group { if let comparison { comparisonContent(comparison) } else { selectionContent } }
                .navigationTitle("Compare Materials")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { closeView() } } }
        }
        #if os(macOS)
        .frame(minWidth: 760, idealWidth: 1100, maxWidth: .infinity, minHeight: 560, idealHeight: 720, maxHeight: .infinity)
        #else
        .frame(minWidth: 620, minHeight: 520)
        #endif
        .onChange(of: selectedIDs) { _, _ in normaliseReference() }
    }

    private var selectionContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select two or more materials to compare.").font(.headline)
            Text("The first material selected becomes the reference. Selection badges show the comparison order.").font(.callout).foregroundStyle(.secondary)
            List { ForEach(groupedCategories, id: \.self) { category in Section(category) { ForEach(allMaterials.filter { $0.category == category }) { material in Button { toggle(material.id) } label: { HStack { Image(systemName: selectedIDs.contains(material.id) ? "checkmark.circle.fill" : "circle"); VStack(alignment: .leading) { Text(material.name); Text(material.isBuiltIn ? "Built-in" : "My Material").font(.caption).foregroundStyle(.secondary) }; Spacer(); selectionBadge(for: material.id) }.contentShape(Rectangle()) }.buttonStyle(.plain) } } } }
            HStack {
                Text("\(selectedIDs.count) selected").foregroundStyle(.secondary)
                Spacer()
                Button("Compare (\(selectedIDs.count))") { beginComparison() }.buttonStyle(.borderedProminent).disabled(selectedIDs.count < 2)
            }
        }.padding(20)
    }

    @ViewBuilder private func selectionBadge(for id: UUID) -> some View { if let index = selectionOrder.firstIndex(of: id) { if index == 0 { Text("R").font(.caption2.bold()).foregroundStyle(.white).frame(width: 24, height: 24).background(Color.green, in: Circle()).accessibilityLabel("Reference material, selected first") } else { Text("\(index + 1)").font(.caption2.bold()).foregroundStyle(.white).frame(width: 24, height: 24).background(Color.accentColor, in: Circle()).accessibilityLabel("Selection \(index + 1)") } } }
    private var groupedCategories: [String] { Array(Set(allMaterials.map(\.category))).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending } }

    private func comparisonContent(_ comparison: MaterialComparison) -> some View {
        VStack(spacing: 0) {
            HStack { Picker("Reference", selection: Binding(get: { referenceID ?? comparison.referenceMaterialID }, set: { referenceID = $0 })) { ForEach(selectedMaterials) { Text($0.name).tag($0.id) } }.frame(maxWidth: 360); Toggle("Differences Only", isOn: $differencesOnly); Spacer(); if !standaloneWindow { Button("Change Materials") { showingComparison = false } } }.padding(16)
            Divider()
            comparisonTable(comparison)
        }
    }

    @ViewBuilder
    private func comparisonTable(_ comparison: MaterialComparison) -> some View {
        #if os(macOS)
        macComparisonTable(comparison)
        #else
        mobileComparisonTable(comparison)
        #endif
    }

    #if os(macOS)
    private func macComparisonTable(_ comparison: MaterialComparison) -> some View {
        let rows = differencesOnly ? comparison.differingRows : comparison.rows
        return HStack(spacing: 0) {
            frozenColumns(comparison, rows: rows)
            Divider()
            ScrollView(.horizontal) {
                scrollingColumns(comparison, rows: rows)
            }
        }
    }

    private func frozenColumns(_ comparison: MaterialComparison, rows: [MaterialComparisonRow]) -> some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text("Property").fontWeight(.semibold).frame(width: propertyColumnWidth, alignment: .leading).padding(8)
                    if let reference = comparison.materials.first { materialHeader(reference, subtitle: "Reference") }
                }.background(.quaternary.opacity(0.35))
                ForEach(MaterialComparisonSection.allCases) { section in
                    let sectionRows = rows.filter { $0.section == section }
                    if !sectionRows.isEmpty {
                        Text(section.rawValue).font(.headline).frame(width: propertyColumnWidth + materialColumnWidth + 32, alignment: .leading).padding(8).background(.regularMaterial)
                        ForEach(sectionRows) { row in
                            HStack(alignment: .top, spacing: 0) {
                                Text(row.label).frame(width: propertyColumnWidth, alignment: .leading).padding(8)
                                if let referenceCell = row.cells.first { comparisonCell(referenceCell) }
                            }.overlay(alignment: .bottom) { Divider() }
                        }
                    }
                }
            }.padding(12)
        }
    }

    private func scrollingColumns(_ comparison: MaterialComparison, rows: [MaterialComparisonRow]) -> some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Array(comparison.materials.dropFirst())) { material in materialHeader(material, subtitle: "Compared") }
                }.background(.quaternary.opacity(0.35))
                ForEach(MaterialComparisonSection.allCases) { section in
                    let sectionRows = rows.filter { $0.section == section }
                    if !sectionRows.isEmpty {
                        Text(section.rawValue).font(.headline).frame(width: CGFloat(max(1, comparison.materials.count - 1)) * (materialColumnWidth + 16), alignment: .leading).padding(8).background(.regularMaterial)
                        ForEach(sectionRows) { row in
                            HStack(alignment: .top, spacing: 0) {
                                ForEach(Array(row.cells.dropFirst())) { cell in comparisonCell(cell) }
                            }.overlay(alignment: .bottom) { Divider() }
                        }
                    }
                }
            }.padding(12)
        }
    }
    #endif

    private func mobileComparisonTable(_ comparison: MaterialComparison) -> some View {
        let rows = differencesOnly ? comparison.differingRows : comparison.rows
        return ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text("Property").fontWeight(.semibold).frame(width: propertyColumnWidth, alignment: .leading).padding(8)
                    ForEach(comparison.materials) { material in materialHeader(material, subtitle: material.id == comparison.referenceMaterialID ? "Reference" : "Compared") }
                }.background(.quaternary.opacity(0.35))
                ForEach(MaterialComparisonSection.allCases) { section in
                    let sectionRows = rows.filter { $0.section == section }
                    if !sectionRows.isEmpty {
                        Text(section.rawValue).font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(8).background(.regularMaterial)
                        ForEach(sectionRows) { row in
                            HStack(alignment: .top, spacing: 0) {
                                Text(row.label).frame(width: propertyColumnWidth, alignment: .leading).padding(8)
                                ForEach(row.cells) { cell in comparisonCell(cell) }
                            }.overlay(alignment: .bottom) { Divider() }
                        }
                    }
                }
            }.padding(12)
        }
    }

    private func materialHeader(_ material: EngineeringMaterial, subtitle: String) -> some View {
        VStack(alignment: .leading) { Text(material.name).fontWeight(.semibold); Text(subtitle).font(.caption2).foregroundStyle(.secondary) }
            .frame(width: materialColumnWidth, alignment: .leading).padding(8)
    }

    private func comparisonCell(_ cell: MaterialComparisonCell) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(display(cell.value)).font(.body.monospacedDigit())
            if cell.differsFromReference { if let delta = cell.absoluteDifference { Text(differenceText(delta: delta, percentage: cell.percentageDifference, value: cell.value)).font(.caption.monospacedDigit()).foregroundStyle(.secondary) } else { Text("Changed").font(.caption).foregroundStyle(.secondary) } }
        }
        .frame(width: materialColumnWidth, alignment: .leading)
        .frame(minHeight: 42, alignment: .topLeading)
        .padding(8)
        .background(cell.differsFromReference ? Color.accentColor.opacity(0.10) : Color.clear)
    }

    private func display(_ value: MaterialComparisonValue) -> String { switch value { case .missing: return "Not specified"; case .text(let text): return text.isEmpty ? "—" : text; case .number(let value, let unit): let s = EngineeringNumberFormatter.string(value); return unit.map { "\(s) \($0)" } ?? s; case .propertySeries(let series): if let equation = series.equation { return equation.effectiveKind.rawValue }; if !series.temperatureTable.isEmpty { return "\(series.temperatureTable.count) temperature points" }; return "Reference value only" } }
    private func differenceText(delta: Double, percentage: Double?, value: MaterialComparisonValue) -> String { let sign = delta > 0 ? "+" : ""; let unit: String; if case .number(_, let u) = value, let u { unit = " \(u)" } else { unit = "" }; let base = "Δ \(sign)\(EngineeringNumberFormatter.string(delta))\(unit)"; guard let percentage else { return base }; return "\(base) (\(percentage > 0 ? "+" : "")\(EngineeringNumberFormatter.string(percentage))%)" }
    private func toggle(_ id: UUID) { if selectedIDs.contains(id) { selectedIDs.remove(id); selectionOrder.removeAll { $0 == id } } else { selectedIDs.insert(id); selectionOrder.append(id) }; referenceID = selectionOrder.first }
    private func normaliseReference() { selectionOrder.removeAll { !selectedIDs.contains($0) }; for id in selectedIDs where !selectionOrder.contains(id) { selectionOrder.append(id) }; if referenceID == nil || !selectedIDs.contains(referenceID!) { referenceID = selectionOrder.first } }

    private func beginComparison() {
        #if os(macOS)
        if !standaloneWindow {
            openMacComparisonWindow()
            dismiss()
            return
        }
        #endif
        showingComparison = true
    }

    private func closeView() {
        #if os(macOS)
        if standaloneWindow { NSApp.keyWindow?.close(); return }
        #endif
        dismiss()
    }

    #if os(macOS)
    private func openMacComparisonWindow() {
        let root = MaterialComparisonView(initialSelectionOrder: selectionOrder, referenceID: referenceID, showingComparison: true, standaloneWindow: true)
            .environmentObject(store)
        let controller = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: controller)
        window.title = "Compare Materials"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 1200, height: 760))
        window.minSize = NSSize(width: 760, height: 560)
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
    #endif
}
