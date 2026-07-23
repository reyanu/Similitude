import UIKit

/// Renders a shareable resemblance card: child centered between parents,
/// relative percentages, brand gradient, Similitude wordmark. 1080×1350
/// (portrait social format). No internal labels beyond the visible UI text.
struct ResemblanceShareCardRenderer {

    struct ParentEntry {
        let name: String
        let image: UIImage
        let sharePercent: Int
        let isPrimary: Bool
    }

    func render(childImage: UIImage, parents: [ParentEntry], headline: String) -> UIImage {
        let size = CGSize(width: 1080, height: 1350)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext

            // Brand gradient background.
            let colors = [
                UIColor(red: 0.06, green: 0.08, blue: 0.20, alpha: 1).cgColor,
                UIColor(red: 0.10, green: 0.14, blue: 0.30, alpha: 1).cgColor,
                UIColor(red: 0.18, green: 0.13, blue: 0.36, alpha: 1).cgColor,
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1]) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }

            drawCentered("Family Resemblance", at: CGPoint(x: size.width / 2, y: 120),
                         fontSize: 64, weight: .bold, color: .white)

            // Child centered, larger; parents flanking.
            let childCenter = CGPoint(x: size.width / 2, y: 560)
            drawCircularImage(childImage, center: childCenter, radius: 220,
                              ringColor: UIColor.white, in: cg)
            drawCentered("Child", at: CGPoint(x: childCenter.x, y: childCenter.y + 285),
                         fontSize: 40, weight: .semibold, color: .white)

            let parentXs: [CGFloat] = parents.count == 2 ? [190, size.width - 190] : [size.width / 2]
            for (parent, x) in zip(parents, parentXs) {
                let center = CGPoint(x: x, y: 420)
                let ring = parent.isPrimary
                    ? UIColor(red: 0.92, green: 0.75, blue: 0.30, alpha: 1)
                    : UIColor(red: 0.45, green: 0.72, blue: 0.96, alpha: 1)
                drawCircularImage(parent.image, center: center, radius: 130, ringColor: ring, in: cg)
                drawCentered(parent.name, at: CGPoint(x: x, y: center.y + 185),
                             fontSize: 36, weight: .semibold, color: .white)
                drawCentered("\(parent.sharePercent)%", at: CGPoint(x: x, y: center.y + 240),
                             fontSize: 52, weight: .bold, color: ring)
            }

            drawCentered(headline, at: CGPoint(x: size.width / 2, y: 950),
                         fontSize: 44, weight: .semibold,
                         color: UIColor(red: 0.45, green: 0.72, blue: 0.96, alpha: 1),
                         maxWidth: size.width - 160)

            drawCentered("For fun, not science — made with love", at: CGPoint(x: size.width / 2, y: 1120),
                         fontSize: 30, weight: .regular, color: UIColor.white.withAlphaComponent(0.55))
            drawCentered("Similitude", at: CGPoint(x: size.width / 2, y: 1230),
                         fontSize: 46, weight: .bold, color: UIColor.white.withAlphaComponent(0.9))
        }
    }

    private func drawCircularImage(_ image: UIImage, center: CGPoint, radius: CGFloat, ringColor: UIColor, in cg: CGContext) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        cg.saveGState()
        cg.addEllipse(in: rect)
        cg.clip()

        // Aspect-fill inside the circle.
        let imageSize = image.size
        let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        image.draw(in: CGRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        ))
        cg.restoreGState()

        cg.setStrokeColor(ringColor.cgColor)
        cg.setLineWidth(radius * 0.06)
        cg.strokeEllipse(in: rect.insetBy(dx: -radius * 0.03, dy: -radius * 0.03))
    }

    private func drawCentered(_ text: String, at point: CGPoint, fontSize: CGFloat, weight: UIFont.Weight, color: UIColor, maxWidth: CGFloat = 1000) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let bounding = attributed.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin], context: nil
        )
        attributed.draw(with: CGRect(
            x: point.x - maxWidth / 2,
            y: point.y - bounding.height / 2,
            width: maxWidth,
            height: bounding.height
        ), options: [.usesLineFragmentOrigin], context: nil)
    }
}
