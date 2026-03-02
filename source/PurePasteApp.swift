import AppKit
import SwiftUI

@main
struct PurePasteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            Button(appState.isActive ? "Pause" : "Activate") {
                appState.toggleActive()
            }

            Divider()

            Text("Removed params: \(appState.totalParamsRemoved)")
                .font(.caption)

            if let rulesStatusMessage = appState.rulesStatusMessage {
                Text(rulesStatusMessage)
                    .font(.caption2)
                    .lineLimit(2)
            }

            Menu("Options") {
                Button(appState.isRefetchingRules ? "Refetching rules..." : "Refetch rules") {
                    appState.refetchRules()
                }
                .disabled(appState.isRefetchingRules)

                Button("Reset counter") {
                    appState.resetCounter()
                }
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Image(systemName: iconName)
        }
        .menuBarExtraStyle(.menu)
    }

    private var iconName: String {
        if !appState.isActive {
            return "pause.circle"
        }
        return "lock.shield"
    }
}
