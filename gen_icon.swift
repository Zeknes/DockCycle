import Cocoa
import CoreGraphics

// 生成 DockCycle 图标：蓝紫渐变圆角方块 + 白色循环箭头
func generateIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext
    let rect = CGRect(x: 0, y: 0, width: s, height: s)

    // 圆角方块背景 + 蓝紫渐变
    let cornerRadius = s * 0.2237  // macOS squircle
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    path.addClip()

    let colors = [NSColor(red: 0.25, green: 0.45, blue: 0.95, alpha: 1).cgColor,
                  NSColor(red: 0.55, green: 0.25, blue: 0.85, alpha: 1).cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: colors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])

    // 白色循环箭头（两个半圆弧 + 箭头头）
    let center = CGPoint(x: s/2, y: s/2)
    let radius = s * 0.28
    let lineWidth = s * 0.08

    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(lineWidth)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // 上半弧（从左到右，顺时针）
    ctx.addArc(center: center, radius: radius, startAngle: .pi, endAngle: 0, clockwise: false)
    ctx.strokePath()

    // 右侧箭头头
    let arrowEnd = CGPoint(x: center.x + radius, y: center.y)
    let arrowSize = s * 0.12
    ctx.move(to: CGPoint(x: arrowEnd.x, y: arrowEnd.y))
    ctx.addLine(to: CGPoint(x: arrowEnd.x - arrowSize * 0.7, y: arrowEnd.y + arrowSize))
    ctx.addLine(to: CGPoint(x: arrowEnd.x + arrowSize * 0.3, y: arrowEnd.y + arrowSize * 0.5))
    ctx.closePath()
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillPath()

    // 下半弧（从右到左，顺时针）
    ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi, clockwise: false)
    ctx.strokePath()

    // 左侧箭头头
    let arrowEnd2 = CGPoint(x: center.x - radius, y: center.y)
    ctx.move(to: CGPoint(x: arrowEnd2.x, y: arrowEnd2.y))
    ctx.addLine(to: CGPoint(x: arrowEnd2.x + arrowSize * 0.7, y: arrowEnd2.y - arrowSize))
    ctx.addLine(to: CGPoint(x: arrowEnd2.x - arrowSize * 0.3, y: arrowEnd2.y - arrowSize * 0.5))
    ctx.closePath()
    ctx.fillPath()

    image.unlockFocus()
    return image
}

// 生成 iconset 目录并转换为 icns
let iconsetPath = "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let sizes = [(16, "icon_16x16"), (32, "icon_16x16@2x"),
             (32, "icon_32x32"), (64, "icon_32x32@2x"),
             (128, "icon_128x128"), (256, "icon_128x128@2x"),
             (256, "icon_256x256"), (512, "icon_256x256@2x"),
             (512, "icon_512x512"), (1024, "icon_512x512@2x")]

for (size, name) in sizes {
    let img = generateIcon(size: size)
    let tiff = img.tiffRepresentation!
    let rep = NSBitmapImageRep(data: tiff)!
    let png = rep.representation(using: .png, properties: [:])!
    try? png.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name).png"))
}

// 用 iconutil 转换
let task = Process()
task.launchPath = "/usr/bin/iconutil"
task.arguments = ["-c", "icns", iconsetPath, "-o", "AppIcon.icns"]
task.launch()
task.waitUntilExit()

// 清理
try? FileManager.default.removeItem(atPath: iconsetPath)

print("✅ 生成 AppIcon.icns")
