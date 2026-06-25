import AppKit
import Foundation

func savePNG(size: Int, to url: URL, drawing: () -> Void) throws {
    guard let bitmap = NSBitmapImageRep(
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
    ) else { throw CocoaError(.fileWriteUnknown) }
    bitmap.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.shouldAntialias = true
    NSGraphicsContext.current?.imageInterpolation = .high
    drawing()
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
    try data.write(to: url, options: .atomic)
}

func roundedRect(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func circle(_ rect: NSRect, color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: rect).fill()
}

func facePath(in rect: NSRect) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: rect.midX, y: rect.maxY))
    path.curve(to: NSPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY + rect.height * 0.22),
               controlPoint1: NSPoint(x: rect.maxX - rect.width * 0.02, y: rect.maxY - rect.height * 0.10),
               controlPoint2: NSPoint(x: rect.maxX + rect.width * 0.02, y: rect.minY + rect.height * 0.48))
    path.curve(to: NSPoint(x: rect.midX, y: rect.minY),
               controlPoint1: NSPoint(x: rect.maxX - rect.width * 0.22, y: rect.minY + rect.height * 0.10),
               controlPoint2: NSPoint(x: rect.midX + rect.width * 0.10, y: rect.minY - rect.height * 0.02))
    path.curve(to: NSPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.22),
               controlPoint1: NSPoint(x: rect.midX - rect.width * 0.10, y: rect.minY - rect.height * 0.02),
               controlPoint2: NSPoint(x: rect.minX - rect.width * 0.02, y: rect.minY + rect.height * 0.48))
    path.curve(to: NSPoint(x: rect.midX, y: rect.maxY),
               controlPoint1: NSPoint(x: rect.minX + rect.width * 0.02, y: rect.maxY - rect.height * 0.10),
               controlPoint2: NSPoint(x: rect.maxX - rect.width * 0.18, y: rect.maxY - rect.height * 0.02))
    path.close()
    return path
}

