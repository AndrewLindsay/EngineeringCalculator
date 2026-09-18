import SwiftUI

struct CalculationDefinition: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
}

enum CalculationRegistry {
    static let all: [CalculationDefinition] = [
        .init(
            id: "pipeWeightBuoyancy",
            title: "Pipe Weight & Buoyancy",
            subtitle: "Dry pipe weight, contents, displacement and submerged weight",
            systemImage: "cylinder.split.1x2"
        ),
        .init(
            id: "placeholder",
            title: "Future Calculator",
            subtitle: "A reserved module showing how the library can grow",
            systemImage: "plus.square.dashed"
        )
    ]
}
