import Foundation

public struct DaySummary: Identifiable, Sendable {
    public var id: String { dateString }
    public let dateString: String
    public let totalPercentDrop: Double
    public let averageDischargeWatts: Double
    public let peakDischargeWatts: Double
}

public struct HistoricalDataContainer: Codable, Sendable {
    public var snapshots: [BatterySnapshot]
    public var appRecords: [String: AppEnergyRecord] // keyed by app identifier
    public var alerts: [BatterySpikeAlert]
    
    public init(snapshots: [BatterySnapshot] = [], appRecords: [String: AppEnergyRecord] = [:], alerts: [BatterySpikeAlert] = []) {
        self.snapshots = snapshots
        self.appRecords = appRecords
        self.alerts = alerts
    }
}

public final class HistoryStore: @unchecked Sendable {
    public static let shared = HistoryStore()
    
    private let fileURL: URL
    private var container: HistoricalDataContainer
    private let queue = DispatchQueue(label: "com.batt.historystore", qos: .utility)
    private let lock = NSLock()
    
    // Retention period: 7 days
    public let maxAgeSeconds: TimeInterval = 7 * 24 * 3600
    
    private var lastDiskSave: Date = .distantPast
    private var pendingChanges = false
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let battDir = appSupport.appendingPathComponent("Batt", isDirectory: true)
        try? FileManager.default.createDirectory(at: battDir, withIntermediateDirectories: true)
        self.fileURL = battDir.appendingPathComponent("history.json")
        
        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode(HistoricalDataContainer.self, from: data) {
            self.container = loaded
        } else {
            self.container = HistoricalDataContainer()
        }
        
        pruneOldRecords()
    }
    
    /// Records a new snapshot and updates rolling history
    public func addSnapshot(_ snapshot: BatterySnapshot) {
        lock.lock()
        defer { lock.unlock() }
        
        container.snapshots.append(snapshot)
        pendingChanges = true
        
        // Save to disk at most every 30 seconds to conserve I/O & SSD wear
        let now = Date()
        if now.timeIntervalSince(lastDiskSave) >= 30.0 {
            saveToDisk()
        }
    }
    
    /// Records or updates app consumption records
    public func updateAppRecords(_ records: [AppEnergyRecord]) {
        lock.lock()
        defer { lock.unlock() }
        
        for record in records {
            var existing = container.appRecords[record.id] ?? record
            existing.batteryPercentConsumed += record.batteryPercentConsumed
            existing.energyConsumedMWh += record.energyConsumedMWh
            existing.lastActiveTimestamp = record.lastActiveTimestamp
            existing.instantPowerWatts = record.instantPowerWatts
            container.appRecords[record.id] = existing
        }
        pendingChanges = true
    }
    
    /// Records a spike alert event
    public func addAlert(_ alert: BatterySpikeAlert) {
        lock.lock()
        defer { lock.unlock() }
        
        container.alerts.append(alert)
        saveToDisk()
    }
    
    /// Prunes any data older than 7 days
    public func pruneOldRecords() {
        lock.lock()
        defer { lock.unlock() }
        
        let cutoff = Date().addingTimeInterval(-maxAgeSeconds)
        container.snapshots.removeAll { $0.timestamp < cutoff }
        container.alerts.removeAll { $0.timestamp < cutoff }
        
        // Prune inactive apps older than 7 days
        container.appRecords = container.appRecords.filter { $0.value.lastActiveTimestamp >= cutoff }
        saveToDisk()
    }
    
    public func getSnapshots(since: Date? = nil) -> [BatterySnapshot] {
        lock.lock()
        defer { lock.unlock() }
        if let since = since {
            return container.snapshots.filter { $0.timestamp >= since }
        }
        return container.snapshots
    }
    
    public func getAppRecords() -> [AppEnergyRecord] {
        lock.lock()
        defer { lock.unlock() }
        return container.appRecords.values
            .sorted { $0.batteryPercentConsumed > $1.batteryPercentConsumed }
    }
    
    public func getAlerts() -> [BatterySpikeAlert] {
        lock.lock()
        defer { lock.unlock() }
        return container.alerts.sorted { $0.timestamp > $1.timestamp }
    }
    
    public func getDailySummaries() -> [DaySummary] {
        lock.lock()
        defer { lock.unlock() }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let grouped = Dictionary(grouping: container.snapshots) { formatter.string(from: $0.timestamp) }
        
        return grouped.map { (dateStr, snaps) in
            let sorted = snaps.sorted { $0.timestamp < $1.timestamp }
            var drop: Double = 0
            if sorted.count >= 2 {
                for i in 1..<sorted.count {
                    let prev = sorted[i-1]
                    let curr = sorted[i]
                    if !curr.isCharging && curr.rawPercentage < prev.rawPercentage {
                        drop += (prev.rawPercentage - curr.rawPercentage)
                    }
                }
            }
            let dischargeWatts = snaps.filter { !$0.isCharging }.map { abs($0.instantPowerWatts) }
            let avgWatts = dischargeWatts.isEmpty ? 0 : (dischargeWatts.reduce(0, +) / Double(dischargeWatts.count))
            let maxWatts = dischargeWatts.max() ?? 0
            
            return DaySummary(
                dateString: dateStr,
                totalPercentDrop: drop,
                averageDischargeWatts: avgWatts,
                peakDischargeWatts: maxWatts
            )
        }.sorted { $0.dateString > $1.dateString }
    }
    
    public func clearAllHistory() {
        lock.lock()
        defer { lock.unlock() }
        container = HistoricalDataContainer()
        saveToDisk()
    }
    
    public func getStorageSizeFormatted() -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int64 else {
            return "0 KB"
        }
        if size > 1_048_576 {
            return String(format: "%.1f MB", Double(size) / 1_048_576.0)
        } else {
            return String(format: "%.1f KB", Double(size) / 1024.0)
        }
    }
    
    private func saveToDisk() {
        guard pendingChanges else { return }
        lastDiskSave = Date()
        pendingChanges = false
        
        let toEncode = self.container
        queue.async {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(toEncode)
                try data.write(to: self.fileURL, options: [.atomic])
            } catch {
                print("Failed to save history: \(error)")
            }
        }
    }
}
