import Foundation
import Darwin

struct RawProcess: Sendable {
    let pid: Int32
    let ppid: Int32
    let user: String
    let cpu: Double
    let residentBytes: UInt64
    let footprintBytes: UInt64?
    let path: String
}

enum ProcessSampler {
    /// Lists every running process.
    ///
    /// `ps` is a privileged system tool, so it can see every process — including ones owned
    /// by root — and supplies the list, CPU and resident memory. For processes you own we also
    /// read the exact memory footprint, which is the number Activity Monitor's Memory column shows.
    static func sample() -> [RawProcess] {
        // -ww: never truncate long executable paths.
        guard let output = Shell.run("/bin/ps", ["-axww", "-o", "pid=,ppid=,user=,pcpu=,rss=,comm="]) else {
            return []
        }

        var processes: [RawProcess] = []
        processes.reserveCapacity(800)

        for line in output.split(separator: "\n") {
            // pid ppid user %cpu rss command — the command (last) may contain spaces.
            let fields = line.split(maxSplits: 5, omittingEmptySubsequences: true,
                                    whereSeparator: { $0 == " " || $0 == "\t" })
            guard fields.count == 6,
                  let pid = Int32(fields[0]),
                  let ppid = Int32(fields[1]) else { continue }

            processes.append(RawProcess(
                pid: pid,
                ppid: ppid,
                user: String(fields[2]),
                cpu: Double(fields[3]) ?? 0,
                residentBytes: (UInt64(fields[4]) ?? 0) * 1024,
                footprintBytes: footprint(of: pid),
                path: fields[5].trimmingCharacters(in: .whitespaces)
            ))
        }
        return processes
    }

    /// Physical memory footprint. macOS only shares this for processes owned by the current user.
    static func footprint(of pid: Int32) -> UInt64? {
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) { pointer -> Int32 in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebound in
                proc_pid_rusage(pid, RUSAGE_INFO_V4, rebound)
            }
        }
        return result == 0 ? info.ri_phys_footprint : nil
    }
}
