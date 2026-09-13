import SwiftUI
import AppKit

public enum EnergyViewMode: String, CaseIterable, Identifiable {
    case all = "All Energy Breakdown"
    case hardware = "Hardware & Physical"
    case apps = "Applications"
    
    public var id: String { rawValue }
}

public struct AppConsumptionView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var settings: SettingsState
    
    @State private var viewMode: EnergyViewMode = .all
    @State private var searchText = ""
    
    public init(appState: AppState, settings: SettingsState) {
        self.appState = appState
        self.settings = settings
    }
    
    private var filteredApps: [AppEnergyRecord] {
        if searchText.isEmpty {
            return appState.appRecords
        } else {
            return appState.appRecords.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    private var totalAppBatteryConsumed: Double {
        appState.appRecords.reduce(0.0) { $0 + $1.batteryPercentConsumed }
    }
    
    private var computeComponents: [ComponentEnergyShare] {
        appState.hardwareShares.filter { $0.category == .compute }
    }
    
    private var physicalComponents: [ComponentEnergyShare] {
        appState.hardwareShares.filter { $0.category == .physical }
    }
    
    private var totalComputeWatts: Double {
        computeComponents.reduce(0.0) { $0 + $1.instantWatts }
    }
    
    private var totalPhysicalWatts: Double {
        physicalComponents.reduce(0.0) { $0 + $1.instantWatts }
    }
    
    private var totalComputeDrop: Double {
        computeComponents.reduce(0.0) { $0 + $1.batteryPercentConsumed }
    }
    
    private var totalPhysicalDrop: Double {
        physicalComponents.reduce(0.0) { $0 + $1.batteryPercentConsumed }
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Header with Segmented Mode Switcher
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apps & Hardware Energy")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Tracks compute silicon power (CPU, GPU, RAM, SSD) and physical peripheral drain (Screen, Fans, Keyboard, Radios).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Picker("", selection: $viewMode) {
                    ForEach(EnergyViewMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 380)
            }
            
            // High-Level Summary Card: Compute vs Physical Power
            VStack(spacing: 12) {
                HStack(spacing: 24) {
                    // Compute Subtotal
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle().fill(Color.blue).frame(width: 10, height: 10)
                            Text("COMPUTE DRAIN (CPU, GPU, RAM, SSD)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(settings.powerUnit.format(watts: totalComputeWatts))
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(.blue)
                            
                            Text(String(format: "(-%.2f%% drop)", totalComputeDrop))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                    
                    // Physical Subtotal
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("PHYSICAL DRAIN (SCREEN, FANS, KBD, RADIOS)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Circle().fill(Color.orange).frame(width: 10, height: 10)
                        }
                        
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(String(format: "(-%.2f%% drop)", totalPhysicalDrop))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                            
                            Text(settings.powerUnit.format(watts: totalPhysicalWatts))
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                // Segmented Stacked Ratio Bar
                let totalWatts = max(0.1, totalComputeWatts + totalPhysicalWatts)
                let computeRatio = totalComputeWatts / totalWatts
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.orange)
                            .frame(width: geo.size.width, height: 8)
                        
                        Capsule()
                            .fill(Color.blue)
                            .frame(width: geo.size.width * CGFloat(computeRatio), height: 8)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Text(String(format: "Compute: %.1f%% of total load", computeRatio * 100.0))
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Spacer()
                    Text(String(format: "Physical: %.1f%% of total load", (1.0 - computeRatio) * 100.0))
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            )
            
            // Section 1: Compute & Hardware Cards
            if viewMode == .all || viewMode == .hardware {
                VStack(alignment: .leading, spacing: 14) {
                    // Compute Subsystem
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "cpu.fill")
                                .foregroundColor(.blue)
                            Text("Compute Silicon Subsystem")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Text("Active SoC Processing")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(computeComponents) { comp in
                                ComponentCardView(comp: comp, settings: settings)
                            }
                        }
                    }
                    
                    // Physical Subsystem
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "display")
                                .foregroundColor(.orange)
                            Text("Physical Hardware & Peripherals")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Text("Illumination & Radios")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(physicalComponents) { comp in
                                ComponentCardView(comp: comp, settings: settings)
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }
            
            // Section 2: Application Breakdown
            if viewMode == .all || viewMode == .apps {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Image(systemName: "app.badge.checkmark")
                                    .foregroundColor(.purple)
                                Text("Active Applications Leaderboard")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                            Text("CPU process time and exact battery % drain attributed to running applications.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Search field
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Filter apps…", text: $searchText)
                                .textFieldStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.8))
                        .cornerRadius(8)
                        .frame(width: 180)
                    }
                    
                    if filteredApps.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "app.dashed")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary)
                            Text("No active app consumption recorded yet.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredApps) { app in
                                AppRowView(
                                    app: app,
                                    maxDrop: appState.appRecords.first?.batteryPercentConsumed ?? 1.0,
                                    settings: settings
                                )
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }
        }
    }
}

private struct ComponentCardView: View {
    let comp: ComponentEnergyShare
    @ObservedObject var settings: SettingsState
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: comp.iconName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(comp.color)
                .frame(width: 32, height: 32)
                .background(comp.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(comp.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(comp.detailDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(settings.powerUnit.format(watts: comp.instantWatts))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 2) {
                    Text(String(format: "-%.2f%%", comp.batteryPercentConsumed))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text(String(format: "(%.0f%%)", comp.sharePercentage))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.8))
        )
    }
}

private struct AppRowView: View {
    let app: AppEnergyRecord
    let maxDrop: Double
    @ObservedObject var settings: SettingsState
    
    private var appIcon: NSImage {
        if let bundleId = app.bundleIdentifier,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .application)
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.body)
                        .fontWeight(.semibold)
                    
                    Text("PID: \(app.pid)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Relative impact bar
                let fraction = maxDrop > 0 ? (app.batteryPercentConsumed / maxDrop) : 0.0
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(geo.size.width * CGFloat(fraction), 4), height: 4)
                    }
                }
                .frame(height: 4)
            }
            
            Spacer()
            
            // Battery drop in exact percentage terms
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.orange)
                    Text(String(format: "-%.2f%%", app.batteryPercentConsumed))
                        .font(.callout)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                
                Text(settings.energyUnit.format(mWh: app.energyConsumedMWh))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 95, alignment: .trailing)
            
            // Instantaneous power attribution
            VStack(alignment: .trailing, spacing: 2) {
                Text(settings.powerUnit.format(watts: app.instantPowerWatts))
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(String(format: "%.1f%% CPU", app.cpuShare * 100.0))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 75, alignment: .trailing)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.7))
        )
    }
}
