import Foundation
import SwiftUI
import Combine
import UserNotifications

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    // Telemetry & Snapshot
    @Published public var currentSnapshot: BatterySnapshot?
    @Published public var previousSnapshot: BatterySnapshot?
    
    // Live Inspector Mode (1-second high frequency tracking)
    @Published public var isLiveInspectorActive: Bool = false {
        didSet {
            resetSamplingTimer()
        }
    }
    @Published public var livePoints: [LiveDropPoint] = []
    
    // Per-app Energy Attribution
    @Published public var appRecords: [AppEnergyRecord] = []
    
    // Alerts
    @Published public var recentAlerts: [BatterySpikeAlert] = []
    @Published public var activeAlertBanner: BatterySpikeAlert?
    
    // Session stats
    @Published public var sessionStartSnapshot: BatterySnapshot?
    @Published public var sessionStartTime: Date = Date()
    
    // Historical summaries
    @Published public var dailySummaries: [DaySummary] = []
    
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        requestNotificationPermissions()
        loadInitialData()
        startSamplingTimer()
        
        // Listen for spike alerts from DropRateEngine
        DropRateEngine.shared.onSpikeAlert = { [weak self] alert in
            Task { @MainActor in
                self?.handleSpikeAlert(alert)
            }
        }
    }
    
    public func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
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
        }
    }
    
    public func refreshNow() {
        sampleTick()
    }
    
    public func toggleLiveInspector() {
        isLiveInspectorActive.toggle()
    }
    
    private func startSamplingTimer() {
        timer?.invalidate()
        let interval = isLiveInspectorActive ? 1.0 : SettingsState.shared.samplingInterval
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sampleTick()
            }
        }
    }
    
    private func resetSamplingTimer() {
        startSamplingTimer()
    }
    
    private func sampleTick() {
        guard let newSnap = BatteryMonitor.shared.fetchSnapshot() else { return }
        
        let oldSnap = currentSnapshot
        self.previousSnapshot = oldSnap
        self.currentSnapshot = newSnap
        
        // Calculate discharged amount in this step
        var dischargedMWh: Double = 0.0
        var dischargedPercent: Double = 0.0
        
        if let old = oldSnap {
            if !newSnap.isCharging && newSnap.rawCurrentCapacity < old.rawCurrentCapacity {
                let deltaMAh = Double(old.rawCurrentCapacity - newSnap.rawCurrentCapacity)
                let avgVoltage = Double(old.voltageMillivolts + newSnap.voltageMillivolts) / 2000.0 // Volts
                dischargedMWh = deltaMAh * avgVoltage
            }
            if !newSnap.isCharging && newSnap.rawPercentage < old.rawPercentage {
                dischargedPercent = old.rawPercentage - newSnap.rawPercentage
            }
        }
        
        // Sample running apps and attribute power
        let updatedApps = ProcessEnergyTracker.shared.sample(
            dischargedMWh: dischargedMWh,
            dischargedPercent: dischargedPercent,
            currentDischargeWatts: abs(newSnap.instantPowerWatts)
        )
        self.appRecords = updatedApps
        
        // Record to live engine & detect spikes
        let topNames = updatedApps.prefix(3).map { $0.name }
        if let alert = DropRateEngine.shared.recordSample(
            snapshot: newSnap,
            topApps: topNames,
            thresholdWatts: SettingsState.shared.alertThresholdWatts,
            alertsEnabled: SettingsState.shared.instantAlertsEnabled
        ) {
            handleSpikeAlert(alert)
        }
        
        self.livePoints = DropRateEngine.shared.getLiveHistory()
        
        // Save to 7-day history store
        HistoryStore.shared.addSnapshot(newSnap)
        HistoryStore.shared.updateAppRecords(updatedApps)
        self.dailySummaries = HistoryStore.shared.getDailySummaries()
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
        recentAlerts.removeAll()
        appRecords.removeAll()
        livePoints.removeAll()
        dailySummaries.removeAll()
        sessionStartTime = Date()
        sessionStartSnapshot = currentSnapshot
    }
}
