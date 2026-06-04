import Foundation

struct ProcessResult {
    let exitCode: Int32
    let output: String
    let error: String

    var errorDescription: String? {
        if !error.isEmpty {
            return error
        }

        if !output.isEmpty {
            return output
        }

        return nil
    }
}

func readPipe(_ pipe: Pipe) -> String {
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}
