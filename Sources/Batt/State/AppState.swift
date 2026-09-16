import Foundation
import SwiftUI
import Combine
import AppKit
import UserNotifications

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    // Window visibility & ultra-low power mode
    @Published public var isWindowVisible: Bool = true {
        didSet {
            resetSamplingTimer()
            if isWindowVisible {
                sampleTick()
            }
        }
    }
    
    // Telemetry & Snapshot
    @Published public var currentSnapshot: BatterySnapshot?
    @Published public var previousSnapshot: BatterySnapshot?
    
    // Sleep / Wake Reconciliation tracking
    private var preSleepSnapshot: BatterySnapshot?
    private var preSleepTime: Date?
    @Published public var lastSleepDurationMinutes: Int? = nil
    @Published public var lastSleepDropPercent: Double? = nil
    
    // Live Inspector Mode (1-second high frequency tracking)
    @Published public var isLiveInspectorActive: Bool = false {
        didSet {
            resetSamplingTimer()
        }
    }
    @Published public var livePoints: [LiveDropPoint] = []
    
    // Per-app Energy Attribution
    @Published public var appRecords: [AppEnergyRecord] = []
    
    // Hardware & Compute Energy Breakdown (CPU, GPU, RAM, SSD, Screen, Fans, Keyboard, Radios)
    @Published public var hardwareShares: [ComponentEnergyShare] = []
    
    // Alerts
    @Published public var recentAlerts: [BatterySpikeAlert] = []
    @Published public var activeAlertBanner: BatterySpikeAlert?
    
    // Session stats
    @Published public var sessionStartSnapshot: BatterySnapshot?
    @Published public var sessionStartTime: Date = Date()
    
    // Historical summaries
    @Published public var dailySummaries: [DaySummary] = []
    
    private var timer: Timer?
    private var lastSampleTime: Date = Date()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        requestNotificationPermissions()
        loadInitialData()
        startSamplingTimer()
        setupSleepWakeObservers()
        setupHardwareChangeObserver()
        
        // Listen for spike alerts from DropRateEngine
        DropRateEngine.shared.onSpikeAlert = { [weak self] alert in
            Task { @MainActor in
                self?.handleSpikeAlert(alert)
            }
        }
    }
    
    public func requestNotificationPermissions() {
        guard Bundle.main.bundleIdentifier != nil else {
            print("[Batt] Running outside an app bundle (e.g. swift run); notifications disabled.")
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    private var lastHardwareChangeTime: Date = .distantPast
    
    private func setupHardwareChangeObserver() {
        BatteryMonitor.shared.onPowerSourceChanged = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Debounce rapid brightness/key events to 0.2s for quick, fluid reactivity
                let now = Date()
                if now.timeIntervalSince(self.lastHardwareChangeTime) >= 0.2 {
                    self.lastHardwareChangeTime = now
                    self.sampleTick()
                }
            }
        }
    }
    
    private func setupSleepWakeObservers() {
        let center = NSWorkspace.shared.notificationCenter
        
        // When system is about to sleep
        center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSystemWillSleep()
            }
        }
        
        // When system wakes up from sleep
        center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSystemWake()
            }
        }
        
        // When display / screen wakes up
        center.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleScreensWake()
            }
        }
    }
    
    private func handleSystemWillSleep() {
        preSleepSnapshot = currentSnapshot
        preSleepTime = Date()
    }
    
    private func handleSystemWake() {
        let now = Date()
        let sleepSeconds = preSleepTime.map { now.timeIntervalSince($0) } ?? 0
        let isRealSleep = sleepSeconds > 15
        
        if isRealSleep {
            lastSleepDurationMinutes = Int(sleepSeconds / 60.0)
        }
        
        // 1. Immediately re-check and reconcile hardware state with zero delay
        sampleTick(isWakeReconciliation: isRealSleep)
        
        // 2. Rapid multi-step stabilization burst
        // MacBook power rails take 0.5s - 2s to stabilize following wake-up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sampleTick()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.sampleTick()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.sampleTick()
        }
        
        resetSamplingTimer()
    }
    
    private func handleScreensWake() {
        // Instant re-check when screen turns on
        sampleTick()
    }
    
    private func loadInitialData() {
        let snap = BatteryMonitor.shared.fetchSnapshot()
        self.currentSnapshot = snap
        self.sessionStartSnapshot = snap
        self.recentAlerts = HistoryStore.shared.getAlerts()
        self.appRecords = HistoryStore.shared.getAppRecords()
        self.dailySummaries = HistoryStore.shared.getDailySummaries()
        
        if let s = snap {
            _ = DropRateEngine.shared.recordSample(
                snapshot: s,
                topApps: [],
                thresholdWatts: SettingsState.shared.alertThresholdWatts,
                alertsEnabled: false
            )
            self.livePoints = DropRateEngine.shared.getLiveHistory()
            self.hardwareShares = HardwareEnergyTracker.shared.calculateBreakdown(
                totalWatts: s.instantPowerWatts,
                dischargedPercent: 0.0,
                dischargedMWh: 0.0,
                temperatureCelsius: s.temperatureCelsius
            )
        }
    }
    
    public func setWindowVisible(_ visible: Bool) {
        let changed = (self.isWindowVisible != visible)
        self.isWindowVisible = visible
        if changed {
            resetSamplingTimer()
            if visible {
                sampleTick()
            }
        }
    }
    
    public func openMainWindow() {
        WindowCloseHandler.shared.showMainWindow()
    }
    
    public func refreshNow() {
        sampleTick()
    }
    
    public func toggleLiveInspector() {
        isLiveInspectorActive.toggle()
        resetSamplingTimer()
    }
    
    private func startSamplingTimer() {
        timer?.invalidate()
        
        // When window is minimized to menu bar, poll every 30s (20x more efficient).
        // When window is open, sample every 1.0s (or 0.5s for live inspector) for true live telemetry!
        let interval: Double
        if !isWindowVisible {
            interval = 30.0
        } else if isLiveInspectorActive {
            interval = 0.5
        } else {
            interval = 1.0
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sampleTick()
            }
        }
    }
    
    private func resetSamplingTimer() {
        startSamplingTimer()
    }
    
    private func sampleTick(isWakeReconciliation: Bool = false) {
        guard let newSnap = BatteryMonitor.shared.fetchSnapshot() else { return }
        
        let now = Date()
        let dt = max(0.1, min(60.0, now.timeIntervalSince(lastSampleTime)))
        lastSampleTime = now
        
        let oldSnap = currentSnapshot
        self.previousSnapshot = oldSnap
        self.currentSnapshot = newSnap
        
        // Calculate discharged amount in this step
        var dischargedMWh: Double = 0.0
        var dischargedPercent: Double = 0.0
        
        // When discharging, continuously integrate power draw across elapsed time dt (every second).
        // This ensures the drop percentage advances smoothly in real-time lockstep with live wattage
        // without being bottlenecked by the battery PMU's coarse ~10-second integer mAh quant.
        if !newSnap.isCharging && newSnap.instantDropRatePerHour > 0 {
            dischargedPercent = (newSnap.instantDropRatePerHour / 3600.0) * dt
            dischargedMWh = abs(newSnap.instantPowerWatts) * (dt / 3600.0) * 1000.0
        }
        
        // If waking up from sleep, reconcile sleep drop to Standby Drain instead of blaming active apps
        if isWakeReconciliation, let pre = preSleepSnapshot {
            if !newSnap.isCharging && newSnap.rawPercentage < pre.rawPercentage {
                let sleepDrop = pre.rawPercentage - newSnap.rawPercentage
                self.lastSleepDropPercent = sleepDrop
                
                // Attribute to Standby item
                let standbyRecord = AppEnergyRecord(
                    id: "com.apple.sleep.standby",
                    pid: 0,
                    name: "macOS Sleep & Standby",
                    bundleIdentifier: "com.apple.sleep.standby",
                    cpuTimeNsDelta: 0,
                    cpuShare: 1.0,
                    batteryPercentConsumed: sleepDrop,
                    energyConsumedMWh: dischargedMWh,
                    instantPowerWatts: 0.15,
                    lastActiveTimestamp: Date()
                )
                ProcessEnergyTracker.shared.updateStandbyDrain(standbyRecord)
                
                // Clear out app delta attribution for this step to avoid false blame
                dischargedPercent = 0.0
                dischargedMWh = 0.0
            }
            preSleepSnapshot = nil
            preSleepTime = nil
        }
        
        // 1. Calculate Hardware vs Compute Energy Breakdown (Screen, Fans, Keyboard, Radios, System rails)
        self.hardwareShares = HardwareEnergyTracker.shared.calculateBreakdown(
            totalWatts: newSnap.instantPowerWatts,
            dischargedPercent: dischargedPercent,
            dischargedMWh: dischargedMWh,
            temperatureCelsius: newSnap.temperatureCelsius
        )
        
        let computeWatts = self.hardwareShares
            .filter { $0.category == .compute }
            .reduce(0.0) { $0 + $1.instantWatts }
        let computeMWh = computeWatts * (dt / 3600.0) * 1000.0
        let computePercent = newSnap.instantPowerWatts != 0 ? (dischargedPercent * (computeWatts / max(0.1, abs(newSnap.instantPowerWatts)))) : dischargedPercent
        
        // 2. Sample running apps and attribute power draw from active compute SoC workload
        let updatedApps = ProcessEnergyTracker.shared.sample(
            dischargedMWh: computeMWh > 0 ? computeMWh : dischargedMWh,
            dischargedPercent: computePercent > 0 ? computePercent : dischargedPercent,
            currentDischargeWatts: max(0.2, computeWatts)
        )
        self.appRecords = updatedApps
        
        // Record to live engine & detect spikes (ignore transient wake spikes)
        if !isWakeReconciliation {
            let topNames = updatedApps.prefix(3).map { $0.name }
            if let alert = DropRateEngine.shared.recordSample(
                snapshot: newSnap,
                topApps: topNames,
                thresholdWatts: SettingsState.shared.alertThresholdWatts,
                alertsEnabled: SettingsState.shared.instantAlertsEnabled
            ) {
                handleSpikeAlert(alert)
            }
        }
        
        self.livePoints = DropRateEngine.shared.getLiveHistory()
        
        // Save to 7-day history store
        HistoryStore.shared.addSnapshot(newSnap)
        HistoryStore.shared.updateAppRecords(updatedApps)
        if isWindowVisible {
            self.dailySummaries = HistoryStore.shared.getDailySummaries()
        }
    }
    
    private func handleSpikeAlert(_ alert: BatterySpikeAlert) {
        withAnimation(.spring()) {
            self.activeAlertBanner = alert
            self.recentAlerts.insert(alert, at: 0)
        }
        HistoryStore.shared.addAlert(alert)
        
        // Auto-dismiss in-app banner after 8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            if self?.activeAlertBanner?.id == alert.id {
                withAnimation {
                    self?.activeAlertBanner = nil
                }
            }
        }
    }
    
    public func dismissAlertBanner() {
        withAnimation {
            activeAlertBanner = nil
        }
    }
    
    public func clearHistory() {
        HistoryStore.shared.clearAllHistory()
        DropRateEngine.shared.clearLiveHistory()
        ProcessEnergyTracker.shared.resetSession()
        HardwareEnergyTracker.shared.reset()
        recentAlerts.removeAll()
        appRecords.removeAll()
        livePoints.removeAll()
        dailySummaries.removeAll()
        hardwareShares.removeAll()
        lastSleepDurationMinutes = nil
        lastSleepDropPercent = nil
        sessionStartTime = Date()
        sessionStartSnapshot = currentSnapshot
    }
}
