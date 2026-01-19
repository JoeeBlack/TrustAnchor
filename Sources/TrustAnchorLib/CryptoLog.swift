import Foundation
import CryptoKit

public actor AuditLogger {
    private let logFileURL: URL
    private var lastHashData: Data?
    private let encoder: JSONEncoder
    private let fileHandle: FileHandle

    public init(logFileURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        self.encoder = encoder
        self.logFileURL = logFileURL

        // Initialize file if not exists
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }

        // Open file handle for writing
        let handle = try FileHandle(forUpdating: logFileURL)
        self.fileHandle = handle

        // Recover state
        let data = try Data(contentsOf: logFileURL)
        if !data.isEmpty,
           let string = String(data: data, encoding: .utf8) {
            let lines = string.components(separatedBy: .newlines).filter { !$0.isEmpty }
            if let lastLine = lines.last,
               let lineData = lastLine.data(using: .utf8),
               let entry = try? JSONDecoder().decode(LogEntry.self, from: lineData) {
                self.lastHashData = Data(base64Encoded: entry.currentHash)
            }
        }

        // Seek to end for appending
        self.fileHandle.seekToEndOfFile()
    }

    deinit {
        try? fileHandle.close()
    }

    public func log(event: TrustAnchorEvent) throws {
        // H_i = SHA256(H_{i-1} || event_blob)
        let previousHashData = lastHashData ?? Data(repeating: 0, count: 32)
        let eventData = try encoder.encode(event)
        
        let combinedData = previousHashData + eventData
        let newHashDigest = SHA256.hash(data: combinedData)
        let newHashData = Data(newHashDigest)
        
        self.lastHashData = newHashData
        
        let logEntry = LogEntry(
            prevHash: previousHashData.base64EncodedString(),
            currentHash: newHashData.base64EncodedString(),
            event: event
        )
        let logLineData = try encoder.encode(logEntry)
        
        fileHandle.write(logLineData)
        if let newline = "\n".data(using: .utf8) {
            fileHandle.write(newline)
        }
        // Force flush if critical? fileHandle.synchronizeFile() is deprecated but OS usually buffers.
    }
}

public struct LogEntry: Codable {
    public let prevHash: String
    public let currentHash: String
    public let event: TrustAnchorEvent
}
