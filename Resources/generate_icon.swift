import Cocoa

let size = 1024
let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: image)
let context = NSGraphicsContext.current!.cgContext
context.setFillColor(NSColor(red: 0.067, green: 0.094, blue: 0.153, alpha: 1).cgColor)
context.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
context.setFillColor(NSColor.white.cgColor)
context.fillEllipse(in: CGRect(x: 112, y: 112, width: 800, height: 800))
context.setFillColor(NSColor(red: 0.055, green: 0.647, blue: 0.914, alpha: 1).cgColor)
context.fillEllipse(in: CGRect(x: 240, y: 240, width: 544, height: 544))
context.setFillColor(NSColor(red: 0.067, green: 0.094, blue: 0.153, alpha: 1).cgColor)
context.fillEllipse(in: CGRect(x: 330, y: 330, width: 364, height: 364))
context.setFillColor(NSColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1).cgColor)
context.fillEllipse(in: CGRect(x: 462, y: 462, width: 100, height: 100))
context.setStrokeColor(NSColor(red: 0.961, green: 0.620, blue: 0.043, alpha: 1).cgColor)
context.setLineWidth(44)
context.setLineCap(.round)
context.move(to: CGPoint(x: 512, y: 512))
context.addLine(to: CGPoint(x: 730, y: 294))
context.strokePath()
NSGraphicsContext.restoreGraphicsState()
let png = image.representation(using: .png, properties: [:])!
try? png.write(to: URL(fileURLWithPath: "Resources/icon-1024.png"))