func birdFace(in rect: NSRect, faceColor: NSColor, outlineColor: NSColor, eyeColor: NSColor, accentBlue: NSColor? = nil, addPointer: Bool = false) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.15)
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.shadowBlurRadius = 16
    shadow.set()

    let face = facePath(in: rect)
    faceColor.setFill()
    face.fill()
    outlineColor.setStroke()
    face.lineWidth = max(6, rect.width * 0.04)
    face.stroke()

    let crest = NSBezierPath()
    crest.move(to: NSPoint(x: rect.midX - rect.width * 0.04, y: rect.maxY - rect.height * 0.04))
    crest.curve(to: NSPoint(x: rect.midX + rect.width * 0.12, y: rect.maxY + rect.height * 0.08),
                controlPoint1: NSPoint(x: rect.midX + rect.width * 0.02, y: rect.maxY + rect.height * 0.08),
                controlPoint2: NSPoint(x: rect.midX + rect.width * 0.07, y: rect.maxY + rect.height * 0.14))
    crest.curve(to: NSPoint(x: rect.midX + rect.width * 0.02, y: rect.maxY - rect.height * 0.01),
                controlPoint1: NSPoint(x: rect.midX + rect.width * 0.17, y: rect.maxY + rect.height * 0.05),
                controlPoint2: NSPoint(x: rect.midX + rect.width * 0.08, y: rect.maxY - rect.height * 0.01))
    crest.close()
    eyeColor.setFill()
    crest.fill()

    let eyeY = rect.minY + rect.height * 0.44
    circle(NSRect(x: rect.midX - rect.width * 0.18, y: eyeY, width: rect.width * 0.075, height: rect.width * 0.075), color: eyeColor)
    circle(NSRect(x: rect.midX + rect.width * 0.09, y: eyeY, width: rect.width * 0.075, height: rect.width * 0.075), color: eyeColor)

    let beak = NSBezierPath()
    beak.move(to: NSPoint(x: rect.midX - rect.width * 0.02, y: rect.minY + rect.height * 0.31))
    beak.line(to: NSPoint(x: rect.midX + rect.width * 0.10, y: rect.minY + rect.height * 0.23))
    beak.line(to: NSPoint(x: rect.midX - rect.width * 0.01, y: rect.minY + rect.height * 0.17))
    beak.close()
    NSColor(calibratedRed: 0.24, green: 0.16, blue: 0.13, alpha: 1).setFill()
    beak.fill()

    let earPatch = NSBezierPath(ovalIn: NSRect(x: rect.midX + rect.width * 0.10, y: rect.minY + rect.height * 0.42, width: rect.width * 0.11, height: rect.width * 0.11))
    NSColor(calibratedRed: 0.92, green: 0.18, blue: 0.16, alpha: 1).setFill()
    earPatch.fill()

    if let accentBlue {
        accentBlue.setStroke()
        let hint = NSBezierPath()
        hint.lineWidth = max(4, rect.width * 0.024)
        hint.lineCapStyle = .round
        hint.move(to: NSPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.24))
        hint.line(to: NSPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.30))
        hint.move(to: NSPoint(x: rect.maxX - rect.width * 0.18, y: rect.minY + rect.height * 0.16))
        hint.line(to: NSPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY + rect.height * 0.22))
        hint.stroke()
    }

    if addPointer {
        let pointer = NSBezierPath()
        pointer.move(to: NSPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY + rect.height * 0.14))
        pointer.line(to: NSPoint(x: rect.maxX - rect.width * 0.02, y: rect.minY + rect.height * 0.03))
        pointer.line(to: NSPoint(x: rect.maxX - rect.width * 0.06, y: rect.minY + rect.height * 0.20))
        pointer.line(to: NSPoint(x: rect.maxX - rect.width * 0.14, y: rect.minY + rect.height * 0.18))
        pointer.close()
        NSColor.white.setFill()
        pointer.fill()
        NSColor(calibratedRed: 0.15, green: 0.23, blue: 0.46, alpha: 1).setStroke()
        pointer.lineWidth = max(4, rect.width * 0.018)
        pointer.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()
}

