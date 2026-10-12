import Foundation

struct AppTraffic: Sendable {
    let pid: Int32
    let name: String
    let bytesIn: UInt64
    let bytesOut: UInt64
}

enum NettopSampler {
    /// Per-process byte counters from macOS's built-in `nettop` tool.
    /// Returns nil when nettop isn't available or its output can't be read.
    static func sample() -> [Int32: AppTraffic]? {
        let arguments = ["-P", "-L", "1", "-n", "-J", "bytes_in,bytes_out"]
        // "-x" asks for exact byte counts; fall back without it on versions that don't know the flag.
        if let output = Shell.run("/usr/bin/nettop", arguments + ["-x"], timeout: 8),
           let parsed = parse(output) {
            return parsed
        }
        if let output = Shell.run("/usr/bin/nettop", arguments, timeout: 8),
           let parsed = parse(output) {
            return parsed
        }
        return nil
    }

    /// Parses nettop's CSV log output. Each data row identifies the process as "name.pid".
    static func parse(_ text: String) -> [Int32: AppTraffic]? {
        let lines = text.split(whereSeparator: \.isNewline)
        guard let headerIndex = lines.firstIndex(where: { $0.contains("bytes_in") }) else { return nil }

        let header = lines[headerIndex]
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let inColumn = header.firstIndex(of: "bytes_in"),
              let outColumn = header.firstIndex(of: "bytes_out") else { return nil }

        var result: [Int32: AppTraffic] = [:]
        for line in lines[lines.index(after: headerIndex)...] {
            let fields = line
                .split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard fields.count > max(inColumn, outColumn),
                  let received = UInt64(fields[inColumn]),
                  let sent = UInt64(fields[outColumn]) else { continue }

            // The process identifier sits just before the byte columns.
            var identity: (name: String, pid: Int32)?
            for index in stride(from: inColumn - 1, through: 0, by: -1) {
                if let parsed = splitIdentity(fields[index]) {
                    identity = parsed
                    break
                }
            }
            guard let identity else { continue }

            if let existing = result[identity.pid] {
                result[identity.pid] = AppTraffic(pid: identity.pid, name: existing.name,
                                                  bytesIn: existing.bytesIn + received,
                                                  bytesOut: existing.bytesOut + sent)
            } else {
                result[identity.pid] = AppTraffic(pid: identity.pid, name: identity.name,
                                                  bytesIn: received, bytesOut: sent)
            }
        }
        return result
    }

    /// "Google Chrome H.1234" → ("Google Chrome H", 1234). Rejects timestamps like "14:02:11.5".
    private static func splitIdentity(_ field: String) -> (name: String, pid: Int32)? {
        guard !field.isEmpty, !field.contains(":"),
              let dot = field.lastIndex(of: "."), dot != field.startIndex,
              let pid = Int32(field[field.index(after: dot)...]) else { return nil }
        return (String(field[..<dot]), pid)
    }
}
