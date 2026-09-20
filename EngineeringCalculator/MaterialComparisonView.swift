import SwiftUI

struct MaterialComparisonView: View {
    @EnvironmentObject private var store: MaterialLibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIDs: Set<UUID> = []
    @State private var referenceID: UUID?
    @State private var differencesOnly = false

    private var allMaterials: [EngineeringMaterial] {
        store.allMaterials.sorted {
            if $0.category.caseInsensitiveCompare($1.category) == .orderedSame {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending
        }
    }

    private var selectedMaterials: [EngineeringMaterial] {
        allMaterials.filter { selectedIDs.contains($0.id) }
    }

    private var comparison: MaterialComparison? {
        guard selectedMaterials.count >= 2 else { return nil }
        return MaterialComparisonEngine.compare(selectedMaterials, referenceMaterialID: referenceID)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let comparison {
                    comparisonContent(comparison)
                } else {
                    selectionContent
                }
            }
            .navigationTitle("Compare Materials")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 620, minHeight: 520)
        .onAppear { normaliseReference() }
        .onChange(of: selectedIDs) { _, _ in normaliseReference() }
    }

    private var selectionContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select at least two materials to compare.")
                .font(.headline)
            Text("The reference material is the baseline used for absolute and percentage differences. You can compare built-in and project-specific materials together.")
                .font(.callout)
                .foregroundStyle(.secondary)

            materialSelectionList

            HStack {
                Text("\(selectedIDs.count) selected")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Compare") { normaliseReference() }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedIDs.count < 2)
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private func comparisonContent(_ comparison: MaterialComparison) -> some View {
        VStack(spacing: 0) {
            controls(comparison)
            Divider()
            comparisonTable(comparison)
        }
    }

    private func controls(_ comparison: MaterialComparison) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Picker("Reference", selection: Binding(
                    get: { referenceID ?? comparison.referenceMaterialID },
                    set: { referenceID = $0 }
                )) {
                    ForEach(selectedMaterials) { material in
                        Text(material.name).tag(material.id)
                    }
                }
                .frame(maxWidth: 360)

                Toggle("Differences Only", isOn: $differencesOnly)
                    .toggleStyle(.switch)

                Spacer()

                Button("Change Materials") {
                    // Dropping below two temporarily returns the view to selection mode.
                    if let referenceID { selectedIDs = [referenceID] }
                    else { selectedIDs.removeAll() }
                }
            }

            Text("Reference: \(comparison.referenceMaterial?.name ?? "—"). All differences are calculated against this material.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private var materialSelectionList: some View {
        List {
            ForEach(groupedCategories, id: \.self) { category in
                Section(category) {
                    ForEach(allMaterials.filter { $0.category == category }) { material in
                        Button {
                            toggle(material.id)
                        } label: {
                            HStack {
                                Image(systemName: selectedIDs.contains(material.id) ? "checkmark.circle.fill" : "circle")
                                    .imageScale(.large)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(material.name)
                                    HStack(spacing: 6) {
                                        Text(material.isBuiltIn ? "Built-in" : "My Material")
                                        if let grade = material.grade, !grade.isEmpty { Text("• \(grade)") }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if material.id == referenceID {
                                    Text("Reference")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(.quaternary, in: Capsule())
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var groupedCategories: [String] {
        Array(Set(allMaterials.map(\.category))).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func comparisonTable(_ comparison: MaterialComparison) -> some View {
        let rows = differencesOnly ? comparison.differingRows : comparison.rows
        return ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                tableHeader(comparison)
                ForEach(MaterialComparisonSection.allCases) { section in
                    let sectionRows = rows.filter { $0.section == section }
                    if !sectionRows.isEmpty {
                        Section {
                            ForEach(sectionRows) { row in comparisonRow(row, comparison: comparison) }
                        } header: {
                            Text(section.rawValue)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(.regularMaterial)
                        }
                    }
                }
            }
            .padding(12)
        }
        .overlay {
            if rows.isEmpty {
                ContentUnavailableView("No Differences", systemImage: "equal.circle", description: Text("The selected materials have no differences in the compared properties."))
            }
        }
    }

    private func tableHeader(_ comparison: MaterialComparison) -> some View {
        HStack(spacing: 0) {
            headerCell("Property", width: 220, alignment: .leading)
            ForEach(comparison.materials) { material in
                VStack(alignment: .leading, spacing: 2) {
                    Text(material.name).fontWeight(.semibold).lineLimit(2)
                    Text(material.id == comparison.referenceMaterialID ? "Reference" : material.isBuiltIn ? "Built-in" : "My Material")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .frame(width: 190, alignment: .leading)
                .padding(8)
            }
        }
        .background(.quaternary.opacity(0.35))
    }

    private func comparisonRow(_ row: MaterialComparisonRow, comparison: MaterialComparison) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(row.label)
                .frame(width: 220, alignment: .leading)
                .padding(8)

            ForEach(row.cells) { cell in
                VStack(alignment: .leading, spacing: 3) {
                    Text(display(cell.value))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(cell.differsFromReference ? .primary : .secondary)
                    if cell.differsFromReference {
                        if let delta = cell.absoluteDifference {
                            Text(differenceText(delta: delta, percentage: cell.percentageDifference, value: cell.value))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Changed")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    } else if cell.materialID != comparison.referenceMaterialID {
                        Text("No change")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 190, minHeight: 42, alignment: .topLeading)
                .padding(8)
                .background(cell.differsFromReference ? Color.accentColor.opacity(0.10) : Color.clear)
            }
        }
        .overlay(alignment: .bottom) { Divider() }
    }

    private func headerCell(_ text: String, width: CGFloat, alignment: Alignment) -> some View {
        Text(text).fontWeight(.semibold).frame(width: width, alignment: alignment).padding(8)
    }

    private func display(_ value: MaterialComparisonValue) -> String {
        switch value {
        case .missing:
            return "Not specified"
        case .text(let text):
            return text.isEmpty ? "—" : text
        case .number(let value, let unit):
            let formatted = EngineeringNumberFormatter.string(value)
            return unit.map { "\(formatted) \($0)" } ?? formatted
        case .propertySeries(let series):
            if let equation = series.equation {
                switch equation.effectiveKind {
                case .polynomial: return "Polynomial equation"
                case .linearReference: return "Linear reference equation"
                case .relativeLinear: return "Relative linear / TCR equation"
                }
            }
            if !series.temperatureTable.isEmpty { return "\(series.temperatureTable.count) temperature points" }
            return "Reference value only"
        }
    }

    private func differenceText(delta: Double, percentage: Double?, value: MaterialComparisonValue) -> String {
        let sign = delta > 0 ? "+" : ""
        let deltaText = "\(sign)\(EngineeringNumberFormatter.string(delta))"
        let unit: String
        if case .number(_, let valueUnit) = value, let valueUnit { unit = " \(valueUnit)" } else { unit = "" }
        guard let percentage else { return "Δ \(deltaText)\(unit)" }
        let percentSign = percentage > 0 ? "+" : ""
        return "Δ \(deltaText)\(unit) (\(percentSign)\(EngineeringNumberFormatter.string(percentage))%)"
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
            if referenceID == id { referenceID = selectedIDs.first }
        } else {
            selectedIDs.insert(id)
            if referenceID == nil { referenceID = id }
        }
    }

    private func normaliseReference() {
        if let referenceID, selectedIDs.contains(referenceID) { return }
        referenceID = selectedMaterials.first?.id
    }
}
