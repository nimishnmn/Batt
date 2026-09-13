import SwiftUI

public struct MenuBarIconView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var settings: SettingsState
    
    public init(appState: AppState, settings: SettingsState) {
        self.appState = appState
        self.settings = settings
    }
    
    private var snapshot: BatterySnapshot? {
        appState.currentSnapshot
    }
    
    private var batteryIconName: String {
        guard let snap = snapshot else { return "battery.50percent" }
        if snap.isCharging {
            return "battery.100percent.bolt"
        }
        let p = snap.rawPercentage
        if p >= 90 { return "battery.100percent" }
        if p >= 75 { return "battery.75percent" }
        if p >= 50 { return "battery.50percent" }
        if p >= 25 { return "battery.25percent" }
        return "battery.0percent"
    }
    
    private var labelString: String {
        guard let snap = snapshot else { return "--%" }
        let batteryStr = UnitsFormatter.formatPercentage(snap.rawPercentage, decimals: settings.decimalPrecision)
        
        switch settings.menuBarStyle {
        case .iconOnly:
            return ""
            
        case .rawPercent:
            return batteryStr
            
        case .percentAndRate:
            if snap.isCharging {
                return "\(batteryStr) · ⚡️ Charging"
            } else if snap.instantDropRatePerHour > 0.01 {
                let arrow = settings.showDropArrow ? "↓" : ""
                return String(format: "%@ · %@%.1f%%/h", batteryStr, arrow, snap.instantDropRatePerHour)
            } else {
                return "\(batteryStr) · 0.0%/h"
            }
            
        case .percentAndWatts:
            let watts = abs(snap.instantPowerWatts)
            if snap.isCharging {
                return String(format: "%@ · +%.1fW", batteryStr, watts)
            } else {
                let arrow = settings.showDropArrow ? "↓" : ""
                return String(format: "%@ · %@%.1fW", batteryStr, arrow, watts)
            }
            
        case .percentAndTime:
            if snap.isCharging {
                return "\(batteryStr) · ⚡️ Charging"
            } else {
                let time = UnitsFormatter.formatDuration(minutes: snap.timeRemainingMinutes ?? -1)
                return "\(batteryStr) · \(time)"
            }
            
        case .timeOnly:
            if snap.isCharging {
                return "⚡️ Charging"
            } else {
                return UnitsFormatter.formatDuration(minutes: snap.timeRemainingMinutes ?? -1)
            }
            
        case .wattsOnly:
            return settings.powerUnit.format(watts: abs(snap.instantPowerWatts))
        }
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: batteryIconName)
            if !labelString.isEmpty {
                Text(labelString)
            }
        }
    }
}
