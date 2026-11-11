import EhModels
import Foundation
import Kanna

// MARK: Archive

extension Parser {
    /// The H@H archive options on an archiver page.
    public static func parseGalleryArchive(doc: HTMLDocument) throws -> GalleryArchive {
        guard let node = doc.at_xpath("//table")
        else { throw AppError.parseFailed }

        var hathArchives = [GalleryArchive.HathArchive]()
        for link in node.xpath("//td") {
            if let archive = parseHathArchive(node: link) {
                hathArchives.append(archive)
            }
        }

        return GalleryArchive(hathArchives: hathArchives)
    }

    private static func parseHathArchive(node: Kanna.XMLElement) -> GalleryArchive.HathArchive? {
        var tmpResolution: ArchiveResolution?
        var tmpFileSize: String?
        var tmpGPPrice: String?

        for pLink in node.xpath("//p") {
            if let pText = pLink.text {
                if let res = ArchiveResolution(rawValue: pText) {
                    tmpResolution = res
                }
                if pText.contains("N/A") {
                    tmpFileSize = "N/A"
                    tmpGPPrice = "N/A"

                    if tmpResolution != nil {
                        break
                    }
                } else {
                    if pText.contains("KiB")
                        || pText.contains("MiB")
                        || pText.contains("GiB")
                    {
                        tmpFileSize = pText
                    } else {
                        tmpGPPrice = pText
                    }
                }
            }
        }

        guard let resolution = tmpResolution,
              let fileSize = tmpFileSize,
              let gpPrice = tmpGPPrice
        else { return nil }

        return GalleryArchive.HathArchive(resolution: resolution, fileSize: fileSize, gpPrice: gpPrice)
    }

    /// The user's gallery points and credits as printed on the archiver page, without
    /// thousands separators.
    public static func parseCurrentFunds(doc: HTMLDocument) throws -> (String, String) {
        var tmpGP: String?
        var tmpCredits: String?

        for element in doc.xpath("//p") {
            if let text = element.text,
               let rangeA = text.range(of: "GP"),
               let rangeB = text.range(of: "[?]"),
               let rangeC = text.range(of: "Credits"),
               rangeB.upperBound <= rangeC.lowerBound
            {
                tmpGP = String(text[..<rangeA.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: ",", with: "")
                tmpCredits = String(text[rangeB.upperBound..<rangeC.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: ",", with: "")
            }
        }

        guard let galleryPoints = tmpGP, let credits = tmpCredits
        else { throw AppError.parseFailed }

        return (galleryPoints, credits)
    }

    /// The message the archiver shows after a H@H download command, condensed to
    /// `"<resolution> -> <client>"` when it has that shape.
    public static func parseDownloadCommandResponse(doc: HTMLDocument) throws -> String {
        guard let dbNode = doc.at_xpath("//div [@id='db']")
        else { throw AppError.parseFailed }

        var response = [String]()
        for pLink in dbNode.xpath("//p") {
            if let pText = pLink.text {
                response.append(pText)
            }
        }

        var respString = response.joined(separator: " ")

        if let rangeA = respString.range(of: "A ") ?? respString.range(of: "An "),
           let rangeB = respString.range(of: "resolution"),
           let rangeC = respString.range(of: "client"),
           let rangeD = respString.range(of: "Downloads"),
           rangeA.upperBound <= rangeB.lowerBound,
           rangeC.upperBound <= rangeD.lowerBound
        {
            let resp = String(respString[rangeA.upperBound..<rangeB.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .firstLetterCapitalized

            if ArchiveResolution(rawValue: resp) != nil {
                let clientName = String(respString[rangeC.upperBound..<rangeD.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !clientName.isEmpty {
                    respString = resp + " -> " + clientName
                } else {
                    respString = resp
                }
            }
        }

        return respString
    }
}
