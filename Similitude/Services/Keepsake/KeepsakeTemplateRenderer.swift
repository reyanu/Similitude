import UIKit

enum KeepsakeRenderError: LocalizedError {
    case unsupportedPortraitCount(provided: Int, template: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedPortraitCount(let provided, let template):
            return "\(template) needs a supported number of portraits (got \(provided))."
        }
    }
}

/// Layered keepsake composition:
/// background → portraits (aspect-fill, masked, feathered, back-to-front)
/// → foreground decorations → editable text → watermark (free exports only)
/// → flattened image.
///
/// Real artwork is used when present in the asset catalog; otherwise the
/// programmatic fallback painters supply the layers. No layer ever contains
/// a sample person, and no internal labels or privacy text are drawn into
/// the artwork.
struct KeepsakeTemplateRenderer {

    /// Renders at `scale` × the 1600×2000 canvas (1.0 = export, ~0.35 = preview).
    func render(
        template: KeepsakeTemplate,
        portraits: [UIImage],
        title: String,
        message: String,
        watermarked: Bool,
        scale: CGFloat = 1.0
    ) throws -> UIImage {
        guard let frames = template.frames(for: portraits.count) else {
            throw KeepsakeRenderError.unsupportedPortraitCount(
                provided: portraits.count, template: template.displayName
            )
        }

        let canvas = CGSize(
            width: KeepsakeTemplate.canvasSize.width * scale,
            height: KeepsakeTemplate.canvasSize.height * scale
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let flattened = UIGraphicsImageRenderer(size: canvas, format: format).image { ctx in
            let cg = ctx.cgContext

            // 1. Background
            layerImage(named: template.backgroundAsset, templateID: template.id, isForeground: false)
                .draw(in: CGRect(origin: .zero, size: canvas))

            // 2. Portraits, back-to-front
            for (portrait, frame) in zip(portraits, frames) {
                let scaledFrame = CGRect(
                    x: frame.minX * scale, y: frame.minY * scale,
                    width: frame.width * scale, height: frame.height * scale
                )
                drawMaskedPortrait(portrait, in: scaledFrame, mask: template.portraitMask, context: cg)
            }

            // 3. Foreground decorations
            layerImage(named: template.foregroundAsset ?? "", templateID: template.id, isForeground: true)
                .draw(in: CGRect(origin: .zero, size: canvas))

            // 4. Editable text
            draw(text: title,
                 in: scaledRect(template.titleFrame, scale),
                 fontSize: template.textStyle.titleFontSize * scale,
                 weight: .bold,
                 color: template.textStyle.titleColor,
                 serif: template.textStyle.usesSerif)
            draw(text: message,
                 in: scaledRect(template.messageFrame, scale),
                 fontSize: template.textStyle.messageFontSize * scale,
                 weight: .medium,
                 color: template.textStyle.messageColor,
                 serif: template.textStyle.usesSerif)
        }

        // 5. Watermark for free exports only.
        return watermarked ? WatermarkService().applyWatermark(to: flattened) : flattened
    }

    // MARK: Layers

    /// Asset-catalog artwork wins; fallback painters otherwise.
    private func layerImage(named assetName: String, templateID: String, isForeground: Bool) -> UIImage {
        if !assetName.isEmpty, let asset = UIImage(named: assetName) {
            return asset
        }
        let size = KeepsakeTemplate.canvasSize
        return isForeground
            ? TemplateArtworkFallback.foreground(for: templateID, size: size)
            : TemplateArtworkFallback.background(for: templateID, size: size)
    }

    private func drawMaskedPortrait(_ portrait: UIImage, in frame: CGRect, mask: PortraitMask, context: CGContext) {
        guard let cgPortrait = portrait.cgImage,
              let maskImage = Self.maskImage(for: mask, size: frame.size)?.cgImage else { return }

        context.saveGState()
        context.clip(to: frame, mask: maskImage)

        // Aspect-fill with a slight upward bias so faces sit well in frame.
        let imageSize = CGSize(width: cgPortrait.width, height: cgPortrait.height)
        let fillScale = max(frame.width / imageSize.width, frame.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * fillScale, height: imageSize.height * fillScale)
        let origin = CGPoint(
            x: frame.midX - drawSize.width / 2,
            y: frame.midY - drawSize.height / 2 - (drawSize.height - frame.height) * 0.18
        )
        portrait.draw(in: CGRect(origin: origin, size: drawSize))
        context.restoreGState()
    }

    /// Grayscale mask (white = visible) with feathered edges.
    static func maskImage(for mask: PortraitMask, size: CGSize) -> UIImage? {
        guard size.width > 1, size.height > 1 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            UIColor.black.setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            switch mask {
            case .circle(let featherFraction):
                let radius = min(size.width, size.height) / 2
                let feather = max(1, radius * featherFraction)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let colors = [
                    UIColor.white.cgColor,
                    UIColor.white.cgColor,
                    UIColor.black.cgColor,
                ] as CFArray
                let solidStop = (radius - feather) / radius
                if let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceGray(),
                    colors: colors,
                    locations: [0, solidStop, 1]
                ) {
                    cg.drawRadialGradient(
                        gradient,
                        startCenter: center, startRadius: 0,
                        endCenter: center, endRadius: radius,
                        options: []
                    )
                } else {
                    UIColor.white.setFill()
                    cg.fillEllipse(in: CGRect(origin: .zero, size: size))
                }

            case .roundedRect(let cornerFraction, let featherFraction):
                let corner = min(size.width, size.height) * cornerFraction
                let feather = max(1, min(size.width, size.height) * featherFraction)
                // Solid core plus translucent expanding rings approximate a
                // feathered edge without a blur pass.
                let core = CGRect(origin: .zero, size: size).insetBy(dx: feather, dy: feather)
                UIColor.white.setFill()
                UIBezierPath(roundedRect: core, cornerRadius: corner).fill()
                let ringCount = 6
                for ring in 1...ringCount {
                    let inset = feather * (1 - CGFloat(ring) / CGFloat(ringCount))
                    let alpha = 1 - CGFloat(ring) / CGFloat(ringCount + 1)
                    UIColor(white: 1, alpha: alpha * 0.5).setFill()
                    UIBezierPath(
                        roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset),
                        cornerRadius: corner
                    ).fill()
                }
            }
        }
    }

    // MARK: Text

    private func scaledRect(_ rect: CGRect, _ scale: CGFloat) -> CGRect {
        CGRect(x: rect.minX * scale, y: rect.minY * scale,
               width: rect.width * scale, height: rect.height * scale)
    }

    private func draw(text: String, in rect: CGRect, fontSize: CGFloat, weight: UIFont.Weight, color: UIColor, serif: Bool) {
        guard !text.isEmpty else { return }

        var font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        if serif, let descriptor = font.fontDescriptor.withDesign(.serif) {
            font = UIFont(descriptor: descriptor, size: fontSize)
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]

        // Shrink to fit the frame if needed.
        var attributed = NSAttributedString(string: text, attributes: attributes)
        var bounding = attributed.boundingRect(
            with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin], context: nil
        )
        var currentSize = fontSize
        while bounding.height > rect.height, currentSize > 10 {
            currentSize *= 0.92
            var smaller = UIFont.systemFont(ofSize: currentSize, weight: weight)
            if serif, let descriptor = smaller.fontDescriptor.withDesign(.serif) {
                smaller = UIFont(descriptor: descriptor, size: currentSize)
            }
            attributes[.font] = smaller
            attributed = NSAttributedString(string: text, attributes: attributes)
            bounding = attributed.boundingRect(
                with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin], context: nil
            )
        }

        // Vertically centered within the frame.
        let drawRect = CGRect(
            x: rect.minX,
            y: rect.minY + max(0, (rect.height - bounding.height) / 2),
            width: rect.width,
            height: bounding.height
        )
        attributed.draw(with: drawRect, options: [.usesLineFragmentOrigin], context: nil)
    }
}
