# Mactivity

A native macOS app for seeing what your Mac is doing: every running process with its memory and CPU, live network traffic per app, and a full picture of your internet connection.

## Build and run

You need macOS 13 Ventura or later, plus Xcode or Apple's Command Line Tools.

In Terminal:

```bash
cd path/to/Mactivity
bash build.sh             # builds build/Mactivity.app and opens it
bash build.sh --install   # also copies it into /Applications
```

The first build takes a minute or two. You can also open `Package.swift` in Xcode and press Run to work on the code — but use `build.sh` for the real app, because only the bundled app gets the icon and can ask for the Location permission that reveals your Wi-Fi name.

## What's inside

**Overview** — live CPU and network graphs, a memory breakdown (app, wired, compressed, cached), memory pressure, swap, uptime, and the top processes by memory, CPU and network.

**Processes** — every process, sortable by memory, CPU, PID, user or kind. Search by name, PID, user or path; filter to All, My Processes, Apps or System. Select a row to see its full path and parent process. Quit or Force Quit from the toolbar, the right-click menu, or the Delete key.

**Network** — current download and upload speed, totals since the app opened, a two-minute throughput chart, each network interface with its addresses, and a table of which apps are using the network right now.

**Connection** — online / no internet / offline status, latency to the internet (1.1.1.1), your router and a web request, packet loss, a ten-minute latency chart, local and public IP, router, DNS servers, Wi-Fi details (signal, noise, link speed, channel, band, Wi-Fi standard) and a built-in speed test.

## Where the numbers come from

| Figure | Source |
|---|---|
| Process list, CPU %, resident memory | `/bin/ps` (can see every process without admin rights) |
| Memory for your own processes | `proc_pid_rusage` physical footprint — the same figure Activity Monitor shows |
| System CPU and memory | Mach host statistics (`host_statistics`, `host_statistics64`) |
| Interface throughput | `getifaddrs` byte counters |
| Per-app network traffic | macOS's built-in `nettop` |
| Connection status | Network framework (`NWPathMonitor`) |
| Router and DNS | SystemConfiguration dynamic store |
| Wi-Fi details | CoreWLAN |

macOS only shares the exact memory footprint of processes you own. For processes owned by the system or other users, Mactivity shows resident memory instead; the status bar says which one you're looking at when you select a process.

## Network requests the app makes

- `ping 1.1.1.1` and a ping to your router every 10 seconds, for latency
- a small HTTPS request to `apple.com` every 10 seconds, to confirm the internet is reachable
- `api.ipify.org`, to show your public IP address
- `speed.cloudflare.com`, only when you press **Run Speed Test**

Location access is used only so macOS will reveal your Wi-Fi network name. The app never reads or stores your location.

## Project layout

```
Sources/Mactivity/
  App/        app entry point
  Samplers/   read the raw data (processes, CPU/memory, interfaces, nettop, ping, Wi-Fi)
  Stores/     sample on a timer and publish to the UI
  Views/      SwiftUI screens and shared components
Resources/    Info.plist and app icon
build.sh      builds and signs Mactivity.app
```
