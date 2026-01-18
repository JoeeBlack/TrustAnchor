# Architecture & Threat Model - TrustAnchor

## System Architecture

```mermaid
graph TD
    subgraph "Kernel Space"
        ES[EndpointSecurity Framework]
        XNY[XNU Kernel]
    end

    subgraph "User Space (Root)"
        Daemon[TrustAnchor Daemon]
        ESClient[ES Client Wrapper]
        Graph[Trust Correlation Engine]
        Logger[Crypto Audit Logger]
        IPC[IPC Server]
        
        ES -->|Events (XPC)| ESClient
        ESClient -->|Normalized Events| Graph
        ESClient -->|Normalized Events| Logger
        Graph -->|Trust Scores| IPC
        Logger -->|Append-Only Log| Storage[(Disk / SQLite)]
    end

    subgraph "User Space (User)"
        CLI[TrustAnchor CLI Tool]
        Verifier[Log Verifier]
        
        CLI -->|Query (TCP/Socket)| IPC
        Verifier -->|Read| Storage
    end
```

## Threat Model

### Trust Assumptions
1.  **Kernel Integrity**: The macOS Kernel is trusted. If the kernel is compromised (kernel extension, DMA attack), ES telemetry cannot be trusted.
2.  **Daemon Integrity**: The `TrustAnchor Daemon` runs as root. We assume root has not been compromised *before* installation.
3.  **Secure Enclave (Future)**: Keys used for signing checkpoints are protected by Hardware.

### Attack Vectors & Mitigations

| Threat | Description | Mitigation |
| :--- | :--- | :--- |
| **Daemon Termination** | Attacker kills the daemon to hide activity. | `launchd` KeepAlive; ES Client holds an "early boot" entitlement to preventing simple kills (requires SIP interaction). |
| **Log Tampering** | Attacker modifies old log entries to erase traces. | Hash Chaining (SHA-256 $H_i = H(H_{i-1} || E)$). Modification invalidates all subsequent hashes. |
| **Event Spoofing** | Attacker injects fake ES events. | ES events are signed by the kernel/ESF. Daemon only accepts input from the ES handle. |
| **IPC Fuzzing** | Attacker floods the local socket to DOS the daemon. | Input validation; separate thread for IPC; rate limiting (future). |

### Security Constraints
-   **Performance**: ES Client must process events < 50ms to avoid blocking system operations (AUTH events). TrustAnchor uses NOTIFY events which are async and non-blocking, minimizing system impact.
