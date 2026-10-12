import Foundation
import AppKit
import Combine

enum ProcessKind: String, Comparable, Sendable {
    case app = "App"
    case background = "Background"
    case system = "System"

    private var order: Int {
        switch self {
        case .app: return 0
        case .background: return 1
        case .system: return 2
        }
    }

    static func < (lhs: ProcessKind, rhs: ProcessKind) -> Bool { lhs.order < rhs.order }
}

struct ProcessRow: Identifiable, Sendable {
    let pid: Int32
    let ppid: Int32
    let name: String
    let path: String
    let bundlePath: String?
    let user: String
    let cpu: Double
    let memory: UInt64
    let memoryIsFootprint: Bool
    let kind: ProcessKind

    var id: Int32 { pid }
    var sortName: String { name.lowercased() }
}

struct AppTrafficRow: Identifiable, Sendable {
    let pid: Int32
    let name: String
    let bundlePath: String?
    let kind: ProcessKind
    let downRate: Double
    let upRate: Double
    let received: UInt64
    let sent: UInt64

    var id: Int32 { pid }
    var sortName: String { name.lowercased() }
}

/// The process list (every 2 s) and per-app network traffic (every ~3 s).
@MainActor
final class ProcessStore: ObservableObject {
    @Published private(set) var processes: [ProcessRow] = []
    @Published private(set) var traffic: [AppTrafficRow] = []
    @Published private(set) var trafficAvailable = true
    @Published private(set) var lastUpdated: Date?

    private let ownPID = getpid()
    private var lastTraffic: [Int32: AppTraffic] = [:]
    private var lastTrafficDate: Date?
    private var processLoop: Task<Void, Never>?
    private var trafficLoop: Task<Void, Never>?

    init() {
        processLoop = Task { [weak self] in
            while !Task.isCancelled {
                let raw = await runInBackground { ProcessSampler.sample() }
                self?.apply(raw)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        trafficLoop = Task { [weak self] in
            while !Task.isCancelled {
                let sample = await runInBackground { NettopSampler.sample() }
                self?.applyTraffic(sample)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    func refreshNow() {
        Task {
            let raw = await runInBackground { ProcessSampler.sample() }
            apply(raw)
        }
    }

    func process(withID pid: Int32) -> ProcessRow? {
        processes.first { $0.pid == pid }
    }

    // MARK: Quitting

    /// Asks the given processes to quit. Returns a message if any of them couldn't be stopped.
    func quit(_ pids: Set<Int32>, force: Bool) -> String? {
        let names = Dictionary(processes.map { ($0.pid, $0.name) }, uniquingKeysWith: { first, _ in first })
        var failures: [String] = []

        for pid in pids where pid > 1 && pid != ownPID {
            var handled = false
            if let app = NSRunningApplication(processIdentifier: pid) {
                handled = force ? app.forceTerminate() : app.terminate()
            }
            if !handled && kill(pid, force ? SIGKILL : SIGTERM) != 0 {
                failures.append(names[pid] ?? "PID \(pid)")
            }
        }

        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            refreshNow()
        }

        guard !failures.isEmpty else { return nil }
        return "macOS didn't allow quitting \(failures.joined(separator: ", ")). "
            + "Processes owned by the system or another user can only be stopped with administrator rights."
    }

    // MARK: Applying samples

    private func apply(_ raw: [RawProcess]) {
        guard !raw.isEmpty else { return }

        var apps: [Int32: NSRunningApplication] = [:]
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            apps[app.processIdentifier] = app
        }

        processes = raw.compactMap { process -> ProcessRow? in
            // Hide the ps/nettop/ping helpers Mactivity itself launches.
            if process.ppid == ownPID { return nil }

            let app = apps[process.pid]
            let executableName = (process.path as NSString).lastPathComponent
            let name = app?.localizedName ?? (executableName.isEmpty ? "PID \(process.pid)" : executableName)
            let kind: ProcessKind
            if app != nil {
                kind = .app
            } else if process.user == "root" || process.user.hasPrefix("_") {
                kind = .system
            } else {
                kind = .background
            }

            return ProcessRow(
                pid: process.pid,
                ppid: process.ppid,
                name: name,
                path: process.path,
                bundlePath: app?.bundleURL?.path ?? Self.bundlePath(forExecutable: process.path),
                user: process.user,
                cpu: process.cpu,
                memory: process.footprintBytes ?? process.residentBytes,
                memoryIsFootprint: process.footprintBytes != nil,
                kind: kind
            )
        }
        lastUpdated = Date()
    }

    private func applyTraffic(_ sample: [Int32: AppTraffic]?) {
        guard let sample else {
            trafficAvailable = false
            return
        }
        trafficAvailable = true

        let now = Date()
        let elapsed = lastTrafficDate.map { now.timeIntervalSince($0) } ?? 0
        let known = Dictionary(processes.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })

        var rows: [AppTrafficRow] = []
        for (pid, current) in sample {
            guard current.bytesIn + current.bytesOut > 0 else { continue }
            var down = 0.0
            var up = 0.0
            if elapsed > 0, let previous = lastTraffic[pid] {
                if current.bytesIn >= previous.bytesIn {
                    down = Double(current.bytesIn - previous.bytesIn) / elapsed
                }
                if current.bytesOut >= previous.bytesOut {
                    up = Double(current.bytesOut - previous.bytesOut) / elapsed
                }
            }
            let process = known[pid]
            rows.append(AppTrafficRow(
                pid: pid,
                name: process?.name ?? current.name,
                bundlePath: process?.bundlePath,
                kind: process?.kind ?? .background,
                downRate: down,
                upRate: up,
                received: current.bytesIn,
                sent: current.bytesOut
            ))
        }

        lastTraffic = sample
        lastTrafficDate = now
        traffic = rows.sorted {
            ($0.downRate + $0.upRate, $0.received) > ($1.downRate + $1.upRate, $1.received)
        }
    }

    /// "/Applications/Safari.app/Contents/MacOS/Safari" → "/Applications/Safari.app".
    /// Helpers nested inside an app resolve to the outer app, so they share its icon.
    static func bundlePath(forExecutable path: String) -> String? {
        guard let range = path.range(of: ".app/") else { return nil }
        return String(path[..<range.lowerBound]) + ".app"
    }
}
