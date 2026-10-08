import AppKit

func createIcon() {
    let size = CGSize(width: 1024, height: 1024)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let cg = context.cgContext

    // Background transparent
    cg.clear(CGRect(origin: .zero, size: size))

    // macOS Apple Icon Squircle: 824x824 placed at center (100, 100)
    let squircleRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let cornerRadius: CGFloat = 185
    let path = NSBezierPath(roundedRect: squircleRect, xRadius: cornerRadius, yRadius: cornerRadius)

    // Shadow
    cg.saveGState()
    let shadowColor = NSColor.black.withAlphaComponent(0.35).cgColor
    cg.setShadow(offset: CGSize(width: 0, height: -20), blur: 40, color: shadowColor)
    NSColor.black.setFill()
    path.fill()
    cg.restoreGState()

    // Base Gradient
    cg.saveGState()
    path.addClip()
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        NSColor(red: 1.0, green: 0.22, blue: 0.32, alpha: 1.0).cgColor,  // Vibrant Apple Coral Red
        NSColor(red: 0.88, green: 0.05, blue: 0.15, alpha: 1.0).cgColor,  // Rich YouTube Red
        NSColor(red: 0.65, green: 0.02, blue: 0.10, alpha: 1.0).cgColor   // Deep Burgundy
    ] as CFArray
    let locations: [CGFloat] = [0.0, 0.55, 1.0]
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations)!
    cg.drawLinearGradient(
        gradient,
        start: CGPoint(x: 512, y: 924),
        end: CGPoint(x: 512, y: 100),
        options: []
    )

    // Inner subtle glow
    let borderPath = NSBezierPath(roundedRect: squircleRect.insetBy(dx: 2, dy: 2), xRadius: cornerRadius - 2, yRadius: cornerRadius - 2)
    NSColor.white.withAlphaComponent(0.25).setStroke()
    borderPath.lineWidth = 3
    borderPath.stroke()
    cg.restoreGState()

    // Center Emblem: Video Plate with Play & Down Arrow
    // White Card inside squircle
    let emblemRect = CGRect(x: 260, y: 260, width: 504, height: 504)
    let emblemPath = NSBezierPath(roundedRect: emblemRect, xRadius: 100, yRadius: 100)

    cg.saveGState()
    let innerShadow = NSColor.black.withAlphaComponent(0.2).cgColor
    cg.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: innerShadow)
    NSColor.white.withAlphaComponent(0.18).setFill()
    emblemPath.fill()
    cg.restoreGState()

    // Downward Download Arrow + Tray Geometry
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -8), blur: 16, color: NSColor.black.withAlphaComponent(0.3).cgColor)

    // Arrow Stem & Head
    let arrowPath = NSBezierPath()
    // Arrow pointing down:
    // Top of arrow stem: x=472 to 552, y=660 to 480
    // Arrow head: x=380, y=480 down to x=512, y=340 up to x=644, y=480
    arrowPath.move(to: NSPoint(x: 468, y: 660))
    arrowPath.line(to: NSPoint(x: 556, y: 660))
    arrowPath.line(to: NSPoint(x: 556, y: 490))
    arrowPath.line(to: NSPoint(x: 636, y: 490))
    arrowPath.line(to: NSPoint(x: 512, y: 350)) // tip
    arrowPath.line(to: NSPoint(x: 388, y: 490))
    arrowPath.line(to: NSPoint(x: 468, y: 490))
    arrowPath.close()

    NSColor.white.setFill()
    arrowPath.fill()

    // Tray horizontal bar underneath
    let trayRect = CGRect(x: 370, y: 290, width: 284, height: 36)
    let trayPath = NSBezierPath(roundedRect: trayRect, xRadius: 18, yRadius: 18)
    trayPath.fill()

    cg.restoreGState()

    NSGraphicsContext.restoreGraphicsState()

    let pngData = rep.representation(using: .png, properties: [:])!
    let iconsetDir = "ClipFlow.iconset"
    try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

    let masterPath = "\(iconsetDir)/icon_512x512@2x.png"
    try! pngData.write(to: URL(fileURLWithPath: masterPath))

    // Generate iconset variants
    let sizes = [16, 32, 128, 256, 512]
    for s in sizes {
        // 1x
        let file1x = "\(iconsetDir)/icon_\(s)x\(s).png"
        let p1 = Process()
        p1.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        p1.arguments = ["-z", "\(s)", "\(s)", masterPath, "--out", file1x]
        try? p1.run()
        p1.waitUntilExit()

        // 2x
        let s2 = s * 2
        let file2x = "\(iconsetDir)/icon_\(s)x\(s)@2x.png"
        let p2 = Process()
        p2.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        p2.arguments = ["-z", "\(s2)", "\(s2)", masterPath, "--out", file2x]
        try? p2.run()
        p2.waitUntilExit()
    }

    // Convert iconset to icns
    let icnsProcess = Process()
    icnsProcess.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    icnsProcess.arguments = ["-c", "icns", iconsetDir, "-o", "AppIcon.icns"]
    try? icnsProcess.run()
    icnsProcess.waitUntilExit()

    print("Successfully generated AppIcon.icns")
}

createIcon()
