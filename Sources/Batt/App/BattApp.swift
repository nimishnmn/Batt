import SwiftUI
import AppKit

@main
struct BattApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var settings = SettingsState.shared
    
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        // Main Dashboard Window
        WindowGroup("Batt - Battery Intelligence", id: "main") {
            DashboardView(appState: appState, settings: settings)
                .preferredColorScheme(settings.theme.colorScheme)
                .background(WindowAccessor())
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 960, height: 680)
        
        // Native Menu Bar Extra
        MenuBarExtra {
            MenuBarView(
                appState: appState,
                settings: settings,
                onOpenDashboard: {
                    WindowCloseHandler.shared.showMainWindow()
                },
                onOpenSettings: {
                    WindowCloseHandler.shared.showMainWindow()
                }
            )
            .preferredColorScheme(settings.theme.colorScheme)
        } label: {
            MenuBarIconView(appState: appState, settings: settings)
        }
        .menuBarExtraStyle(.window)
        
        // Dedicated Settings Window
        Settings {
            SettingsView(settings: settings, appState: appState)
                .preferredColorScheme(settings.theme.colorScheme)
        }
    }
}
