import Foundation

/// A model with one date the UI shows; the app formats it.
public protocol DateFormattable {
    var originalDate: Date { get }
}
