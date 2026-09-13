import SwiftUI

public struct AlertsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var settings: SettingsState
    
    public init(appState: AppState, settings: SettingsState) {
        self.appState = appState
        self.settings = settings
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Instantaneous Drop Spike Alerts")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Triggered instantaneously when current draw exceeds your power threshold (\(String(format: "%.1f W", settings.alertThresholdWatts))).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    appState.recentAlerts.removeAll()
                }) {
                    Text("Clear Alerts")
                }
                .buttonStyle(.bordered)
                .disabled(appState.recentAlerts.isEmpty)
            }
            
            // Active alert banner if visible
            if let active = appState.activeAlertBanner {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active High Drop Alert!")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(String(
                            format: "Spike to %.1f W (%.1f%%/hr) at %.2f%% battery. Top apps: %@",
                            active.dischargeWatts,
                            active.dropRatePerHour,
                            active.batteryPercentage,
                            active.topAppNames.joined(separator: ", ")
                        ))
                        .font(.caption)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        appState.dismissAlertBanner()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            // Recent alerts list
            if appState.recentAlerts.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green.opacity(0.8))
                    Text("No Sudden Drop Spikes Recorded")
                        .font(.headline)
                    Text("When a sudden high current draw occurs, Batt logs the instant rate and culprit apps here.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 250)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(appState.recentAlerts) { alert in
                            AlertRowView(alert: alert, settings: settings)
                        }
                    }
                }
            }
        }
    }
}

private struct AlertRowView: View {
    let alert: BatterySpikeAlert
    @ObservedObject var settings: SettingsState
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: alert.timestamp)
    }
    
    public var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                .font(.title2)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(String(format: "High Draw: %.1f W", alert.dischargeWatts))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(String(format: "(%.1f%% / hr drop)", alert.dropRatePerHour))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Text(formattedTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    Text("Battery Level: " + String(format: "%.2f%%", alert.batteryPercentage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !alert.topAppNames.isEmpty {
                        Text("Active culprits: " + alert.topAppNames.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
