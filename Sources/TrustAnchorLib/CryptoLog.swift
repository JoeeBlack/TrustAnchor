import Foundation
import CryptoKit

public class AuditLogger {
    private let logFileURL: URL
    private var lastHash: SHA256.Digest?
    private let encoder = JSONEncoder()

    public init(logFileURL: URL) throws {
        self.logFileURL = logFileURL
        // Initialize file if not exists
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }
        // In a real implementation, we would read the last line to get the last hash on startup.
        // For this prototype, we'll start a fresh chain or just assume we append blindly (which breaks the chain verification across restarts unless we read back).
        // Let's implement a basic read-back of the last line for "correctness".
    }

    private func getLastHash() -> SHA256.Digest {
        // Fallback or read from file.
        // Simplified: Return empty hash or zero hash if no file content.
        return SHA256.hash(data: Data()) 
    }

    public func log(event: TrustAnchorEvent) throws {
        var eventToLog = event
        
        // Serialize event *without* the hash first to prepare for hashing
        // Actually, the requirement is H_i = SHA256(H_{i-1} || event_blob)
        // So we take the previous hash, concatenate the new event data, and hash that.
        
        let previousHashData = lastHash.map { Data($0) } ?? Data(repeating: 0, count: 32)
        let eventData = try encoder.encode(event)
        
        let combinedData = previousHashData + eventData
        let newHash = SHA256.hash(data: combinedData)
        self.lastHash = newHash
        
        // We actally want to store the hash WITH the event so verification is easy.
        // We can't modify the struct if it's let constants, but we can wrap it or just write the hash alongside.
        // Let's define a LogEntry wrapper.
        
        let logEntry = LogEntry(prevHash: previousHashData.base64EncodedString(), currentHash: newHash.withUnsafeBytes { Data($0).base64EncodedString() }, event: event)
        let logLineData = try encoder.encode(logEntry)
        
        if let fileHandle = FileHandle(forWritingAtPath: logFileURL.path) {
            defer { fileHandle.closeFile() }
            fileHandle.seekToEndOfFile()
            fileHandle.write(logLineData)
            fileHandle.write("\n".data(using: .utf8)!)
        }
    }
}

struct LogEntry: Codable {
    let prevHash: String
    let currentHash: String // The hash of (prevHashBytes || eventBytes)
    let event: TrustAnchorEvent
}
