import Cocoa

class AppSwitcher {
    let store: AppMappingStore

    // Track cycle position per letter for cycling through apps with same first letter
    private var cycleIndex: [Character: Int] = [:]

    init(store: AppMappingStore) {
        self.store = store
    }

    func handleKey(_ key: Character, modifiers: KeyModifiers) {
        if modifiers.contains(.option) {
            assignKeyToFrontmostApp(key)
            return
        }
        switchToApp(forKey: key)
    }

    // MARK: - Assign Mode (Right Cmd + Option + letter)

    private func assignKeyToFrontmostApp(_ key: Character) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
            let bundleId = frontApp.bundleIdentifier,
            let name = frontApp.localizedName
        else { return }

        store.assignKey(key, toBundleId: bundleId, displayName: name)
        print("KeyPilot: Assigned '\(key)' to \(name)")
    }

    // MARK: - Switch Mode (Right Cmd + letter)

    private func switchToApp(forKey key: Character) {
        // 1. Check static/custom mappings first
        if let entry = store.entry(forKey: key) {
            handleStaticEntry(entry)
            return
        }

        // 2. Fall back to first-letter matching among running apps
        let matches = runningGUIApps().filter {
            ($0.localizedName ?? "").lowercased().hasPrefix(String(key))
        }

        guard !matches.isEmpty else { return }

        let frontApp = NSWorkspace.shared.frontmostApplication

        if let front = frontApp, matches.contains(where: { $0.processIdentifier == front.processIdentifier }) {
            // Already focused on a matching app - cycle to next
            cycleAmongApps(matches, forKey: key)
        } else {
            // Focus the first match
            cycleIndex[key] = 0
            activate(matches[0])
        }
    }

    private func handleStaticEntry(_ entry: AppEntry) {
        let running = NSRunningApplication.runningApplications(
            withBundleIdentifier: entry.bundleIdentifier)

        if running.isEmpty {
            // Launch the app
            if let appURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: entry.bundleIdentifier)
            {
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(at: appURL, configuration: config)
            }
            print("KeyPilot: Launching \(entry.displayName)")
            return
        }

        guard let app = running.first else { return }

        if app.isActive {
            switch entry.behavior {
            case .hideWhenFocused:
                app.hide()
            case .cycleApps:
                // Cycle among all running apps with same key
                guard let entryKey = entry.keyCharacter else {
                    app.hide()
                    break
                }
                let allMatches = runningGUIApps().filter {
                    ($0.localizedName ?? "").lowercased().hasPrefix(String(entryKey))
                }
                if allMatches.count > 1 {
                    cycleAmongApps(allMatches, forKey: entryKey)
                } else {
                    app.hide()
                }
            }
        } else {
            activate(app)
        }
    }

    private func cycleAmongApps(_ apps: [NSRunningApplication], forKey key: Character) {
        guard apps.count > 0 else { return }

        let currentIdx = cycleIndex[key] ?? -1
        let nextIdx = (currentIdx + 1) % apps.count
        cycleIndex[key] = nextIdx
        activate(apps[nextIdx])
    }

    private func activate(_ app: NSRunningApplication) {
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }

    private func runningGUIApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
        }
    }
}
