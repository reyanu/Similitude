import UIKit

/// Programmatic placeholder artwork used when a template's PNG assets are
/// not yet in the asset catalog. Deterministic (no randomness), tasteful,
/// and — like the real assets must be — entirely free of sample people.
/// Drop real 1600×2000 artwork into Assets.xcassets/KeepsakeTemplates to
/// replace these without code changes.
enum TemplateArtworkFallback {

    static func background(for templateID: String, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            switch templateID {
            case "birthday": drawBirthdayBackground(cg, size: size)
            case "graduation": drawGraduationBackground(cg, size: size)
            default: drawFamilyBackground(cg, size: size)
            }
        }
    }

    static func foreground(for templateID: String, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            switch templateID {
            case "birthday": drawBirthdayForeground(cg, size: size)
            case "graduation": drawGraduationForeground(cg, size: size)
            default: drawFamilyForeground(cg, size: size)
            }
        }
    }

    // MARK: Birthday — pastel watercolor, balloons, confetti, ribbon

    private static func drawBirthdayBackground(_ cg: CGContext, size: CGSize) {
        drawVerticalGradient(
            cg, size: size,
            top: UIColor(red: 1.00, green: 0.92, blue: 0.94, alpha: 1),
            bottom: UIColor(red: 0.96, green: 0.94, blue: 0.99, alpha: 1)
        )

        // Soft watercolor blots.
        let blots: [(CGFloat, CGFloat, CGFloat, UIColor)] = [
            (0.15, 0.10, 0.22, UIColor(red: 0.99, green: 0.80, blue: 0.85, alpha: 0.35)),
            (0.85, 0.16, 0.18, UIColor(red: 0.80, green: 0.88, blue: 0.99, alpha: 0.35)),
            (0.10, 0.80, 0.20, UIColor(red: 0.86, green: 0.95, blue: 0.85, alpha: 0.40)),
            (0.90, 0.85, 0.24, UIColor(red: 0.99, green: 0.93, blue: 0.78, alpha: 0.40)),
        ]
        for (x, y, r, color) in blots {
            color.setFill()
            let radius = size.width * r
            cg.fillEllipse(in: CGRect(
                x: size.width * x - radius, y: size.height * y - radius,
                width: radius * 2, height: radius * 2
            ))
        }

        // Balloons behind the portrait region.
        let balloons: [(CGFloat, CGFloat, UIColor)] = [
            (0.13, 0.30, UIColor(red: 0.98, green: 0.55, blue: 0.65, alpha: 0.9)),
            (0.22, 0.22, UIColor(red: 0.55, green: 0.70, blue: 0.98, alpha: 0.9)),
            (0.82, 0.26, UIColor(red: 0.98, green: 0.80, blue: 0.40, alpha: 0.9)),
            (0.90, 0.34, UIColor(red: 0.65, green: 0.88, blue: 0.65, alpha: 0.9)),
        ]
        for (x, y, color) in balloons {
            drawBalloon(cg, center: CGPoint(x: size.width * x, y: size.height * y),
                        radius: size.width * 0.055, color: color, canvasHeight: size.height)
        }

        // Gift boxes near the bottom corners.
        drawGiftBox(cg, origin: CGPoint(x: size.width * 0.06, y: size.height * 0.86),
                    side: size.width * 0.11,
                    body: UIColor(red: 0.75, green: 0.85, blue: 0.98, alpha: 1),
                    ribbon: UIColor(red: 0.95, green: 0.60, blue: 0.70, alpha: 1))
        drawGiftBox(cg, origin: CGPoint(x: size.width * 0.82, y: size.height * 0.87),
                    side: size.width * 0.09,
                    body: UIColor(red: 0.98, green: 0.85, blue: 0.60, alpha: 1),
                    ribbon: UIColor(red: 0.60, green: 0.75, blue: 0.95, alpha: 1))

        // Simple layered cake bottom-center.
        drawCake(cg, centerX: size.width * 0.5, baseY: size.height * 0.955, width: size.width * 0.16)
    }

    private static func drawBirthdayForeground(_ cg: CGContext, size: CGSize) {
        drawConfetti(cg, size: size, colors: [
            UIColor(red: 0.98, green: 0.60, blue: 0.68, alpha: 0.85),
            UIColor(red: 0.60, green: 0.72, blue: 0.98, alpha: 0.85),
            UIColor(red: 0.98, green: 0.85, blue: 0.45, alpha: 0.85),
            UIColor(red: 0.65, green: 0.88, blue: 0.68, alpha: 0.85),
        ])
        // Decorative ribbon band under the title area.
        let ribbonY = size.height * 0.225
        UIColor(red: 0.95, green: 0.65, blue: 0.74, alpha: 0.9).setFill()
        cg.fill(CGRect(x: size.width * 0.30, y: ribbonY, width: size.width * 0.40, height: size.height * 0.006))
    }

    // MARK: Graduation — ivory, navy/gold border, banner, confetti

    private static func drawGraduationBackground(_ cg: CGContext, size: CGSize) {
        UIColor(red: 0.98, green: 0.97, blue: 0.93, alpha: 1).setFill()
        cg.fill(CGRect(origin: .zero, size: size))

        let navy = UIColor(red: 0.10, green: 0.15, blue: 0.35, alpha: 1)
        let gold = UIColor(red: 0.78, green: 0.64, blue: 0.25, alpha: 1)

        // Double border: outer navy, inner gold.
        navy.setStroke()
        cg.setLineWidth(size.width * 0.012)
        cg.stroke(CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.030, dy: size.width * 0.030))
        gold.setStroke()
        cg.setLineWidth(size.width * 0.005)
        cg.stroke(CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.048, dy: size.width * 0.048))

        // Navy banner behind the title block.
        navy.withAlphaComponent(0.08).setFill()
        let banner = UIBezierPath(
            roundedRect: CGRect(x: size.width * 0.09, y: size.height * 0.085,
                                width: size.width * 0.82, height: size.height * 0.115),
            cornerRadius: size.width * 0.02
        )
        cg.addPath(banner.cgPath)
        cg.fillPath()

        // Lower ribbon.
        gold.withAlphaComponent(0.85).setFill()
        cg.fill(CGRect(x: size.width * 0.24, y: size.height * 0.715,
                       width: size.width * 0.52, height: size.height * 0.005))
    }

    private static func drawGraduationForeground(_ cg: CGContext, size: CGSize) {
        drawConfetti(cg, size: size, colors: [
            UIColor(red: 0.82, green: 0.68, blue: 0.28, alpha: 0.9),
            UIColor(red: 0.90, green: 0.80, blue: 0.50, alpha: 0.8),
        ])
        // Mortarboard cap perched on the portrait's top-right corner.
        drawCap(cg,
                center: CGPoint(x: size.width * 0.665, y: size.height * 0.295),
                halfDiagonal: size.width * 0.085)
    }

    // MARK: Family Poster — cream, botanical corners

    private static func drawFamilyBackground(_ cg: CGContext, size: CGSize) {
        drawVerticalGradient(
            cg, size: size,
            top: UIColor(red: 0.99, green: 0.98, blue: 0.95, alpha: 1),
            bottom: UIColor(red: 0.95, green: 0.94, blue: 0.90, alpha: 1)
        )
        let sage = UIColor(red: 0.60, green: 0.68, blue: 0.55, alpha: 0.55)
        drawLeafArc(cg, corner: CGPoint(x: 0, y: 0), size: size, color: sage, flipX: false, flipY: false)
        drawLeafArc(cg, corner: CGPoint(x: size.width, y: 0), size: size, color: sage, flipX: true, flipY: false)
    }

    private static func drawFamilyForeground(_ cg: CGContext, size: CGSize) {
        let sage = UIColor(red: 0.55, green: 0.64, blue: 0.50, alpha: 0.60)
        drawLeafArc(cg, corner: CGPoint(x: 0, y: size.height), size: size, color: sage, flipX: false, flipY: true)
        drawLeafArc(cg, corner: CGPoint(x: size.width, y: size.height), size: size, color: sage, flipX: true, flipY: true)
    }

    // MARK: Shared drawing helpers

    private static func drawVerticalGradient(_ cg: CGContext, size: CGSize, top: UIColor, bottom: UIColor) {
        let colors = [top.cgColor, bottom.cgColor] as CFArray
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]
        ) else {
            top.setFill()
            cg.fill(CGRect(origin: .zero, size: size))
            return
        }
        cg.drawLinearGradient(
            gradient,
            start: .zero,
            end: CGPoint(x: 0, y: size.height),
            options: []
        )
    }

    private static func drawBalloon(_ cg: CGContext, center: CGPoint, radius: CGFloat, color: UIColor, canvasHeight: CGFloat) {
        color.setFill()
        cg.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius * 1.15,
                                  width: radius * 2, height: radius * 2.3))
        color.withAlphaComponent(0.6).setStroke()
        cg.setLineWidth(radius * 0.06)
        cg.move(to: CGPoint(x: center.x, y: center.y + radius * 1.15))
        cg.addCurve(
            to: CGPoint(x: center.x + radius * 0.4, y: center.y + radius * 3.2),
            control1: CGPoint(x: center.x - radius * 0.5, y: center.y + radius * 1.9),
            control2: CGPoint(x: center.x + radius * 0.8, y: center.y + radius * 2.5)
        )
        cg.strokePath()
    }

    private static func drawGiftBox(_ cg: CGContext, origin: CGPoint, side: CGFloat, body: UIColor, ribbon: UIColor) {
        body.setFill()
        cg.fill(CGRect(x: origin.x, y: origin.y, width: side, height: side * 0.8))
        ribbon.setFill()
        cg.fill(CGRect(x: origin.x + side * 0.44, y: origin.y, width: side * 0.12, height: side * 0.8))
        cg.fill(CGRect(x: origin.x, y: origin.y + side * 0.32, width: side, height: side * 0.10))
    }

    private static func drawCake(_ cg: CGContext, centerX: CGFloat, baseY: CGFloat, width: CGFloat) {
        let tierHeight = width * 0.28
        UIColor(red: 0.95, green: 0.80, blue: 0.85, alpha: 1).setFill()
        cg.fill(CGRect(x: centerX - width / 2, y: baseY - tierHeight, width: width, height: tierHeight))
        UIColor(red: 0.98, green: 0.90, blue: 0.93, alpha: 1).setFill()
        cg.fill(CGRect(x: centerX - width * 0.35, y: baseY - tierHeight * 1.9, width: width * 0.7, height: tierHeight * 0.9))
        UIColor(red: 0.98, green: 0.75, blue: 0.35, alpha: 1).setFill()
        cg.fill(CGRect(x: centerX - width * 0.02, y: baseY - tierHeight * 2.35, width: width * 0.04, height: tierHeight * 0.45))
    }

    private static func drawConfetti(_ cg: CGContext, size: CGSize, colors: [UIColor]) {
        // Deterministic pseudo-scatter from a fixed table.
        let positions: [(CGFloat, CGFloat, CGFloat)] = [
            (0.06, 0.06, 1.0), (0.16, 0.12, 0.6), (0.30, 0.05, 0.8), (0.52, 0.09, 0.5),
            (0.70, 0.04, 0.9), (0.86, 0.10, 0.7), (0.94, 0.05, 1.0), (0.08, 0.42, 0.6),
            (0.93, 0.45, 0.7), (0.05, 0.62, 0.8), (0.95, 0.66, 0.6), (0.10, 0.93, 0.7),
            (0.30, 0.96, 0.5), (0.68, 0.95, 0.8), (0.90, 0.93, 0.9), (0.50, 0.98, 0.6),
        ]
        for (index, (x, y, scale)) in positions.enumerated() {
            colors[index % colors.count].setFill()
            let radius = size.width * 0.008 * scale
            cg.fillEllipse(in: CGRect(
                x: size.width * x - radius, y: size.height * y - radius,
                width: radius * 2, height: radius * 2
            ))
        }
    }

    private static func drawCap(_ cg: CGContext, center: CGPoint, halfDiagonal: CGFloat) {
        let navy = UIColor(red: 0.10, green: 0.15, blue: 0.35, alpha: 1)
        let gold = UIColor(red: 0.82, green: 0.68, blue: 0.28, alpha: 1)

        navy.setFill()
        cg.saveGState()
        cg.translateBy(x: center.x, y: center.y)
        let board = UIBezierPath()
        board.move(to: CGPoint(x: 0, y: -halfDiagonal * 0.45))
        board.addLine(to: CGPoint(x: halfDiagonal, y: 0))
        board.addLine(to: CGPoint(x: 0, y: halfDiagonal * 0.45))
        board.addLine(to: CGPoint(x: -halfDiagonal, y: 0))
        board.close()
        cg.addPath(board.cgPath)
        cg.fillPath()

        // Crown under the board.
        navy.withAlphaComponent(0.9).setFill()
        cg.fill(CGRect(x: -halfDiagonal * 0.35, y: 0, width: halfDiagonal * 0.7, height: halfDiagonal * 0.4))

        // Tassel.
        gold.setStroke()
        cg.setLineWidth(halfDiagonal * 0.05)
        cg.move(to: .zero)
        cg.addLine(to: CGPoint(x: halfDiagonal * 0.75, y: halfDiagonal * 0.6))
        cg.strokePath()
        gold.setFill()
        cg.fillEllipse(in: CGRect(x: halfDiagonal * 0.68, y: halfDiagonal * 0.55,
                                  width: halfDiagonal * 0.14, height: halfDiagonal * 0.22))
        cg.restoreGState()
    }

    private static func drawLeafArc(_ cg: CGContext, corner: CGPoint, size: CGSize, color: UIColor, flipX: Bool, flipY: Bool) {
        cg.saveGState()
        cg.translateBy(x: corner.x, y: corner.y)
        cg.scaleBy(x: flipX ? -1 : 1, y: flipY ? -1 : 1)

        color.setFill()
        let reach = size.width * 0.30
        // A stem of simple leaves fanning from the corner.
        for i in 0..<6 {
            let angle = CGFloat(i) * 0.16 + 0.15
            let distance = reach * (0.45 + CGFloat(i) * 0.10)
            let leafCenter = CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
            let leafLength = size.width * 0.055 * (1.0 - CGFloat(i) * 0.08)

            cg.saveGState()
            cg.translateBy(x: leafCenter.x, y: leafCenter.y)
            cg.rotate(by: angle)
            cg.fillEllipse(in: CGRect(x: -leafLength, y: -leafLength * 0.35,
                                      width: leafLength * 2, height: leafLength * 0.7))
            cg.restoreGState()
        }
        cg.restoreGState()
    }
}
