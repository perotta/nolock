import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func drawIcon(size: Int, filename: String) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = CGFloat(size) / 1024
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: scale, y: scale)
    let tile = NSBezierPath(roundedRect: NSRect(x: 68, y: 68, width: 888, height: 888), xRadius: 198, yRadius: 198)
    NSGradient(starting: NSColor(red: 0.13, green: 0.18, blue: 0.22, alpha: 1),
               ending: NSColor(red: 0.04, green: 0.07, blue: 0.10, alpha: 1))!.draw(in: tile, angle: -60)
    let mint = NSColor(red: 0.43, green: 0.91, blue: 0.70, alpha: 1)
    mint.setStroke()
    for inset in [0.0, 86.0] {
        let arc = NSBezierPath()
        arc.appendArc(withCenter: NSPoint(x: 530, y: 526), radius: 294 - inset, startAngle: -14, endAngle: 110)
        arc.lineWidth = 31
        arc.lineCapStyle = .round
        arc.stroke()
    }
    let cursor = NSBezierPath()
    cursor.move(to: NSPoint(x: 300, y: 758))
    cursor.line(to: NSPoint(x: 316, y: 283))
    cursor.line(to: NSPoint(x: 447, y: 414))
    cursor.line(to: NSPoint(x: 544, y: 210))
    cursor.line(to: NSPoint(x: 635, y: 254))
    cursor.line(to: NSPoint(x: 538, y: 459))
    cursor.line(to: NSPoint(x: 722, y: 473))
    cursor.close()
    NSColor.white.setFill()
    cursor.fill()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(filename))
}

for base in [16, 32, 128, 256, 512] {
    try drawIcon(size: base, filename: "icon_\(base)x\(base).png")
    try drawIcon(size: base * 2, filename: "icon_\(base)x\(base)@2x.png")
}
