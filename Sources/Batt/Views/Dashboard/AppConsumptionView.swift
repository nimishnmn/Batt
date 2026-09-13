import SwiftUI
import AppKit

public struct AppConsumptionView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var settings: SettingsState
    @State private var searchText = ""
    
    public init(appState: AppState, settings: SettingsState) {
        self.appState = appState
        self.settings = settings
    }
    
    private var filteredApps: [AppEnergyRecord] {
        if searchText.isEmpty {
            return appState.appRecords
        } else {
            return appState.appRecords.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    private var totalBatteryConsumed: Double {
        appState.appRecords.reduce(0.0) { $0 + $1.batteryPercentConsumed }
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Per-App Battery Consumption")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Attributes measured battery percentage drop and energy draw to active applications.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Filter apps…", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.8))
                .cornerRadius(8)
                .frame(width: 200)
            }
            
            // Total session impact banner
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total App Drained Battery")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "-%.2f%%", totalBatteryConsumed))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                
                Divider()
                    .frame(height: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tracked Processes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(appState.appRecords.count) active")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                Button(action: {
                    ProcessEnergyTracker.shared.resetSession()
                    appState.appRecords = []
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset Tracking Session")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            
            // App rows list
            if filteredApps.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "app.dashed")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No active app consumption recorded yet.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("As applications use CPU and battery power, their exact percentage drain will appear here.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 250)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredApps) { app in
                            AppRowView(
                                app: app,
                                maxDrop: appState.appRecords.first?.batteryPercentConsumed ?? 1.0,
                                settings: settings
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct AppRowView: View {
    let app: AppEnergyRecord
    let maxDrop: Double
    @ObservedObject var settings: SettingsState
    
    private var appIcon: NSImage {
        if let bundleId = app.bundleIdentifier,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .application)
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.body)
                        .fontWeight(.semibold)
                    
                    Text("PID: \(app.pid)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Progress bar of relative impact
                let fraction = maxDrop > 0 ? (app.batteryPercentConsumed / maxDrop) : 0.0
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(geo.size.width * CGFloat(fraction), 4), height: 4)
                    }
                }
                .frame(height: 4)
            }
            
            Spacer()
            
            // Battery drop in exact percentage terms
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                    Text(String(format: "-%.2f%%", app.batteryPercentConsumed))
                        .font(.callout)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                
                Text(settings.energyUnit.format(mWh: app.energyConsumedMWh))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 100, alignment: .trailing)
            
            // Instantaneous power attribution
            VStack(alignment: .trailing, spacing: 2) {
                Text(settings.powerUnit.format(watts: app.instantPowerWatts))
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(String(format: "%.1f%% CPU", app.cpuShare * 100.0))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80, alignment: .trailing)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
        )
    }
}
