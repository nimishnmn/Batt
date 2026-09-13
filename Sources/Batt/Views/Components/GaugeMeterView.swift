import SwiftUI

public struct GaugeMeterView: View {
    public let percentage: Double
    public let isCharging: Bool
    public let dropRatePerHour: Double
    public let size: CGFloat
    
    public init(
        percentage: Double,
        isCharging: Bool,
        dropRatePerHour: Double,
        size: CGFloat = 160
    ) {
        self.percentage = percentage
        self.isCharging = isCharging
        self.dropRatePerHour = dropRatePerHour
        self.size = size
    }
    
    private var progress: Double {
        min(max(percentage / 100.0, 0.0), 1.0)
    }
    
    private var gaugeColor: Color {
        if isCharging {
            return .green
        }
        if percentage > 40 {
            return .green
        } else if percentage > 20 {
            return .orange
        } else {
            return .red
        }
    }
    
    public var body: some View {
        ZStack {
            // Background track
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(
                    Color.secondary.opacity(0.18),
                    style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
            
            // Progress fill
            Circle()
                .trim(from: 0.15, to: 0.15 + (0.70 * progress))
                .stroke(
                    LinearGradient(
                        colors: [gaugeColor.opacity(0.8), gaugeColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: progress)
            
            // Center content
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: isCharging ? "bolt.fill" : "battery.100percent")
                        .foregroundColor(gaugeColor)
                        .font(.system(size: size * 0.12, weight: .bold))
                    
                    if isCharging {
                        Text("CHARGING")
                            .font(.system(size: size * 0.07, weight: .black))
                            .foregroundColor(.green)
                    }
                }
                
                Text(String(format: "%.2f%%", percentage))
                    .font(.system(size: size * 0.20, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                
                if !isCharging && dropRatePerHour > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down.right")
                            .font(.system(size: size * 0.07, weight: .bold))
                            .foregroundColor(.orange)
                        Text(String(format: "-%.2f %%/h", dropRatePerHour))
                            .font(.system(size: size * 0.08, weight: .semibold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                } else if isCharging {
                    Text("Powered")
                        .font(.system(size: size * 0.08, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}
