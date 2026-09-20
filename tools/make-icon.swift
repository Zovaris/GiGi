import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetDir = root.appendingPathComponent(".build/GiGi.iconset")
let icnsURL = root.appendingPathComponent("Resources/GiGi.icns")
let brandURL = root.appendingPathComponent("assets/brand/gigi-icon.png")
let previewURL = root.appendingPathComponent(".build/icon-preview.html")
let canvasSize = 1024

let backgroundTop = CGColor(red: 0.51, green: 0.38, blue: 1.00, alpha: 1)
let backgroundBottom = CGColor(red: 0.16, green: 0.09, blue: 0.62, alpha: 1)

func pointerPath(in rect: CGRect) -> CGPath {
    let points: [CGPoint] = [
        CGPoint(x: 0.00, y: 0.02),
        CGPoint(x: 0.00, y: 0.62),
        CGPoint(x: 0.15, y: 0.48),
        CGPoint(x: 0.26, y: 0.72),
        CGPoint(x: 0.38, y: 0.66),
        CGPoint(x: 0.27, y: 0.43),
        CGPoint(x: 0.48, y: 0.41),
    ]
    let path = CGMutablePath()
    for (index, point) in points.enumerated() {
        let mapped = CGPoint(x: rect.minX + point.x * rect.width,
                             y: rect.maxY - point.y * rect.height)
        index == 0 ? path.move(to: mapped) : path.addLine(to: mapped)
    }
    path.closeSubpath()
    return path
}

func motionArc(center: CGPoint, radius: CGFloat, start: CGFloat, end: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
    return path
}

func render(size: Int) -> CGImage? {
    let space = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let side = CGFloat(size) * 0.825
    let squircle = CGRect(x: (CGFloat(size) - side) / 2,
                          y: (CGFloat(size) - side) / 2,
                          width: side,
                          height: side)
    let corner = side * 0.2237
    context.setAllowsAntialiasing(true)
    context.interpolationQuality = .high

    let shape = CGPath(roundedRect: squircle, cornerWidth: corner, cornerHeight: corner, transform: nil)
    context.saveGState()
    context.addPath(shape)
    context.clip()
    if let gradient = CGGradient(colorsSpace: space,
                                 colors: [backgroundTop, backgroundBottom] as CFArray,
                                 locations: [0, 1]) {
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: squircle.minX, y: squircle.maxY),
                                   end: CGPoint(x: squircle.maxX, y: squircle.minY),
                                   options: [])
    }
    if let glow = CGGradient(colorsSpace: space,
                             colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 0.30),
                                      CGColor(red: 1, green: 1, blue: 1, alpha: 0.00)] as CFArray,
                             locations: [0, 1]) {
        let focus = CGPoint(x: squircle.midX, y: squircle.maxY - side * 0.08)
        context.drawRadialGradient(glow,
                                   startCenter: focus, startRadius: 0,
                                   endCenter: focus, endRadius: side * 0.72,
                                   options: [])
    }
    context.restoreGState()

    context.saveGState()
    context.addPath(shape)
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.16))
    context.setLineWidth(max(1, side * 0.012))
    context.strokePath()
    context.restoreGState()

    context.saveGState()
    context.setLineCap(.round)
    let arcCenter = CGPoint(x: squircle.minX + side * 0.36, y: squircle.minY + side * 0.48)
    let boost = size <= 32 ? 1.16 : 1.0
    let arcs: [(CGFloat, CGFloat, CGFloat)] = [(side * 0.21, 0.70, 0.16), (side * 0.32, 0.60, 0.13)]
    for (radius, alpha, width) in arcs {
        context.addPath(motionArc(center: arcCenter,
                                  radius: radius * boost,
                                  start: .pi * 0.78,
                                  end: .pi * 1.28))
        context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: alpha))
        context.setLineWidth(max(1, side * width * 0.17))
        context.strokePath()
    }
    context.restoreGState()

    context.saveGState()
    let pointerBox = CGRect(x: squircle.minX + side * 0.40,
                            y: squircle.minY + side * 0.22,
                            width: side * 0.50 * boost,
                            height: side * 0.58 * boost)
    context.translateBy(x: pointerBox.midX, y: pointerBox.midY)
    context.rotate(by: -0.14)
    context.translateBy(x: -pointerBox.midX, y: -pointerBox.midY)
    context.setShadow(offset: CGSize(width: 0, height: -side * 0.012),
                      blur: side * 0.05,
                      color: CGColor(red: 0.05, green: 0.02, blue: 0.25, alpha: 0.45))
    context.addPath(pointerPath(in: pointerBox))
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fillPath()
    context.restoreGState()

    return context.makeImage()
}

func pngData(_ image: CGImage) -> Data? {
    NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
}

func write(_ data: Data, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
    try data.write(to: url)
}

try? FileManager.default.removeItem(at: iconsetDir)
try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let variants: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

var previewSources: [Int: String] = [:]

for (name, size) in variants {
    guard let image = render(size: size), let data = pngData(image) else {
        FileHandle.standardError.write(Data("cannot render \(name)\n".utf8))
        exit(1)
    }
    try write(data, to: iconsetDir.appendingPathComponent("\(name).png"))
    if [16, 32, 64, 128, 512].contains(size) {
        previewSources[size] = data.base64EncodedString()
    }
    if name == "icon_512x512" {
        try write(data, to: brandURL)
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsURL.path]
try FileManager.default.createDirectory(at: icnsURL.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("iconutil failed\n".utf8))
    exit(1)
}

print("wrote \(icnsURL.path)")
print("wrote \(brandURL.path)")

if CommandLine.arguments.contains("--preview") {
    func img(_ size: Int, _ display: Int) -> String {
        let source = previewSources[size] ?? previewSources[512] ?? ""
        return "<img src=\"data:image/png;base64,\(source)\" width=\"\(display)\" height=\"\(display)\">"
    }
    let html = """
    <!DOCTYPE html>
    <html lang="en"><head><meta charset="utf-8"><title>GiGi icon</title><style>
    body { margin: 0; font: 13px -apple-system, system-ui, sans-serif; color: #eee; background: #1c1c1e; }
    .row { display: flex; align-items: flex-end; gap: 26px; padding: 26px; }
    .light { background: #f2f2f7; color: #1c1c1e; }
    figure { margin: 0; text-align: center; }
    figcaption { margin-top: 8px; opacity: .55; font-size: 11px; }
    img { display: block; }
    </style></head><body>
    <div class="row">
      <figure>\(img(512, 256))<figcaption>256</figcaption></figure>
      <figure>\(img(128, 128))<figcaption>128</figcaption></figure>
      <figure>\(img(64, 64))<figcaption>64</figcaption></figure>
      <figure>\(img(32, 32))<figcaption>32</figcaption></figure>
      <figure>\(img(16, 16))<figcaption>16</figcaption></figure>
    </div>
    <div class="row light">
      <figure>\(img(512, 128))<figcaption>on light</figcaption></figure>
      <figure>\(img(64, 64))<figcaption>64</figcaption></figure>
      <figure>\(img(32, 32))<figcaption>32</figcaption></figure>
      <figure>\(img(16, 16))<figcaption>16</figcaption></figure>
    </div>
    </body></html>
    """
    try write(Data(html.utf8), to: previewURL)
    print("wrote \(previewURL.path)")
}
