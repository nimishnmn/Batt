import Foundation
import SwiftUI
import AppKit

public enum ComponentCategory: String, CaseIterable, Identifiable, Sendable {
    case compute = "Compute (SoC & Apps)"
    case physical = "Physical & Peripherals"
    
    public var id: String { rawValue }
}

public struct ComponentEnergyShare: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let iconName: String
    public let color: Color
    public var instantWatts: Double
    public var batteryPercentConsumed: Double
    public var sharePercentage: Double // 0 to 100%
    public var category: ComponentCategory
    public var detailDescription: String
}

public final class HardwareEnergyTracker: @unchecked Sendable {
    public static let shared = HardwareEnergyTracker()
    
    private var cumulativeComponentDrop: [String: Double] = [:]
    private var cumulativeComponentEnergyMWh: [String: Double] = [:]
    private let lock = NSLock()
    
    private typealias GetBrightnessFunc = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private var getBrightnessFn: GetBrightnessFunc?
    
    private init() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY) {
            if let sym = dlsym(handle, "DisplayServicesGetBrightness") {
                self.getBrightnessFn = unsafeBitCast(sym, to: GetBrightnessFunc.self)
            }
        }
    }
    
    /// Reads current display brightness between 0.0 and 1.0
    public func getDisplayBrightness() -> Float {
        guard let fn = getBrightnessFn else { return 0.5 }
        var b: Float = 0.5
        let res = fn(1, &b) // 1 = Main display
        if res == 0 && b >= 0.0 && b <= 1.0 {
            return b
        }
        return 0.5
    }
    
    /// Calculates live hardware breakdown and accumulates battery drop %
    public func calculateBreakdown(
        totalWatts: Double,
        dischargedPercent: Double,
        dischargedMWh: Double,
        temperatureCelsius: Double
    ) -> [ComponentEnergyShare] {
        lock.lock()
        defer { lock.unlock() }
        
        let watts = max(0.5, abs(totalWatts))
        let brightness = Double(getDisplayBrightness())
        
        // 1. Physical & Peripheral Power Model
        // Screen backlight: 0.4W idle panel + up to 5.0W backlight based on brightness curve
        let rawScreenWatts = 0.4 + 4.8 * pow(brightness, 1.6)
        let screenWatts = min(watts * 0.50, max(0.4, rawScreenWatts))
        
        // Keyboard Backlight & Ambient Sensors: 0.05W to 0.3W
        let kbdWatts = min(0.35, max(0.05, watts * 0.03))
        
        // Cooling Fans & Thermal Dissipation
        let fansWatts: Double
        if temperatureCelsius > 42.0 {
            fansWatts = min(2.5, 0.4 + (temperatureCelsius - 42.0) * 0.12)
        } else if temperatureCelsius > 35.0 {
            fansWatts = 0.2
        } else {
            fansWatts = 0.08
        }
        
        // Wi-Fi & Bluetooth Radios
        let radioWatts = min(0.9, max(0.18, watts * 0.05))
        
        // Audio & Baseboard Standby
        let audioStandbyWatts = min(0.6, max(0.2, watts * 0.04))
        
        let physicalSum = screenWatts + kbdWatts + fansWatts + radioWatts + audioStandbyWatts
        
        // 2. Compute Power (CPU, GPU, RAM, SSD)
        let computeTotal = max(0.2, watts - physicalSum)
        
        // CPU: 52% of compute
        let cpuWatts = computeTotal * 0.52
        // GPU & Neural/Media Engine: 26% of compute
        let gpuWatts = computeTotal * 0.26
        // Unified RAM: 14% of compute
        let ramWatts = computeTotal * 0.14
        // SSD Storage Controller: 8% of compute
        let ssdWatts = computeTotal * 0.08
        
        // Components definitions
        let componentsRaw: [(id: String, name: String, icon: String, color: Color, watts: Double, category: ComponentCategory, desc: String)] = [
            // Compute
            ("cpu", "CPU Cores & Threads", "cpu.fill", .blue, cpuWatts, .compute, "Efficiency & Performance core workload"),
            ("gpu", "GPU & Media Engine", "square.grid.2x2.fill", .purple, gpuWatts, .compute, "Metal graphics, display compositor & video decode"),
            ("ram", "Unified Memory (RAM)", "memorychip.fill", .indigo, ramWatts, .compute, "Unified memory controller & LPDDR bandwidth"),
            ("ssd", "SSD Storage & I/O", "internaldrive.fill", .cyan, ssdWatts, .compute, "NVMe flash storage read/write bus"),
            
            // Physical
            ("screen", "Display Screen & Backlight", "display", .orange, screenWatts, .physical, String(format: "Liquid Retina panel (Brightness: %.0f%%)", brightness * 100.0)),
            ("fans", "Cooling Fans & Thermals", "fanblades.fill", .teal, fansWatts, .physical, String(format: "Active thermal dissipation (%.1f°C)", temperatureCelsius)),
            ("kbd", "Keyboard Backlight & Sensors", "keyboard.fill", .yellow, kbdWatts, .physical, "Keyboard illumination LEDs & ambient light sensors"),
            ("radios", "Wi-Fi & Bluetooth Radios", "antenna.radiowaves.left.and.right", .green, radioWatts, .physical, "Wireless transmission & network packet processing"),
            ("system", "Baseboard & Standby Rails", "powerplug", .gray, audioStandbyWatts, .physical, "Power management ICs, audio DAC & board idle")
        ]
        
        var shares: [ComponentEnergyShare] = []
        let allWattsSum = componentsRaw.reduce(0.0) { $0 + $1.watts }
        
        for comp in componentsRaw {
            let shareRatio = allWattsSum > 0 ? (comp.watts / allWattsSum) : 0.0
            let deltaPercent = dischargedPercent * shareRatio
            let deltaMWh = dischargedMWh * shareRatio
            
            cumulativeComponentDrop[comp.id] = (cumulativeComponentDrop[comp.id] ?? 0.0) + deltaPercent
            cumulativeComponentEnergyMWh[comp.id] = (cumulativeComponentEnergyMWh[comp.id] ?? 0.0) + deltaMWh
            
            let totalDrop = cumulativeComponentDrop[comp.id] ?? 0.0
            
            shares.append(ComponentEnergyShare(
                id: comp.id,
                name: comp.name,
                iconName: comp.icon,
                color: comp.color,
                instantWatts: comp.watts,
                batteryPercentConsumed: totalDrop,
                sharePercentage: shareRatio * 100.0,
                category: comp.category,
                detailDescription: comp.desc
            ))
        }
        
        return shares
    }
    
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        cumulativeComponentDrop.removeAll()
        cumulativeComponentEnergyMWh.removeAll()
    }
}
