#if DEBUG
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Draws the numbered test pages of the reader harness. Everything is generated on demand, off
/// the main actor, so the harness needs no bundled images.
nonisolated enum ReaderHarnessImages {
    struct Spec {
        var pixelSize: CGSize
        var isAnimated = false
        var label: String

        var aspectRatio: CGFloat { pixelSize.width / pixelSize.height }
        var fileExtension: String { isAnimated ? "gif" : "jpg" }
    }

    /// Mostly ordinary portrait pages, plus the shapes that tend to break readers.
    static func spec(forPage page: Int) -> Spec {
        switch page {
        case 4:
            return Spec(pixelSize: CGSize(width: 800, height: 9_000), label: "long strip")
        case 5:
            return Spec(pixelSize: CGSize(width: 600, height: 800), isAnimated: true, label: "animated GIF")
        case 8:
            return Spec(pixelSize: CGSize(width: 2_400, height: 900), label: "wide")
        default:
            break
        }
        if page % 9 == 0 {
            return Spec(pixelSize: CGSize(width: 3_200, height: 4_500), label: "large original")
        }
        if page % 6 == 0 {
            return Spec(pixelSize: CGSize(width: 1_920, height: 1_280), label: "landscape")
        }
        if page % 4 == 3 {
            return Spec(pixelSize: CGSize(width: 1_280, height: 2_000), label: "tall")
        }
        return Spec(pixelSize: CGSize(width: 1_280, height: 1_810), label: "portrait")
    }

    /// The encoded image for a page: a JPEG, or a GIF for the animated page.
    static func data(forPage page: Int) -> Data? {
        let spec = spec(forPage: page)
        guard spec.isAnimated else {
            return render(page: page, spec: spec, frame: 0).jpegData(compressionQuality: 0.8)
        }
        let frameCount = 8
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.gif.identifier as CFString, frameCount, nil
        ) else { return nil }
        let loop = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]]
        CGImageDestinationSetProperties(destination, loop as CFDictionary)
        let delay = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.12]]
        for frame in 0..<frameCount {
            guard let image = render(page: page, spec: spec, frame: frame).cgImage else { return nil }
            CGImageDestinationAddImage(destination, image, delay as CFDictionary)
        }
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    private static func render(page: Int, spec: Spec, frame: Int) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let size = spec.pixelSize
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let hue = CGFloat((page * 47) % 360) / 360
            UIColor(hue: hue, saturation: 0.3, brightness: 0.96, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            drawGrid(in: context.cgContext, size: size)
            drawRulers(size: size)
            drawNumbers(page: page, spec: spec)
            if spec.isAnimated {
                // A block that walks across the page, so it is obvious whether frames advance.
                let step = (size.width - 120) / 7
                UIColor.black.withAlphaComponent(0.6).setFill()
                context.fill(CGRect(x: CGFloat(frame) * step, y: size.height - 140, width: 120, height: 80))
            }
            UIColor.black.withAlphaComponent(0.5).setStroke()
            context.stroke(CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4))
        }
    }

    /// One-pixel lines every 100 pixels: they blur visibly when a page is shown below its resolution.
    private static func drawGrid(in context: CGContext, size: CGSize) {
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.15).cgColor)
        context.setLineWidth(1)
        for x in stride(from: 100, to: size.width, by: 100) {
            context.move(to: CGPoint(x: x + 0.5, y: 0))
            context.addLine(to: CGPoint(x: x + 0.5, y: size.height))
        }
        for y in stride(from: 100, to: size.height, by: 100) {
            context.move(to: CGPoint(x: 0, y: y + 0.5))
            context.addLine(to: CGPoint(x: size.width, y: y + 0.5))
        }
        context.strokePath()
    }

    /// Small text down the left edge, for judging sharpness when zoomed in.
    private static func drawRulers(size: CGSize) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .regular),
            .foregroundColor: UIColor.black.withAlphaComponent(0.7)
        ]
        for y in stride(from: 0, to: size.height, by: 200) {
            ("y \(Int(y))  The quick brown fox 0123456789" as NSString)
                .draw(at: CGPoint(x: 16, y: y + 8), withAttributes: attributes)
        }
    }

    /// The page number, repeated down long pages so that some of it is always on screen.
    private static func drawNumbers(page: Int, spec: Spec) {
        let size = spec.pixelSize
        let fontSize = min(size.width * 0.45, 600)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let number: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .heavy),
            .foregroundColor: UIColor.black.withAlphaComponent(0.8),
            .paragraphStyle: style
        ]
        let caption: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 44, weight: .semibold),
            .foregroundColor: UIColor.black.withAlphaComponent(0.7),
            .paragraphStyle: style
        ]
        let blockHeight = fontSize * 1.2 + 70
        let spacing = max(blockHeight * 1.6, 1_600)
        let count = max(Int((size.height / spacing).rounded(.down)), 1)
        for index in 0..<count {
            let centre = size.height * (CGFloat(index) + 0.5) / CGFloat(count)
            let top = centre - blockHeight / 2
            ("\(page)" as NSString).draw(
                in: CGRect(x: 0, y: top, width: size.width, height: fontSize * 1.2), withAttributes: number
            )
            let text = "\(spec.label) · \(Int(size.width))×\(Int(size.height))"
            (text as NSString).draw(
                in: CGRect(x: 0, y: top + fontSize * 1.2, width: size.width, height: 60), withAttributes: caption
            )
        }
    }
}
#endif
