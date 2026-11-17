import Foundation
#if canImport(AppKit)
import AppKit

if CommandLine.arguments.count >= 4, CommandLine.arguments[1] == "--watchdog",
   let ownerPID = Int32(CommandLine.arguments[3]) {
    let runtimeURL = URL(fileURLWithPath: CommandLine.arguments[2])
    if let layout = try? RuntimeLayout(runtimeURL: runtimeURL) {
        let lockURL = runtimeURL.appendingPathComponent("Contents/SharedSupport/native-wine-session.lock")
        runCleanupWatchdog(layout: layout, ownerPID: ownerPID, lockURL: lockURL)
    }
    exit(0)
}

let modeName = (Bundle.main.object(forInfoDictionaryKey: "WineLauncherMode") as? String)
    ?? CommandLine.arguments.dropFirst().first
    ?? "steam"
let mode = LaunchMode(rawValue: modeName) ?? .steam
let application = NSApplication.shared
let delegate = LauncherController(mode: mode, bundleURL: Bundle.main.bundleURL)
application.delegate = delegate
application.setActivationPolicy(.regular)
application.activate(ignoringOtherApps: true)
application.run()
#else
fputs("WineSupervisor requires macOS AppKit\n", stderr)
exit(1)
#endif
