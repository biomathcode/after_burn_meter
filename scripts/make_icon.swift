import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = root.appendingPathComponent("build/AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor(calibratedRed: 0.10, green: 0.17, blue: 0.23, alpha: 1).setFill()
        let inset = CGFloat(pixels) * 0.045
        NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: CGFloat(pixels) - inset*2,
            height: CGFloat(pixels) - inset*2), xRadius: CGFloat(pixels)*0.22,
            yRadius: CGFloat(pixels)*0.22).fill()
        let configuration = NSImage.SymbolConfiguration(pointSize: CGFloat(pixels)*0.55, weight: .medium)
            .applying(.init(paletteColors: [NSColor(calibratedRed: 0.98, green: 0.50, blue: 0.28, alpha: 1)]))
        let flame = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: nil)!
            .withSymbolConfiguration(configuration)!
        flame.draw(in: NSRect(x: CGFloat(pixels)*0.27, y: CGFloat(pixels)*0.21,
            width: CGFloat(pixels)*0.46, height: CGFloat(pixels)*0.61))
        NSGraphicsContext.restoreGraphicsState()
        let filename = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(filename))
    }
}
