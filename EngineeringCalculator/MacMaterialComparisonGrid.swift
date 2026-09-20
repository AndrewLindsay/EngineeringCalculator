#if os(macOS)
import SwiftUI

struct MacMaterialComparisonGrid: View {
    let comparison: MaterialComparison
    let rows: [MaterialComparisonRow]

    @State private var propertyWidth: CGFloat = 220
    @State private var materialWidths: [UUID: CGFloat] = [:]
    @State private var horizontalOffset: CGFloat = 0
    @State private var userResizedColumns: Set<String> = []

    private let minimumPropertyWidth: CGFloat = 160
    private let minimumMaterialWidth: CGFloat = 150
    private let horizontalPadding: CGFloat = 12
    private let handleWidth: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let widths = resolvedWidths(availableWidth: geometry.size.width)
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header(widths: widths)
                    ForEach(MaterialComparisonSection.allCases) { section in
                        let sectionRows = rows.filter { $0.section == section }
                        if !sectionRows.isEmpty {
                            sectionHeader(section.rawValue, widths: widths)
                            ForEach(sectionRows) { row in
                                comparisonRow(row, widths: widths)
                            }
                        }
                    }
                }
                .padding(horizontalPadding)
                .frame(minWidth: max(0, geometry.size.width - 2 * horizontalPadding), alignment: .leading)
                .background(MacComparisonScrollOffsetReader(offsetX: $horizontalOffset))
            }
        }
    }

    private func resolvedWidths(availableWidth: CGFloat) -> ColumnWidths {
        let usable = max(0, availableWidth - 2 * horizontalPadding - 18)
        let count = max(1, comparison.materials.count)
        let minimumTotal = minimumPropertyWidth + CGFloat(count) * minimumMaterialWidth
        let extra = max(0, usable - minimumTotal)

        var property = userResizedColumns.contains("property") ? propertyWidth : minimumPropertyWidth + extra * 0.20
        property = max(minimumPropertyWidth, property)

        var materials: [UUID: CGFloat] = [:]
        let automaticIDs = comparison.materials.filter { !userResizedColumns.contains($0.id.uuidString) }
        let fixedMaterialTotal = comparison.materials.reduce(CGFloat.zero) { partial, material in
            guard userResizedColumns.contains(material.id.uuidString) else { return partial }
            return partial + max(minimumMaterialWidth, materialWidths[material.id] ?? minimumMaterialWidth)
        }
        let remaining = max(0, usable - property - fixedMaterialTotal)
        let automaticWidth = automaticIDs.isEmpty ? minimumMaterialWidth : max(minimumMaterialWidth, remaining / CGFloat(automaticIDs.count))

        for material in comparison.materials {
            if userResizedColumns.contains(material.id.uuidString) {
                materials[material.id] = max(minimumMaterialWidth, materialWidths[material.id] ?? minimumMaterialWidth)
            } else {
                materials[material.id] = automaticWidth
            }
        }
        return ColumnWidths(property: property, materials: materials)
    }

    private func header(widths: ColumnWidths) -> some View {
        HStack(spacing: 0) {
            frozenPropertyHeader(width: widths.property)
            if let reference = comparison.materials.first {
                frozenMaterialHeader(reference, subtitle: "Reference", width: widths.material(reference.id), propertyWidth: widths.property)
            }
            ForEach(Array(comparison.materials.dropFirst())) { material in
                materialHeader(material, subtitle: "Compared", width: widths.material(material.id))
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func sectionHeader(_ title: String, widths: ColumnWidths) -> some View {
        let total = widths.property + comparison.materials.reduce(CGFloat.zero) { $0 + widths.material($1.id) }
        return ZStack(alignment: .leading) {
            Color(nsColor: .controlBackgroundColor)
            Text(title).font(.headline).padding(8)
        }
        .frame(width: total, alignment: .leading)
    }

    private func comparisonRow(_ row: MaterialComparisonRow, widths: ColumnWidths) -> some View {
        HStack(alignment: .top, spacing: 0) {
            frozenPropertyCell(row.label, width: widths.property)
            if let referenceCell = row.cells.first {
                frozenComparisonCell(referenceCell, width: widths.material(referenceCell.materialID), propertyWidth: widths.property)
            }
            ForEach(Array(row.cells.dropFirst())) { cell in
                comparisonCell(cell, width: widths.material(cell.materialID))
            }
        }
        .overlay(alignment: .bottom) { Divider() }
    }

    private func frozenPropertyHeader(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Color(nsColor: .windowBackgroundColor)
            Text("Property").fontWeight(.semibold).padding(8)
        }
        .frame(width: width)
        .overlay(alignment: .trailing) { resizeHandle(key: "property", currentWidth: width, minimum: minimumPropertyWidth) }
        .offset(x: horizontalOffset)
        .zIndex(20)
    }

    private func frozenPropertyCell(_ text: String, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: .windowBackgroundColor)
            Text(text).padding(8)
        }
        .frame(width: width, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .trailing) { resizeHandle(key: "property", currentWidth: width, minimum: minimumPropertyWidth) }
        .offset(x: horizontalOffset)
        .zIndex(20)
    }

    private func frozenMaterialHeader(_ material: EngineeringMaterial, subtitle: String, width: CGFloat, propertyWidth: CGFloat) -> some View {
        materialHeader(material, subtitle: subtitle, width: width)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color.secondary.opacity(0.35)).frame(width: 1)
                resizeHandle(key: material.id.uuidString, materialID: material.id, currentWidth: width, minimum: minimumMaterialWidth)
            }
            .offset(x: horizontalOffset)
            .zIndex(19)
    }

    private func frozenComparisonCell(_ cell: MaterialComparisonCell, width: CGFloat, propertyWidth: CGFloat) -> some View {
        comparisonCell(cell, width: width)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color.secondary.opacity(0.35)).frame(width: 1)
                resizeHandle(key: cell.materialID.uuidString, materialID: cell.materialID, currentWidth: width, minimum: minimumMaterialWidth)
            }
            .offset(x: horizontalOffset)
            .zIndex(19)
    }

    private func materialHeader(_ material: EngineeringMaterial, subtitle: String, width: CGFloat) -> some View {
        VStack(alignment: .leading) {
            Text(material.name).fontWeight(.semibold)
            Text(subtitle).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(width: width, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .overlay(alignment: .trailing) {
            resizeHandle(key: material.id.uuidString, materialID: material.id, currentWidth: width, minimum: minimumMaterialWidth)
        }
    }

    private func comparisonCell(_ cell: MaterialComparisonCell, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(display(cell.value)).font(.body.monospacedDigit())
            if cell.differsFromReference {
                if let delta = cell.absoluteDifference {
                    Text(differenceText(delta: delta, percentage: cell.percentageDifference, value: cell.value))
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                } else {
                    Text("Changed").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: width, alignment: .leading)
        .frame(minHeight: 42, alignment: .topLeading)
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .background(cell.differsFromReference ? Color.accentColor.opacity(0.10) : Color.clear)
        .overlay(alignment: .trailing) {
            resizeHandle(key: cell.materialID.uuidString, materialID: cell.materialID, currentWidth: width, minimum: minimumMaterialWidth)
        }
    }

    @ViewBuilder
    private func resizeHandle(key: String, materialID: UUID? = nil, currentWidth: CGFloat, minimum: CGFloat) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: handleWidth)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        userResizedColumns.insert(key)
                        let newWidth = max(minimum, currentWidth + value.translation.width)
                        if let materialID { materialWidths[materialID] = newWidth } else { propertyWidth = newWidth }
                    }
            )
    }

    private func display(_ value: MaterialComparisonValue) -> String {
        switch value {
        case .missing: return "Not specified"
        case .text(let text): return text.isEmpty ? "—" : text
        case .number(let value, let unit):
            let s = EngineeringNumberFormatter.string(value)
            return unit.map { "\(s) \($0)" } ?? s
        case .propertySeries(let series):
            if let equation = series.equation { return equation.effectiveKind.rawValue }
            if !series.temperatureTable.isEmpty { return "\(series.temperatureTable.count) temperature points" }
            return "Reference value only"
        }
    }

    private func differenceText(delta: Double, percentage: Double?, value: MaterialComparisonValue) -> String {
        let sign = delta > 0 ? "+" : ""
        let unit: String
        if case .number(_, let u) = value, let u { unit = " \(u)" } else { unit = "" }
        let base = "Δ \(sign)\(EngineeringNumberFormatter.string(delta))\(unit)"
        guard let percentage else { return base }
        return "\(base) (\(percentage > 0 ? "+" : "")\(EngineeringNumberFormatter.string(percentage))%)"
    }

    private struct ColumnWidths {
        let property: CGFloat
        let materials: [UUID: CGFloat]
        func material(_ id: UUID) -> CGFloat { materials[id] ?? 150 }
    }
}

