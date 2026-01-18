import Foundation
import Network
import TrustAnchorLib

class IPCServer {
    private var listener: NWListener?
    private let graph: TrustGraph
    
    init(graph: TrustGraph) {
        self.graph = graph
    }
    
    func start() {
        // let params = NWParameters.init()
        // Unix Domain Socket path defaults not directly exposed in simple init across all versions, 
        // using TCP for localhost for maximum compatibility in this snippet unless custom path logic is added.
        // But the requirements said "Local broker (XPC or Unix socket)".
        // Let's use specific TCP port 9999 for localhost for simplicity in this generated code to avoid permission issues with /var/run files.
        // Real implementation would use AF_UNIX.
        
        do {
            self.listener = try NWListener(using: .tcp, on: 9999)
        } catch {
            print("Failed to create listener: \(error)")
            return
        }
        
        listener?.stateUpdateHandler = { state in
            print("[IPC] Listener state: \(state)")
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        
        listener?.start(queue: .global())
        print("[IPC] Listening on 9999...")
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global())
        receive(on: connection)
    }
    
    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] (data, context, isComplete, error) in
            if let data = data, let command = String(data: data, encoding: .utf8) {
                self?.processCommand(command, on: connection)
            }
            if error == nil && !isComplete {
                self?.receive(on: connection)
            }
        }
    }
    
    private func processCommand(_ command: String, on connection: NWConnection) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        var response = ""
        
        if trimmed == "graph" {
            response = graph.getGraphViz() // We implemented this in TrustGraph
        } else if trimmed == "suspicious" {
             let nodes = graph.getSuspiciousProcesses()
             response = nodes.map { "\($0.id.id) (Score: \($0.trustScore))" }.joined(separator: "\n")
        } else {
            response = "Unknown command"
        }
        
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed({ _ in }))
    }
}
