import AppKit
import Foundation

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let canvasSize = NSSize(width: 1024, height: 1024)
let image = NSImage(size: canvasSize)

image.lockFocus()
let rect = NSRect(origin: .zero, size: canvasSize)

let maroonTop = NSColor(calibratedRed: 0.42, green: 0.05, blue: 0.12, alpha: 1.0)
let maroonBottom = NSColor(calibratedRed: 0.12, green: 0.02, blue: 0.04, alpha: 1.0)
let backgroundGradient = NSGradient(starting: maroonTop, ending: maroonBottom)!
backgroundGradient.draw(in: NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220), angle: -45)

let frameRect = rect.insetBy(dx: 44, dy: 44)
let framePath = NSBezierPath(roundedRect: frameRect, xRadius: 186, yRadius: 186)
framePath.lineWidth = 14
NSColor(calibratedRed: 0.98, green: 0.93, blue: 0.84, alpha: 0.55).setStroke()
framePath.stroke()

let formerAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 78, weight: .black),
    .foregroundColor: NSColor(calibratedRed: 0.97, green: 0.93, blue: 0.85, alpha: 1.0),
    .kern: 8.0
]
let formerText = NSAttributedString(string: "FORMER", attributes: formerAttributes)
let formerSize = formerText.size()
formerText.draw(at: NSPoint(x: (1024 - formerSize.width) / 2, y: 786))

let bulldogsAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 88, weight: .black),
    .foregroundColor: NSColor(calibratedRed: 0.97, green: 0.93, blue: 0.85, alpha: 1.0),
    .kern: 6.0
]
let bulldogsText = NSAttributedString(string: "BULLDOGS", attributes: bulldogsAttributes)
let bulldogsSize = bulldogsText.size()
bulldogsText.draw(at: NSPoint(x: (1024 - bulldogsSize.width) / 2, y: 102))

NSGraphicsContext.current?.shouldAntialias = true

NSColor(calibratedRed: 0.94, green: 0.89, blue: 0.80, alpha: 1.0).setFill()
let outerDiamond = NSBezierPath()
outerDiamond.move(to: NSPoint(x: 512, y: 748))
outerDiamond.line(to: NSPoint(x: 772, y: 512))
outerDiamond.line(to: NSPoint(x: 512, y: 252))
outerDiamond.line(to: NSPoint(x: 252, y: 512))
outerDiamond.close()
outerDiamond.fill()

NSColor(calibratedRed: 0.51, green: 0.31, blue: 0.14, alpha: 1.0).setFill()
let infield = NSBezierPath()
infield.move(to: NSPoint(x: 512, y: 714))
infield.line(to: NSPoint(x: 714, y: 512))
infield.line(to: NSPoint(x: 512, y: 310))
infield.line(to: NSPoint(x: 310, y: 512))
infield.close()
infield.fill()

NSColor(calibratedRed: 0.18, green: 0.60, blue: 0.26, alpha: 1.0).setFill()
let grass = NSBezierPath()
grass.move(to: NSPoint(x: 512, y: 668))
grass.line(to: NSPoint(x: 668, y: 512))
grass.line(to: NSPoint(x: 512, y: 356))
grass.line(to: NSPoint(x: 356, y: 512))
grass.close()
grass.fill()

let chalk = NSBezierPath()
chalk.lineWidth = 22
NSColor(calibratedRed: 0.99, green: 0.96, blue: 0.90, alpha: 1.0).setStroke()
chalk.move(to: NSPoint(x: 512, y: 714))
chalk.line(to: NSPoint(x: 512, y: 310))
chalk.move(to: NSPoint(x: 310, y: 512))
chalk.line(to: NSPoint(x: 714, y: 512))
chalk.stroke()

func drawBase(center: NSPoint) {
    let size: CGFloat = 46
    let base = NSBezierPath()
    base.move(to: NSPoint(x: center.x, y: center.y + size))
    base.line(to: NSPoint(x: center.x + size, y: center.y))
    base.line(to: NSPoint(x: center.x, y: center.y - size))
    base.line(to: NSPoint(x: center.x - size, y: center.y))
    base.close()
    NSColor(calibratedRed: 1.0, green: 0.97, blue: 0.92, alpha: 1.0).setFill()
    base.fill()
}

drawBase(center: NSPoint(x: 512, y: 748))
drawBase(center: NSPoint(x: 748, y: 512))
drawBase(center: NSPoint(x: 512, y: 276))
drawBase(center: NSPoint(x: 276, y: 512))

let mound = NSBezierPath(ovalIn: NSRect(x: 478, y: 478, width: 68, height: 68))
NSColor(calibratedRed: 1.0, green: 0.97, blue: 0.92, alpha: 1.0).setFill()
mound.fill()

image.unlockFocus()

func writePNG(from sourceImage: NSImage, size: Int, to url: URL) throws {
    let targetRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    targetRep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: targetRep)
    sourceImage.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: rect,
        operation: .copy,
        fraction: 1.0
    )
    NSGraphicsContext.restoreGraphicsState()

    let data = targetRep.representation(using: .png, properties: [:])!
    try data.write(to: url)
}

let fileNames = [
    "icon-20@2x.png": 40,
    "icon-20@3x.png": 60,
    "icon-29@2x.png": 58,
    "icon-29@3x.png": 87,
    "icon-40@2x.png": 80,
    "icon-40@3x.png": 120,
    "icon-60@2x.png": 120,
    "icon-60@3x.png": 180,
    "icon-20~ipad.png": 20,
    "icon-20@2x~ipad.png": 40,
    "icon-29~ipad.png": 29,
    "icon-29@2x~ipad.png": 58,
    "icon-40~ipad.png": 40,
    "icon-40@2x~ipad.png": 80,
    "icon-76~ipad.png": 76,
    "icon-76@2x~ipad.png": 152,
    "icon-83.5@2x~ipad.png": 167,
    "icon-1024.png": 1024
]

for (name, pixelSize) in fileNames {
    try writePNG(from: image, size: pixelSize, to: outputDirectory.appendingPathComponent(name))
}
