import SwiftUI
import AppKit

public struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var settings: SettingsState
    let onOpenDashboard: () -> Void
    let onOpenSettings: () -> Void
    
    public init(
        appState: AppState,
        settings: SettingsState,
        onOpenDashboard: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.appState = appState
        self.settings = settings
        self.onOpenDashboard = onOpenDashboard
        self.onOpenSettings = onOpenSettings
    }
    
    private var snapshot: BatterySnapshot? {
        appState.currentSnapshot
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            if let snap = snapshot {
                // Header with raw %
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(UnitsFormatter.formatPercentage(snap.rawPercentage, decimals: settings.decimalPrecision))
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                            
                            if snap.isCharging {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Text("Battery Status")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(snap.isCharging ? "Charging" : settings.dropRateUnit.format(
                            ratePerHour: snap.instantDropRatePerHour,
                            dischargeWatts: abs(snap.instantPowerWatts),
                            dischargeMilliamps: abs(snap.instantAmperage)
                        ))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(snap.isCharging ? .green : (snap.instantDropRatePerHour > 18 ? .red : .orange))
                        
                        Text(snap.isCharging ? settings.powerUnit.format(watts: abs(snap.instantPowerWatts)) : "Current Draw")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                
                // Sleep / Wake Sync Badge
                if let mins = appState.lastSleepDurationMinutes, mins > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.purple)
                        Text("Hardware synced after \(mins)m sleep")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.purple)
                        if let drop = appState.lastSleepDropPercent, drop > 0.05 {
                            Text(String(format: "(-%.2f%% standby)", drop))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.12))
                    .cornerRadius(5)
                    .padding(.horizontal, 14)
                }
                
                // Apple vs Raw comparison bar
                let diff = Double(snap.appleReportedPercentage) - snap.rawPercentage
                HStack {
                    Image(systemName: "applelogo")
                        .font(.caption2)
                    Text("Apple Menu Bar: \(snap.appleReportedPercentage)% (\(String(format: "%@%.2f%%", diff >= 0 ? "+" : "", diff)))")
                        .font(.caption2)
                    Spacer()
                    Text("Health: \(String(format: "%.0f%%", snap.healthPercentage))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
                .padding(.horizontal, 14)
                .help("Formula: \(snap.rawCurrentCapacity) mAh ÷ \(snap.rawMaxCapacity) mAh = \(String(format: "%.2f%%", snap.rawPercentage)) (Apple reports \(snap.appleReportedPercentage)% smoothed)")
                
                Divider()
                
                // Hardware stats line
                HStack {
                    Text("Time Remaining: \(UnitsFormatter.formatDuration(minutes: snap.timeRemainingMinutes ?? -1))")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(String(format: "%.1fV · %dmA", Double(snap.voltageMillivolts) / 1000.0, abs(snap.instantAmperage)))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                
                // Top draining apps
                if !appState.appRecords.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TOP BATTERY DRAINING APPS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        ForEach(appState.appRecords.prefix(3)) { app in
                            HStack(spacing: 8) {
                                Text(app.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text(String(format: "-%.2f%%", app.batteryPercentConsumed))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                                
                                Text(settings.powerUnit.format(watts: app.instantPowerWatts))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(8)
                    .padding(.horizontal, 14)
                }
                
                Divider()
                
                // Quick actions
                HStack(spacing: 12) {
                    Button(action: {
                        onOpenDashboard()
                    }) {
                        Label("Dashboard", systemImage: "macwindow")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: {
                        onOpenSettings()
                    }) {
                        Label("Settings", systemImage: "gearshape")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Text("Quit")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            } else {
                ProgressView()
                    .padding(20)
            }
        }
        .frame(width: 320)
        .onAppear {
            // Instantly re-check and sync hardware on click
            appState.refreshNow()
        }
    }
}