private struct MacComparisonScrollOffsetReader: NSViewRepresentable {
    @Binding var offsetX: CGFloat
    func makeCoordinator() -> Coordinator { Coordinator(offsetX: $offsetX) }
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { context.coordinator.attach(from: view) }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.offsetX = $offsetX
        DispatchQueue.main.async { context.coordinator.attach(from: nsView) }
    }
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) { coordinator.detach() }

    final class Coordinator {
        var offsetX: Binding<CGFloat>
        weak var clipView: NSClipView?
        var observer: NSObjectProtocol?
        init(offsetX: Binding<CGFloat>) { self.offsetX = offsetX }
        func attach(from view: NSView) {
            var current: NSView? = view
            while let candidate = current, !(candidate is NSClipView) { current = candidate.superview }
            guard let clip = current as? NSClipView, clip !== clipView else { return }
            detach()
            clipView = clip
            clip.postsBoundsChangedNotifications = true
            observer = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: clip, queue: .main) { [weak self] _ in self?.publish() }
            publish()
        }
        func publish() { guard let clipView else { return }; offsetX.wrappedValue = max(0, clipView.bounds.origin.x) }
        func detach() { if let observer { NotificationCenter.default.removeObserver(observer) }; observer = nil; clipView = nil }
        deinit { detach() }
    }
}
#endif