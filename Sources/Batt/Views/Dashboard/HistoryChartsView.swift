import SwiftUI
import Charts

public struct HistoryChartsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var settings: SettingsState
    
    @State private var timeRange: TimeRange = .day
    
    public enum TimeRange: String, CaseIterable, Identifiable {
        case day = "24 Hours"
        case week = "7 Days"
        
        public var id: String { rawValue }
        
        public var timeInterval: TimeInterval {
            switch self {
            case .day: return 24 * 3600
            case .week: return 7 * 24 * 3600
            }
        }
    }
    
    public init(appState: AppState, settings: SettingsState) {
        self.appState = appState
        self.settings = settings
    }
    
    private var filteredSnapshots: [BatterySnapshot] {
        let cutoff = Date().addingTimeInterval(-timeRange.timeInterval)
        return HistoryStore.shared.getSnapshots(since: cutoff)
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header & Time Range Picker
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Historical Battery Analytics")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Uninflated raw percentage logs and discharge rates stored for up to 7 days.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Picker("Time Range", selection: $timeRange) {
                        ForEach(TimeRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                
                // Chart 1: True Battery Percentage Curve
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("True Battery Chemistry (%) Over Time")
                                .font(.headline)
                            Text("Plots actual uninflated raw capacity percentage over time.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Circle().fill(Color.green).frame(width: 8, height: 8)
                                Text("Charging").font(.caption2).foregroundColor(.secondary)
                            }
                            HStack(spacing: 4) {
                                Circle().fill(Color.blue).frame(width: 8, height: 8)
                                Text("Discharging").font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    let snaps = filteredSnapshots
                    if snaps.count >= 2 {
                        Chart {
                            ForEach(snaps) { snap in
                                LineMark(
                                    x: .value("Time", snap.timestamp),
                                    y: .value("Percentage", snap.rawPercentage)
                                )
                                .foregroundStyle(Color.blue.gradient)
                                .interpolationMethod(.catmullRom)
                                
                                AreaMark(
                                    x: .value("Time", snap.timestamp),
                                    yStart: .value("Min", 0),
                                    yEnd: .value("Percentage", snap.rawPercentage)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.25), Color.blue.opacity(0.01)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            }
                        }
                        .chartYScale(domain: 0...100)
                        .chartYAxis {
                            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let intVal = value.as(Int.self) {
                                        Text("\(intVal)%")
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks { value in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.hour().minute())
                            }
                        }
                        .frame(height: 200)
                    } else {
                        VStack {
                            Spacer()
                            Text("Collecting history points… (Snapshots logged every \(Int(settings.samplingInterval))s)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                
                // Daily Summaries Table
                VStack(alignment: .leading, spacing: 12) {
                    Text("Daily Battery Drop Summary (Last 7 Days)")
                        .font(.headline)
                    
                    let summaries = appState.dailySummaries
                    if summaries.isEmpty {
                        Text("No multi-day history recorded yet.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Date").font(.caption).fontWeight(.bold).frame(width: 110, alignment: .leading)
                                Text("Total Battery Drop").font(.caption).fontWeight(.bold).frame(width: 130, alignment: .trailing)
                                Text("Avg Discharge Power").font(.caption).fontWeight(.bold).frame(width: 130, alignment: .trailing)
                                Text("Peak Power Draw").font(.caption).fontWeight(.bold).frame(width: 130, alignment: .trailing)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            
                            Divider()
                            
                            ForEach(summaries) { day in
                                HStack {
                                    Text(day.dateString)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .frame(width: 110, alignment: .leading)
                                    
                                    Text(String(format: "-%.2f%%", day.totalPercentDrop))
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.orange)
                                        .frame(width: 130, alignment: .trailing)
                                    
                                    Text(settings.powerUnit.format(watts: day.averageDischargeWatts))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .frame(width: 130, alignment: .trailing)
                                    
                                    Text(settings.powerUnit.format(watts: day.peakDischargeWatts))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(day.peakDischargeWatts > 18 ? .red : .primary)
                                        .frame(width: 130, alignment: .trailing)
                                    
                                    Spacer()
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                                )
                            }
                        }
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                
                // Storage footnote
                HStack {
                    Text("Local Database: \(HistoryStore.shared.getStorageSizeFormatted()) · Automatically pruned after 7 days")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
        }
    }
}
