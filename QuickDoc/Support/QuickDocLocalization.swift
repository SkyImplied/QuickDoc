import Foundation

extension Notification.Name {
    static let quickDocLanguageDidChange = Notification.Name("QuickDocLanguageDidChange")
}

enum QuickDocLocalization {
    static let supportedCodes = ["zh-Hans", "zh-Hant", "en", "ja"]
    static let hostBundleIdentifier = "com.skyimplied.QuickDoc"
    static let extensionBundleIdentifier = "com.skyimplied.QuickDoc.FinderSync"
    static let loginItemBundleIdentifier = "com.skyimplied.QuickDoc.LoginItem"

    /// Preview and tests set this in memory. It is never written to preferences.
    static var previewOverride: String?

    private static var storedChoice: StoredChoice?
    private static var didLoadStoredChoice = false
    private static var tables: [String: [String: String]]?
    private static let lock = NSLock()

    private enum StoredChoice {
        case system
        case language(String)
    }

    static func text(_ key: String) -> String {
        let code = resolvedCode()
        if let value = table(for: code)[key], !value.isEmpty {
            return value
        }
        if code != "en", let english = table(for: "en")[key], !english.isEmpty {
            return english
        }
        return key
    }

    static func format(_ key: String, _ args: [CVarArg]) -> String {
        String(format: text(key), locale: Locale(identifier: resolvedCode()), arguments: args)
    }

    static func resolvedCode() -> String {
        resolvedCode(preferredLanguages: Locale.preferredLanguages)
    }

    static func resolvedCode(preferredLanguages: [String]) -> String {
        if let previewOverride, supportedCodes.contains(previewOverride) {
            return previewOverride
        }
        loadStoredChoiceIfNeeded()
        if case .language(let code) = storedChoice, supportedCodes.contains(code) {
            return code
        }
        return code(matchingPreferred: preferredLanguages)
    }

    static func explicitChoice() -> String? {
        if previewOverride != nil {
            return nil
        }
        loadStoredChoiceIfNeeded()
        if case .language(let code) = storedChoice {
            return code
        }
        return nil
    }

    static func select(_ code: String?) {
        if let code {
            guard supportedCodes.contains(code) else { return }
            storedChoice = .language(code)
        } else {
            storedChoice = .system
        }
        didLoadStoredChoice = true
        persist(code)
        NotificationCenter.default.post(name: .quickDocLanguageDidChange, object: nil)
    }

    static func code(matching identifier: String) -> String? {
        let parts = identifier
            .replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
            .map(String.init)
        guard let language = parts.first?.lowercased() else { return nil }
        let markers = Set(parts.map { $0.lowercased() })
        let region = parts.dropFirst().first { $0.count == 2 && $0.allSatisfy(\.isLetter) }?.uppercased()
        switch language {
        case "zh":
            // An explicit script wins over the region. zh-Hans-HK is Simplified
            // Chinese used with a Hong Kong region, not Traditional Chinese.
            if markers.contains("hans") {
                return "zh-Hans"
            }
            if markers.contains("hant") || region == "TW" || region == "HK" || region == "MO" {
                return "zh-Hant"
            }
            return "zh-Hans"
        case "ja":
            return "ja"
        case "en":
            return "en"
        default:
            return nil
        }
    }

    static func code(matchingPreferred identifiers: [String]) -> String {
        for identifier in identifiers {
            if let code = code(matching: identifier) {
                return code
            }
        }
        return "en"
    }

    private static func table(for code: String) -> [String: String] {
        lock.lock()
        defer { lock.unlock() }
        if tables == nil {
            tables = loadTables()
        }
        return tables?[code] ?? [:]
    }

    private static func loadTables() -> [String: [String: String]] {
        let candidates = catalogURLs()
        for url in candidates {
            guard let data = try? Data(contentsOf: url),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: [String: String]] else {
                continue
            }
            return object
        }
        return [:]
    }

    private static func catalogURLs() -> [URL] {
        var urls: [URL] = []
        if let override = ProcessInfo.processInfo.environment["QUICKDOC_LOCALIZATION_FILE"], !override.isEmpty {
            urls.append(URL(fileURLWithPath: override))
        }
        if let bundled = Bundle.main.url(forResource: "QuickDocLocalizable", withExtension: "json") {
            urls.append(bundled)
        }
        if let bundled = Bundle(for: LocalizationAnchor.self).url(forResource: "QuickDocLocalizable", withExtension: "json") {
            urls.append(bundled)
        }
        return urls
    }

    private static func loadStoredChoiceIfNeeded() {
        guard !didLoadStoredChoice else { return }
        didLoadStoredChoice = true
        #if SIDEBAR_PREVIEW
        storedChoice = .system
        return
        #else
        let languages = appleLanguages(inDomain: preferenceDomains()[0])
        if let first = languages.first, let code = code(matching: first), supportedCodes.contains(code) {
            storedChoice = .language(code)
        } else if languages.isEmpty {
            storedChoice = .system
        } else {
            storedChoice = .system
        }
        #endif
    }

    private static func persist(_ code: String?) {
        #if SIDEBAR_PREVIEW
        return
        #else
        let value = code.map { [$0] as CFArray }
        for domain in preferenceDomains() {
            CFPreferencesSetAppValue("AppleLanguages" as CFString, value, domain as CFString)
            CFPreferencesAppSynchronize(domain as CFString)
        }
        #endif
    }

    private static var preferencesDomainOverride: String?

    static func useIsolatedPreferencesDomainForTesting(_ domain: String) {
        preferencesDomainOverride = domain
        storedChoice = nil
        didLoadStoredChoice = false
    }

    static func reloadStoredChoiceForTesting() {
        storedChoice = nil
        didLoadStoredChoice = false
        loadStoredChoiceIfNeeded()
    }

    static func clearIsolatedPreferencesDomainForTesting() {
        if let domain = preferencesDomainOverride {
            CFPreferencesSetAppValue("AppleLanguages" as CFString, nil, domain as CFString)
            CFPreferencesAppSynchronize(domain as CFString)
            let url = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Preferences/\(domain).plist")
            try? FileManager.default.removeItem(at: url)
        }
        preferencesDomainOverride = nil
        storedChoice = nil
        didLoadStoredChoice = false
    }

    private static func preferenceDomains() -> [String] {
        if let preferencesDomainOverride {
            return [preferencesDomainOverride]
        }
        return [hostBundleIdentifier, extensionBundleIdentifier, loginItemBundleIdentifier]
    }

    private static func appleLanguages(inDomain domain: String) -> [String] {
        let domainName = domain as CFString
        CFPreferencesAppSynchronize(domainName)
        // Read this application domain only. CFPreferencesCopyAppValue also
        // searches the global domain and would treat the system language list
        // as an explicit per-app choice.
        guard let value = CFPreferencesCopyValue(
            "AppleLanguages" as CFString,
            domainName,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        ) else {
            return []
        }
        if let languages = value as? [String] {
            return languages
        }
        return []
    }
}

private final class LocalizationAnchor {}

func L(_ key: String) -> String {
    QuickDocLocalization.text(key)
}

func LF(_ key: String, _ args: CVarArg...) -> String {
    QuickDocLocalization.format(key, args)
}
