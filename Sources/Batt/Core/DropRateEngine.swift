import Foundation
import UserNotifications

public struct LiveDropPoint: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let dropRatePerHour: Double  // % / hour
    public let dischargeWatts: Double    // Watts
    public let rawPercentage: Double    // True %
    public let instantAmperage: Int     // mA
}

public final class DropRateEngine: @unchecked Sendable {
    public static let shared = DropRateEngine()
    
    // Live rolling history (last 60 seconds)
    private var liveHistory: [LiveDropPoint] = []
    private let maxLivePoints = 60
    private let lock = NSLock()
    
    // Spike alert tracking
    private var lastAlertTime: Date = .distantPast
    public var alertCooldownSeconds: TimeInterval = 60.0
    
    // Alert callback
    public var onSpikeAlert: (@Sendable (BatterySpikeAlert) -> Void)?
    
    private init() {}
    
    public func recordSample(snapshot: BatterySnapshot, topApps: [String], thresholdWatts: Double, alertsEnabled: Bool) -> BatterySpikeAlert? {
        lock.lock()
        defer { lock.unlock() }
        
        let point = LiveDropPoint(
            timestamp: snapshot.timestamp,
            dropRatePerHour: snapshot.instantDropRatePerHour,
            dischargeWatts: abs(snapshot.instantPowerWatts),
            rawPercentage: snapshot.rawPercentage,
            instantAmperage: snapshot.instantAmperage
        )
        
        liveHistory.append(point)
        if liveHistory.count > maxLivePoints {
            liveHistory.removeFirst(liveHistory.count - maxLivePoints)
        }
        
        // Only evaluate drop spikes when discharging
        guard !snapshot.isCharging && !snapshot.isExternalConnected else {
            return nil
        }
        
        let dischargeWatts = abs(snapshot.instantPowerWatts)
        let now = Date()
        
        if alertsEnabled && dischargeWatts >= thresholdWatts && now.timeIntervalSince(lastAlertTime) >= alertCooldownSeconds {
            lastAlertTime = now
            let alert = BatterySpikeAlert(
                dropRatePerHour: snapshot.instantDropRatePerHour,
                dischargeWatts: dischargeWatts,
                thresholdWatts: thresholdWatts,
                topAppNames: topApps,
                batteryPercentage: snapshot.rawPercentage
            )
            
            // Trigger system notification
            sendSystemSpikeNotification(alert: alert)
            
            // Dispatch in-app callback
            if let callback = onSpikeAlert {
                DispatchQueue.main.async {
                    callback(alert)
                }
            }
            return alert
        }
        
        return nil
    }
    
    public func getLiveHistory() -> [LiveDropPoint] {
        lock.lock()
        defer { lock.unlock() }
        return liveHistory
    }
    
    public func clearLiveHistory() {
        lock.lock()
        defer { lock.unlock() }
        liveHistory.removeAll()
    }
    
    private func sendSystemSpikeNotification(alert: BatterySpikeAlert) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ High Battery Drop Rate Detected"
        let appStr = alert.topAppNames.isEmpty ? "High system workload" : alert.topAppNames.prefix(3).joined(separator: ", ")
        content.body = String(
            format: "Discharge rate spiked to %.1f W (%.1f%%/hr drop) at %.2f%% battery.\nTop apps: %@",
            alert.dischargeWatts,
            alert.dropRatePerHour,
            alert.batteryPercentage,
            appStr
        )
        content.sound = .defaultCritical
        
        let request = UNNotificationRequest(
            identifier: "spike_\(UUID().uuidString)",
            content: content,
            trigger: nil // immediate delivery
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }
}
