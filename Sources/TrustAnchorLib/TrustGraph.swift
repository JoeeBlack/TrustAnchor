import Foundation

public class TrustGraph {
    // A simplified graph model: storage of processes (nodes) and their relationships.
    // In a real system, this would be a directed graph structure.
    
    public struct NodeID: Hashable {
        public let id: String // e.g., pid, path, or unique string
    }
    
    public enum NodeType {
        case process
        case binary
        case file
    }
    
    public struct Node {
        public let id: NodeID
        public let type: NodeType
        public var data: [String: String]
        public var trustScore: Double // 0.0 to 1.0
    }
    
    private var nodes: [NodeID: Node] = [:]
    private var edges: [NodeID: [NodeID]] = [:] // Adjacency list
    
    public init() {}
    
    public func ingest(event: TrustAnchorEvent) {
        // Map event to graph updates
        let processID = NodeID(id: "pid:\(event.process.pid)")
        
        // Ensure process node exists
        if nodes[processID] == nil {
            let score = calculateTrust(process: event.process)
            let node = Node(id: processID, type: .process, data: ["path": event.process.path], trustScore: score)
            nodes[processID] = node
        }
        
        // Handle parent relationship
        let parentID = NodeID(id: "pid:\(event.process.ppid)")
        if nodes[parentID] != nil {
             // Add edge parent -> child if not exists
             addEdge(from: parentID, to: processID)
        }
        
        // Handle file interactions/etc based on event type
        if let path = event.targetPath {
            let fileID = NodeID(id: "file:\(path)")
            if nodes[fileID] == nil {
                nodes[fileID] = Node(id: fileID, type: .file, data: ["path": path], trustScore: 0.5)
            }
            addEdge(from: processID, to: fileID)
        }
    }
    
    private func addEdge(from source: NodeID, to target: NodeID) {
        if edges[source] == nil { edges[source] = [] }
        if !edges[source]!.contains(target) {
            edges[source]!.append(target)
        }
    }
    
    private func calculateTrust(process: TrustAnchorProcessInfo) -> Double {
        // Basic heuristic
        var score = 0.5
        
        // Apple signed?
        if let teamID = process.teamID, teamID == "APPLE" { // hypothetical check
            score += 0.4
        } else if process.teamID != nil {
            score += 0.2
        }
        
        // Sandbox?
        if process.entitlements.contains("com.apple.security.app-sandbox") {
            score += 0.1
        }
        
        return min(score, 1.0)
    }
    
    public func getSuspiciousProcesses(threshold: Double = 0.4) -> [Node] {
        return nodes.values.filter { $0.type == .process && $0.trustScore < threshold }
    }
    
    public func getGraphViz() -> String {
        var dot = "digraph TrustGraph {\n"
        for (id, node) in nodes {
            let label = "\(node.type): \(node.data["path"] ?? id.id)\\nScore: \(node.trustScore)"
            dot += "  \"\(id.id)\" [label=\"\(label)\"];\n"
        }
        for (source, targets) in edges {
            for target in targets {
                dot += "  \"\(source.id)\" -> \"\(target.id)\";\n"
            }
        }
        dot += "}"
        return dot
    }
}
