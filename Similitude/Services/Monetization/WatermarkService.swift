import UIKit

/// Draws the "Similitude" watermark: bottom-right, white text with a subtle
/// shadow — visible but tasteful. Only the brand word is ever drawn; internal
/// labels (style names, roles, debug text) are never burned into exports.
struct WatermarkService {

    static let watermarkText = "Similitude"

    func applyWatermark(to image: UIImage) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))

            let fontSize = max(16, size.width * 0.045)
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.55)
            shadow.shadowBlurRadius = fontSize * 0.12
            shadow.shadowOffset = CGSize(width: 0, height: fontSize * 0.06)

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.88),
                .shadow: shadow,
            ]

            let text = NSAttributedString(string: Self.watermarkText, attributes: attributes)
            let textSize = text.size()
            let inset = size.width * 0.035
            text.draw(at: CGPoint(
                x: size.width - textSize.width - inset,
                y: size.height - textSize.height - inset
            ))
        }
    }
}
