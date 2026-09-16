import XCTest
import Foundation
@testable import Batt

final class BattTests: XCTestCase {

    func testRawBatteryPercentage() {
        let rawCurrent = 6265
        let rawMax = 8043
        let rawPercent = (Double(rawCurrent) / Double(rawMax)) * 100.0
        
        // 6265 / 8043 = 77.8938%
        XCTAssertTrue(abs(rawPercent - 77.8938) < 0.01)
        
        let formatted1 = UnitsFormatter.formatPercentage(rawPercent, decimals: 1)
        XCTAssertEqual(formatted1, "77.9%")
        
        let formatted2 = UnitsFormatter.formatPercentage(rawPercent, decimals: 2)
        XCTAssertEqual(formatted2, "77.89%")
    }

    func testDropRateCalculations() {
        let rawMax = 8043
        let instantAmperage = -762 // negative when discharging
        let voltageMillivolts = 12251 // 12.251 V
        
        // Drop rate per hour = (762 / 8043) * 100% = 9.474% / hour
        let dropRatePerHour = (Double(abs(instantAmperage)) / Double(rawMax)) * 100.0
        XCTAssertTrue(abs(dropRatePerHour - 9.474) < 0.01)
        
        // Instantaneous power (Watts) = (12251 * -762) / 1,000,000 = -9.335 W
        let watts = (Double(voltageMillivolts) * Double(instantAmperage)) / 1_000_000.0
        XCTAssertTrue(abs(watts - (-9.335)) < 0.01)
        
        // Units formatting
        let formattedRate = DropRateUnit.percentPerHour.format(
            ratePerHour: dropRatePerHour,
            dischargeWatts: abs(watts),
            dischargeMilliamps: abs(instantAmperage)
        )
        XCTAssertEqual(formattedRate, "9.47 %/hr")
        
        let formattedMinRate = DropRateUnit.percentPerMinute.format(
            ratePerHour: dropRatePerHour,
            dischargeWatts: abs(watts),
            dischargeMilliamps: abs(instantAmperage)
        )
        XCTAssertEqual(formattedMinRate, "0.158 %/min")
    }

    func testEnergyUnits() {
        let mWh = 12000.0 // 12 Wh
        let voltage = 12.0 // Volts
        
        let whStr = EnergyUnit.wattHours.format(mWh: mWh, voltageVolts: voltage)
        XCTAssertEqual(whStr, "12.00 Wh")
        
        let mahStr = EnergyUnit.milliampereHours.format(mWh: mWh, voltageVolts: voltage)
        XCTAssertEqual(mahStr, "1000 mAh")
        
        let jStr = EnergyUnit.joules.format(mWh: mWh, voltageVolts: voltage)
        XCTAssertEqual(jStr, "43200 J") // 12 Wh * 3600 = 43200 J
    }

    func testPowerUnits() {
        let watts = 9.35
        XCTAssertEqual(PowerUnit.watts.format(watts: watts), "9.35 W")
        XCTAssertEqual(PowerUnit.milliwatts.format(watts: watts), "9350 mW")
    }

    func testLiveSnapshotFetch() {
        let monitor = BatteryMonitor.shared
        let snapshot = monitor.fetchSnapshot()
        
        XCTAssertNotNil(snapshot)
        if let snap = snapshot {
            XCTAssertTrue(snap.rawPercentage >= 0.0 && snap.rawPercentage <= 100.0)
            XCTAssertTrue(snap.voltageMillivolts > 5000) // Laptop packs > 5V
            XCTAssertTrue(snap.rawMaxCapacity > 1000)
            XCTAssertTrue(snap.cycleCount >= 0)
        }
    }

    func testBrightnessDeltaResponsiveness() {
        let monitor = BatteryMonitor.shared
        guard let snap = monitor.fetchSnapshot() else { return }
        
        XCTAssertTrue(snap.rawMaxCapacity > 0)
        XCTAssertTrue(snap.voltageMillivolts > 0)
        if !snap.isCharging {
            XCTAssertTrue(snap.instantPowerWatts < 0)
            XCTAssertTrue(snap.instantDropRatePerHour > 0)
        }
    }

    func testHistoryRetention() {
        let store = HistoryStore.shared
        
        // Add a recent snapshot
        let recentSnap = BatterySnapshot(
            timestamp: Date(),
            rawCurrentCapacity: 5000,
            rawMaxCapacity: 6000,
            designCapacity: 6000,
            nominalChargeCapacity: 6000,
            rawPercentage: 83.33,
            appleReportedPercentage: 84,
            healthPercentage: 100.0,
            voltageMillivolts: 12000,
            instantAmperage: -800,
            filteredAmperage: -800,
            instantPowerWatts: -9.6,
            instantDropRatePerHour: 13.33,
            cycleCount: 10,
            temperatureCelsius: 25.0,
            isExternalConnected: false,
            isCharging: false,
            isFullyCharged: false
        )
        store.addSnapshot(recentSnap)
        
        // Add an old snapshot (8 days ago)
        let oldSnap = BatterySnapshot(
            timestamp: Date().addingTimeInterval(-8 * 24 * 3600),
            rawCurrentCapacity: 5000,
            rawMaxCapacity: 6000,
            designCapacity: 6000,
            nominalChargeCapacity: 6000,
            rawPercentage: 83.33,
            appleReportedPercentage: 84,
            healthPercentage: 100.0,
            voltageMillivolts: 12000,
            instantAmperage: -800,
            filteredAmperage: -800,
            instantPowerWatts: -9.6,
            instantDropRatePerHour: 13.33,
            cycleCount: 10,
            temperatureCelsius: 25.0,
            isExternalConnected: false,
            isCharging: false,
            isFullyCharged: false
        )
        store.addSnapshot(oldSnap)
        
        // Trigger prune
        store.pruneOldRecords()
        
        let snapshots = store.getSnapshots()
        let cutoff = Date().addingTimeInterval(-store.maxAgeSeconds)
        let hasOld = snapshots.contains { $0.timestamp < cutoff }
        XCTAssertFalse(hasOld)
    }
}
