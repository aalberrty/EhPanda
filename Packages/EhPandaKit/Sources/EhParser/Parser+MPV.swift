import EhModels
import Foundation
import Kanna

// MARK: MPV

extension Parser {
    /// The multi-page viewer key and the per-page image keys (keyed by 1-based index) from
    /// the MPV page's script.
    public static func parseMPVKeys(doc: HTMLDocument) throws -> (String, [Int: String]) {
        var tmpMPVKey: String?
        var imgKeys = [Int: String]()

        for link in doc.xpath("//script [@type='text/javascript']") {
            guard let text = link.text,
                  let rangeA = text.range(of: "mpvkey = \""),
                  let rangeB = text.range(of: "\";\nvar imagelist = "),
                  let rangeC = text.range(of: "\"}]"),
                  rangeA.upperBound <= rangeB.lowerBound,
                  rangeB.upperBound <= rangeC.upperBound
            else { continue }

            tmpMPVKey = String(text[rangeA.upperBound..<rangeB.lowerBound])

            guard let data = String(text[rangeB.upperBound..<rangeC.upperBound])
                .replacingOccurrences(of: "\\/", with: "/")
                .replacingOccurrences(of: "\n", with: "")
                .data(using: .utf8),
                let array = try? JSONSerialization.jsonObject(with: data) as? [[String: String]]
            else { throw AppError.parseFailed }

            array.enumerated().forEach { index, dict in
                if let imgKey = dict["k"] {
                    imgKeys[index + 1] = imgKey
                }
            }
        }

        guard let mpvKey = tmpMPVKey, !imgKeys.isEmpty
        else { throw AppError.parseFailed }

        return (mpvKey, imgKeys)
    }

    /// Decodes the `imagedispatch` API response (legacy `GalleryMPVImageURLRequest`).
    ///
    /// - Parameter host: the site the request went to; the original image path (`lf`) is
    ///   relative to it.
    /// - Returns: the image URL, the original image URL if offered, and the skip-server
    ///   identifier for a reload.
    public static func parseGalleryMPVImageURL(data: Data, host: GalleryHost) throws -> (URL, URL?, String) {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let imageURLString = dict["i"] as? String,
              let imageURL = URL(string: imageURLString)
        else { throw AppError.parseFailed }

        var skipServerIdentifier: String?

        if let integerIdentifier = dict["s"] as? Int {
            skipServerIdentifier = integerIdentifier.description
        } else if let stringIdentifier = dict["s"] as? String {
            skipServerIdentifier = stringIdentifier
        }

        guard let skipServerIdentifier else { throw AppError.parseFailed }

        if let originalImageURLStringSlice = dict["lf"] as? String {
            let originalImageURL = host.url.appendingPathComponent(originalImageURLStringSlice)
            return (imageURL, originalImageURL, skipServerIdentifier)
        } else {
            return (imageURL, nil, skipServerIdentifier)
        }
    }
}