func birdSilhouetteApp(in rect: NSRect) {
    let body = NSBezierPath()
    body.move(to: NSPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.08))
    body.curve(to: NSPoint(x: rect.minX + rect.width * 0.25, y: rect.minY + rect.height * 0.55),
               controlPoint1: NSPoint(x: rect.minX + rect.width * 0.09, y: rect.minY + rect.height * 0.22),
               controlPoint2: NSPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.43))
    body.line(to: NSPoint(x: rect.minX + rect.width * 0.20, y: rect.minY + rect.height * 0.62))
    body.curve(to: NSPoint(x: rect.minX + rect.width * 0.30, y: rect.minY + rect.height * 0.58),
               controlPoint1: NSPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.68),
               controlPoint2: NSPoint(x: rect.minX + rect.width * 0.20, y: rect.minY + rect.height * 0.70))
    body.curve(to: NSPoint(x: rect.minX + rect.width * 0.28, y: rect.maxY - rect.height * 0.02),
               controlPoint1: NSPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.75),
               controlPoint2: NSPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY - rect.height * 0.01))
    body.curve(to: NSPoint(x: rect.minX + rect.width * 0.67, y: rect.minY + rect.height * 0.72),
               controlPoint1: NSPoint(x: rect.minX + rect.width * 0.39, y: rect.minY + rect.height * 0.82),
               controlPoint2: NSPoint(x: rect.minX + rect.width * 0.58, y: rect.minY + rect.height * 0.80))
    body.curve(to: NSPoint(x: rect.minX + rect.width * 0.75, y: rect.minY + rect.height * 0.42),
               controlPoint1: NSPoint(x: rect.minX + rect.width * 0.76, y: rect.minY + rect.height * 0.64),
               controlPoint2: NSPoint(x: rect.minX + rect.width * 0.78, y: rect.minY + rect.height * 0.51))
    body.curve(to: NSPoint(x: rect.minX + rect.width * 0.60, y: rect.minY + rect.height * 0.08),
               controlPoint1: NSPoint(x: rect.minX + rect.width * 0.76, y: rect.minY + rect.height * 0.24),
               controlPoint2: NSPoint(x: rect.minX + rect.width * 0.69, y: rect.minY + rect.height * 0.12))
    body.close()

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.shadowBlurRadius = 18
    shadow.set()
    NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
    body.fill()
    NSGraphicsContext.restoreGraphicsState()

    let face = NSBezierPath()
    face.move(to: NSPoint(x: rect.minX + rect.width * 0.36, y: rect.minY + rect.height * 0.08))
    face.curve(to: NSPoint(x: rect.minX + rect.width * 0.43, y: rect.minY + rect.height * 0.53),
               controlPoint1: NSPoint(x: rect.minX + rect.width * 0.36, y: rect.minY + rect.height * 0.25),
               controlPoint2: NSPoint(x: rect.minX + rect.width * 0.37, y: rect.minY + rect.height * 0.45))
    face.curve(to: NSPoint(x: rect.minX + rect.width * 0.62, y: rect.minY + rect.height * 0.61),
               controlPoint1: NSPoint(x: rect.minX + rect.width * 0.48, y: rect.minY + rect.height * 0.62),
               controlPoint2: NSPoint(x: rect.minX + rect.width * 0.57, y: rect.minY + rect.height * 0.64))
    face.curve(to: NSPoint(x: rect.minX + rect.width * 0.70, y: rect.minY + rect.height * 0.45),
               controlPoint1: NSPoint(x: rect.minX + rect.width * 0.69, y: rect.minY + rect.height * 0.58),
               controlPoint2: NSPoint(x: rect.minX + rect.width * 0.72, y: rect.minY + rect.height * 0.52))
    face.curve(to: NSPoint(x: rect.minX + rect.width * 0.63, y: rect.minY + rect.height * 0.10),
               controlPoint1: NSPoint(x: rect.minX + rect.width * 0.69, y: rect.minY + rect.height * 0.30),
               controlPoint2: NSPoint(x: rect.minX + rect.width * 0.68, y: rect.minY + rect.height * 0.15))
    face.curve(to: NSPoint(x: rect.minX + rect.width * 0.36, y: rect.minY + rect.height * 0.08),
               controlPoint1: NSPoint(x: rect.minX + rect.width * 0.55, y: rect.minY + rect.height * 0.06),
               controlPoint2: NSPoint(x: rect.minX + rect.width * 0.45, y: rect.minY + rect.height * 0.06))
    face.close()
    NSColor.white.setFill()
    face.fill()

    let cheek = NSBezierPath(ovalIn: NSRect(x: rect.minX + rect.width * 0.23, y: rect.minY + rect.height * 0.37, width: rect.width * 0.18, height: rect.height * 0.13))
    NSColor(calibratedRed: 0.96, green: 0.25, blue: 0.10, alpha: 1).setFill()
    cheek.fill()

    let eye = NSBezierPath(ovalIn: NSRect(x: rect.minX + rect.width * 0.49, y: rect.minY + rect.height * 0.49, width: rect.width * 0.095, height: rect.width * 0.095))
    NSColor.black.setFill()
    eye.fill()
    let eyeHighlight = NSBezierPath(ovalIn: NSRect(x: rect.minX + rect.width * 0.515, y: rect.minY + rect.height * 0.545, width: rect.width * 0.032, height: rect.width * 0.032))
    NSColor.white.setFill()
    eyeHighlight.fill()

    let beak = NSBezierPath()
    beak.move(to: NSPoint(x: rect.minX + rect.width * 0.65, y: rect.minY + rect.height * 0.49))
    beak.curve(to: NSPoint(x: rect.minX + rect.width * 0.84, y: rect.minY + rect.height * 0.53),
               controlPoint1: NSPoint(x: rect.minX + rect.width * 0.72, y: rect.minY + rect.height * 0.58),
               controlPoint2: NSPoint(x: rect.minX + rect.width * 0.79, y: rect.minY + rect.height * 0.56))
    beak.curve(to: NSPoint(x: rect.minX + rect.width * 0.67, y: rect.minY + rect.height * 0.44),
               controlPoint1: NSPoint(x: rect.minX + rect.width * 0.78, y: rect.minY + rect.height * 0.48),
               controlPoint2: NSPoint(x: rect.minX + rect.width * 0.72, y: rect.minY + rect.height * 0.43))
    beak.close()
    NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
    beak.fill()

    let pointer = NSBezierPath()
    pointer.move(to: NSPoint(x: rect.minX + rect.width * 0.66, y: rect.minY + rect.height * 0.20))
    pointer.line(to: NSPoint(x: rect.minX + rect.width * 0.84, y: rect.minY + rect.height * 0.10))
    pointer.line(to: NSPoint(x: rect.minX + rect.width * 0.78, y: rect.minY + rect.height * 0.08))
    pointer.line(to: NSPoint(x: rect.minX + rect.width * 0.83, y: rect.minY + rect.height * 0.01))
    pointer.line(to: NSPoint(x: rect.minX + rect.width * 0.78, y: rect.minY - rect.height * 0.01))
    pointer.line(to: NSPoint(x: rect.minX + rect.width * 0.73, y: rect.minY + rect.height * 0.07))
    pointer.line(to: NSPoint(x: rect.minX + rect.width * 0.69, y: rect.minY + rect.height * 0.03))
    pointer.close()
    NSColor.white.setFill()
    pointer.fill()
    NSColor(calibratedWhite: 0.08, alpha: 1).setStroke()
    pointer.lineJoinStyle = .round
    pointer.lineWidth = max(4, rect.width * 0.014)
    pointer.stroke()
}

