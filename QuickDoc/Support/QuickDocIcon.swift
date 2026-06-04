import Cocoa

enum QuickDocIcon {
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

        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.size = size
        image.isTemplate = false
        return image
    }
}
