import UIKit

/// What a page shows while it has no image: its number, and a spinner, a progress bar or a
/// retry button underneath (the legacy placeholder, rebuilt without SwiftUI).
final class ReaderPageStatusView: UIView {
    enum Mode: Equatable {
        /// The image URL is being resolved.
        case resolving
        /// The image is downloading or decoding.
        case loading
        /// Resolving or loading failed.
        case failed
    }

    var onRetry: (() -> Void)?

    private let numberLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let retryButton = UIButton(type: .system)
    private var mode: Mode?

    /// In a very long page the middle can be screens away, so the content stays near the top.
    private static let maximumCenterY: CGFloat = 400
    private static let indicatorHeight: CGFloat = 44
    private static let spacing: CGFloat = 16

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .readerBackground

        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
        numberLabel.font = UIFont(descriptor: descriptor.withSymbolicTraits(.traitBold) ?? descriptor, size: 0)
        numberLabel.adjustsFontForContentSizeCategory = true
        numberLabel.textColor = .systemGray
        numberLabel.textAlignment = .center
        addSubview(numberLabel)

        spinner.hidesWhenStopped = true
        addSubview(spinner)

        progressView.isHidden = true
        addSubview(progressView)

        let symbol = UIImage(
            systemName: "exclamationmark.arrow.triangle.2.circlepath",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        )
        retryButton.setImage(symbol, for: .normal)
        retryButton.tintColor = .systemGray
        retryButton.accessibilityLabel = L10n.Localizable.ErrorView.Button.retry
        retryButton.isHidden = true
        retryButton.addAction(UIAction { [weak self] _ in self?.onRetry?() }, for: .primaryActionTriggered)
        addSubview(retryButton)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setPageNumber(_ page: Int) {
        numberLabel.text = String(page)
        setNeedsLayout()
    }

    func setMode(_ newMode: Mode) {
        guard newMode != mode else { return }
        mode = newMode
        retryButton.isHidden = newMode != .failed
        progressView.isHidden = newMode != .loading
        if newMode == .loading {
            progressView.setProgress(0, animated: false)
        }
        if newMode == .resolving {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
    }

    func setProgress(_ fraction: Float) {
        progressView.setProgress(fraction, animated: false)
    }

    /// Stops the spinner while the view is hidden or waiting in the reuse pool.
    func pause() {
        mode = nil
        spinner.stopAnimating()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let labelHeight = numberLabel.sizeThatFits(bounds.size).height
        let groupHeight = labelHeight + Self.spacing + Self.indicatorHeight
        let centerY = min(bounds.midY, Self.maximumCenterY)
        let top = max(centerY - groupHeight / 2, 0)
        numberLabel.frame = CGRect(x: 0, y: top, width: bounds.width, height: labelHeight)

        let indicatorCenter = CGPoint(x: bounds.midX, y: top + labelHeight + Self.spacing + Self.indicatorHeight / 2)
        spinner.center = indicatorCenter
        retryButton.bounds = CGRect(x: 0, y: 0, width: 64, height: Self.indicatorHeight)
        retryButton.center = indicatorCenter

        let progressWidth = min(bounds.width / 2, 280)
        let progressHeight = progressView.sizeThatFits(CGSize(width: progressWidth, height: .greatestFiniteMagnitude)).height
        progressView.frame = CGRect(
            x: bounds.midX - progressWidth / 2, y: indicatorCenter.y - progressHeight / 2,
            width: progressWidth, height: progressHeight
        )
    }
}
