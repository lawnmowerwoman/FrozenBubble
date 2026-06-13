import Foundation

enum GameResources {
    private static let resourceBundleName = "FrozenBubbleSwift_FrozenBubbleSwift.bundle"

    static var bundle: Bundle {
        if let appResourceURL = Bundle.main.resourceURL?.appendingPathComponent(resourceBundleName),
           let bundle = Bundle(url: appResourceURL) {
            return bundle
        }

        let appRootURL = Bundle.main.bundleURL.appendingPathComponent(resourceBundleName)
        if let bundle = Bundle(url: appRootURL) {
            return bundle
        }

        return Bundle.module
    }
}
