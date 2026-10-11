// Renders the app icon: swift Icon/make_icon.swift Icon/icon_1024.png
import AppKit
import CoreGraphics

let S: CGFloat = 1024
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(red: r/255, green: g/255, blue: b/255, alpha: a) }

// Tile (macOS icon grid: 824pt square inside 1024)
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

// Soft shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: rgb(0, 0, 0, 0.35))
ctx.addPath(tilePath); ctx.setFillColor(rgb(20, 80, 40)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(tilePath); ctx.clip()

// Sky gradient
let sky = CGGradient(colorsSpace: cs, colors: [rgb(120, 205, 245), rgb(205, 240, 255)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: [])

// Rolling fairway hills
ctx.setFillColor(rgb(70, 160, 70))
ctx.move(to: CGPoint(x: 100, y: 430))
ctx.addCurve(to: CGPoint(x: 924, y: 470), control1: CGPoint(x: 350, y: 560), control2: CGPoint(x: 650, y: 330))
ctx.addLine(to: CGPoint(x: 924, y: 100)); ctx.addLine(to: CGPoint(x: 100, y: 100)); ctx.closePath(); ctx.fillPath()

let grass = CGGradient(colorsSpace: cs, colors: [rgb(60, 160, 60), rgb(25, 110, 45)] as CFArray, locations: [0, 1])!
ctx.saveGState()
ctx.move(to: CGPoint(x: 100, y: 330))
ctx.addCurve(to: CGPoint(x: 924, y: 360), control1: CGPoint(x: 330, y: 440), control2: CGPoint(x: 680, y: 240))
ctx.addLine(to: CGPoint(x: 924, y: 100)); ctx.addLine(to: CGPoint(x: 100, y: 100)); ctx.closePath(); ctx.clip()
ctx.drawLinearGradient(grass, start: CGPoint(x: 0, y: 440), end: CGPoint(x: 0, y: 100), options: [])
ctx.restoreGState()

// Putting green with hole
let center = CGPoint(x: 512, y: 300)
let green = CGRect(x: center.x - 250, y: center.y - 85, width: 500, height: 170)
ctx.setFillColor(rgb(110, 205, 95)); ctx.fillEllipse(in: green)

// GPS rings
for (i, r) in [CGFloat(95), 170, 245].enumerated() {
    ctx.setStrokeColor(rgb(255, 255, 255, 0.85 - CGFloat(i) * 0.2))
    ctx.setLineWidth(10)
    ctx.strokeEllipse(in: CGRect(x: center.x - r, y: center.y - r * 0.34, width: r * 2, height: r * 0.68))
}

// Hole
ctx.setFillColor(rgb(20, 40, 25)); ctx.fillEllipse(in: CGRect(x: center.x - 38, y: center.y - 14, width: 76, height: 28))

// Flagstick
ctx.setFillColor(rgb(250, 250, 250))
ctx.fill(CGRect(x: center.x - 7, y: center.y, width: 14, height: 400))
// Flag
ctx.setFillColor(rgb(235, 55, 55))
ctx.move(to: CGPoint(x: center.x + 7, y: center.y + 400))
ctx.addLine(to: CGPoint(x: center.x + 200, y: center.y + 335))
ctx.addLine(to: CGPoint(x: center.x + 7, y: center.y + 270)); ctx.closePath(); ctx.fillPath()

// Golf ball
let ball = CGRect(x: 640, y: 215, width: 78, height: 78)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 8, color: rgb(0, 0, 0, 0.4))
ctx.setFillColor(rgb(255, 255, 255)); ctx.fillEllipse(in: ball)
ctx.restoreGState()
ctx.setFillColor(rgb(215, 220, 225))
for (dx, dy) in [(22, 48), (42, 50), (30, 30), (50, 30), (22, 20), (44, 12)] {
    ctx.fillEllipse(in: CGRect(x: ball.minX + CGFloat(dx), y: ball.minY + CGFloat(dy), width: 8, height: 8))
}
ctx.restoreGState()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
