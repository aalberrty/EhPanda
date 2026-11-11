#if DEBUG
import EhFeatures
import SwiftUI

/// A screen for exercising the reader engine by hand, with a synthetic gallery.
///
/// What to expect from the gallery: page 4 is a very long strip, page 5 an animated GIF, page 8
/// a wide panorama, every 9th page a large original (zooming in should sharpen it), every 6th a
/// landscape page. Every 7th page fails to resolve once and every 11th fails to load once, so
/// both retry paths can be tried.
struct ReaderHarnessView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model = ReaderHarnessModel()

    var body: some View {
        ReaderEngineView(
            configuration: model.configuration, proxy: model.proxy, dataSource: model, delegate: model
        )
        .ignoresSafeArea()
        .overlay(alignment: .top) { status }
        .overlay(alignment: .bottom) {
            if model.isPanelVisible {
                ReaderHarnessPanel(model: model) { dismiss() }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: model.isPanelVisible)
        .statusBarHidden(!model.isPanelVisible)
        .onDisappear { model.stop() }
    }

    private var status: some View {
        VStack(spacing: 2) {
            Text(verbatim: "\(model.currentPage) / \(model.pageCount)")
                .font(.headline.monospacedDigit())
            if model.isPanelVisible {
                ForEach(Array(model.events.enumerated()), id: \.offset) { _, event in
                    Text(verbatim: event).font(.caption2)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
        .padding(.top, 4)
        .allowsHitTesting(false)
    }
}

private struct ReaderHarnessPanel: View {
    @Bindable var model: ReaderHarnessModel
    let close: () -> Void

    @State private var sliderPage = 1.0
    @State private var isDraggingSlider = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                navigation
                Divider()
                layout
                Divider()
                zoomAndLoading
                Divider()
                actions
            }
            .padding(14)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: 520)
        .containerRelativeFrame(.vertical) { height, _ in min(max(height * 0.42, 230), height - 70) }
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
        .padding(.horizontal, 10)
        .font(.footnote)
        .onAppear { sliderPage = Double(model.currentPage) }
        .onChange(of: model.currentPage) { _, page in
            // The slider follows the reader, except while a finger is on it.
            if !isDraggingSlider {
                sliderPage = Double(page)
            }
        }
    }

    private var navigation: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(verbatim: "Go to \(Int(sliderPage))")
                Slider(value: $sliderPage, in: 1...Double(max(model.pageCount, 2)), step: 1) { editing in
                    isDraggingSlider = editing
                    if !editing {
                        model.proxy.scrollToPage(Int(sliderPage))
                    }
                }
            }
            HStack {
                Button("First") { model.proxy.scrollToPage(1) }
                Button("Back (animated)") { model.proxy.scrollToPage(model.currentPage - 1, animated: true) }
                Button("Next (animated)") { model.proxy.advance() }
                Button("Last") { model.proxy.scrollToPage(model.pageCount) }
            }
            .buttonStyle(.bordered)
            Picker("Auto-advance", selection: $model.autoAdvanceInterval) {
                Text(verbatim: "Auto off").tag(0.0)
                ForEach([1.0, 2.0, 3.0], id: \.self) { seconds in
                    Text(verbatim: "\(Int(seconds)) s").tag(seconds)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var layout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Direction", selection: $model.configuration.direction) {
                Text(verbatim: "Vertical").tag(ReaderDirection.vertical)
                Text(verbatim: "Left to right").tag(ReaderDirection.leftToRight)
                Text(verbatim: "Right to left").tag(ReaderDirection.rightToLeft)
            }
            .pickerStyle(.segmented)
            Toggle("Dual page (paged, landscape)", isOn: $model.configuration.allowsDualPage)
            Toggle("Except cover", isOn: $model.configuration.exceptCover)
            Stepper(value: $model.configuration.pageGap, in: 0...20, step: 5) {
                Text(verbatim: "Gap \(Int(model.configuration.pageGap)) pt (vertical)")
            }
            Picker("Pages", selection: Binding(get: { model.pageCount }, set: { model.setPageCount($0) })) {
                ForEach([1, 2, 3, 60, 1_000], id: \.self) { count in
                    Text(verbatim: "\(count)").tag(count)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var zoomAndLoading: some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper(value: $model.configuration.maximumZoomScale, in: 1.5...10, step: 0.5) {
                Text(verbatim: "Maximum zoom \(model.configuration.maximumZoomScale.formatted())×")
            }
            Stepper(value: $model.configuration.doubleTapZoomScale, in: 1.5...5, step: 0.5) {
                Text(verbatim: "Double-tap zoom \(model.configuration.doubleTapZoomScale.formatted())×")
            }
            Stepper(value: $model.configuration.prefetchLimit, in: 6...18, step: 4) {
                Text(verbatim: "Preload limit \(model.configuration.prefetchLimit)")
            }
            Stepper(value: $model.latency, in: 0...4, step: 0.4) {
                Text(verbatim: "Latency \(model.latency.formatted()) s (resolve, then download)")
            }
            Toggle("Host knows aspect ratios", isOn: $model.knowsAspectRatios)
            Toggle(isOn: $model.configuration.isLiveTextEnabled) {
                Text(verbatim: ReaderLiveText.isSupported ? "Live Text" : "Live Text (not supported here)")
            }
        }
    }

    private var actions: some View {
        HStack {
            Button("Reload all") { model.resetPages() }
            Button("Clear image cache") { model.clearImageCache() }
            Spacer()
            Button("Close", role: .cancel, action: close)
        }
        .buttonStyle(.bordered)
    }
}

/// Opens the reader harness. It sits on the placeholder screen in debug builds, and launching
/// the app with `-ReaderHarness YES` opens the harness straight away. The rows under it open
/// a real gallery in the reader (see `ReaderDebugLauncher`).
struct ReaderHarnessLauncher: View {
    private static var hasOpenedAtLaunch = false

    @State private var isPresented = false

    var body: some View {
        Button("Reader harness") { isPresented = true }
            .buttonStyle(.borderedProminent)
            .fullScreenCover(isPresented: $isPresented) { ReaderHarnessView() }
            .onAppear {
                guard !Self.hasOpenedAtLaunch, UserDefaults.standard.bool(forKey: "ReaderHarness") else { return }
                Self.hasOpenedAtLaunch = true
                isPresented = true
            }
        ReaderDebugLauncher()
    }
}
#endif
