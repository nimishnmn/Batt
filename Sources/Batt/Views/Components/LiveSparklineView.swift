import SwiftUI

public struct LiveSparklineView: View {
    public let points: [LiveDropPoint]
    public let showWatts: Bool
    
    public init(points: [LiveDropPoint], showWatts: Bool = false) {
        self.points = points
        self.showWatts = showWatts
    }
    
    private var values: [Double] {
        if points.isEmpty { return [0] }
        return points.map { showWatts ? $0.dischargeWatts : $0.dropRatePerHour }
    }
    
    private var minValue: Double {
        0.0
    }
    
    private var maxValue: Double {
        let mx = values.max() ?? 10.0
        return max(mx * 1.15, 12.0)
    }
    
    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            if points.count >= 2 {
                ZStack {
                    // Fill gradient under curve
                    Path { path in
                        let stepX = w / CGFloat(max(points.count - 1, 1))
                        path.move(to: CGPoint(x: 0, y: h))
                        
                        for (index, val) in values.enumerated() {
                            let normY = (val - minValue) / max((maxValue - minValue), 1.0)
                            let y = h - CGFloat(normY) * h
                            let x = CGFloat(index) * stepX
                            if index == 0 {
                                path.addLine(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        path.addLine(to: CGPoint(x: CGFloat(values.count - 1) * stepX, y: h))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.35), Color.orange.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Sparkline stroke
                    Path { path in
                        let stepX = w / CGFloat(max(points.count - 1, 1))
                        for (index, val) in values.enumerated() {
                            let normY = (val - minValue) / max((maxValue - minValue), 1.0)
                            let y = h - CGFloat(normY) * h
                            let x = CGFloat(index) * stepX
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        Color.orange,
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                    )
                    
                    // Current head point
                    if let lastVal = values.last {
                        let stepX = w / CGFloat(max(points.count - 1, 1))
                        let lastX = CGFloat(values.count - 1) * stepX
                        let normY = (lastVal - minValue) / max((maxValue - minValue), 1.0)
                        let lastY = h - CGFloat(normY) * h
                        
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                            .position(x: lastX, y: lastY)
                            .shadow(color: .orange.opacity(0.8), radius: 4)
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Text("Sampling real-time drop rate…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
