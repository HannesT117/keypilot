import Foundation

enum SwitchBehavior: String, Codable, CaseIterable {
    case hideWhenFocused = "Hide"
    case cycleApps = "Cycle"
}

struct AppEntry: Codable, Identifiable {
    let id: UUID
    var bundleIdentifier: String
    var displayName: String
    var assignedKey: String  // single lowercase letter, e.g. "s"
    var behavior: SwitchBehavior

    var keyCharacter: Character? {
        assignedKey.lowercased().first
    }
}

class AppMappingStore: ObservableObject {
    @Published var entries: [AppEntry] = []

    private let defaultsKey = "com.keypilot.appEntries"

    init() {
        load()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode([AppEntry].self, from: data)
        else { return }
        entries = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    func entry(forKey key: Character) -> AppEntry? {
        entries.first { $0.keyCharacter == key }
    }

    func assignKey(_ key: Character, toBundleId bundleId: String, displayName: String) {
        // Remove any existing entry with this key
        entries.removeAll { $0.keyCharacter == key }

        if let idx = entries.firstIndex(where: { $0.bundleIdentifier == bundleId }) {
            entries[idx].assignedKey = String(key)
        } else {
            entries.append(
                AppEntry(
                    id: UUID(),
                    bundleIdentifier: bundleId,
                    displayName: displayName,
                    assignedKey: String(key),
                    behavior: .hideWhenFocused
                ))
        }
        save()
    }

    func removeEntry(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }

    func updateEntry(_ entry: AppEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
            save()
        }
    }
}
