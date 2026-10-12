import SwiftUI
import AppKit

enum ProcessScope: String, CaseIterable, Identifiable {
    case all = "All Processes"
    case mine = "My Processes"
    case apps = "Apps"
    case system = "System"

    var id: String { rawValue }
}

/// Screen state for the process list. Kept in an ObservableObject rather than @State so the
/// app also builds with Apple's Command Line Tools (which lack the SwiftUI macro plugin).
@MainActor
final class ProcessListState: ObservableObject {
    @Published var search = ""
    @Published var scope: ProcessScope = .all
    @Published var sortOrder: [KeyPathComparator<ProcessRow>] = [KeyPathComparator(\ProcessRow.memory, order: .reverse)]
    @Published var selection = Set<Int32>()
    @Published var quitTargets = Set<Int32>()
    @Published var confirmingQuit = false
    @Published var errorMessage: String?
}

struct ProcessesView: View {
    @EnvironmentObject var store: ProcessStore
    @StateObject private var state = ProcessListState()

    var body: some View {
        let rows = visibleRows
        let peakMemory = Double(max(rows.map { $0.memory }.max() ?? 1, 1))

        ProcessTable(
            rows: rows,
            peakMemory: peakMemory,
            selection: $state.selection,
            sortOrder: $state.sortOrder,
            onQuit: { ids in askToQuit(ids) },
            onReveal: { ids in reveal(ids) },
            onCopyPIDs: { ids in copyPIDs(ids) }
        )
        .onDeleteCommand { askToQuit(state.selection) }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ProcessStatusBar(selected: selectedRow, shown: rows.count)
        }
        .searchable(text: $state.search, placement: .toolbar, prompt: "Name, PID, user or path")
        .navigationTitle("Processes")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Show", selection: $state.scope) {
                    ForEach(ProcessScope.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    askToQuit(state.selection)
                } label: {
                    Label("Quit Process", systemImage: "xmark.octagon")
                }
                .disabled(state.selection.isEmpty)
                .help("Quit the selected process (⌫)")
            }
        }
        .confirmationDialog(quitTitle, isPresented: $state.confirmingQuit) {
            Button("Quit") { performQuit(force: false) }
            Button("Force Quit", role: .destructive) { performQuit(force: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Quit asks politely so apps can save. Force Quit stops immediately and unsaved changes are lost.")
        }
        .alert("Couldn't quit everything", isPresented: errorIsShowing) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(state.errorMessage ?? "")
        }
    }

    // MARK: Rows

    private var visibleRows: [ProcessRow] {
        let me = NSUserName()
        let query = state.search.trimmingCharacters(in: .whitespaces)
        let scope = state.scope
        let filtered = store.processes.filter { (row: ProcessRow) -> Bool in
            switch scope {
            case .all: break
            case .mine: if row.user != me { return false }
            case .apps: if row.kind != .app { return false }
            case .system: if row.kind != .system { return false }
            }
            if query.isEmpty { return true }
            if row.name.localizedCaseInsensitiveContains(query) { return true }
            if row.user.localizedCaseInsensitiveContains(query) { return true }
            if String(row.pid).hasPrefix(query) { return true }
            return row.path.localizedCaseInsensitiveContains(query)
        }
        return filtered.sorted(using: state.sortOrder)
    }

    private var selectedRow: ProcessRow? {
        guard state.selection.count == 1, let pid = state.selection.first else { return nil }
        return store.process(withID: pid)
    }

    private var errorIsShowing: Binding<Bool> {
        Binding(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } }
        )
    }

    // MARK: Actions

    private var quitTitle: String {
        let names = store.processes.filter { state.quitTargets.contains($0.pid) }.map { $0.name }
        if names.count == 1, let name = names.first {
            return "Quit “\(name)”?"
        }
        return "Quit \(state.quitTargets.count) processes?"
    }

    private func askToQuit(_ ids: Set<Int32>) {
        guard !ids.isEmpty else { return }
        state.quitTargets = ids
        state.confirmingQuit = true
    }

    private func performQuit(force: Bool) {
        state.errorMessage = store.quit(state.quitTargets, force: force)
        state.selection.subtract(state.quitTargets)
        state.quitTargets = []
    }

    private func reveal(_ ids: Set<Int32>) {
        let urls = store.processes
            .filter { ids.contains($0.pid) }
            .compactMap { (row: ProcessRow) -> URL? in
                let path = row.bundlePath ?? row.path
                return path.hasPrefix("/") ? URL(fileURLWithPath: path) : nil
            }
        if !urls.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        }
    }

    private func copyPIDs(_ ids: Set<Int32>) {
        let text = ids.sorted().map { String($0) }.joined(separator: " ")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Table

/// The table on its own, with one small view per cell, keeps each piece simple
/// enough for the Swift compiler to type-check quickly.
private struct ProcessTable: View {
    let rows: [ProcessRow]
    let peakMemory: Double
    @Binding var selection: Set<Int32>
    @Binding var sortOrder: [KeyPathComparator<ProcessRow>]
    let onQuit: (Set<Int32>) -> Void
    let onReveal: (Set<Int32>) -> Void
    let onCopyPIDs: (Set<Int32>) -> Void

    var body: some View {
        Table(rows, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Process", value: \ProcessRow.sortName) { (row: ProcessRow) in
                ProcessNameCell(row: row)
            }
            .width(min: 200, ideal: 280)

            TableColumn("Memory", value: \ProcessRow.memory) { (row: ProcessRow) in
                MemoryCell(row: row, peak: peakMemory)
            }
            .width(min: 140, ideal: 170)

            TableColumn("CPU", value: \ProcessRow.cpu) { (row: ProcessRow) in
                CPUCell(cpu: row.cpu)
            }
            .width(min: 60, ideal: 70)

            TableColumn("PID", value: \ProcessRow.pid) { (row: ProcessRow) in
                SecondaryCell(text: String(row.pid), monospaced: true)
            }
            .width(min: 50, ideal: 64)

            TableColumn("User", value: \ProcessRow.user) { (row: ProcessRow) in
                SecondaryCell(text: row.user, monospaced: false)
            }
            .width(min: 70, ideal: 100)

            TableColumn("Kind", value: \ProcessRow.kind) { (row: ProcessRow) in
                SecondaryCell(text: row.kind.rawValue, monospaced: false)
            }
            .width(min: 70, ideal: 90)
        }
        .contextMenu(forSelectionType: Int32.self) { (ids: Set<Int32>) in
            Button("Quit…") { onQuit(ids) }
                .disabled(ids.isEmpty)
            Divider()
            Button("Show in Finder") { onReveal(ids) }
                .disabled(ids.isEmpty)
            Button("Copy PID") { onCopyPIDs(ids) }
                .disabled(ids.isEmpty)
        }
    }
}

