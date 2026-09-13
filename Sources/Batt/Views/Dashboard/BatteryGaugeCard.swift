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
                                .background(Color.green.opacity(0.25))
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
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(6)
                            }
                            
                            if let mins = appState.lastSleepDurationMinutes, mins > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "moon.stars.fill")
                                        .font(.caption2)
                                        .foregroundColor(.purple)
                                    Text("Synced after \(mins)m sleep")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.purple)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.purple.opacity(0.18))
                                .cornerRadius(6)
                            }
                        }
                        
                        // 4 Key Enlarged Colorful Metrics
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            // 1. Apple Menu Bar (inflated)
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 4) {
                                    Image(systemName: "applelogo")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.blue)
                                    Text("APPLE MENU BAR (INFLATED)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                                
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("\(snap.appleReportedPercentage)%")
                                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                                        .foregroundColor(.primary)
                                    
                                    let diff = Double(snap.appleReportedPercentage) - snap.rawPercentage
                                    Text(String(format: "(%@%.2f%%)", diff >= 0 ? "+" : "", diff))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.orange)
                                }
                                
                                Text("\(snap.rawCurrentCapacity) mAh ÷ \(snap.rawMaxCapacity) mAh = \(String(format: "%.2f%%", snap.rawPercentage))")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.blue.opacity(0.10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                                    )
                            )
                            
                            // 2. Live Drop Rate
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 4) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.orange)
                                    Text("LIVE DROP RATE")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.orange)
                                }
                                
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
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.orange.opacity(0.10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                                    )
                            )
                            
                            // 3. Time Remaining
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.teal)
                                    Text("TIME REMAINING")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.teal)
                                }
                                
                                Text(UnitsFormatter.formatDuration(minutes: snap.timeRemainingMinutes ?? -1))
                                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    .foregroundColor(.teal)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.teal.opacity(0.10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.teal.opacity(0.25), lineWidth: 1)
                                    )
                            )
                            
                            // 4. Battery Health
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 4) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.green)
                                    Text("BATTERY HEALTH")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.green)
                                }
                                
                                Text(String(format: "%.1f%%", snap.healthPercentage))
                                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    .foregroundColor(snap.healthPercentage >= 80 ? .green : .orange)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.green.opacity(0.10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.green.opacity(0.25), lineWidth: 1)
                                    )
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
                
                // Colorful Hardware Telemetry Details Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricCardView(
                        title: "Current Draw",
                        value: settings.currentUnit.format(milliampere: snap.instantAmperage),
                        subtitle: snap.instantAmperage < 0 ? "Discharging" : "Charging",
                        iconName: "bolt.badge.clock.fill",
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
                        accentColor: .pink
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
