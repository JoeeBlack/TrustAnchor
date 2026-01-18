import Foundation

public enum TrustAnchorEventType: String, Codable {
    case exec
    case open
    case write
    case mmap
    case csInvalidated
    case xpcConnect
    case netConnect
    case unknown
}

public struct TrustAnchorProcessInfo: Codable {
    public let pid: Int32
    public let ppid: Int32
    public let path: String
    public let signingID: String?
    public let teamID: String?
    public let cdHash: String?
    public let entitlements: [String]
    public let auditToken: [UInt32] // Simplified representation

    public init(pid: Int32, ppid: Int32, path: String, signingID: String?, teamID: String?, cdHash: String?, entitlements: [String], auditToken: [UInt32]) {
        self.pid = pid
        self.ppid = ppid
        self.path = path
        self.signingID = signingID
        self.teamID = teamID
        self.cdHash = cdHash
        self.entitlements = entitlements
        self.auditToken = auditToken
    }
}

public struct TrustAnchorEvent: Codable {
    public let id: UUID
    public let timestamp: Date
    public let type: TrustAnchorEventType
    public let process: TrustAnchorProcessInfo
    public let targetPath: String? // For file events
    public let targetAddress: String? // For net events
    public let eventHash: String? // Will be set by the logger

    public init(type: TrustAnchorEventType, process: TrustAnchorProcessInfo, targetPath: String? = nil, targetAddress: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = type
        self.process = process
        self.targetPath = targetPath
        self.targetAddress = targetAddress
        self.eventHash = nil
    }
}
