import SwiftUI

struct HomeView: View {
    @AppStorage("calculatorOrder") private var storedOrder = ""

    private var orderedCalculations: [CalculationDefinition] {
        let saved = storedOrder.split(separator: ",").map(String.init)

        let lookup = Dictionary(
            uniqueKeysWithValues: CalculationRegistry.all.map { ($0.id, $0) }
        )

        let savedItems = saved.compactMap { lookup[$0] }
        let savedSet = Set(saved)

        return savedItems
            + CalculationRegistry.all.filter { !savedSet.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(orderedCalculations) { calculation in
                        NavigationLink(value: calculation.id) {
                            Label {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(calculation.title)
                                        .font(.headline)

                                    Text(calculation.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: calculation.systemImage)
                                    .font(.title2)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .onMove(perform: move)

                } header: {
                    Text("Calculations")

                } footer: {
                    #if os(iOS)
                    Text(
                        "Tap Edit to rearrange calculators. "
                        + "Your preferred order is saved on this device."
                    )
                    #elseif os(macOS)
                    Text(
                        "Drag calculators to rearrange them. "
                        + "Your preferred order is saved on this Mac."
                    )
                    #endif
                }
            }
            .navigationTitle("Engineering Calculator")

            #if os(iOS)
            .toolbar {
                EditButton()
            }
            #endif

            .navigationDestination(for: String.self) { id in
                switch id {
                case "pipeWeightBuoyancy":
                    PipeWeightBuoyancyView()

                default:
                    PlaceholderCalculatorView()
                }
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var items = orderedCalculations
        items.move(fromOffsets: source, toOffset: destination)

        storedOrder = items
            .map(\.id)
            .joined(separator: ",")
    }
}


private struct PlaceholderCalculatorView: View {
    var body: some View {
        ContentUnavailableView(
            "Future Calculator",
            systemImage: "wrench.and.screwdriver",
            description: Text(
                "Add future calculation modules here."
            )
        )
        .navigationTitle("Future Calculator")
    }
}
