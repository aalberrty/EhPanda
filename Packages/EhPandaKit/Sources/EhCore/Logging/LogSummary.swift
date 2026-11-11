import Foundation

/// One row of the Logs screen: a log file and what its lines say about it.
public struct LogSummary: Sendable, Hashable, Identifiable {
    public let file: LogFile
    /// Number of non-empty lines.
    public let recordCount: Int
    /// The date part (`yyyy-MM-dd`) of the first and last line, when the lines start with one.
    public let firstDate: String?
    public let lastDate: String?

    public var id: String { file.id }

    public init(file: LogFile, recordCount: Int, firstDate: String?, lastDate: String?) {
        self.file = file
        self.recordCount = recordCount
        self.firstDate = firstDate
        self.lastDate = lastDate
    }

    /// Summarises `data`, the contents of `file`, in one pass over its bytes without building
    /// its lines. Lines end at `\n`, `\r`, vertical tab or form feed, so `\r\n` ends one line;
    /// the logger escapes line breaks inside messages, so no other separator occurs.
    init(file: LogFile, data: Data) {
        var count = 0
        var first: Range<Int>?
        var last: Range<Int>?
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            var start = 0
            for index in 0...bytes.count {
                guard index == bytes.count || Self.isLineBreak(bytes[index]) else { continue }
                if index > start {
                    count += 1
                    if first == nil { first = start..<index }
                    last = start..<index
                }
                start = index + 1
            }
        }
        self.init(
            file: file, recordCount: count,
            firstDate: first.flatMap { Self.datePart(of: data, line: $0) },
            lastDate: last.flatMap { Self.datePart(of: data, line: $0) }
        )
    }

    private static func isLineBreak(_ byte: UInt8) -> Bool {
        byte == 0x0A || byte == 0x0D || byte == 0x0B || byte == 0x0C
    }

    /// Lines written by both the new logger and legacy SwiftyBeaver start with
    /// `yyyy-MM-dd HH:mm:ss.SSS`; legacy showed the text before the first space.
    private static func datePart(of data: Data, line: Range<Int>) -> String? {
        let bytes = data[(data.startIndex + line.lowerBound)..<(data.startIndex + line.upperBound)]
        guard let space = bytes.firstIndex(of: 0x20), space > bytes.startIndex else { return nil }
        return String(decoding: bytes[..<space], as: UTF8.self)
    }
}
