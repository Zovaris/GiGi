import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetDir = root.appendingPathComponent(".build/GiGi.iconset")
let icnsURL = root.appendingPathComponent("Resources/GiGi.icns")
let brandURL = root.appendingPathComponent("assets/brand/gigi-icon.png")
let previewURL = root.appendingPathComponent(".build/icon-preview.html")
let canvasSize = 1024

func render(size: Int) -> CGImage? {
    let space = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(data: nil, width: size, height: size,
                                  bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    context.setAllowsAntialiasing(true)
    let tile = CGRect(x: 88, y: 88, width: 848, height: 848)
    let outline = CGPath(roundedRect: tile, cornerWidth: 190, cornerHeight: 190, transform: nil)
    context.saveGState()
    context.addPath(outline)
    context.clip()
    let top = CGColor(red: 1.0, green: 0.40, blue: 0.36, alpha: 1)
    let bottom = CGColor(red: 0.91, green: 0.20, blue: 0.29, alpha: 1)
    if let gradient = CGGradient(colorsSpace: space, colors: [bottom, top] as CFArray, locations: [0, 1]) {
        context.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 88),
                                   end: CGPoint(x: 512, y: 936), options: [])
    }
    context.restoreGState()

    context.saveGState()
    context.translateBy(x: 545, y: 520)
    context.rotate(by: .pi / 7)
    let mouse = CGPath(roundedRect: CGRect(x: -158, y: -258, width: 316, height: 516),
                       cornerWidth: 158, cornerHeight: 158, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -14), blur: 22,
                      color: CGColor(red: 0.42, green: 0.06, blue: 0.10, alpha: 0.24))
    context.addPath(mouse)
    context.setFillColor(CGColor(red: 1, green: 0.98, blue: 0.95, alpha: 1))
    context.fillPath()
    context.restoreGState()

    let wheel = CGPath(roundedRect: CGRect(x: -19, y: 92, width: 38, height: 96),
                       cornerWidth: 19, cornerHeight: 19, transform: nil)
    context.addPath(wheel)
    context.setFillColor(CGColor(red: 0.93, green: 0.26, blue: 0.30, alpha: 1))
    context.fillPath()
    context.restoreGState()

    context.setLineCap(.round)
    context.setLineWidth(30)
    context.setStrokeColor(CGColor(red: 1, green: 0.98, blue: 0.95, alpha: 0.85))
    for (start, end) in [(CGPoint(x: 240, y: 430), CGPoint(x: 300, y: 455)),
                         (CGPoint(x: 260, y: 325), CGPoint(x: 340, y: 360))] {
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
    }
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
