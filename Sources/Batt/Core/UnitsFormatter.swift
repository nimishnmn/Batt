import Foundation

public enum PowerUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case watts = "W"
    case milliwatts = "mW"
    
    public var id: String { rawValue }
    
    public func format(watts: Double) -> String {
        switch self {
        case .watts:
            return String(format: "%.2f W", watts)
        case .milliwatts:
            return String(format: "%.0f mW", watts * 1000.0)
        }
    }
}

public enum CurrentUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case milliamperes = "mA"
    case amperes = "A"
    
    public var id: String { rawValue }
    
    public func format(milliampere: Int) -> String {
        switch self {
        case .milliamperes:
            return "\(milliampere) mA"
        case .amperes:
            return String(format: "%.3f A", Double(milliampere) / 1000.0)
        }
    }
}

public enum VoltageUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case volts = "V"
    case millivolts = "mV"
    
    public var id: String { rawValue }
    
    public func format(millivolts: Int) -> String {
        switch self {
        case .volts:
            return String(format: "%.2f V", Double(millivolts) / 1000.0)
        case .millivolts:
            return "\(millivolts) mV"
        }
    }
}

public enum EnergyUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case wattHours = "Wh"
    case milliampereHours = "mAh"
    case joules = "J"
    
    public var id: String { rawValue }
    
    public func format(mWh: Double, voltageVolts: Double = 12.0) -> String {
        switch self {
        case .wattHours:
            return String(format: "%.2f Wh", mWh / 1000.0)
        case .milliampereHours:
            // mWh = mAh * V  => mAh = mWh / V
            let mah = voltageVolts > 0 ? (mWh / voltageVolts) : 0
            return String(format: "%.0f mAh", mah)
        case .joules:
            // 1 Wh = 3600 Joules  => 1 mWh = 3.6 Joules
            return String(format: "%.0f J", mWh * 3.6)
        }
    }
}

public enum DropRateUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case percentPerHour = "%/hr"
    case percentPerMinute = "%/min"
    case watts = "W"
    case milliamperes = "mA"
    
    public var id: String { rawValue }
    
    public func format(ratePerHour: Double, dischargeWatts: Double, dischargeMilliamps: Int) -> String {
        switch self {
        case .percentPerHour:
            return String(format: "%.2f %%/hr", ratePerHour)
        case .percentPerMinute:
            return String(format: "%.3f %%/min", ratePerHour / 60.0)
        case .watts:
            return String(format: "%.2f W", abs(dischargeWatts))
        case .milliamperes:
            return "\(abs(dischargeMilliamps)) mA"
        }
    }
}

public struct UnitsFormatter: Sendable {
    public static func formatPercentage(_ percent: Double, decimals: Int = 2) -> String {
        let formatStr = "%.\(decimals)f%%"
        return String(format: formatStr, percent)
    }
    
    public static func formatPercentageDelta(_ deltaPercent: Double, decimals: Int = 2) -> String {
        let sign = deltaPercent > 0 ? "+" : ""
        let formatStr = "\(sign)%.\(decimals)f%%"
        return String(format: formatStr, deltaPercent)
    }
    
    public static func formatDuration(minutes: Int) -> String {
        if minutes < 0 { return "Calculating…" }
        if minutes == 0 { return "Full" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}
