import AppKit
let target = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: target, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = CGFloat(size) / 1024
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: scale, y: scale)
    let frame = NSRect(x: 74, y: 74, width: 876, height: 876)
    NSColor(calibratedRed: 0.12, green: 0.40, blue: 0.94, alpha: 1).setFill()
    NSBezierPath(roundedRect: frame, xRadius: 194, yRadius: 194).fill()
    NSColor.white.withAlphaComponent(0.13).setFill()
    NSBezierPath(roundedRect: NSRect(x: 220, y: 252, width: 584, height: 545), xRadius: 94, yRadius: 94).fill()
    NSColor.white.setFill()
    let drive = NSBezierPath()
    drive.move(to: NSPoint(x: 310, y: 703)); drive.line(to: NSPoint(x: 714, y: 703))
    drive.line(to: NSPoint(x: 777, y: 412)); drive.line(to: NSPoint(x: 247, y: 412)); drive.close(); drive.fill()
    NSBezierPath(roundedRect: NSRect(x: 247, y: 315, width: 530, height: 114), xRadius: 35, yRadius: 35).fill()
    NSColor(calibratedRed: 0.12, green: 0.40, blue: 0.94, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 306, y: 352, width: 208, height: 22), xRadius: 11, yRadius: 11).fill()
    NSBezierPath(ovalIn: NSRect(x: 681, y: 350, width: 27, height: 27)).fill()
    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    let name: String
    if size == 1024 { name = "icon_512x512@2x.png" }
    else { name = "icon_\(size)x\(size).png" }
    try png.write(to: URL(fileURLWithPath: target).appendingPathComponent(name))
    if [32,64,256,512].contains(size) {
        try png.write(to: URL(fileURLWithPath: target).appendingPathComponent("icon_\(size/2)x\(size/2)@2x.png"))
    }
}
