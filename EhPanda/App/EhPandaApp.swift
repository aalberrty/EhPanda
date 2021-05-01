//
//  EhPandaApp.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI
import Kingfisher
import SDWebImageSwiftUI

@main
struct EhPandaApp: App {
    @StateObject var store = Store()

    var setting: Setting? {
        store.appState.settings.setting
    }
    var accentColor: Color? {
        setting?.accentColor
    }
    var preferredColorScheme: ColorScheme? {
        setting?.colorScheme ?? .none
    }

    init() {
        configureWebImage()
        clearImageCachesIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            Home()
                .environmentObject(store)
                .accentColor(accentColor)
                .onOpenURL(perform: onOpenURL)
                .preferredColorScheme(preferredColorScheme)
        }
    }

    func onOpenURL(_ url: URL) {
        setEntry(url.host)
    }

    func configureWebImage() {
        let config = KingfisherManager.shared.downloader.sessionConfiguration
        config.httpCookieStorage = HTTPCookieStorage.shared
        KingfisherManager.shared.downloader.sessionConfiguration = config
    }
    func clearImageCachesIfNeeded() {
        let threshold = 200 * 1024 * 1024

        if SDImageCache.shared.totalDiskSize() > threshold {
            SDImageCache.shared.clearDisk()
        }
        KingfisherManager.shared.cache.calculateDiskStorageSize { result in
            if case .success(let size) = result {
                if size > threshold {
                    KingfisherManager.shared.cache.clearDiskCache()
                }
            }
        }
    }
}