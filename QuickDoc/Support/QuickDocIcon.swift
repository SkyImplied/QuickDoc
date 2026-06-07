import Cocoa

enum QuickDocIcon {
    private struct CacheKey: Hashable {
        let resourceName: String
        let width: Int
        let height: Int
    }

    private static let builtInIconResourceNames: [String: String] = [
        "txt": "txt",
        "md": "md",
        "docx": "word_icon",
        "xlsx": "excel",
        "csv": "CSV",
        "pptx": "PPT",
        "json": "json",
        "blank": "空白",
        "py": "python",
        "html": "html",
        "sh": "shell",
        "rtf": "rtf"
    ]
    @MainActor private static var cache: [CacheKey: NSImage] = [:]

    @MainActor
    static func icon(for id: String, size: NSSize) -> NSImage? {
        let resourceName: String
        if let builtInResourceName = builtInIconResourceNames[id] {
            resourceName = builtInResourceName
        } else if id.hasPrefix("custom.") {
            resourceName = "空白"
        } else {
            return nil
        }

        let cacheKey = CacheKey(
            resourceName: resourceName,
            width: Int(size.width.rounded()),
            height: Int(size.height.rounded())
        )
        if let cachedImage = cache[cacheKey] {
            return cachedImage
        }

        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.size = size
        image.isTemplate = false
        cache[cacheKey] = image
        return image
    }
}
