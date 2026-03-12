import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AppMappingStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Permission status
            HStack {
                Circle()
                    .fill(PermissionHelper.isAccessibilityGranted() ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(
                    PermissionHelper.isAccessibilityGranted()
                        ? "Accessibility: Granted" : "Accessibility: Not Granted"
                )
                .font(.caption)
                if !PermissionHelper.isAccessibilityGranted() {
                    Button("Grant") {
                        PermissionHelper.requestAccessibility()
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Text("Hold Right \u{2318} + letter to switch apps. Hold Right \u{2318} + \u{2325} + letter to assign.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            // App list
            List {
                ForEach(store.entries) { entry in
                    AppEntryRow(entryID: entry.id, store: store)
                }
                .onDelete { offsets in
                    store.removeEntry(at: offsets)
                }
            }
            .frame(minHeight: 200)

            HStack {
                Button("Add App...") {
                    addApp()
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .frame(width: 420, height: 380)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let bundle = Bundle(url: url),
            let bundleId = bundle.bundleIdentifier,
            let name =
                (bundle.infoDictionary?["CFBundleName"] as? String)
                ?? (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                ?? url.deletingPathExtension().lastPathComponent as String?
        else { return }

        guard let firstLetter = name.lowercased().first else { return }
        store.assignKey(firstLetter, toBundleId: bundleId, displayName: name)
    }
}

struct AppEntryRow: View {
    let entryID: UUID
    @ObservedObject var store: AppMappingStore

    private var entry: AppEntry? {
        store.entries.first { $0.id == entryID }
    }

    private var keyBinding: Binding<String> {
        Binding(
            get: { entry?.assignedKey ?? "" },
            set: { newValue in
                guard var updated = entry else { return }
                updated.assignedKey = String(newValue.lowercased().prefix(1))
                store.updateEntry(updated)
            }
        )
    }

    private var behaviorBinding: Binding<SwitchBehavior> {
        Binding(
            get: { entry?.behavior ?? .hideWhenFocused },
            set: { newValue in
                guard var updated = entry else { return }
                updated.behavior = newValue
                store.updateEntry(updated)
            }
        )
    }

    var body: some View {
        if let entry = entry {
            HStack {
                if let url = NSWorkspace.shared.urlForApplication(
                    withBundleIdentifier: entry.bundleIdentifier)
                {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .frame(width: 24, height: 24)
                }

                Text(entry.displayName)
                    .frame(minWidth: 120, alignment: .leading)

                Text("Key:")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                TextField("", text: keyBinding)
                    .frame(width: 30)
                    .textFieldStyle(.roundedBorder)

                Picker("", selection: behaviorBinding) {
                    ForEach(SwitchBehavior.allCases, id: \.self) { b in
                        Text(b.rawValue).tag(b)
                    }
                }
                .frame(width: 80)
            }
        }
    }
}
