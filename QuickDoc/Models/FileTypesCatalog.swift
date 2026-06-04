import Foundation

let quickDocFileTypes: [FileType] = [
    FileType(id: "txt", title: "TXT", menuTitle: "新建 TXT 文件", pathExtension: "txt", enabledByDefault: true),
    FileType(id: "md", title: "Markdown (.md)", menuTitle: "新建 Markdown 文件", pathExtension: "md", enabledByDefault: true),
    FileType(id: "docx", title: "Word (.docx)", menuTitle: "新建 Word 文档", pathExtension: "docx", enabledByDefault: true),
    FileType(id: "xlsx", title: "Excel (.xlsx)", menuTitle: "新建 Excel 表格", pathExtension: "xlsx", enabledByDefault: true),
    FileType(id: "csv", title: "CSV", menuTitle: "新建 CSV 表格", pathExtension: "csv", enabledByDefault: true),
    FileType(id: "pptx", title: "PowerPoint (.pptx)", menuTitle: "新建 PowerPoint 演示文稿", pathExtension: "pptx", enabledByDefault: true),
    FileType(id: "json", title: "JSON", menuTitle: "新建 JSON 文件", pathExtension: "json", enabledByDefault: true),
    FileType(id: "blank", title: "空白文件", menuTitle: "新建空白文件", pathExtension: nil, enabledByDefault: true),
    FileType(id: "py", title: "Python (.py)", menuTitle: "新建 Python 文件", pathExtension: "py", enabledByDefault: false),
    FileType(id: "html", title: "HTML", menuTitle: "新建 HTML 文件", pathExtension: "html", enabledByDefault: false),
    FileType(id: "sh", title: "Shell (.sh)", menuTitle: "新建 Shell 文件", pathExtension: "sh", enabledByDefault: false),
    FileType(id: "rtf", title: "Rich Text (.rtf)", menuTitle: "新建 RTF 文件", pathExtension: "rtf", enabledByDefault: false)
]
