# TrustAnchor

**A Research-Grade Security Agent for macOS**

TrustAnchor is a modular security daemon that collects low-level system telemetry using Apple's EndpointSecurity Framework (ESF), correlates events into a live process trust graph, and stores an immutable, cryptographically verifiable audit log.

![Architecture](https://mermaid.ink/img/pako:eNp1ksFu2zAMhl9F0Ckb4Kbr0G4DtmFAu2GPgyEoiY6tRJYMyWnQBH33UUnjbumlR_Ij-f9DivRS1VRoSbp9L9nyteTKl0Z9yB-1_FBy1-idDq-nN_j83l2_vb9_QW4aB3hH5wP89A2_vR3g5R3_0QpY1x_4o_0Av37B39oBft4qfCg04K8Wj9qAv_XU319h7-H81s9y21GvX0p-I4tCsm95eYCcK9cK8pI3o8jRk7xWq_w1y-9Ffqb38h_5Qf6T32k6t4X0B9mIfJ_Mci-NnJ9E_iD_iTyL_JnkTzKRJ5HvRM71K3-Q2bwQeRL5n1Fm5rM8iPxF5Ik8ifxI5Fm-ijyJ_EDkmTzLZ3kQeRL5mciTyJ_kQZ7lsxyIPIn8Wj7Kg8iTyBM5uXySB5GTyx9Fnsify4PIk8iTyHP5JA8izyI_EnkS-bU8iDyJ_FKeRT7Lg8iTyHP5LA8iTyI_E3kS-bU8iDyLfC6fy2d5EHmn-Q11D_oA91rfs_2a39A_FzTWb0c96ANc6x28v8PXd_iG37T9Dq-vR32A97o__4_Xo_7R_wB9g3Tf)

> **Note**: This is a research project designed to demonstrate secure telemetry collection and trust modeling. It falls back to a **Simulation Mode** if the required EndpointSecurity entitlements are not present.

## Features

- **🛡️ Core Agent**: Runs as a `launchd` daemon, subscribing to process execution (`EXEC`), file access (`OPEN`, `WRITE`), and memory mapping (`MMAP`) events.
- **🕸️ Trust Correlation Engine**: Builds a real-time in-memory graph of process lineage, code signing status, and behavior to calculate dynamic "Trust Scores".
- **🔒 Cryptographic Ledger**: Implements an append-only audit log using SHA-256 hash chaining ($H_i = SHA256(H_{i-1} || E)$), ensuring logs cannot be tampered with retroactively.
- **📡 Telemetry Broker**: Exposes authorized IPC endpoints (Unix Domain Socket / TCP Localhost) for CLI tools to query the agent without blocking the event stream.
- **🔍 CLI Tool**: `trustanchor` provides `ps` (process list), `trace` (process history), and `graph` (GraphViz export) commands.

## Prerequisites

- macOS 13.0 (Ventura) or later.
- Swift 5.9+.
- (Optional) `com.apple.developer.endpoint-security.client` entitlement for real system monitoring. Without this, TrustAnchor runs in **Simulation Mode**.

## Installation

### Build from Source

TrustAnchor is built using Swift Package Manager:

```bash
git clone https://github.com/your-username/trustanchor.git
cd trustanchor
swift build -c release
```

The binaries will be located in `.build/release/`.

## Usage

### 1. Start the Daemon

The daemon requires root privileges to initialize the ES Client (even in simulation mode, it attempts to load).

```bash
sudo .build/release/trustanchor-daemon
```

*If you do not have the ES entitlement, you will see:*
```
[!] Failed to create ES Client: Missing entitlements?
[*] Falling back to SIMULATION MODE.
```

### 2. CLI Commands

Open a new terminal to interact with the running daemon.

**List Suspicious Processes**
Find processes with a Trust Score below 0.4.
```bash
.build/release/trustanchor ps --suspicious
```

**Visualize the Trust Graph**
Export the current process graph to DOT format and render with GraphViz (if installed).
```bash
.build/release/trustanchor graph | dot -Tpng > trust_graph.png
open trust_graph.png
```

**Verify Log Integrity**
Validate that the audit log (`trustanchor_audit.log`) has not been tampered with.
```bash
.build/release/trustanchor verify-log trustanchor_audit.log
```

## Architecture

*See `architecture_threat_model.md` for a detailed threat model.*

The system is composed of three main modules:
1.  **TrustAnchorDaemon**: The privileged coordinator.
2.  **TrustAnchorLib**: Shared core logic (Crypto, Graph, Models).
3.  **TrustAnchorCLI**: User interface.

### Directory Structure
```
├── Sources
│   ├── TrustAnchorDaemon    # Main Run Loop, ESClient Wrapper, IPC Server
│   ├── TrustAnchorCLI       # Command Line Interface (ArgumentParser)
│   └── TrustAnchorLib       # Shared Logic (Event Models, TrustGraph, CryptoLog)
├── Package.swift     # Dependency definitions
└── architecture_threat_model.md
```

## Security

TrustAnchor is designed with a specific threat model in mind:
- **Root Compromise**: We assume the daemon starts in a clean state.
- **Log Tampering**: Mitigated via Hash Chaining.
- **Event Spoofing**: Mitigated by kernel-enforced signatures on ES events.

## License

MIT License. See [LICENSE](LICENSE) for details.