func birdSilhouetteMenu(in rect: NSRect) {
    let body = NSBezierPath()
    body.move(to: NSPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.12))
    body.curve(to: NSPoint(x: rect.minX + rect.width * 0.27, y: rect.minY + rect.height * 0.61),
               controlPoint1: NSPoint(x: rect.minX + rect.width * 0.11, y: rect.minY + rect.height * 0.32),
               controlPoint2: NSPoint(x: rect.minX + rect.width * 0.17, y: rect.minY + rect.height * 0.48))
    body.line(to: NSPoint(x: rect.minX + rect.width * 0.21, y: rect.minY + rect.height * 0.69))
    body.line(to: NSPoint(x: rect.minX + rect.width * 0.32, y: rect.minY + rect.height * 0.63))
    body.curve(to: NSPoint(x: rect.minX + rect.width * 0.29, y: rect.maxY),
               controlPoint1: NSPoint(x: rect.minX + rect.width * 0.25, y: rect.minY + rect.height * 0.80),
               controlPoint2: NSPoint(x: rect.minX + rect.width * 0.27, y: rect.minY + rect.height * 0.95))
    body.curve(to: NSPoint(x: rect.minX + rect.width * 0.72, y: rect.minY + rect.height * 0.69),
               controlPoint1: NSPoint(x: rect.minX + rect.width * 0.43, y: rect.minY + rect.height * 0.82),
               controlPoint2: NSPoint(x: rect.minX + rect.width * 0.63, y: rect.minY + rect.height * 0.80))
    body.curve(to: NSPoint(x: rect.minX + rect.width * 0.66, y: rect.minY + rect.height * 0.14),
               controlPoint1: NSPoint(x: rect.minX + rect.width * 0.79, y: rect.minY + rect.height * 0.51),
               controlPoint2: NSPoint(x: rect.minX + rect.width * 0.75, y: rect.minY + rect.height * 0.25))
    body.close()
    NSColor.black.setFill()
    body.fill()

    let face = NSBezierPath()
    face.move(to: NSPoint(x: rect.minX + rect.width * 0.39, y: rect.minY + rect.height * 0.14))
    face.curve(to: NSPoint(x: rect.minX + rect.width * 0.46, y: rect.minY + rect.height * 0.58),
               controlPoint1: NSPoint(x: rect.minX + rect.width * 0.38, y: rect.minY + rect.height * 0.32),
               controlPoint2: NSPoint(x: rect.minX + rect.width * 0.40, y: rect.minY + rect.height * 0.51))
    face.curve(to: NSPoint(x: rect.minX + rect.width * 0.69, y: rect.minY + rect.height * 0.47),
               controlPoint1: NSPoint(x: rect.minX + rect.width * 0.60, y: rect.minY + rect.height * 0.72),
               controlPoint2: NSPoint(x: rect.minX + rect.width * 0.72, y: rect.minY + rect.height * 0.62))
    face.curve(to: NSPoint(x: rect.minX + rect.width * 0.64, y: rect.minY + rect.height * 0.15),
               controlPoint1: NSPoint(x: rect.minX + rect.width * 0.68, y: rect.minY + rect.height * 0.34),
               controlPoint2: NSPoint(x: rect.minX + rect.width * 0.68, y: rect.minY + rect.height * 0.21))
    face.close()
    NSColor.clear.setFill()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current?.compositingOperation = .clear
    face.fill()
    NSGraphicsContext.restoreGraphicsState()

    let eye = NSBezierPath(ovalIn: NSRect(x: rect.minX + rect.width * 0.51, y: rect.minY + rect.height * 0.53, width: rect.width * 0.075, height: rect.width * 0.075))
    NSColor.black.setFill()
    eye.fill()

    let beak = NSBezierPath()
    beak.move(to: NSPoint(x: rect.minX + rect.width * 0.66, y: rect.minY + rect.height * 0.50))
    beak.line(to: NSPoint(x: rect.minX + rect.width * 0.91, y: rect.minY + rect.height * 0.54))
    beak.line(to: NSPoint(x: rect.minX + rect.width * 0.69, y: rect.minY + rect.height * 0.43))
    beak.close()
    NSColor.black.setFill()
    beak.fill()
}

