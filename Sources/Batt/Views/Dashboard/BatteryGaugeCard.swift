import SwiftUI

public struct BatteryGaugeCard: View {
    @ObservedObject var appState: AppState
    @ObservedObject var settings: SettingsState
    
    public init(appState: AppState, settings: SettingsState) {
        self.appState = appState
        self.settings = settings
    }
    
    private var snapshot: BatterySnapshot? {
        appState.currentSnapshot
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            if let snap = snapshot {
                // Header & Primary Gauge Row
                HStack(alignment: .center, spacing: 32) {
                    GaugeMeterView(
                        percentage: snap.rawPercentage,
                        isCharging: snap.isCharging,
                        dropRatePerHour: snap.instantDropRatePerHour,
                        size: 180
                    )
                    
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            Text("Battery Status")
                                .font(.system(size: 26, weight: .bold))
                            
                            if snap.isCharging {
                                HStack(spacing: 4) {
                                    Image(systemName: "bolt.fill")
                                        .font(.caption)
                                    Text("Charging")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.18))
                                .foregroundColor(.green)
                                .cornerRadius(6)
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down")
                                        .font(.caption2)
                                    Text("On Battery")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.15))
                                .foregroundColor(.secondary)
                                .cornerRadius(6)
                            }
                        }
                        
                        // 4 Key Enlarged Metrics
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            // 1. Apple Menu Bar
                            VStack(alignment: .leading, spacing: 4) {
                                Text("APPLE MENU BAR")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("\(snap.appleReportedPercentage)%")
                                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    
                                    let diff = Double(snap.appleReportedPercentage) - snap.rawPercentage
                                    Text(String(format: "(%@%.2f%%)", diff >= 0 ? "+" : "", diff))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(diff.magnitude > 0.05 ? .secondary : .green)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
                            )
                            
                            // 2. Live Drop Rate
                            VStack(alignment: .leading, spacing: 4) {
                                Text("LIVE DROP RATE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                if snap.isCharging {
                                    Text("+" + settings.powerUnit.format(watts: abs(snap.instantPowerWatts)))
                                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                                        .foregroundColor(.green)
                                } else {
                                    Text(settings.dropRateUnit.format(
                                        ratePerHour: snap.instantDropRatePerHour,
                                        dischargeWatts: abs(snap.instantPowerWatts),
                                        dischargeMilliamps: abs(snap.instantAmperage)
                                    ))
                                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    .foregroundColor(snap.instantDropRatePerHour > 18 ? .red : .orange)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
                            )
                            
                            // 3. Time Remaining
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TIME REMAINING")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                Text(UnitsFormatter.formatDuration(minutes: snap.timeRemainingMinutes ?? -1))
                                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
                            )
                            
                            // 4. Battery Health
                            VStack(alignment: .leading, spacing: 4) {
                                Text("BATTERY HEALTH")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                Text(String(format: "%.1f%%", snap.healthPercentage))
                                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    .foregroundColor(snap.healthPercentage >= 80 ? .green : .orange)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
                            )
                        }
                    }
                    
                    Spacer()
                }
                .padding(22)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
                )
                
                // Hardware Telemetry Details Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricCardView(
                        title: "Current Draw",
                        value: settings.currentUnit.format(milliampere: snap.instantAmperage),
                        subtitle: snap.instantAmperage < 0 ? "Discharging" : "Charging",
                        iconName: "bolt.badge.clock",
                        accentColor: snap.instantAmperage < 0 ? .orange : .green
                    )
                    
                    MetricCardView(
                        title: "Power Draw",
                        value: settings.powerUnit.format(watts: abs(snap.instantPowerWatts)),
                        subtitle: String(format: "System Load: %.1f W", snap.systemLoadWatts ?? abs(snap.instantPowerWatts)),
                        iconName: "flame.fill",
                        accentColor: abs(snap.instantPowerWatts) > 15 ? .red : .orange
                    )
                    
                    MetricCardView(
                        title: "Pack Voltage",
                        value: settings.voltageUnit.format(millivolts: snap.voltageMillivolts),
                        subtitle: "Nominal Pack",
                        iconName: "waveform.path.ecg",
                        accentColor: .blue
                    )
                    
                    MetricCardView(
                        title: "Capacity",
                        value: "\(snap.rawCurrentCapacity) / \(snap.rawMaxCapacity) mAh",
                        subtitle: "Design: \(snap.designCapacity) mAh",
                        iconName: "battery.100",
                        accentColor: .purple
                    )
                    
                    MetricCardView(
                        title: "Cycle Count",
                        value: "\(snap.cycleCount) cycles",
                        subtitle: "Condition: Normal",
                        iconName: "arrow.triangle.2.circlepath",
                        accentColor: .teal
                    )
                    
                    MetricCardView(
                        title: "Pack Temperature",
                        value: String(format: "%.1f °C", snap.temperatureCelsius),
                        subtitle: String(format: "%.1f °F", snap.temperatureCelsius * 1.8 + 32),
                        iconName: "thermometer.medium",
                        accentColor: snap.temperatureCelsius > 38 ? .red : .teal
                    )
                    
                    MetricCardView(
                        title: "Session Drop",
                        value: sessionDropFormatted,
                        subtitle: "Since \(sessionStartTimeFormatted)",
                        iconName: "chart.line.downtrend.xyaxis",
                        accentColor: .orange
                    )
                    
                    MetricCardView(
                        title: "Power Source",
                        value: snap.isExternalConnected ? (snap.isCharging ? "AC (Charging)" : "AC Connected") : "Battery Power",
                        subtitle: snap.isExternalConnected ? "Wall Connected" : "On Battery",
                        iconName: snap.isExternalConnected ? "powerplug.fill" : "laptopcomputer",
                        accentColor: snap.isExternalConnected ? .green : .cyan
                    )
                }
            } else {
                ProgressView("Reading battery telemetry…")
                    .padding(40)
            }
        }
    }
    
    private var sessionDropFormatted: String {
        guard let current = snapshot?.rawPercentage,
              let start = appState.sessionStartSnapshot?.rawPercentage else {
            return "0.00%"
        }
        let delta = start - current
        if delta > 0 {
            return String(format: "-%.2f%%", delta)
        } else if delta < 0 {
            return String(format: "+%.2f%%", abs(delta))
        } else {
            return "0.00%"
        }
    }
    
    private var sessionStartTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: appState.sessionStartTime)
    }
}
