import EhModels

// Rules that tie settings together, ported from the legacy app. Each setter enforces the rule
// for the property it changed; `Setting.enforcingRules()` restores the same invariants for a
// whole value (on load and in `apply`).
//
// A rule only assigns when the value really differs: `@Observable` routes a write made inside
// `didSet` back through the setter, so an unconditional write would recurse.

/// The blur radius legacy switches to when auto-lock is enabled with no blur.
let autoLockBlurRadius: Double = 10

extension SettingsStore {
    /// Turning the tags extension off turns off everything that depends on it.
    /// Legacy: `Setting.enablesTagsExtension.didSet` (`Models/Persistent/Setting.swift`).
    func enforceTagsExtensionRule() {
        guard !enablesTagsExtension else { return }
        if translatesTags { translatesTags = false }
        if showsTagsSearchSuggestion { showsTagsSearchSuggestion = false }
        if showsImagesInTags { showsImagesInTags = false }
    }

    /// Choosing an auto-lock time while the blur radius is 0 sets the radius to 10.
    /// Legacy: `SettingReducer` `onChange(of: \.setting.autoLockPolicy)`.
    func enforceAutoLockRule() {
        if autoLockPolicy != .never && backgroundBlurRadius == 0 {
            backgroundBlurRadius = autoLockBlurRadius
        }
    }

    /// Setting the blur radius to 0 turns auto-lock off.
    /// Legacy: `SettingReducer` `onChange(of: \.setting.backgroundBlurRadius)`.
    func enforceBlurRadiusRule() {
        if backgroundBlurRadius == 0 && autoLockPolicy != .never {
            autoLockPolicy = .never
        }
    }

    /// Lowering the maximum zoom below the double-tap zoom lowers the double-tap zoom.
    /// Legacy: `SettingReducer` `onChange(of: \.setting.maximumScaleFactor)`.
    func enforceMaximumScaleFactorRule() {
        if doubleTapScaleFactor > maximumScaleFactor {
            doubleTapScaleFactor = maximumScaleFactor
        }
    }

    /// Raising the double-tap zoom above the maximum zoom raises the maximum.
    /// Legacy: `SettingReducer` `onChange(of: \.setting.doubleTapScaleFactor)`.
    func enforceDoubleTapScaleFactorRule() {
        if maximumScaleFactor < doubleTapScaleFactor {
            maximumScaleFactor = doubleTapScaleFactor
        }
    }
}

extension Setting {
    /// This value with every rule above satisfied.
    ///
    /// When a whole value breaks a rule there is no "changed" field to tell which side wins, so
    /// this picks the outcome that keeps the user's explicit choices safest: auto-lock stays on
    /// (blur becomes 10) and the maximum zoom stays put (double-tap is lowered to it).
    func enforcingRules() -> Setting {
        var setting = self
        if !setting.enablesTagsExtension {
            setting.translatesTags = false
            setting.showsTagsSearchSuggestion = false
            setting.showsImagesInTags = false
        }
        if setting.autoLockPolicy != .never && setting.backgroundBlurRadius == 0 {
            setting.backgroundBlurRadius = autoLockBlurRadius
        }
        if setting.doubleTapScaleFactor > setting.maximumScaleFactor {
            setting.doubleTapScaleFactor = setting.maximumScaleFactor
        }
        return setting
    }
}