// Geometry traced from the approved reference composition. The y values below
// use image coordinates (top-to-bottom) and are converted for AppKit drawing.
func birdReferenceApp(in rect: NSRect) {
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: rect.minX + rect.width * x,
                y: rect.minY + rect.height * (1 - y))
    }

    let body = NSBezierPath()
    body.move(to: p(0.116, 0.902))
    body.curve(to: p(0.158, 0.744), controlPoint1: p(0.095, 0.869), controlPoint2: p(0.127, 0.817))
    body.curve(to: p(0.342, 0.373), controlPoint1: p(0.205, 0.630), controlPoint2: p(0.252, 0.484))
    body.line(to: p(0.312, 0.330))
    body.curve(to: p(0.288, 0.241), controlPoint1: p(0.294, 0.304), controlPoint2: p(0.275, 0.250))
    body.curve(to: p(0.348, 0.261), controlPoint1: p(0.291, 0.226), controlPoint2: p(0.319, 0.247))
    body.curve(to: p(0.345, 0.078), controlPoint1: p(0.314, 0.190), controlPoint2: p(0.318, 0.089))
    body.curve(to: p(0.583, 0.258), controlPoint1: p(0.411, 0.150), controlPoint2: p(0.464, 0.202))
    body.curve(to: p(0.773, 0.486), controlPoint1: p(0.713, 0.319), controlPoint2: p(0.770, 0.364))
    body.curve(to: p(0.626, 0.887), controlPoint1: p(0.765, 0.620), controlPoint2: p(0.704, 0.793))
    body.curve(to: p(0.116, 0.902), controlPoint1: p(0.607, 0.905), controlPoint2: p(0.260, 0.902))
    body.close()

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    shadow.shadowBlurRadius = 14
    shadow.set()
    NSGradient(starting: NSColor(calibratedWhite: 0.10, alpha: 1),
               ending: NSColor(calibratedWhite: 0.20, alpha: 1))?.draw(in: body, angle: -35)
    NSGraphicsContext.restoreGraphicsState()

    func makeFacePath(offsetX: CGFloat = 0, offsetY: CGFloat = 0) -> NSBezierPath {
        let face = NSBezierPath()
        face.move(to: p(0.289 + offsetX, 0.902 + offsetY))
        face.curve(to: p(0.414 + offsetX, 0.646 + offsetY), controlPoint1: p(0.305 + offsetX, 0.802 + offsetY), controlPoint2: p(0.350 + offsetX, 0.716 + offsetY))
        face.curve(to: p(0.505 + offsetX, 0.456 + offsetY), controlPoint1: p(0.455 + offsetX, 0.600 + offsetY), controlPoint2: p(0.463 + offsetX, 0.508 + offsetY))
        face.curve(to: p(0.699 + offsetX, 0.489 + offsetY), controlPoint1: p(0.563 + offsetX, 0.384 + offsetY), controlPoint2: p(0.658 + offsetX, 0.419 + offsetY))
        face.curve(to: p(0.709 + offsetX, 0.658 + offsetY), controlPoint1: p(0.728 + offsetX, 0.538 + offsetY), controlPoint2: p(0.707 + offsetX, 0.604 + offsetY))
        face.curve(to: p(0.630 + offsetX, 0.890 + offsetY), controlPoint1: p(0.705 + offsetX, 0.754 + offsetY), controlPoint2: p(0.690 + offsetX, 0.840 + offsetY))
        face.curve(to: p(0.289 + offsetX, 0.902 + offsetY), controlPoint1: p(0.602 + offsetX, 0.910 + offsetY), controlPoint2: p(0.390 + offsetX, 0.902 + offsetY))
        face.close()
        return face
    }

    let faceShadow = NSBezierPath()
    faceShadow.move(to: p(0.620, 0.456))
    faceShadow.curve(to: p(0.755, 0.585), controlPoint1: p(0.730, 0.438), controlPoint2: p(0.770, 0.510))
    faceShadow.curve(to: p(0.665, 0.898), controlPoint1: p(0.755, 0.735), controlPoint2: p(0.720, 0.855))
    faceShadow.curve(to: p(0.585, 0.902), controlPoint1: p(0.640, 0.903), controlPoint2: p(0.610, 0.903))
    faceShadow.curve(to: p(0.620, 0.456), controlPoint1: p(0.665, 0.790), controlPoint2: p(0.675, 0.590))
    faceShadow.close()
    NSColor(calibratedWhite: 0.89, alpha: 1).setFill()
    faceShadow.fill()

    let face = makeFacePath()
    NSGradient(starting: .white, ending: NSColor(calibratedWhite: 0.97, alpha: 1))?.draw(in: face, angle: -90)

    let cheek = NSBezierPath(ovalIn: NSRect(
        x: rect.minX + rect.width * 0.288,
        y: rect.minY + rect.height * (1 - 0.685),
        width: rect.width * 0.214,
        height: rect.height * 0.145
    ))
    NSGradient(starting: NSColor(calibratedRed: 0.96, green: 0.18, blue: 0.07, alpha: 1),
               ending: NSColor(calibratedRed: 0.95, green: 0.38, blue: 0.18, alpha: 1))?.draw(in: cheek, angle: -25)

    let eye = NSBezierPath(ovalIn: NSRect(
        x: rect.minX + rect.width * 0.538,
        y: rect.minY + rect.height * (1 - 0.593),
        width: rect.width * 0.114,
        height: rect.height * 0.114
    ))
    NSGradient(starting: NSColor(calibratedWhite: 0.02, alpha: 1),
               ending: NSColor(calibratedWhite: 0.10, alpha: 1))?.draw(in: eye, angle: -90)

    let eyeHighlight = NSBezierPath(ovalIn: NSRect(
        x: rect.minX + rect.width * 0.574,
        y: rect.minY + rect.height * (1 - 0.542),
        width: rect.width * 0.046,
        height: rect.height * 0.046
    ))
    NSColor.white.setFill()
    eyeHighlight.fill()

    let beak = NSBezierPath()
    beak.move(to: p(0.694, 0.537))
    beak.curve(to: p(0.902, 0.524), controlPoint1: p(0.750, 0.474), controlPoint2: p(0.835, 0.477))
    beak.curve(to: p(0.696, 0.569), controlPoint1: p(0.842, 0.579), controlPoint2: p(0.765, 0.612))
    beak.close()
    NSGradient(starting: NSColor(calibratedWhite: 0.08, alpha: 1),
               ending: NSColor(calibratedWhite: 0.24, alpha: 1))?.draw(in: beak, angle: 55)

    let pointer = NSBezierPath()
    pointer.move(to: p(0.756, 0.768))
    pointer.line(to: p(0.908, 0.848))
    pointer.line(to: p(0.838, 0.870))
    pointer.line(to: p(0.899, 0.920))
    pointer.line(to: p(0.867, 0.951))
    pointer.line(to: p(0.816, 0.886))
    pointer.line(to: p(0.797, 0.933))
    pointer.close()
    NSColor.white.setFill()
    pointer.fill()
    NSColor(calibratedWhite: 0.08, alpha: 1).setStroke()
    pointer.lineWidth = rect.width * 0.012
    pointer.lineJoinStyle = .round
    pointer.lineCapStyle = .round
    pointer.stroke()
}

