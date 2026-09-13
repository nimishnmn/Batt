import SwiftUI

public enum NavigationSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case apps = "Apps & Energy"
    case history = "7-Day History"
    case alerts = "Drop Alerts"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .overview: return "battery.100percent"
        case .apps: return "app.badge.checkmark"
        case .history: return "chart.xyaxis.line"
        case .alerts: return "exclamationmark.triangle.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

public struct DashboardView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var settings: SettingsState
    
    @State private var selectedSection: NavigationSection = .overview
    
    public init(appState: AppState, settings: SettingsState) {
        self.appState = appState
        self.settings = settings
    }
    
    public var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 6) {
                // Sidebar items with FULL hit box coverage to entire left bar width
                ForEach(NavigationSection.allCases) { section in
                    Button(action: {
                        selectedSection = section
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: section.iconName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(sectionColor(section))
                                .frame(width: 22)
                            
                            Text(section.rawValue)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(selectedSection == section ? .primary : .secondary)
                            
                            Spacer()
                            
                            if section == .alerts && !appState.recentAlerts.isEmpty {
                                Text("\(appState.recentAlerts.count)")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle()) // Makes entire width clickable!
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selectedSection == section ? Color(nsColor: .quaternaryLabelColor).opacity(0.95) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Sidebar Footer with Monitoring Status
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                        .padding(.bottom, 4)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.isLiveInspectorActive ? Color.red : Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text(appState.isLiveInspectorActive ? "Live (1s inspection)" : "Monitoring (10s)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 10)
            .padding(.top, 14)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)
        } detail: {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top alert banner if spike active
                    if let alert = appState.activeAlertBanner {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(String(
                                format: "⚠️ High discharge spike: %.1f W (%.1f%%/hr) at %.2f%% battery!",
                                alert.dischargeWatts,
                                alert.dropRatePerHour,
                                alert.batteryPercentage
                            ))
                            .font(.callout)
                            .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Button("Dismiss") {
                                appState.dismissAlertBanner()
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.15))
                    }
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            switch selectedSection {
                            case .overview:
                                BatteryGaugeCard(appState: appState, settings: settings)
                                
                            case .apps:
                                AppConsumptionView(appState: appState, settings: settings)
                                
                            case .history:
                                HistoryChartsView(appState: appState, settings: settings)
                                
                            case .alerts:
                                AlertsView(appState: appState, settings: settings)
                                
                            case .settings:
                                SettingsView(settings: settings, appState: appState)
                            }
                        }
                        .padding(24)
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    // Precision live rate button with flawless hover and no text-overlap glitch
                    ToolbarLiveRateItem(appState: appState, settings: settings)
                    
                    Button(action: {
                        appState.refreshNow()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh battery telemetry now")
                }
            }
        }
        .frame(minWidth: 880, minHeight: 620)
        .preferredColorScheme(settings.theme.colorScheme)
    }
    
    private func sectionColor(_ section: NavigationSection) -> Color {
        switch section {
        case .overview: return .green
        case .apps: return .blue
        case .history: return .purple
        case .alerts: return .red
        case .settings: return .gray
        }
    }
}

/// Dynamic toolbar live rate item:
/// Fixes animation glitch: uses crisp state change without text-on-text overlapping.
public struct ToolbarLiveRateItem: View {
    @ObservedObject var appState: AppState
    @ObservedObject var settings: SettingsState
    @State private var isHovering = false
    @State private var pulse = false
    
    public init(appState: AppState, settings: SettingsState) {
        self.appState = appState
        self.settings = settings
    }
    
    public var body: some View {
        if appState.isLiveInspectorActive {
            Button(action: {
                appState.isLiveInspectorActive = false
            }) {
                ZStack {
                    if isHovering {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 13, weight: .bold))
                            
                            Text("Stop Live")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.red)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .opacity(pulse ? 1.0 : 0.3)
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                                .onAppear { pulse = true }
                            
                            if let snap = appState.currentSnapshot {
                                if snap.isCharging {
                                    Text(String(format: "+%.1fW", abs(snap.instantPowerWatts)))
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.green)
                                } else {
                                    Text(String(format: "-%.2f %%/h", snap.instantDropRatePerHour))
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.orange)
                                }
                            } else {
                                Text("Sampling…")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovering ? Color.red.opacity(0.18) : Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(isHovering ? Color.red.opacity(0.5) : Color.orange.opacity(0.4), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovering = hovering
            }
            .animation(nil, value: isHovering) // Disables cross-fade to eliminate the text-overlap bug!
            .help("Click to stop live rate inspection")
        } else {
            Button(action: {
                appState.isLiveInspectorActive = true
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    Text("Live Rate")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .help("Inspect instantaneous live battery drop rate")
        }
    }
}
