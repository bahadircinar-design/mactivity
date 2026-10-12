import Foundation
import Combine
import Network
import CoreLocation
import AppKit
import SwiftUI

enum InternetStatus: Equatable {
    case checking, online, noInternet, offline

    var title: String {
        switch self {
        case .checking: return "Checking…"
        case .online: return "Online"
        case .noInternet: return "No Internet"
        case .offline: return "Offline"
        }
    }

    var headline: String {
        switch self {
        case .checking: return "Checking your connection…"
        case .online: return "Connected to the internet"
        case .noInternet: return "On a network, but the internet isn't reachable"
        case .offline: return "Not connected to any network"
        }
    }

    var color: Color {
        switch self {
        case .checking: return .gray
        case .online: return .green
        case .noInternet: return .orange
        case .offline: return .red
        }
    }

    var symbol: String {
        switch self {
        case .checking: return "clock"
        case .online: return "checkmark.circle.fill"
        case .noInternet: return "exclamationmark.triangle.fill"
        case .offline: return "xmark.circle.fill"
        }
    }
}

enum SpeedTestState: Equatable {
    case idle
    case running(String)
    case finished(down: Double?, up: Double?, date: Date)
}

/// Location access is only used so macOS will reveal the Wi-Fi network name.
@MainActor
final class LocationAccess: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var status: CLAuthorizationStatus = .notDetermined
    var onChange: (@MainActor () -> Void)?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        status = manager.authorizationStatus
    }

    var isDenied: Bool { status == .denied || status == .restricted }

    func request() {
        manager.requestWhenInUseAuthorization()
    }

    func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.status = self.manager.authorizationStatus
            self.onChange?()
        }
    }
}

/// Internet reachability, latency, addresses, Wi-Fi details and the speed test.
@MainActor
final class ConnectionStore: ObservableObject {
    @Published private(set) var status: InternetStatus = .checking
    @Published private(set) var interfaceType = "—"
    @Published private(set) var interfaceSymbol = "network"
    @Published private(set) var interfaceName: String?
    @Published private(set) var isExpensive = false
    @Published private(set) var isConstrained = false
    @Published private(set) var supportsIPv4 = false
    @Published private(set) var supportsIPv6 = false

    @Published private(set) var globals = NetworkGlobals()
    @Published private(set) var webResponseMs: Double?
    @Published private(set) var internetPing: PingResult?
    @Published private(set) var routerPing: PingResult?
    @Published private(set) var latencyHistory: [ValueSample] = []
    @Published private(set) var publicIP: String?
    @Published private(set) var wifi: WiFiDetails?
    @Published private(set) var speedTest: SpeedTestState = .idle
    @Published private(set) var lastChecked: Date?

    let location = LocationAccess()

    /// Ten minutes of checks at one every 10 s.
    private let latencyHistoryLength = 60
    private let pathMonitor = NWPathMonitor()
    private var pathSatisfied = true
    private var isChecking = false
    private var checkLoop: Task<Void, Never>?
    private var wifiLoop: Task<Void, Never>?
    private let session: URLSession
    private let speedSession: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 15
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        session = URLSession(configuration: config)

        let speedConfig = URLSessionConfiguration.ephemeral
        speedConfig.timeoutIntervalForRequest = 15
        speedConfig.timeoutIntervalForResource = 90
        speedConfig.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        speedSession = URLSession(configuration: speedConfig)

        // Runs on the monitor's own queue; hop to the main actor before touching state.
        pathMonitor.pathUpdateHandler = { @Sendable [weak self] path in
            Task { @MainActor in self?.apply(path) }
        }
        pathMonitor.start(queue: DispatchQueue(label: "Mactivity.path-monitor"))

        location.onChange = { [weak self] in self?.refreshWiFi() }

        checkLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.runChecks()
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
        wifiLoop = Task { [weak self] in
            while !Task.isCancelled {
                self?.refreshWiFi()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    // MARK: Path changes

    private func apply(_ path: NWPath) {
        let wasSatisfied = pathSatisfied
        pathSatisfied = path.status == .satisfied

        if path.usesInterfaceType(.wifi) {
            interfaceType = "Wi-Fi"
            interfaceSymbol = "wifi"
        } else if path.usesInterfaceType(.wiredEthernet) {
            interfaceType = "Ethernet"
            interfaceSymbol = "cable.connector"
        } else if path.usesInterfaceType(.cellular) {
            interfaceType = "Cellular"
            interfaceSymbol = "antenna.radiowaves.left.and.right"
        } else if pathSatisfied {
            interfaceType = "Other"
            interfaceSymbol = "network"
        } else {
            interfaceType = "None"
            interfaceSymbol = "wifi.slash"
        }

        interfaceName = path.availableInterfaces.first?.name
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        supportsIPv4 = path.supportsIPv4
        supportsIPv6 = path.supportsIPv6

        if !pathSatisfied {
            status = .offline
            webResponseMs = nil
            internetPing = nil
            routerPing = nil
            publicIP = nil
        }

        refreshWiFi()
        if pathSatisfied != wasSatisfied || pathSatisfied {
            Task {
                await runChecks()
                await fetchPublicIP()
            }
        }
    }

    // MARK: Checks

    func runChecks() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        globals = await runInBackground { ConnectionProbe.globals() }

        guard pathSatisfied else {
            status = .offline
            lastChecked = Date()
            return
        }

        let routerAddress = globals.router
        async let webResult = measureWebResponse()
        async let internetResult = runInBackground { ConnectionProbe.ping("1.1.1.1") }
        async let routerResult = runInBackground { routerAddress.map { ConnectionProbe.ping($0) } }
        let (web, internet, router) = await (webResult, internetResult, routerResult)

        webResponseMs = web
        internetPing = internet
        routerPing = router
        status = (web != nil || internet.averageMs != nil) ? .online : .noInternet

        if let latency = internet.averageMs ?? web {
            latencyHistory.append(ValueSample(date: Date(), value: latency))
            if latencyHistory.count > latencyHistoryLength {
                latencyHistory.removeFirst(latencyHistory.count - latencyHistoryLength)
            }
        }
        lastChecked = Date()
    }

    /// Time for a small HTTPS request to complete. Any HTTP response at all proves the internet works.
    private func measureWebResponse() async -> Double? {
        guard let url = URL(string: "https://www.apple.com/library/test/success.html") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 6
        let start = Date()
        do {
            let (_, response) = try await session.data(for: request)
            guard response is HTTPURLResponse else { return nil }
            return Date().timeIntervalSince(start) * 1000
        } catch {
            return nil
        }
    }

    func fetchPublicIP() async {
        guard pathSatisfied, let url = URL(string: "https://api.ipify.org") else { return }
        do {
            let (data, _) = try await session.data(from: url)
            let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            publicIP = (!text.isEmpty && text.count <= 45) ? text : nil
        } catch {
            publicIP = nil
        }
    }

    func refreshWiFi() {
        Task {
            wifi = await runInBackground { ConnectionProbe.wifi() }
        }
    }

    // MARK: Speed test

    var isSpeedTestRunning: Bool {
        if case .running = speedTest { return true }
        return false
    }

    func runSpeedTest() {
        guard !isSpeedTestRunning else { return }
        Task {
            speedTest = .running("Measuring download…")
            let down = await measureDownload()
            speedTest = .running("Measuring upload…")
            let up = await measureUpload()
            speedTest = .finished(down: down, up: up, date: Date())
        }
    }

    /// A short probe sizes the real test so it lasts about six seconds on any connection.
    private func measureDownload() async -> Double? {
        guard let probe = await download(bytes: 2_000_000) else { return nil }
        let target = Int(min(max(probe / 8 * 6, 5_000_000), 150_000_000))
        return await download(bytes: target) ?? probe
    }

    private func measureUpload() async -> Double? {
        guard let probe = await upload(bytes: 1_000_000) else { return nil }
        let target = Int(min(max(probe / 8 * 6, 2_000_000), 60_000_000))
        return await upload(bytes: target) ?? probe
    }

    /// Returns bits per second.
    private func download(bytes: Int) async -> Double? {
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=\(bytes)") else { return nil }
        let start = Date()
        guard let result = try? await speedSession.data(from: url) else { return nil }
        let seconds = Date().timeIntervalSince(start)
        guard seconds > 0, !result.0.isEmpty else { return nil }
        return Double(result.0.count) * 8 / seconds
    }

    /// Returns bits per second.
    private func upload(bytes: Int) async -> Double? {
        guard let url = URL(string: "https://speed.cloudflare.com/__up") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let payload = Data(count: bytes)
        let start = Date()
        guard (try? await speedSession.upload(for: request, from: payload)) != nil else { return nil }
        let seconds = Date().timeIntervalSince(start)
        guard seconds > 0 else { return nil }
        return Double(bytes) * 8 / seconds
    }
}
