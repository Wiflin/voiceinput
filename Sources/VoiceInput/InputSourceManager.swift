import Carbon
import Foundation

final class InputSourceManager {
    func switchToASCIIIfNeeded() -> TISInputSource? {
        guard let current = currentInputSource(), isCJKInputSource(current) else {
            return nil
        }

        guard let asciiSource = preferredASCIIInputSource() else {
            return nil
        }

        TISSelectInputSource(asciiSource)
        return current
    }

    func restore(_ source: TISInputSource?) {
        guard let source else { return }
        TISSelectInputSource(source)
    }

    private func currentInputSource() -> TISInputSource? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }
        return source
    }

    private func preferredASCIIInputSource() -> TISInputSource? {
        let preferredIDs = [
            "com.apple.keylayout.ABC",
            "com.apple.keylayout.US"
        ]

        let sources = allInputSources()

        for id in preferredIDs {
            if let source = sources.first(where: {
                stringProperty($0, kTISPropertyInputSourceID) == id
                    && boolProperty($0, kTISPropertyInputSourceIsEnabled)
            }) {
                return source
            }
        }

        return sources.first { source in
            stringProperty(source, kTISPropertyInputSourceType) == (kTISTypeKeyboardLayout as String)
                && boolProperty(source, kTISPropertyInputSourceIsEnabled)
                && supportsASCII(source)
        }
    }

    private func allInputSources() -> [TISInputSource] {
        guard let rawSources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() else {
            return []
        }
        return rawSources as NSArray as? [TISInputSource] ?? []
    }

    private func isCJKInputSource(_ source: TISInputSource) -> Bool {
        let languageCodes = arrayProperty(source, kTISPropertyInputSourceLanguages)
            .compactMap { $0 as? String }
            .map { $0.lowercased() }

        if languageCodes.contains(where: { $0.hasPrefix("zh") || $0.hasPrefix("ja") || $0.hasPrefix("ko") }) {
            return true
        }

        let id = stringProperty(source, kTISPropertyInputSourceID).lowercased()
        let name = stringProperty(source, kTISPropertyLocalizedName).lowercased()
        let cjkMarkers = [
            "pinyin", "wubi", "zhuyin", "cangjie", "stroke", "chinese",
            "hiragana", "katakana", "kotoeri", "japanese",
            "hangul", "korean", "sogou", "baidu", "qq"
        ]
        return cjkMarkers.contains { id.contains($0) || name.contains($0) }
    }

    private func supportsASCII(_ source: TISInputSource) -> Bool {
        guard let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return false
        }
        let data = unsafeBitCast(layoutData, to: CFTypeRef.self)
        return CFGetTypeID(data) == CFDataGetTypeID()
    }

    private func stringProperty(_ source: TISInputSource, _ key: CFString) -> String {
        guard let pointer = TISGetInputSourceProperty(source, key) else {
            return ""
        }
        let value = unsafeBitCast(pointer, to: CFString.self)
        return value as String
    }

    private func arrayProperty(_ source: TISInputSource, _ key: CFString) -> [Any] {
        guard let pointer = TISGetInputSourceProperty(source, key) else {
            return []
        }
        let value = unsafeBitCast(pointer, to: CFArray.self)
        return value as NSArray as? [Any] ?? []
    }

    private func boolProperty(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let pointer = TISGetInputSourceProperty(source, key) else {
            return false
        }
        let value = unsafeBitCast(pointer, to: CFBoolean.self)
        return CFBooleanGetValue(value)
    }
}
