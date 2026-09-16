import SwiftUI

public struct LiveDropRateView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var settings: SettingsState
    
    @State private var pulse = false
    @State private var chartUnitIsWatts = false
    
    public init(appState: AppState, settings: SettingsState) {
        self.appState = appState
        self.settings = settings
    }
    
    private var snapshot: BatterySnapshot? {
        appState.currentSnapshot
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Live Inspector Header & Big Toggle Button
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Live Drop Rate Inspector")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if appState.isLiveInspectorActive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: Color.red.opacity(0.6), radius: 2)
                                
                                Text("LIVE (1s)")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(4)
                        }
                    }
                    
                    Text("Instantaneous hardware telemetry directly from AppleSmartBattery current sense shunt.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Live Button
                Button(action: {
                    appState.toggleLiveInspector()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: appState.isLiveInspectorActive ? "stop.circle.fill" : "bolt.badge.clock.fill")
                            .font(.headline)
                        
                        Text(appState.isLiveInspectorActive ? "Stop Live Inspection" : "Inspect Live Drop Rate")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .foregroundColor(.white)
                    .background(
                        appState.isLiveInspectorActive
                            ? LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(10)
                    .shadow(color: appState.isLiveInspectorActive ? Color.red.opacity(0.3) : Color.blue.opacity(0.3), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            
            // Educational Sensitivity Banner
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.max.fill")
                    .foregroundColor(.yellow)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Precision Brightness Sensitivity Test")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Change your Mac screen brightness (or keyboard backlight) right now. You will see the instantaneous drop rate, amperage, and wattage respond immediately on the meter below.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.yellow.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                    )
            )
            
            if let snap = snapshot {
                // Live Meter & Current Reading
                HStack(spacing: 24) {
                    // Big Drop Rate Callout
                    VStack(alignment: .leading, spacing: 8) {
                        Text("INSTANTANEOUS DISCHARGE RATE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(String(format: "-%.2f", snap.instantDropRatePerHour))
                                .font(.system(size: 46, weight: .heavy, design: .rounded))
                                .foregroundColor(snap.instantDropRatePerHour > 18 ? .red : .orange)
                                .contentTransition(.numericText())
                            
                            Text("% / hr")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(String(format: "Equivalent to -%.3f%% battery drop per minute", snap.instantDropRatePerHour / 60.0))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                    )
                    
                    // Big Instant Power Callout
                    VStack(alignment: .leading, spacing: 8) {
                        Text("INSTANTANEOUS POWER DRAW")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(String(format: "%.2f", abs(snap.instantPowerWatts)))
                                .font(.system(size: 46, weight: .heavy, design: .rounded))
                                .foregroundColor(abs(snap.instantPowerWatts) > 18 ? .red : .primary)
                                .contentTransition(.numericText())
                            
                            Text("Watts")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(String(format: "Current: %d mA at %.2f V", abs(snap.instantAmperage), Double(snap.voltageMillivolts) / 1000.0))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                    )
                }
                
                // Real-Time 60-Second Oscillograph
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("60-Second Real-Time Discharge Curve")
                                .font(.headline)
                            Text("Plots instantaneous fluctuations as screen brightness or background apps change.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Picker("", selection: $chartUnitIsWatts) {
                            Text("Drop Rate (%/h)").tag(false)
                            Text("Power (Watts)").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }
                    
                    LiveSparklineView(points: appState.livePoints, showWatts: chartUnitIsWatts)
                        .frame(height: 140)
                        .padding(.vertical, 8)
                    
                    HStack {
                        Text("60 seconds ago")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Now (Live)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }
        }
    }
}
