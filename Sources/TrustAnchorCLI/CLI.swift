import Foundation
import ArgumentParser
import Network
import TrustAnchorLib
import CryptoKit

@main
struct TrustAnchor: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "TrustAnchor CLI",
        subcommands: [Ps.self, Graph.self, VerifyLog.self]
    )
}

struct Ps: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List processes")
    
    @Flag(name: .long, help: "Show only suspicious processes")
    var suspicious: Bool = false
    
    func run() throws {
        let cmd = suspicious ? "suspicious" : "ps"
        let response = sendCommand(cmd)
        print(response)
    }
}

struct Graph: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Export trust graph")
    
    func run() throws {
        let response = sendCommand("graph")
        print(response)
    }
}

struct VerifyLog: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Verify the cryptographic audit log")
    
    @Argument(help: "Path to log file")
    var path: String
    
    func run() throws {
        print("Verifying log at \(path)...")
        
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            print("Error: File not found.")
            throw ExitCode.validationFailure
        }

        // Read file content
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) else {
            print("Error: Could not read file as UTF8.")
            throw ExitCode.validationFailure
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        var prevHashData = Data(repeating: 0, count: 32) // Genesis hash is all zeros
        var valid = true
        var count = 0
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys // Must match the logger's setting
        let decoder = JSONDecoder()
        
        for (index, line) in lines.enumerated() {
            guard let lineData = line.data(using: .utf8) else {
                print("Line \(index + 1): Invalid encoding")
                valid = false
                break
            }

            do {
                let entry = try decoder.decode(LogEntry.self, from: lineData)

                // 1. Verify 'prevHash' matches our rolling hash
                guard let entryPrevHash = Data(base64Encoded: entry.prevHash) else {
                     print("Line \(index + 1): Invalid prevHash format")
                     valid = false
                     break
                }

                if entryPrevHash != prevHashData {
                    print("Line \(index + 1): BROKEN CHAIN!")
                    print("  Expected prev: \(prevHashData.base64EncodedString())")
                    print("  Found prev:    \(entry.prevHash)")
                    valid = false
                    break
                }

                // 2. Compute Expected Hash for this entry
                // H_i = SHA256(H_{i-1} || encode(event))

                // We must re-encode the event to get the bytes that were hashed.
                // NOTE: This relies on deterministic encoding (.sortedKeys).
                let eventBytes = try encoder.encode(entry.event)
                let combined = prevHashData + eventBytes
                let calculatedHash = SHA256.hash(data: combined)

                // 3. Compare with 'currentHash'
                guard let entryCurrentHash = Data(base64Encoded: entry.currentHash) else {
                    print("Line \(index + 1): Invalid currentHash format")
                    valid = false
                    break
                }

                // Convert SHA256.Digest to Data for comparison
                let calculatedHashData = Data(calculatedHash)

                if calculatedHashData != entryCurrentHash {
                    print("Line \(index + 1): HASH MISMATCH!")
                    print("  Calculated: \(calculatedHashData.base64EncodedString())")
                    print("  Recorded:   \(entry.currentHash)")
                    valid = false
                    break
                }

                // Update for next iteration
                prevHashData = calculatedHashData
                count += 1

            } catch {
                print("Line \(index + 1): Decoding error: \(error)")
                valid = false
                break
            }
        }
        
        if valid {
            print("✅ Log verification passed. \(count) entries verified.")
        } else {
            print("❌ Log verification FAILED.")
            throw ExitCode.failure
        }
    }
}

// Helper for IPC
func sendCommand(_ cmd: String) -> String {
    // Synchronous-like wrapper around NWConnection for CLI tool usage
    let semaphore = DispatchSemaphore(value: 0)
    var output = ""
    
    let connection = NWConnection(host: "localhost", port: 9999, using: .tcp)
    connection.start(queue: .global())
    
    connection.send(content: cmd.data(using: .utf8), completion: .contentProcessed { error in
        if let error = error {
            print("Send error: \(error)")
            semaphore.signal()
        }
    })
    
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { (data, _, _, error) in
        if let data = data, let string = String(data: data, encoding: .utf8) {
            output = string
        }
        if let error = error {
            print("Receive error: \(error)")
        }
        semaphore.signal()
    }
    
    _ = semaphore.wait(timeout: .now() + 5.0)
    return output
}
