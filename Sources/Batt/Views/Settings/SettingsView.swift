import SwiftUI
import UserNotifications

public struct SettingsView: View {
    @ObservedObject var settings: SettingsState
    @ObservedObject var appState: AppState
    
    public init(settings: SettingsState, appState: AppState) {
        self.settings = settings
        self.appState = appState
    }
    
    public var body: some View {
        TabView {
            // Tab 1: General (Merged Appearance, Tracking, and Menu Bar)
            ScrollView {
                VStack(spacing: 22) {
                    // Appearance Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Appearance & Theme", systemImage: "paintpalette.fill")
                            .font(.headline)
                        
                        Picker("Theme", selection: $settings.theme) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.rawValue).tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Picker("Decimal Precision", selection: $settings.decimalPrecision) {
                            Text("1 Decimal (e.g. 77.9%)").tag(1)
                            Text("2 Decimals (e.g. 77.89%)").tag(2)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    
                    // Tracking & Performance Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Tracking & Resource Usage", systemImage: "timer")
                            .font(.headline)
                        
                        Picker("Background Polling Interval", selection: $settings.samplingInterval) {
                            ForEach(SamplingInterval.allCases) { interval in
                                Text(interval.title).tag(interval.rawValue)
                            }
                        }
                        
                        Text("Batt uses direct sub-millisecond IORegistry hardware reads. Even at 10 seconds, background CPU usage is under 0.05%.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Toggle("Adaptive Idle Saver (Reduce polling when display is asleep)", isOn: $settings.adaptiveIdleSlowdown)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    
                    // Menu Bar Display Settings Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Menu Bar Display Settings", systemImage: "menubar.rectangle")
                            .font(.headline)
                        
                        Picker("Display Style", selection: $settings.menuBarStyle) {
                            ForEach(MenuBarDisplayStyle.allCases) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                        
                        Toggle("Show Charging Indicator (⚡️)", isOn: $settings.showChargingIndicator)
                        Toggle("Show Drop Indicator (↓)", isOn: $settings.showDropArrow)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }
                .padding(20)
            }
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            
            // Tab 2: Units of Measurement
            Form {
                Section(header: Text("Units Configuration").font(.headline)) {
                    Picker("Power Unit", selection: $settings.powerUnit) {
                        ForEach(PowerUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    
                    Picker("Discharge / Drop Rate Unit", selection: $settings.dropRateUnit) {
                        ForEach(DropRateUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    
                    Picker("Energy Unit", selection: $settings.energyUnit) {
                        ForEach(EnergyUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    
                    Picker("Current Unit", selection: $settings.currentUnit) {
                        ForEach(CurrentUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    
                    Picker("Voltage Unit", selection: $settings.voltageUnit) {
                        ForEach(VoltageUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                }
            }
            .padding(20)
            .tabItem {
                Label("Units", systemImage: "scalemass")
            }
            
            // Tab 3: Instant Alerts
            Form {
                Section(header: Text("Instantaneous Drop Alerts").font(.headline)) {
                    Toggle("Enable Instantaneous High Drop Rate Alerts", isOn: $settings.instantAlertsEnabled)
                    
                    if settings.instantAlertsEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Alert Trigger Threshold:")
                                Spacer()
                                Text(String(format: "%.1f Watts", settings.alertThresholdWatts))
                                    .fontWeight(.bold)
                            }
                            
                            Slider(value: $settings.alertThresholdWatts, in: 8.0...35.0, step: 0.5)
                            
                            Text("Equivalent to ~\(String(format: "%.1f", (settings.alertThresholdWatts / 12.0 / 8.0) * 100.0))%/hr drop rate on this Mac.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Toggle("Play Sound with Alert", isOn: $settings.alertSoundEnabled)
                        
                        Button("Send Test Spike Alert") {
                            let testAlert = BatterySpikeAlert(
                                dropRatePerHour: 24.5,
                                dischargeWatts: settings.alertThresholdWatts + 2.0,
                                thresholdWatts: settings.alertThresholdWatts,
                                topAppNames: ["High Load Demo", "Safari"],
                                batteryPercentage: appState.currentSnapshot?.rawPercentage ?? 85.0
                            )
                            withAnimation {
                                appState.activeAlertBanner = testAlert
                                appState.recentAlerts.insert(testAlert, at: 0)
                            }
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 4)
                    }
                }
            }
            .padding(20)
            .tabItem {
                Label("Alerts", systemImage: "bell.badge")
            }
            
            // Tab 4: Startup & Storage
            Form {
                Section(header: Text("Auto Start with the PC").font(.headline)) {
                    Toggle("Launch Batt automatically when logging in", isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.toggleLaunchAtLogin($0) }
                    ))
                    
                    Text("Uses native macOS ServiceManagement (SMAppService) to launch seamlessly at login with zero background overhead.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("7-Day Data Storage").font(.headline)) {
                    HStack {
                        Text("Current Storage Size:")
                        Spacer()
                        Text(HistoryStore.shared.getStorageSizeFormatted())
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Snapshots and per-app stats older than 7 days are automatically pruned to keep disk usage minimal.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Clear All Historical Data", role: .destructive) {
                        appState.clearHistory()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding(20)
            .tabItem {
                Label("System & Data", systemImage: "externaldrive")
            }
            
            // Tab 5: About Section
            VStack(spacing: 20) {
                Spacer()
                
                Image(nsImage: NSImage(named: "AppIcon") ?? NSWorkspace.shared.icon(for: .application))
                    .resizable()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                
                VStack(spacing: 4) {
                    Text("Batt")
                        .font(.title)
                        .fontWeight(.heavy)
                    
                    Text("Version 1.0.0 · Precision Battery & Power Intelligence")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(width: 280)
                
                VStack(spacing: 12) {
                    Text("Created by Nimish")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 16) {
                        // GitHub Button
                        Link(destination: URL(string: "https://github.com/nimishnmn")!) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                    .font(.caption)
                                Text("GitHub (@nimishnmn)")
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        // Instagram Button
                        Link(destination: URL(string: "https://instagram.com/nimish0_0")!) {
                            HStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.caption)
                                Text("Instagram (@nimish0_0)")
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .padding(24)
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .frame(width: 600, height: 480)
    }
}
