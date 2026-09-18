import SwiftUI

enum InterfaceDensity: String, CaseIterable, Identifiable {
    case compact
    case standard
    case comfortable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact: return "Compact"
        case .standard: return "Standard"
        case .comfortable: return "Comfortable"
        }
    }

    var bodySize: CGFloat {
        switch self {
        case .compact: return 13
        case .standard: return 16
        case .comfortable: return 19
        }
    }

    var smallSize: CGFloat {
        switch self {
        case .compact: return 10
        case .standard: return 12
        case .comfortable: return 14
        }
    }

    var rowPadding: CGFloat {
        switch self {
        case .compact: return 1
        case .standard: return 4
        case .comfortable: return 8
        }
    }

    var controlHeight: CGFloat {
        switch self {
        case .compact: return 24
        case .standard: return 30
        case .comfortable: return 38
        }
    }
}

private struct InterfaceDensityKey: EnvironmentKey {
    static let defaultValue: InterfaceDensity = .compact
}

extension EnvironmentValues {
    var interfaceDensity: InterfaceDensity {
        get { self[InterfaceDensityKey.self] }
        set { self[InterfaceDensityKey.self] = newValue }
    }
}

@main
struct EngineeringCalculatorApp: App {
    @StateObject private var materialLibrary = MaterialLibraryStore()
    @AppStorage("interfaceDensity") private var densityRaw = InterfaceDensity.compact.rawValue

    private var density: InterfaceDensity {
        InterfaceDensity(rawValue: densityRaw) ?? .compact
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.interfaceDensity, density)
                .environmentObject(materialLibrary)
        }
    }
}
