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
                // processCommand is now async because it accesses the actor `graph`
                Task {
                    await self?.processCommand(command, on: connection)
                }
            }
            if error == nil && !isComplete {
                self?.receive(on: connection)
            }
        }
    }
    
    private func processCommand(_ command: String, on connection: NWConnection) async {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        var response = ""
        
        if trimmed == "graph" {
            response = await graph.getGraphViz()
        } else if trimmed == "suspicious" {
             let nodes = await graph.getSuspiciousProcesses()
             response = nodes.map { "\($0.id.id) (Score: \($0.trustScore))" }.joined(separator: "\n")
        } else {
            response = "Unknown command"
        }
        
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed({ _ in }))
    }
}
