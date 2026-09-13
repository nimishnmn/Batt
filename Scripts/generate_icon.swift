import AppKit

func generateIcon() {
    let size = NSSize(width: 1024, height: 1024)
    let image = NSImage(size: size)
    
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    
    // Background rounded squircle
    let rect = CGRect(x: 40, y: 40, width: 944, height: 944)
    let bgPath = CGPath(roundedRect: rect, cornerWidth: 210, cornerHeight: 210, transform: nil)
    
    // Gradient dark slate background
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        CGColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1.0),
        CGColor(red: 0.03, green: 0.04, blue: 0.06, alpha: 1.0)
    ] as CFArray
    let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0])!
    
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    ctx.drawLinearGradient(bgGradient, start: CGPoint(x: 512, y: 984), end: CGPoint(x: 512, y: 40), options: [])
    ctx.restoreGState()
    
    // Subtle border
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.setStrokeColor(CGColor(red: 0.2, green: 0.25, blue: 0.35, alpha: 0.5))
    ctx.setLineWidth(10)
    ctx.strokePath()
    ctx.restoreGState()
    
    // Outer battery body
    let battWidth: CGFloat = 460
    let battHeight: CGFloat = 260
    let battX: CGFloat = (1024 - battWidth) / 2
    let battY: CGFloat = (1024 - battHeight) / 2
    
    let battRect = CGRect(x: battX, y: battY, width: battWidth, height: battHeight)
    let battPath = CGPath(roundedRect: battRect, cornerWidth: 36, cornerHeight: 36, transform: nil)
    
    ctx.saveGState()
    ctx.addPath(battPath)
    ctx.setStrokeColor(CGColor(red: 0.3, green: 0.85, blue: 0.65, alpha: 0.9))
    ctx.setLineWidth(22)
    ctx.strokePath()
    ctx.restoreGState()
    
    // Battery terminal nipple on the right
    let capWidth: CGFloat = 28
    let capHeight: CGFloat = 110
    let capX = battX + battWidth + 6
    let capY = battY + (battHeight - capHeight) / 2
    let capRect = CGRect(x: capX, y: capY, width: capWidth, height: capHeight)
    let capPath = CGPath(roundedRect: capRect, cornerWidth: 14, cornerHeight: 14, transform: nil)
    
    ctx.saveGState()
    ctx.addPath(capPath)
    ctx.setFillColor(CGColor(red: 0.3, green: 0.85, blue: 0.65, alpha: 0.9))
    ctx.fillPath()
    ctx.restoreGState()
    
    // Battery charge fill levels (3 segments)
    let segCount = 3
    let segSpacing: CGFloat = 16
    let totalSpacing = CGFloat(segCount - 1) * segSpacing
    let segWidth = (battWidth - 60 - totalSpacing) / CGFloat(segCount)
    let segHeight = battHeight - 56
    
    for i in 0..<segCount {
        let sx = battX + 28 + CGFloat(i) * (segWidth + segSpacing)
        let sy = battY + 28
        let srect = CGRect(x: sx, y: sy, width: segWidth, height: segHeight)
        let spath = CGPath(roundedRect: srect, cornerWidth: 16, cornerHeight: 16, transform: nil)
        
        ctx.saveGState()
        ctx.addPath(spath)
        let segGradient = CGGradient(colorsSpace: colorSpace, colors: [
            CGColor(red: 0.2, green: 0.88, blue: 0.6, alpha: 0.85),
            CGColor(red: 0.1, green: 0.72, blue: 0.45, alpha: 0.95)
        ] as CFArray, locations: [0.0, 1.0])!
        ctx.clip()
        ctx.drawLinearGradient(segGradient, start: CGPoint(x: sx, y: sy + segHeight), end: CGPoint(x: sx, y: sy), options: [])
        ctx.restoreGState()
    }
    
    // Dynamic lightning bolt overlay in center
    let boltPath = CGMutablePath()
    boltPath.move(to: CGPoint(x: 535, y: 690))
    boltPath.addLine(to: CGPoint(x: 465, y: 520))
    boltPath.addLine(to: CGPoint(x: 525, y: 520))
    boltPath.addLine(to: CGPoint(x: 485, y: 350))
    boltPath.addLine(to: CGPoint(x: 575, y: 505))
    boltPath.addLine(to: CGPoint(x: 515, y: 505))
    boltPath.closeSubpath()
    
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 4), blur: 20, color: CGColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 0.8))
    ctx.addPath(boltPath)
    ctx.setFillColor(CGColor(red: 1.0, green: 0.92, blue: 0.25, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()
    
    image.unlockFocus()
    
    // Save to AppIcon.iconset
    let fileManager = FileManager.default
    let iconsetURL = URL(fileURLWithPath: "Resources/AppIcon.iconset")
    try? fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
    
    let sizes = [16, 32, 64, 128, 256, 512, 1024]
    for s in sizes {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: s,
            pixelsHigh: s,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: s, height: s))
        NSGraphicsContext.restoreGraphicsState()
        
        if let pngData = rep.representation(using: .png, properties: [:]) {
            let name = (s == 1024) ? "icon_512x512@2x.png" : "icon_\(s)x\(s).png"
            let target = iconsetURL.appendingPathComponent(name)
            try? pngData.write(to: target)
            
            if s <= 512 {
                let name2x = "icon_\(s/2)x\(s/2)@2x.png"
                let target2x = iconsetURL.appendingPathComponent(name2x)
                try? pngData.write(to: target2x)
            }
        }
    }
}

generateIcon()
