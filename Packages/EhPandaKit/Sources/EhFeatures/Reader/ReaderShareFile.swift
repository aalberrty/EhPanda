import Foundation

/// A page's image as a file for the share sheet.
///
/// The sheet is given the original bytes under a name with the right extension, so the
/// receiving app gets the image as the site served it (an animated GIF stays animated) and
/// the system can offer "Save Image". Legacy shared a decoded `UIImage`, or the GIF data
/// without a type.
nonisolated enum ReaderShareFile {
    /// Writes `data` to a file in a folder of its own and returns the file's URL.
    @concurrent
    static func write(_ data: Data, gid: String, page: Int) async throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "ReaderShare/\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "\(gid)-\(page).\(fileExtension(for: data))"
        let url = directory.appending(path: name, directoryHint: .notDirectory)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Deletes a file made by `write` together with its folder, so no page image outlives the
    /// reader in the temporary directory.
    @concurrent
    static func remove(_ file: URL) async {
        try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
    }

    /// The extension for image data, from its first bytes. The site serves JPEG, PNG, GIF and WebP.
    static func fileExtension(for data: Data) -> String {
        let bytes = [UInt8](data.prefix(12))
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "png" }
        if bytes.starts(with: [0x47, 0x49, 0x46, 0x38]) { return "gif" }
        if bytes.count >= 12, bytes.starts(with: [0x52, 0x49, 0x46, 0x46]),
           Array(bytes[8..<12]) == [0x57, 0x45, 0x42, 0x50]
        {
            return "webp"
        }
        return "jpg"
    }
}
