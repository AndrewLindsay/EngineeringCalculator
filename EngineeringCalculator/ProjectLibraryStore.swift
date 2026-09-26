import Foundation

struct ProjectLibraryEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var projectID: UUID?
    var title: String
    var fileURL: URL
    var calculationCount: Int
    var modifiedAt: Date
    var bookmarkData: Data?

    init(
        id: UUID = UUID(),
        projectID: UUID? = nil,
        title: String,
        fileURL: URL,
        calculationCount: Int,
        modifiedAt: Date,
        bookmarkData: Data? = nil
    ) {
        self.id = id
        self.projectID = projectID
        self.title = title
        self.fileURL = fileURL
        self.calculationCount = calculationCount
        self.modifiedAt = modifiedAt
        self.bookmarkData = bookmarkData
    }
}

enum ProjectLibraryAccessError: LocalizedError, Equatable {
    case bookmarkResolutionFailed(String)
    case replacementIsNotProject
    case projectIdentityMismatch(expected: UUID, found: UUID)

    var errorDescription: String? {
        switch self {
        case .bookmarkResolutionFailed(let title):
            return "The saved location for ‘\(title)’ could not be accessed. Locate the project file to restore access, or remove the project from the list."
        case .replacementIsNotProject:
            return "The selected file is not an Engineering Calculator project. Choose the original .ecproject file for this project."
        case let .projectIdentityMismatch(expected, found):
            return "The selected project has a different project identity. Expected \(expected.uuidString), but found \(found.uuidString). The Project Library entry was not changed."
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

    /// Returns the library entry representing the same logical project, regardless of filename.
    func entry(forProjectID projectID: UUID) -> ProjectLibraryEntry? {
        entries.first { $0.projectID == projectID }
    }

    /// Registers a saved project. Project UUID is authoritative; URL is only its current location.
    /// Older entries without projectID are upgraded when the same URL is encountered.
    func register(document: CalculationDocument, at url: URL) {
        let standardizedURL = url.standardizedFileURL
        let bookmarkData = makeBookmark(for: standardizedURL)

        let matchingIndex = entries.firstIndex(where: { $0.projectID == document.id })
            ?? entries.firstIndex(where: {
                $0.projectID == nil && $0.fileURL.standardizedFileURL == standardizedURL
            })

        if let index = matchingIndex {
            let existingID = entries[index].id
            entries[index] = ProjectLibraryEntry(
                id: existingID,
                projectID: document.id,
                title: document.title,
                fileURL: standardizedURL,
                calculationCount: document.calculations.count,
                modifiedAt: document.modifiedAt,
                bookmarkData: bookmarkData ?? entries[index].bookmarkData
            )
        } else {
            entries.append(ProjectLibraryEntry(
                projectID: document.id,
                title: document.title,
                fileURL: standardizedURL,
                calculationCount: document.calculations.count,
                modifiedAt: document.modifiedAt,
                bookmarkData: bookmarkData
            ))
        }
        sortAndPersist()
    }

    func refresh(_ entry: ProjectLibraryEntry, with document: CalculationDocument) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].projectID = document.id
        entries[index].title = document.title
        entries[index].calculationCount = document.calculations.count
        entries[index].modifiedAt = document.modifiedAt
        sortAndPersist()
    }

    /// Repairs the saved location for an existing library entry. The project UUID is
    /// authoritative: a different project can never silently replace the missing one.
    /// Legacy entries without a project UUID are upgraded after the selected file is validated.
    func relink(_ entry: ProjectLibraryEntry, to url: URL, document: CalculationDocument) throws {
        guard document.kind == .project else {
            throw ProjectLibraryAccessError.replacementIsNotProject
        }
        if let expectedID = entry.projectID, expectedID != document.id {
            throw ProjectLibraryAccessError.projectIdentityMismatch(expected: expectedID, found: document.id)
        }
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }

        let standardizedURL = url.standardizedFileURL
        entries[index].projectID = document.id
        entries[index].title = document.title
        entries[index].fileURL = standardizedURL
        entries[index].calculationCount = document.calculations.count
        entries[index].modifiedAt = document.modifiedAt
        entries[index].bookmarkData = makeBookmark(for: standardizedURL)
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
#if os(macOS)
            let resolutionOptions: URL.BookmarkResolutionOptions = [.withSecurityScope]
#else
            let resolutionOptions: URL.BookmarkResolutionOptions = []
#endif
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: resolutionOptions,
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
#if os(macOS)
        return try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
#else
        return try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
#endif
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
