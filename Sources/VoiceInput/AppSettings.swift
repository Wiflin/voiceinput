import Foundation

enum LanguageOption: String, CaseIterable {
    case english = "en-US"
    case simplifiedChinese = "zh-CN"
    case traditionalChinese = "zh-TW"
    case japanese = "ja-JP"
    case korean = "ko-KR"

    var title: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "Simplified Chinese"
        case .traditionalChinese: "Traditional Chinese"
        case .japanese: "Japanese"
        case .korean: "Korean"
        }
    }
}

final class AppSettings {
    static let shared = AppSettings()

    private enum Key {
        static let language = "language"
        static let inputDeviceUID = "audio.inputDeviceUID"
        static let llmEnabled = "llm.enabled"
        static let apiBaseURL = "llm.apiBaseURL"
        static let apiKey = "llm.apiKey"
        static let model = "llm.model"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.language: LanguageOption.simplifiedChinese.rawValue,
            Key.inputDeviceUID: "",
            Key.llmEnabled: false,
            Key.apiBaseURL: "https://api.openai.com/v1",
            Key.apiKey: "",
            Key.model: "gpt-4o-mini"
        ])
    }

    var language: LanguageOption {
        get {
            LanguageOption(rawValue: defaults.string(forKey: Key.language) ?? "") ?? .simplifiedChinese
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.language)
        }
    }

    var inputDeviceUID: String? {
        get {
            let value = defaults.string(forKey: Key.inputDeviceUID) ?? ""
            return value.isEmpty ? nil : value
        }
        set {
            defaults.set(newValue ?? "", forKey: Key.inputDeviceUID)
        }
    }

    var llmEnabled: Bool {
        get { defaults.bool(forKey: Key.llmEnabled) }
        set { defaults.set(newValue, forKey: Key.llmEnabled) }
    }

    var apiBaseURL: String {
        get { defaults.string(forKey: Key.apiBaseURL) ?? "" }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.apiBaseURL) }
    }

    var apiKey: String {
        get { defaults.string(forKey: Key.apiKey) ?? "" }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.apiKey) }
    }

    var model: String {
        get { defaults.string(forKey: Key.model) ?? "" }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.model) }
    }

    var isLLMConfigured: Bool {
        !apiBaseURL.isEmpty && !apiKey.isEmpty && !model.isEmpty
    }
}
