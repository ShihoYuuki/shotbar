// Resources/AppIcon.icns を描く。  swift scripts/make-icon.swift
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let inset = size * 0.08
let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let shape = NSBezierPath(roundedRect: rect, xRadius: size * 0.21, yRadius: size * 0.21)
NSGradient(colors: [NSColor(calibratedWhite: 0.99, alpha: 1), NSColor(calibratedRed: 0.86, green: 0.89, blue: 0.94, alpha: 1)])!
    .draw(in: shape, angle: -90)
let config = NSImage.SymbolConfiguration(pointSize: size * 0.46, weight: .medium)
if let symbol = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
    let tinted = NSImage(size: symbol.size)
    tinted.lockFocus()
    symbol.draw(in: NSRect(origin: .zero, size: symbol.size))
    NSColor(calibratedRed: 0.13, green: 0.22, blue: 0.40, alpha: 1).set()
    NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
    tinted.unlockFocus()
    let origin = NSPoint(x: (size - symbol.size.width) / 2, y: (size - symbol.size.height) / 2)
    tinted.draw(in: NSRect(origin: origin, size: symbol.size))
}
image.unlockFocus()

let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("ShotBar.iconset")
try? FileManager.default.removeItem(at: tmp)
try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
func write(_ px: Int, _ name: String) {
    let out = NSImage(size: NSSize(width: px, height: px))
    out.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    out.unlockFocus()
    let tiff = out.tiffRepresentation!
    let png = NSBitmapImageRep(data: tiff)!.representation(using: .png, properties: [:])!
    try! png.write(to: tmp.appendingPathComponent(name))
}
for (pt, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    write(pt * scale, scale == 1 ? "icon_\(pt)x\(pt).png" : "icon_\(pt)x\(pt)@2x.png")
}
let dest = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.icns")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", tmp.path, "-o", dest.path]
try! task.run(); task.waitUntilExit()
print(task.terminationStatus == 0 ? "wrote \(dest.path)" : "iconutil failed")