private struct ProcessNameCell: View {
    let row: ProcessRow

    var body: some View {
        HStack(spacing: 8) {
            ProcessIcon(bundlePath: row.bundlePath, kind: row.kind)
            Text(row.name).lineLimit(1)
        }
        .help(row.path)
    }
}

private struct MemoryCell: View {
    let row: ProcessRow
    let peak: Double

    var body: some View {
        HStack(spacing: 8) {
            Text(Format.bytes(row.memory))
                .monospacedDigit()
                .frame(width: 70, alignment: .trailing)
            UsageBar(fraction: Double(row.memory) / peak, tint: Palette.memory.opacity(0.75))
        }
    }
}

private struct CPUCell: View {
    let cpu: Double

    var body: some View {
        Text(String(format: "%.1f", cpu))
            .monospacedDigit()
            .foregroundStyle(cpu >= 50 ? Color.red : Color.primary)
    }
}

private struct SecondaryCell: View {
    let text: String
    let monospaced: Bool

    var body: some View {
        Text(text)
            .font(monospaced ? Font.body.monospacedDigit() : Font.body)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

/// Bottom bar: details of the selected process, or totals. Observes memory stats on its
/// own so the table above isn't re-rendered every second.
private struct ProcessStatusBar: View {
    @EnvironmentObject var store: ProcessStore
    @EnvironmentObject var stats: StatsStore
    let selected: ProcessRow?
    let shown: Int

    var body: some View {
        HStack(spacing: 10) {
            if let row = selected {
                ProcessIcon(bundlePath: row.bundlePath, kind: row.kind, size: 14)
                Text(row.path.isEmpty ? row.name : row.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Spacer(minLength: 12)
                Text(row.memoryIsFootprint ? "Memory: footprint" : "Memory: resident")
                    .help(row.memoryIsFootprint
                          ? "Physical footprint — the same figure Activity Monitor shows."
                          : "Resident memory. macOS only shares exact footprints for your own processes.")
                Text("Parent: \(parentName(of: row))")
            } else {
                Text("\(shown) of \(store.processes.count) processes")
                Spacer()
                if let memory = stats.memory {
                    Text("Memory used: \(Format.bytes(memory.used)) of \(Format.bytes(memory.total))")
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
    }

    private func parentName(of row: ProcessRow) -> String {
        if let parent = store.process(withID: row.ppid) {
            return "\(parent.name) (\(parent.pid))"
        }
        return "PID \(row.ppid)"
    }
}
