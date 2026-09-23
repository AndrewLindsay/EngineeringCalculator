import Foundation

struct ProjectLibraryEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var fileURL: URL
    var calculationCount: Int
    var modifiedAt: Date

    init(id: UUID = UUID(), title: String, fileURL: URL, calculationCount: Int, modifiedAt: Date) {
        self.id = id
        self.title = title
        self.fileURL = fileURL
        self.calculationCount = calculationCount
        self.modifiedAt = modifiedAt
    }
}

@MainActor
final class ProjectLibraryStore: ObservableObject {
    @Published private(set) var entries: [ProjectLibraryEntry] = []

    private let defaults: UserDefaults
    private let storageKey = "engineeringCalculator.projectLibrary.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func register(document: CalculationDocument, at url: URL) {
        let standardizedURL = url.standardizedFileURL
        let entry = ProjectLibraryEntry(
            title: document.title,
            fileURL: standardizedURL,
            calculationCount: document.calculations.count,
            modifiedAt: document.modifiedAt
        )
        if let index = entries.firstIndex(where: { $0.fileURL.standardizedFileURL == standardizedURL }) {
            let existingID = entries[index].id
            entries[index] = ProjectLibraryEntry(
                id: existingID,
                title: entry.title,
                fileURL: entry.fileURL,
                calculationCount: entry.calculationCount,
                modifiedAt: entry.modifiedAt
            )
        } else {
            entries.append(entry)
        }
        sortAndPersist()
    }

    func refresh(_ entry: ProjectLibraryEntry, with document: CalculationDocument) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].title = document.title
        entries[index].calculationCount = document.calculations.count
        entries[index].modifiedAt = document.modifiedAt
        sortAndPersist()
    }

    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ProjectLibraryEntry].self, from: data) else { return }
        entries = decoded.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    private func sortAndPersist() {
        entries.sort { $0.modifiedAt > $1.modifiedAt }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
