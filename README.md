# ⚓️ TrustAnchor

**A Research-Grade Security Agent for macOS**

TrustAnchor is a secure system monitor that builds a real-time "Web of Trust" for your running processes. It combines low-level system telemetry with a tamper-proof cryptographic ledger to ensure that your system's history is both visible and immutable.

---

## 🧐 Why TrustAnchor?

Modern operating systems are complex. Malware often hides by mimicking legitimate processes or injecting itself into them. Traditional logs can be deleted or modified by an attacker with root privileges.

**TrustAnchor solves this by:**
1.  **Contextualizing Events**: It doesn't just see "Process A started Process B". It builds a live **Graph** of relationships, calculating a dynamic "Trust Score" based on lineage, code signatures, and behavior.
2.  **Immutable History**: Every event is stored in a **Cryptographic Hash Chain**. Each log entry relies on the hash of the previous one ($H_i = SHA256(H_{i-1} || E)$). If an attacker modifies a single byte in the past, the entire chain breaks, and TrustAnchor detects it.

## 🚀 How It Works

TrustAnchor consists of three parts:

1.  **The Daemon (`trustanchor-daemon`)**: Runs in the background with high privileges.
    *   **Telemetry**: Listens to system events (Execution, File Access) using Apple's **EndpointSecurity** framework.
    *   **Trust Graph**: Maintains an in-memory graph of process relationships.
    *   **Audit Logger**: Writes events to a hash-chained log file.
2.  **The CLI (`trustanchor`)**: Your window into the system.
    *   Query suspicious processes.
    *   Visualize the process graph.
    *   Verify the integrity of the audit logs.
3.  **The Library**: Shared core logic for cryptographic verification and graph algorithms.

---

## 🛠 Installation

### Prerequisites
*   macOS 13.0 (Ventura) or later.
*   Swift 5.9+.

### Building from Source

```bash
# Clone the repository
git clone https://github.com/your-username/trustanchor.git
cd trustanchor

# Build the project
swift build -c release
```

The binaries will be available in `.build/release/`.

---

## 🎮 Usage

### 1. Start the Daemon
The daemon needs root privileges to monitor system events.

```bash
sudo .build/release/trustanchor-daemon
```

> **Note**: If you don't have the specific EndpointSecurity entitlement (common for personal builds), TrustAnchor will automatically fall back to **Simulation Mode**, generating fake events for testing.

### 2. Inspect the System
Open a new terminal window to use the CLI.

**Find Suspicious Processes**
List processes with a low Trust Score (< 0.4).
```bash
.build/release/trustanchor ps --suspicious
```

**Visualize the Trust Graph**
Generate a GraphViz (DOT) representation of the process tree.
```bash
.build/release/trustanchor graph
# Pro tip: Pipe to dot to generate an image
# .build/release/trustanchor graph | dot -Tpng > graph.png
```

**Verify Log Integrity**
Check if your audit log has been tampered with.
```bash
.build/release/trustanchor verify-log trustanchor_audit.log
```
_If the verification passes, you know for a fact that the history is intact._

---

## 🏗 Architecture & Safety

*   **Concurrency**: The Daemon uses Swift **Actors** (`TrustGraph`, `AuditLogger`) to safely handle high-velocity system events without data races.
*   **Tamper Evidence**: The `AuditLogger` ensures that even across daemon restarts, the hash chain is preserved.
*   **Robustness**: The IPC mechanism uses structured concurrency (`async`/`await`) for reliable communication between the CLI and the Daemon.

## 📄 License
MIT License.
