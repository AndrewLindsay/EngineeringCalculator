import SwiftUI

struct HomeView: View {
    @AppStorage("calculatorOrder") private var storedOrder = ""
    @Environment(\.interfaceDensity) private var density

    private var orderedCalculations: [CalculationDefinition] {
        let saved = storedOrder.split(separator: ",").map(String.init)
        let lookup = Dictionary(uniqueKeysWithValues: CalculationRegistry.all.map { ($0.id, $0) })
        let savedItems = saved.compactMap { lookup[$0] }
        let savedSet = Set(saved)
        return savedItems + CalculationRegistry.all.filter { !savedSet.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(orderedCalculations) { calculation in
                        NavigationLink(value: calculation.id) {
                            Label {
                                VStack(alignment: .leading, spacing: density.rowPadding) {
                                    Text(calculation.title).font(.system(size: density.bodySize, weight: .semibold))
                                    Text(calculation.subtitle).font(.system(size: density.smallSize)).foregroundStyle(.secondary)
                                }
                            } icon: { Image(systemName: calculation.systemImage).font(.system(size: density.bodySize + 3)) }
                            .padding(.vertical, density.rowPadding)
                        }
                    }
                    .onMove(perform: move)
                } header: { Text("Calculations") } footer: {
                    #if os(iOS)
                    Text("Tap Edit to rearrange calculators. Your preferred order is saved on this device.")
                    #elseif os(macOS)
                    Text("Drag calculators to rearrange them. Your preferred order is saved on this Mac.")
                    #endif
                }
            }
            .navigationTitle("Engineering Calculator")
            .toolbar {
                #if os(iOS)
                EditButton()
                #endif
                NavigationLink(value: "propertyInspector") { Image(systemName: "chart.xyaxis.line") }.help("Material property inspector")
                NavigationLink(value: "materials") { Image(systemName: "books.vertical") }.help("Material library")
                NavigationLink(value: "settings") { Image(systemName: "gearshape") }.help("Interface settings")
            }
            .navigationDestination(for: String.self) { id in
                switch id {
                case "pipeWeightBuoyancy": PipeWeightBuoyancyView()
                case "propertyInspector": MaterialPropertyInspectorView()
                case "materials": MaterialLibraryView()
                case "settings": SettingsView()
                default: PlaceholderCalculatorView()
                }
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) { var items = orderedCalculations; items.move(fromOffsets: source, toOffset: destination); storedOrder = items.map(\.id).joined(separator: ",") }
}

private struct SettingsView: View {
    @AppStorage("interfaceDensity") private var densityRaw = InterfaceDensity.compact.rawValue
    @Environment(\.interfaceDensity) private var density
    var body: some View {
        Form {
            Section("Interface") {
                Picker("Interface Density", selection: $densityRaw) { ForEach(InterfaceDensity.allCases) { option in Text(option.title).tag(option.rawValue) } }.pickerStyle(.segmented)
                Text("Compact shows more engineering data on screen. Standard uses a conventional layout. Comfortable increases text and spacing.").font(.system(size: density.smallSize)).foregroundStyle(.secondary)
            }
            Section("Preview") {
                LabeledContent("Pipe density") { Text("7,850 kg/m³").monospacedDigit() }.font(.system(size: density.bodySize))
                LabeledContent("Wall thickness") { Text("20.00 mm").monospacedDigit() }.font(.system(size: density.bodySize))
            }
        }.formStyle(.grouped).navigationTitle("Settings")
    }
}

private struct PlaceholderCalculatorView: View {
    var body: some View { ContentUnavailableView("Future Calculator", systemImage: "wrench.and.screwdriver", description: Text("Add future calculation modules here.")).navigationTitle("Future Calculator") }
}
