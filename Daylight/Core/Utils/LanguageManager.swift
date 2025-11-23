import Foundation
import ObjectiveC.runtime

final class LanguageManager {
    static let shared = LanguageManager()
    private let storageKey = "DaylightSelectedLanguage"

    private init() {}

    var currentLocale: Locale {
        if let code = UserDefaults.standard.string(forKey: storageKey) {
            return Locale(identifier: code)
        }
        return .autoupdatingCurrent
    }

    func applySavedLanguage() {
        let code = UserDefaults.standard.string(forKey: storageKey)
        setLanguage(code)
    }

    func setLanguage(_ code: String?) {
        if let code = code, !code.isEmpty {
            UserDefaults.standard.set(code, forKey: storageKey)
            Bundle.setLanguage(code)
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey)
            Bundle.resetLanguage()
        }
        UserDefaults.standard.synchronize()
    }
}

// MARK: - Bundle swizzle
private var kBundleKey: UInt8 = 0

private class PrivateBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = objc_getAssociatedObject(self, &kBundleKey) as? Bundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

private extension Bundle {
    static func setLanguage(_ language: String) {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return }
        objc_setAssociatedObject(Bundle.main, &kBundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        object_setClass(Bundle.main, PrivateBundle.self)
    }

    static func resetLanguage() {
        objc_setAssociatedObject(Bundle.main, &kBundleKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        object_setClass(Bundle.main, Bundle.self)
    }
}
