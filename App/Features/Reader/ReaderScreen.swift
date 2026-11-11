import Dependencies
import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// The full-screen reader for a gallery (legacy `ReadingView`). Present it with
/// `fullScreenCover`. `initialPage` is 1-based; nil opens at the stored reading progress.
///
/// Three layers: the background, the UIKit reading engine, and the control panel on top.
/// The engine view reads the reading settings and nothing of the panel, so showing the panel,
/// dragging the slider or turning a page never re-renders it.
struct ReaderScreen: View {
    @State private var model: ReaderModel
    @State private var bridge: ReaderEngineBridge

    init(gallery: Gallery, initialPage: Int? = nil) {
        let model = withDependencies {
            // Copy, save and share take the bytes the reader already has on disk.
            $0.imageCacheClient.imageData = { url in try await ReaderImageData.load(url) }
        } operation: {
            ReaderModel(gallery: gallery, initialPage: initialPage)
        }
        _model = State(initialValue: model)
        _bridge = State(initialValue: ReaderEngineBridge(model: model))
    }

    var body: some View {
        ZStack {
            // What the engine paints behind its pages, here while the stored pages are read.
            Color(uiColor: .readerBackground).ignoresSafeArea()
            ReaderEngineHost(model: model, bridge: bridge)
            ReaderControlPanel(model: model)
        }
        .modifier(ReaderChrome(model: model))
        .task { await model.start() }
        .onDisappear { model.close() }
    }
}

/// The engine, configured from the individual reading settings so a change applies live.
private struct ReaderEngineHost: View {
    let model: ReaderModel
    let bridge: ReaderEngineBridge

    @Environment(SettingsStore.self) private var settings

    var body: some View {
        if model.isReady {
            ReaderEngineView(
                configuration: configuration, initialPage: model.initialPage,
                proxy: bridge.proxy, dataSource: bridge, delegate: bridge
            )
            .ignoresSafeArea()
        }
    }

    private var configuration: ReaderConfiguration {
        ReaderConfiguration(
            direction: direction,
            allowsDualPage: settings.enablesDualPageMode,
            exceptCover: settings.exceptCover,
            pageGap: settings.contentDividerHeight,
            maximumZoomScale: settings.maximumScaleFactor,
            doubleTapZoomScale: settings.doubleTapScaleFactor,
            prefetchLimit: settings.prefetchLimit,
            isLiveTextEnabled: model.isLiveTextEnabled
        )
    }

    private var direction: ReaderDirection {
        switch settings.readingDirection {
        case .vertical: .vertical
        case .rightToLeft: .rightToLeft
        case .leftToRight: .leftToRight
        }
    }
}

/// Everything around the reader that follows the model: status bar, sheets, HUD and haptics.
/// A modifier, so its updates do not run the screen's body.
private struct ReaderChrome: ViewModifier {
    @Bindable var model: ReaderModel

    @Environment(SettingsStore.self) private var settings

    func body(content: Content) -> some View {
        content
            // Legacy: the status bar shows with the control panel.
            .statusBarHidden(!model.showsPanel)
            .sheet(item: $model.destination) { destination in
                switch destination {
                case .settings:
                    ReaderSettingsSheet(showsLandscapeSetting: model.showsLandscapeSetting)
                        .tint(settings.accentColor.color)
                case .share(let file):
                    ActivityView(items: [file])
                        .presentationDetents([.medium, .large])
                }
            }
            .hud(notice)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: model.showsSliderPreview)
            .sensoryFeedback(.impact(weight: .light), trigger: model.destination) { _, destination in
                destination != nil
            }
            .onChange(of: settings.enablesLandscape) { _, isEnabled in
                model.enablesLandscapeDidChange(isEnabled)
            }
        #if DEBUG
            .onChange(of: model.timeToFirstPage) { _, time in
                if let time {
                    ReaderDebugSession.shared.record(firstPage: time, gid: model.gallery.gid)
                }
            }
        #endif
    }

    private var notice: Binding<HUDConfiguration?> {
        Binding(
            get: { model.notice?.hud },
            set: { if $0 == nil { model.notice = nil } }
        )
    }
}
