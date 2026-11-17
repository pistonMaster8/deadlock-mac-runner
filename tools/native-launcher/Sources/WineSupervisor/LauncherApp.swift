import Foundation
#if canImport(AppKit)
import AppKit
#endif

#if canImport(AppKit)
public final class LauncherController: NSObject, NSApplicationDelegate {
    private let mode: LaunchMode
    private let bundleURL: URL
    private var layout: RuntimeLayout?
    private var lock: SessionLock?
    private var watchdogProcess: Process?
    private var steamProcess: Process?
    private var gameProcess: Process?
    private var trafficLightOverlay: TrafficLightOverlayController?
    private var ownsSession = false

    public init(mode: LaunchMode, bundleURL: URL) {
        self.mode = mode
        self.bundleURL = bundleURL
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try launch()
        } catch {
            let message = String(describing: error)
            try? message.write(to: URL(fileURLWithPath: "/tmp/WineSupervisor-\(mode.rawValue).log"), atomically: true, encoding: .utf8)
            terminate()
            let alert = NSAlert()
            alert.messageText = "Wine Launcher could not start"
            alert.informativeText = message
            alert.alertStyle = .critical
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        terminate()
        return .terminateNow
    }

    public func applicationWillTerminate(_ notification: Notification) {
        terminate()
    }

    public func launch() throws {
        let resolvedLayout = try RuntimeLayout(bundleURL: bundleURL)
        layout = resolvedLayout
        let lockURL = resolvedLayout.runtimeURL.appendingPathComponent("Contents/SharedSupport/native-wine-session.lock")
        let candidateLock = SessionLock(url: lockURL, mode: mode)
        do {
            try candidateLock.acquire()
            lock = candidateLock
            ownsSession = true
            let watchdog = Process()
            watchdog.executableURL = Bundle.main.executableURL
            watchdog.arguments = ["--watchdog", resolvedLayout.runtimeURL.path, "\(getpid())"]
            watchdog.environment = resolvedLayout.wineEnvironment
            try watchdog.run()
            watchdogProcess = watchdog
        } catch SessionLockError.alreadyRunning {
            // A game launcher can submit an AppID request to the existing Steam session.
            // Steam.app itself simply activates its already-running session.
            if mode == .steam { return }
        }

        if mode == .steam && !ownsSession { return }
        steamProcess = try launchWine(layout: resolvedLayout, arguments: [resolvedLayout.steamWindowsPath])
        if mode == .steam {
            trafficLightOverlay = TrafficLightOverlayController()
            trafficLightOverlay?.start()
        }

        guard let appID = resolvedLayout.appID(for: mode) else { return }
        DispatchQueue.global().asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, let layout = self.layout else { return }
            self.gameProcess = try? launchWine(layout: layout, arguments: [layout.steamWindowsPath, "-applaunch", appID])
        }
    }

    public func terminate() {
        trafficLightOverlay?.stop()
        trafficLightOverlay = nil
        if ownsSession, let layout {
            watchdogProcess?.terminate()
            let pids = [steamProcess?.processIdentifier, gameProcess?.processIdentifier].compactMap { $0 }
            cleanupWineSession(buildCleanupPlan(layout: layout, trackedPIDs: pids))
            lock?.release()
            ownsSession = false
            watchdogProcess = nil
        } else {
            terminateWindowsGame(mode)
            gameProcess?.terminate()
            steamProcess?.terminate()
            gameProcess = nil
            steamProcess = nil
        }
    }
}
#endif
