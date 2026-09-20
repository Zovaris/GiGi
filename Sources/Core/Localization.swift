import Foundation

func L(_ key: String) -> String {
    let language = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
    let selected = language == "system"
        ? Bundle.preferredLocalizations(from: ["en", "es"]).first ?? "en"
        : language
    guard let path = Bundle.main.path(forResource: selected, ofType: "lproj"),
          let bundle = Bundle(path: path) else {
        return NSLocalizedString(key, comment: "")
    }
    return bundle.localizedString(forKey: key, value: key, table: nil)
}