func birdReferenceMenu(in rect: NSRect) {
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: rect.minX + rect.width * x,
                y: rect.minY + rect.height * (1 - y))
    }

    // Compact single-mass silhouette inspired by the visual density of Codex
    // and WeChat menu bar marks. It keeps only the bird's essential features.
    let body = NSBezierPath()
    body.move(to: p(0.18, 0.78))
    body.curve(to: p(0.20, 0.39), controlPoint1: p(0.11, 0.65), controlPoint2: p(0.12, 0.49))
    body.line(to: p(0.14, 0.27))
    body.line(to: p(0.31, 0.32))
    body.curve(to: p(0.36, 0.12), controlPoint1: p(0.29, 0.23), controlPoint2: p(0.31, 0.15))
    body.line(to: p(0.51, 0.29))
    body.curve(to: p(0.78, 0.47), controlPoint1: p(0.65, 0.29), controlPoint2: p(0.75, 0.35))
    body.line(to: p(0.94, 0.54))
    body.line(to: p(0.78, 0.63))
    body.curve(to: p(0.60, 0.84), controlPoint1: p(0.76, 0.73), controlPoint2: p(0.69, 0.81))
    body.curve(to: p(0.18, 0.78), controlPoint1: p(0.44, 0.91), controlPoint2: p(0.28, 0.87))
    body.close()
    NSColor.black.withAlphaComponent(0.94).setFill()
    body.fill()

    // One generous negative-space eye remains crisp at 18 pt.
    let eye = NSBezierPath(ovalIn: NSRect(
        x: rect.minX + rect.width * 0.54,
        y: rect.minY + rect.height * (1 - 0.53),
        width: rect.width * 0.12,
        height: rect.width * 0.12
    ))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current?.compositingOperation = .clear
    eye.fill()
    NSGraphicsContext.restoreGraphicsState()
}

func drawAppIcon() {
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()
    birdReferenceApp(in: NSRect(x: 0, y: 0, width: 1024, height: 1024))
}

func drawMenuIcon() {
    NSColor.clear.setFill(); NSRect(x: 0, y: 0, width: 72, height: 72).fill()
    birdReferenceMenu(in: NSRect(x: 2, y: 1.5, width: 68, height: 69))
}

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate_icons <output-directory>\n", stderr)
    exit(2)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
try savePNG(size: 1024, to: output.appendingPathComponent("MacMate-1024.png"), drawing: drawAppIcon)
try savePNG(size: 72, to: output.appendingPathComponent("MenuBarIcon.png"), drawing: drawMenuIcon)
