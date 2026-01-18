import Foundation
import TrustAnchorLib

@main
struct TrustAnchorDaemon {
    static func main() {
        print("Starting TrustAnchor...")
        
        let runLoop = RunLoop.current
        
        // 1. Setup Data Structures
        let graph = TrustGraph()
        let logURL = URL(fileURLWithPath: "trustanchor_audit.log") // Default to current dir
        
        let logger: AuditLogger
        do {
            logger = try AuditLogger(logFileURL: logURL)
        } catch {
            print("Fatal: Could not init logger: \(error)")
            exit(1)
        }
        
        // 2. Setup ES Client
        let esWrapper = ESClientWrapper { event in
            // Ingest into Graph
            graph.ingest(event: event)
            
            // Log to disk
            do {
                try logger.log(event: event)
            } catch {
                print("Failed to log event: \(error)")
            }
            
            // Debug print
            print("[Event] \(event.type) pid=\(event.process.pid) path=\(event.process.path)")
        }
        
        // 3. Setup IPC
        let ipc = IPCServer(graph: graph)
        ipc.start()
        
        // 4. Keep alive
        print("Daemon running. Log: \(logURL.path)")
        withExtendedLifetime(esWrapper) {
            runLoop.run()
        }
    }
}
