import AppKit
import Foundation

// Local review aid. Original screenshots and state coordinates remain unchanged.
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let rows = try JSONSerialization.jsonObject(with: Data(contentsOf: input)) as! [[String: Any]]
let cellW = 600, cellH = 500, columns = 4
let height = ((rows.count + columns - 1) / columns) * cellH
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: columns * cellW, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(calibratedWhite: 0.07, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: columns * cellW, height: height)).fill()
for (index, row) in rows.enumerated() {
    let image = NSImage(contentsOfFile: row["path"] as! String)!
    let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    let r = row["crop"] as! [Double]
    let crop = cg.cropping(to: CGRect(x: r[0], y: r[1], width: r[2], height: r[3]).integral)!
    let thumb = NSImage(cgImage: crop, size: NSSize(width: crop.width, height: crop.height))
    let x = Double(index % columns * cellW), y = Double(height - (index / columns + 1) * cellH)
    let scale = min(Double(cellW - 16) / Double(crop.width), Double(cellH - 35) / Double(crop.height))
    thumb.draw(in: NSRect(x: x + 8, y: y + 8, width: Double(crop.width) * scale, height: Double(crop.height) * scale))
    (row["label"] as! NSString).draw(at: NSPoint(x: x + 8, y: y + Double(cellH - 23)), withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), .foregroundColor: NSColor.white])
}
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: output)
