import Foundation
import TrustAnchorLib

@main
struct TrustAnchorDaemon {
    static func main() async {
        print("Starting TrustAnchor...")
        
        // 1. Setup Data Structures
        let graph = TrustGraph() // actor
        let logURL = URL(fileURLWithPath: "trustanchor_audit.log")
        
        let logger: AuditLogger
        do {
            logger = try AuditLogger(logFileURL: logURL) // actor
        } catch {
            print("Fatal: Could not init logger: \(error)")
            exit(1)
        }
        
        // 2. Setup ES Client
        // ESClientWrapper captures graph and logger.
        // The handler is called by ESClientWrapper on its own queue (or simulation timer).
        // Since we are calling actor methods, we need to wrap the call in Task { await ... }

        let esWrapper = ESClientWrapper { event in
            Task {
                // Ingest into Graph
                await graph.ingest(event: event)

                // Log to disk
                do {
                    try await logger.log(event: event)
                } catch {
                    print("Failed to log event: \(error)")
                }

                // Debug print
                print("[Event] \(event.type) pid=\(event.process.pid) path=\(event.process.path)")
            }
        }
        
        // 3. Setup IPC
        let ipc = IPCServer(graph: graph)
        ipc.start()
        
        // 4. Keep alive
        print("Daemon running. Log: \(logURL.path)")

        // RunLoop is needed for ES Client (if it uses mach ports/runloop sources)
        // Ensure esWrapper is kept alive during execution

        await withTaskCancellationHandler {
            withExtendedLifetime(esWrapper) {
                 RunLoop.current.run()
            }
        } onCancel: {
            print("Shutting down...")
        }
    }
}
