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
        _ = now.timeIntervalSince(lastSampleTime)
        lastSampleTime = now
        
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
        
        // Compute attribution
        var intervalRecords: [AppEnergyRecord] = []
        
        for (pid, info) in processDeltas {
            let share = (totalDeltaNs > 0) ? (Double(info.deltaNs) / Double(totalDeltaNs)) : 0.0
            let appId = info.bundleId ?? "\(info.name)_\(pid)"
            let attributedMWh = dischargedMWh * share
            let attributedPercent = dischargedPercent * share
            let attributedWatts = currentDischargeWatts * share
            
            var existing = cumulativeAppRecords[appId] ?? AppEnergyRecord(
                id: appId,
                pid: pid,
                name: info.name,
                bundleIdentifier: info.bundleId
            )
            
            existing.cpuTimeNsDelta = info.deltaNs
            existing.cpuShare = share
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
