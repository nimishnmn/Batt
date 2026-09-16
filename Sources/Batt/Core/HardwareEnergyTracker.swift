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
    private var smoothedComponentWatts: [String: Double] = [:]
    private var smoothedBrightness: Double = 0.5
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
    
    /// Calculates live hardware breakdown with Exponential Moving Average (EMA) smoothing
    /// to avoid hyperactive flickering when brightness or current draw changes.
    public func calculateBreakdown(
        totalWatts: Double,
        dischargedPercent: Double,
        dischargedMWh: Double,
        temperatureCelsius: Double,
        activeComputeWatts: Double = 0.0
    ) -> [ComponentEnergyShare] {
        lock.lock()
        defer { lock.unlock() }
        
        let watts = max(0.5, abs(totalWatts))
        let targetBrightness = Double(getDisplayBrightness())
        
        // Smooth brightness with EMA (alpha = 0.35) for fluid transitions
        smoothedBrightness = (smoothedBrightness * 0.65) + (targetBrightness * 0.35)
        let brightness = smoothedBrightness
        
        // Dynamic Compute Allocation:
        // Quiescent Apple Silicon SoC baseline (caches, uncore, memory controller): ~0.35W - 0.75W
        let socBaseline = min(watts * 0.25, max(0.35, 0.65))
        // Total compute = active applications dynamic workload + SoC baseline
        let targetComputeTotal = min(max(0.4, watts - 0.5), max(0.45, activeComputeWatts + socBaseline))
        // Physical total is the remaining hardware draw (Screen, PMIC, Radios, Fans)
        let targetPhysicalTotal = max(0.2, watts - targetComputeTotal)
        
        // 1. Physical Component Weighting (Liquid Retina XDR Mini-LED, PMIC conversion loss, Radios)
        // Liquid Retina XDR screen: 0.8W base panel + up to 6.2W at max brightness
        let rawScreen = 0.80 + 6.2 * pow(brightness, 1.5)
        let rawKbd = min(0.35, max(0.05, watts * 0.025))
        let rawFans: Double
        if temperatureCelsius > 42.0 {
            rawFans = min(2.5, 0.4 + (temperatureCelsius - 42.0) * 0.12)
        } else if temperatureCelsius > 35.0 {
            rawFans = 0.15
        } else {
            rawFans = 0.05
        }
        let rawRadios = min(0.9, max(0.20, watts * 0.04))
        // Baseboard, PMIC power conversion loss & audio rails
        let rawBoard = min(2.5, max(0.40, watts * 0.12))
        
        let physicalWeightsSum = rawScreen + rawKbd + rawFans + rawRadios + rawBoard
        let physicalScale = physicalWeightsSum > 0 ? (targetPhysicalTotal / physicalWeightsSum) : 1.0
        
        let screenWatts = rawScreen * physicalScale
        let kbdWatts = rawKbd * physicalScale
        let fansWatts = rawFans * physicalScale
        let radioWatts = rawRadios * physicalScale
        let boardWatts = rawBoard * physicalScale
        
        // 2. Compute Power Breakdown (CPU, GPU, RAM, SSD)
        let cpuWatts = targetComputeTotal * 0.52
        let gpuWatts = targetComputeTotal * 0.26
        let ramWatts = targetComputeTotal * 0.14
        let ssdWatts = targetComputeTotal * 0.08
        
        // Raw instantaneous components
        let rawList: [(id: String, name: String, icon: String, color: Color, watts: Double, category: ComponentCategory, desc: String)] = [
            // Compute
            ("cpu", "CPU Cores & Threads", "cpu.fill", .blue, cpuWatts, .compute, "Efficiency & Performance core workload"),
            ("gpu", "GPU & Media Engine", "square.grid.2x2.fill", .purple, gpuWatts, .compute, "Metal graphics, display compositor & video decode"),
            ("ram", "Unified Memory (RAM)", "memorychip.fill", .indigo, ramWatts, .compute, "Unified memory controller & LPDDR bandwidth"),
            ("ssd", "SSD Storage & I/O", "internaldrive.fill", .cyan, ssdWatts, .compute, "NVMe flash storage read/write bus"),
            
            // Physical
            ("screen", "Display Screen & Backlight", "display", .orange, screenWatts, .physical, String(format: "Liquid Retina panel (Brightness: %.0f%%)", brightness * 100.0)),
            ("system", "Baseboard, PMIC & Power Rails", "powerplug", .gray, boardWatts, .physical, "Power management ICs, voltage regulators & idle rails"),
            ("radios", "Wi-Fi & Bluetooth Radios", "antenna.radiowaves.left.and.right", .green, radioWatts, .physical, "Wireless transmission & network packet processing"),
            ("kbd", "Keyboard Backlight & Sensors", "keyboard.fill", .yellow, kbdWatts, .physical, "Keyboard illumination LEDs & ambient light sensors"),
            ("fans", "Cooling Fans & Thermals", "fanblades.fill", .teal, fansWatts, .physical, String(format: "Active thermal dissipation (%.1f°C)", temperatureCelsius))
        ]
        
        // Apply EMA smoothing to each component (alpha = 0.3) so numbers glide gracefully
        var smoothedList: [(id: String, name: String, icon: String, color: Color, watts: Double, category: ComponentCategory, desc: String)] = []
        for item in rawList {
            let prev = smoothedComponentWatts[item.id] ?? item.watts
            let smoothW = (prev * 0.70) + (item.watts * 0.30)
            smoothedComponentWatts[item.id] = smoothW
            smoothedList.append((item.id, item.name, item.icon, item.color, smoothW, item.category, item.desc))
        }
        
        // Normalize smoothed components within their categories so totals match targetComputeTotal and targetPhysicalTotal exactly
        let smoothedComputeSum = smoothedList.filter { $0.category == .compute }.reduce(0.0) { $0 + $1.watts }
        let smoothedPhysicalSum = smoothedList.filter { $0.category == .physical }.reduce(0.0) { $0 + $1.watts }
        
        let computeNorm = smoothedComputeSum > 0 ? (targetComputeTotal / smoothedComputeSum) : 1.0
        let physicalNorm = smoothedPhysicalSum > 0 ? (targetPhysicalTotal / smoothedPhysicalSum) : 1.0
        
        var shares: [ComponentEnergyShare] = []
        
        for item in smoothedList {
            let normWatts: Double
            if item.category == .compute {
                normWatts = item.watts * computeNorm
            } else {
                normWatts = item.watts * physicalNorm
            }
            
            let shareRatio = watts > 0 ? (normWatts / watts) : 0.0
            let deltaPercent = dischargedPercent * shareRatio
            let deltaMWh = dischargedMWh * shareRatio
            
            cumulativeComponentDrop[item.id] = (cumulativeComponentDrop[item.id] ?? 0.0) + deltaPercent
            cumulativeComponentEnergyMWh[item.id] = (cumulativeComponentEnergyMWh[item.id] ?? 0.0) + deltaMWh
            
            let totalDrop = cumulativeComponentDrop[item.id] ?? 0.0
            
            shares.append(ComponentEnergyShare(
                id: item.id,
                name: item.name,
                iconName: item.icon,
                color: item.color,
                instantWatts: normWatts,
                batteryPercentConsumed: totalDrop,
                sharePercentage: shareRatio * 100.0,
                category: item.category,
                detailDescription: item.desc
            ))
        }
        
        return shares
    }
    
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        cumulativeComponentDrop.removeAll()
        cumulativeComponentEnergyMWh.removeAll()
        smoothedComponentWatts.removeAll()
    }
}
