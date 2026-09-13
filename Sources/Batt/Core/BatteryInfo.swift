import Foundation

/// Represents a comprehensive snapshot of battery telemetry from hardware registers
public struct BatterySnapshot: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    
    // Capacities (mAh)
    public let rawCurrentCapacity: Int
    public let rawMaxCapacity: Int
    public let designCapacity: Int
    public let nominalChargeCapacity: Int
    
    // Percentages (%)
    public let rawPercentage: Double          // e.g. 77.89% (actual unrounded physics value)
    public let appleReportedPercentage: Int    // e.g. 80% (Apple's rounded/smoothed menu bar number)
    public let healthPercentage: Double       // rawMaxCapacity / designCapacity * 100
    
    // Electrical measurements
    public let voltageMillivolts: Int         // mV (e.g. 12251 mV = 12.251 V)
    public let instantAmperage: Int           // mA (negative = discharging, positive = charging)
    public let filteredAmperage: Int          // mA (smoothed)
    public let instantPowerWatts: Double      // W (e.g. -9.33 W)
    public let systemLoadWatts: Double?       // W from PowerTelemetryData if available
    
    // Instantaneous Drop Rate (% / hour)
    // Formula: -(instantAmperage / rawMaxCapacity) * 100%
    public let instantDropRatePerHour: Double // e.g. 9.85% / hr drop rate
    
    // Physical & Lifecycle
    public let cycleCount: Int
    public let temperatureCelsius: Double     // °C
    public let isExternalConnected: Bool
    public let isCharging: Bool
    public let isFullyCharged: Bool
    public let timeRemainingMinutes: Int?     // nil if unknown/calculating
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        rawCurrentCapacity: Int,
        rawMaxCapacity: Int,
        designCapacity: Int,
        nominalChargeCapacity: Int,
        rawPercentage: Double,
        appleReportedPercentage: Int,
        healthPercentage: Double,
        voltageMillivolts: Int,
        instantAmperage: Int,
        filteredAmperage: Int,
        instantPowerWatts: Double,
        systemLoadWatts: Double? = nil,
        instantDropRatePerHour: Double,
        cycleCount: Int,
        temperatureCelsius: Double,
        isExternalConnected: Bool,
        isCharging: Bool,
        isFullyCharged: Bool,
        timeRemainingMinutes: Int? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.rawCurrentCapacity = rawCurrentCapacity
        self.rawMaxCapacity = rawMaxCapacity
        self.designCapacity = designCapacity
        self.nominalChargeCapacity = nominalChargeCapacity
        self.rawPercentage = rawPercentage
        self.appleReportedPercentage = appleReportedPercentage
        self.healthPercentage = healthPercentage
        self.voltageMillivolts = voltageMillivolts
        self.instantAmperage = instantAmperage
        self.filteredAmperage = filteredAmperage
        self.instantPowerWatts = instantPowerWatts
        self.systemLoadWatts = systemLoadWatts
        self.instantDropRatePerHour = instantDropRatePerHour
        self.cycleCount = cycleCount
        self.temperatureCelsius = temperatureCelsius
        self.isExternalConnected = isExternalConnected
        self.isCharging = isCharging
        self.isFullyCharged = isFullyCharged
        self.timeRemainingMinutes = timeRemainingMinutes
    }
}

/// Represents an instantaneous drop alert event
public struct BatterySpikeAlert: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let dropRatePerHour: Double
    public let dischargeWatts: Double
    public let thresholdWatts: Double
    public let topAppNames: [String]
    public let batteryPercentage: Double
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        dropRatePerHour: Double,
        dischargeWatts: Double,
        thresholdWatts: Double,
        topAppNames: [String],
        batteryPercentage: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.dropRatePerHour = dropRatePerHour
        self.dischargeWatts = dischargeWatts
        self.thresholdWatts = thresholdWatts
        self.topAppNames = topAppNames
        self.batteryPercentage = batteryPercentage
    }
}
