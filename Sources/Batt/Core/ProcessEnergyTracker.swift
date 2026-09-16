import Foundation
import AppKit
import Darwin.libproc

public struct AppEnergyRecord: Identifiable, Codable, Sendable {
    public let id: String // bundleIdentifier or process name
    public let pid: Int32
    public let name: String
    public let bundleIdentifier: String?
    
    public var cpuTimeNsDelta: UInt64
    public var cpuShare: Double // 0.0 to 1.0
    
    // Attributed consumption
    public var batteryPercentConsumed: Double // % drop attributed to this app
    public var energyConsumedMWh: Double      // mWh consumed
    public var instantPowerWatts: Double      // instantaneous power attribution
    public var lastActiveTimestamp: Date
    
    public init(
        id: String,
        pid: Int32,
        name: String,
        bundleIdentifier: String?,
        cpuTimeNsDelta: UInt64 = 0,
        cpuShare: Double = 0.0,
        batteryPercentConsumed: Double = 0.0,
        energyConsumedMWh: Double = 0.0,
        instantPowerWatts: Double = 0.0,
        lastActiveTimestamp: Date = Date()
    ) {
        self.id = id
        self.pid = pid
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.cpuTimeNsDelta = cpuTimeNsDelta
        self.cpuShare = cpuShare
        self.batteryPercentConsumed = batteryPercentConsumed
        self.energyConsumedMWh = energyConsumedMWh
        self.instantPowerWatts = instantPowerWatts
        self.lastActiveTimestamp = lastActiveTimestamp
    }
}

public final class ProcessEnergyTracker: @unchecked Sendable {
    public static let shared = ProcessEnergyTracker()
    
    private var lastCpuTimes: [pid_t: UInt64] = [:]
    private var lastSampleTime: Date = Date()
    
    // Cumulative session metrics per app ID
    private var cumulativeAppRecords: [String: AppEnergyRecord] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    /// Samples all running GUI applications and computes energy attribution based on CPU activity.
    /// This runs in < 1ms because it only queries active NSRunningApplication instances.
    public func sample(dischargedMWh: Double, dischargedPercent: Double, currentDischargeWatts: Double) -> [AppEnergyRecord] {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        let dt = max(0.1, min(60.0, now.timeIntervalSince(lastSampleTime)))
        lastSampleTime = now
        let wallNs = UInt64(dt * 1_000_000_000.0)
        
        let apps = NSWorkspace.shared.runningApplications
        var processDeltas: [pid_t: (name: String, bundleId: String?, deltaNs: UInt64)] = [:]
        var totalDeltaNs: UInt64 = 0
        
        var currentPids = Set<pid_t>()
        
        for app in apps {
            let pid = app.processIdentifier
            currentPids.insert(pid)
            guard let totalTime = getProcessCpuTime(pid: pid) else { continue }
            
            let prev = lastCpuTimes[pid] ?? totalTime
            lastCpuTimes[pid] = totalTime
            
            let delta = (totalTime >= prev) ? (totalTime - prev) : 0
            if delta > 0 {
                let name = app.localizedName ?? "Unknown Process"
                let bundleId = app.bundleIdentifier
                processDeltas[pid] = (name, bundleId, delta)
                totalDeltaNs += delta
            }
        }
        
        // Prune terminated PIDs from cache
        lastCpuTimes = lastCpuTimes.filter { currentPids.contains($0.key) }
        
        // Reset instant power & cpuShare for apps that are idle in this sampling interval
        for appId in cumulativeAppRecords.keys {
            if cumulativeAppRecords[appId]?.id == "com.apple.sleep.standby" { continue }
            if let pid = cumulativeAppRecords[appId]?.pid, processDeltas[pid] == nil {
                cumulativeAppRecords[appId]?.cpuTimeNsDelta = 0
                cumulativeAppRecords[appId]?.cpuShare = 0.0
                cumulativeAppRecords[appId]?.instantPowerWatts = 0.0
            }
        }
        
        // Compute attribution for active processes
        var intervalRecords: [AppEnergyRecord] = []
        let activeComputeRatio = wallNs > 0 ? min(1.0, Double(totalDeltaNs) / Double(wallNs)) : 0.0
        
        for (pid, info) in processDeltas {
            // Actual CPU fraction of 1 core (e.g. 0.015 = 1.5% CPU core usage)
            let actualCpuFraction = wallNs > 0 ? (Double(info.deltaNs) / Double(wallNs)) : 0.0
            let relativeShare = (totalDeltaNs > 0) ? (Double(info.deltaNs) / Double(totalDeltaNs)) : 0.0
            
            // Dynamic CPU power: ~1.6W per 100% active core workload on Apple Silicon / Intel.
            // Under heavy load, scales with relative share of compute wattage.
            // At idle, strictly bounds to actual dynamic CPU wattage so idle apps never inherit idle SoC baseboard leakage!
            let dynamicWatts = actualCpuFraction * 1.6
            let scaledWatts = currentDischargeWatts * relativeShare * activeComputeRatio
            let attributedWatts = min(currentDischargeWatts, max(dynamicWatts, scaledWatts))
            
            let appId = info.bundleId ?? "\(info.name)_\(pid)"
            let attributedMWh = (attributedWatts * (dt / 3600.0)) * 1000.0
            let attributedPercent = dischargedPercent * relativeShare * activeComputeRatio
            
            var existing = cumulativeAppRecords[appId] ?? AppEnergyRecord(
                id: appId,
                pid: pid,
                name: info.name,
                bundleIdentifier: info.bundleId
            )
            
            existing.cpuTimeNsDelta = info.deltaNs
            existing.cpuShare = actualCpuFraction
            existing.batteryPercentConsumed += attributedPercent
            existing.energyConsumedMWh += attributedMWh
            existing.instantPowerWatts = attributedWatts
            existing.lastActiveTimestamp = now
            
            cumulativeAppRecords[appId] = existing
            intervalRecords.append(existing)
        }
        
        // Return sorted by highest battery percentage consumed
        return cumulativeAppRecords.values
            .sorted { $0.batteryPercentConsumed > $1.batteryPercentConsumed }
    }
    
    public func updateStandbyDrain(_ record: AppEnergyRecord) {
        lock.lock()
        defer { lock.unlock() }
        var existing = cumulativeAppRecords[record.id] ?? record
        existing.batteryPercentConsumed += record.batteryPercentConsumed
        existing.energyConsumedMWh += record.energyConsumedMWh
        existing.lastActiveTimestamp = Date()
        cumulativeAppRecords[record.id] = existing
    }
    
    public func getCumulativeRecords() -> [AppEnergyRecord] {
        lock.lock()
        defer { lock.unlock() }
        return cumulativeAppRecords.values
            .sorted { $0.batteryPercentConsumed > $1.batteryPercentConsumed }
    }
    
    public func resetSession() {
        lock.lock()
        defer { lock.unlock() }
        cumulativeAppRecords.removeAll()
        lastCpuTimes.removeAll()
        lastSampleTime = Date()
    }
    
    private func getProcessCpuTime(pid: pid_t) -> UInt64? {
        var taskInfo = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.stride
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(size))
        guard result == size else { return nil }
        return taskInfo.pti_total_user + taskInfo.pti_total_system
    }
}
