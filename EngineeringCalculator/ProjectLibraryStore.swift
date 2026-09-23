import Foundation

struct ProjectLibraryEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var fileURL: URL
    var calculationCount: Int
    var modifiedAt: Date
    var bookmarkData: Data?

    init(
        id: UUID = UUID(),
        title: String,
        fileURL: URL,
        calculationCount: Int,
        modifiedAt: Date,
        bookmarkData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.fileURL = fileURL
        self.calculationCount = calculationCount
        self.modifiedAt = modifiedAt
        self.bookmarkData = bookmarkData
    }
}

enum ProjectLibraryAccessError: LocalizedError {
    case bookmarkResolutionFailed(String)

    var errorDescription: String? {
        switch self {
        case .bookmarkResolutionFailed(let title):
            return "The saved location for ‘\(title)’ could not be accessed. Remove the project from the list and open it again to restore access."
        }
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
        let bookmarkData = makeBookmark(for: standardizedURL)
        let entry = ProjectLibraryEntry(
            title: document.title,
            fileURL: standardizedURL,
            calculationCount: document.calculations.count,
            modifiedAt: document.modifiedAt,
            bookmarkData: bookmarkData
        )
        if let index = entries.firstIndex(where: { $0.fileURL.standardizedFileURL == standardizedURL }) {
            let existingID = entries[index].id
            entries[index] = ProjectLibraryEntry(
                id: existingID,
                title: entry.title,
                fileURL: entry.fileURL,
                calculationCount: entry.calculationCount,
                modifiedAt: entry.modifiedAt,
                bookmarkData: bookmarkData ?? entries[index].bookmarkData
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

    /// Resolves the persistent location for a project. Existing library entries from
    /// versions before bookmark support remain compatible and fall back to fileURL.
    /// If a bookmark is stale, it is refreshed immediately after successful resolution.
    func resolvedURL(for entry: ProjectLibraryEntry) throws -> URL {
        guard let bookmarkData = entry.bookmarkData else {
            return entry.fileURL.standardizedFileURL
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ).standardizedFileURL

            if isStale,
               let index = entries.firstIndex(where: { $0.id == entry.id }),
               let refreshedBookmark = makeBookmark(for: url) {
                entries[index].fileURL = url
                entries[index].bookmarkData = refreshedBookmark
                persist()
            } else if let index = entries.firstIndex(where: { $0.id == entry.id }),
                      entries[index].fileURL.standardizedFileURL != url {
                entries[index].fileURL = url
                persist()
            }

            return url
        } catch {
            throw ProjectLibraryAccessError.bookmarkResolutionFailed(entry.title)
        }
    }

    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    private func makeBookmark(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
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
