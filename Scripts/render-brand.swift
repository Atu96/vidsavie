import AppKit

// Reproducible code-native artwork; no fonts or external artwork dependencies.
let root = URL(fileURLWithPath: CommandLine.arguments[1])
func path(_ points: [(CGFloat, CGFloat)], close: Bool = false) -> NSBezierPath {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: points[0].0, y: points[0].1))
    for point in points.dropFirst() { p.line(to: NSPoint(x: point.0, y: point.1)) }
    if close { p.close() }
    return p
}
func render(size: Int, menu: Bool = false, companion: Bool = false, to destination: URL) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    if !menu {
        let tile = companion
            ? NSBezierPath(roundedRect: NSRect(x: 16, y: 16, width: 992, height: 992), xRadius: 96, yRadius: 96)
            : NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 204, yRadius: 204)
        NSGradient(starting: NSColor(calibratedRed: 0.08, green: 0.17, blue: 0.34, alpha: 1),
                   ending: NSColor(calibratedRed: 0.025, green: 0.055, blue: 0.13, alpha: 1))!.draw(in: tile, angle: -90)
        NSColor(calibratedWhite: 1, alpha: 0.12).setStroke(); tile.lineWidth = 4; tile.stroke()
    }
    // Tall film strip: true cut-out sprocket holes and a centered lightning mark.
    let frame = NSBezierPath(roundedRect: NSRect(x: 244, y: 176, width: 536, height: 672), xRadius: 54, yRadius: 54)
    frame.windingRule = .evenOdd
    frame.append(NSBezierPath(roundedRect: NSRect(x: 344, y: 224, width: 336, height: 576), xRadius: 20, yRadius: 20))
    let holePositions: [CGFloat] = menu ? [272, 472, 672] : [248, 358, 468, 578, 688]
    for x: CGFloat in [268, 704] {
        for y in holePositions {
            frame.append(NSBezierPath(roundedRect: NSRect(x: x, y: y, width: 52, height: menu ? 80 : 60), xRadius: 10, yRadius: 10))
        }
    }
    let bolt = menu || companion
        ? path([(614, 824), (322, 477), (500, 477), (413, 200), (716, 555), (540, 555)], close: true)
        : path([(588, 742), (405, 493), (516, 493), (442, 282), (627, 531), (514, 531)], close: true)
    if menu {
        let ring = NSBezierPath()
        ring.appendArc(withCenter: NSPoint(x: 512, y: 512), radius: 386, startAngle: -52, endAngle: 232)
        NSColor.black.setStroke(); ring.lineWidth = 60; ring.lineCapStyle = .round; ring.stroke()
        let tray = path([(342, 114), (682, 114)])
        tray.lineWidth = 60; tray.lineCapStyle = .round; tray.stroke()
        let fit = NSAffineTransform()
        fit.translateX(by: 512, yBy: 512); fit.scale(by: 0.85); fit.translateX(by: -512, yBy: -512)
        bolt.transform(using: fit as AffineTransform)
        NSColor.black.setFill(); bolt.fill()
    } else {
        NSColor(calibratedWhite: 1, alpha: 0.94).setFill()
        if companion {
            let edge = NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 56, yRadius: 56)
            edge.windingRule = .evenOdd
            edge.append(NSBezierPath(roundedRect: NSRect(x: 202, y: 114, width: 620, height: 796), xRadius: 20, yRadius: 20))
            let rows: [CGFloat] = size <= 32 ? [180, 448, 716] : [148, 298, 448, 598, 748]
            for x: CGFloat in [80, 872] {
                for y in rows {
                    edge.append(NSBezierPath(roundedRect: NSRect(x: x, y: y, width: 72, height: size <= 32 ? 128 : 98), xRadius: 10, yRadius: 10))
                }
            }
            edge.fill()
        } else { frame.fill() }
        NSGradient(starting: NSColor(calibratedRed: 0.24, green: 0.80, blue: 1, alpha: 1),
                   ending: NSColor(calibratedRed: 0.92, green: 0.98, blue: 1, alpha: 1))!.draw(in: bolt, angle: 90)
    }
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: destination)
}
let resources = root.appendingPathComponent("Resources")
try render(size: 1024, to: resources.appendingPathComponent("AppIcon-1024.png"))
try render(size: 72, menu: true, to: resources.appendingPathComponent("MenuBarIcon.png"))
for (name, size) in [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024)] {
    try render(size: size, to: resources.appendingPathComponent("AppIcon.iconset/\(name).png"))
}
for size in [16,32,48,128,1024] {
    try render(size: size, companion: true, to: root.appendingPathComponent("ChromeExtension/icons/icon-\(size).png"))
}
