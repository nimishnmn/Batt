import Foundation
import SwiftUI
import Combine

public enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    public var id: String { rawValue }
    
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

public enum MenuBarDisplayStyle: String, CaseIterable, Identifiable {
    case iconOnly = "Icon Only"
    case rawPercent = "Battery %"
    case percentAndRate = "Battery % + Drop Rate"
    case percentAndWatts = "Battery % + Watts"
    case percentAndTime = "Battery % + Time Remaining"
    case timeOnly = "Time Remaining Only"
    case wattsOnly = "Watts Only"
    
    public var id: String { rawValue }
}

public enum SamplingInterval: Double, CaseIterable, Identifiable {
    case ultraFast = 1.0     // 1s
    case fast = 5.0          // 5s
    case balanced = 10.0     // 10s (default, lowest background wakeups)
    case relaxed = 30.0      // 30s
    case powerSaver = 60.0   // 60s
    
    public var id: Double { rawValue }
    
    public var title: String {
        switch self {
        case .ultraFast: return "1 second (Precision)"
        case .fast: return "5 seconds"
        case .balanced: return "10 seconds (Recommended)"
        case .relaxed: return "30 seconds"
        case .powerSaver: return "60 seconds (Power Saver)"
        }
    }
}

@MainActor
public final class SettingsState: ObservableObject {
    public static let shared = SettingsState()
    
    // Theme
    @AppStorage("app_theme") public var theme: AppTheme = .system
    
    // Tracking & Precision
    @AppStorage("sampling_interval") public var samplingInterval: Double = 10.0
    @AppStorage("decimal_precision") public var decimalPrecision: Int = 2
    @AppStorage("adaptive_idle_slowdown") public var adaptiveIdleSlowdown: Bool = true
    
    // Menu Bar Display
    @AppStorage("menubar_style") public var menuBarStyle: MenuBarDisplayStyle = .percentAndRate
    @AppStorage("show_charging_indicator") public var showChargingIndicator: Bool = true
    @AppStorage("show_drop_arrow") public var showDropArrow: Bool = true
    
    // Units
    @AppStorage("power_unit") public var powerUnit: PowerUnit = .watts
    @AppStorage("current_unit") public var currentUnit: CurrentUnit = .milliamperes
    @AppStorage("voltage_unit") public var voltageUnit: VoltageUnit = .volts
    @AppStorage("energy_unit") public var energyUnit: EnergyUnit = .wattHours
    @AppStorage("drop_rate_unit") public var dropRateUnit: DropRateUnit = .percentPerHour
    
    // Instant Alerts
    @AppStorage("instant_drop_alerts_enabled") public var instantAlertsEnabled: Bool = true
    @AppStorage("alert_threshold_watts") public var alertThresholdWatts: Double = 16.0
    @AppStorage("alert_threshold_droprate") public var alertThresholdDropRate: Double = 20.0
    @AppStorage("alert_sound_enabled") public var alertSoundEnabled: Bool = true
    
    // Auto start
    @Published public var launchAtLogin: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.launchAtLogin = LaunchAtLoginManager.shared.isEnabled
        
        LaunchAtLoginManager.shared.$isEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                self?.launchAtLogin = enabled
            }
            .store(in: &cancellables)
    }
    
    public func toggleLaunchAtLogin(_ enable: Bool) {
        launchAtLogin = enable
        LaunchAtLoginManager.shared.setEnabled(enable)
    }
}
