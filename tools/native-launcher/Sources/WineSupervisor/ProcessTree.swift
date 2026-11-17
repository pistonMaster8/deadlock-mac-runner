import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public struct CleanupPlan: Sendable, Equatable {
    public let prefixURL: URL
    public let wineserverURL: URL
    public let environment: [String: String]
    public let trackedPIDs: [Int32]

    public init(prefixURL: URL, wineserverURL: URL, environment: [String: String], trackedPIDs: [Int32]) {
        self.prefixURL = prefixURL
        self.wineserverURL = wineserverURL
        self.environment = environment
        self.trackedPIDs = trackedPIDs
    }
}

public func buildCleanupPlan(layout: RuntimeLayout, trackedPIDs: [Int32]) -> CleanupPlan {
    CleanupPlan(
        prefixURL: layout.prefixURL,
        wineserverURL: layout.wineserverURL,
        environment: layout.wineEnvironment,
        trackedPIDs: trackedPIDs
    )
}

public enum ProcessTreeError: Error, CustomStringConvertible {
    case launchFailed(String)

    public var description: String {
        switch self {
        case .launchFailed(let message): return message
        }
    }
}

@discardableResult
public func launchWine(layout: RuntimeLayout, arguments: [String], extraEnvironment: [String: String] = [:]) throws -> Process {
    let process = Process()
    var environment = layout.wineEnvironment
    let injectionPath = extraEnvironment["DYLD_INSERT_LIBRARIES"]
    if let injectionPath {
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [
            "-c",
            "export DYLD_INSERT_LIBRARIES=\"$1\"; shift; exec \"$@\"",
            "wine-style-wrapper",
            injectionPath,
            layout.wineURL.path
        ] + arguments
        for key in extraEnvironment.keys {
            environment.removeValue(forKey: key)
        }
    } else {
        process.executableURL = layout.wineURL
        process.arguments = arguments
    }
    process.environment = environment
    process.standardError = FileHandle.standardError
    do {
        try process.run()
    } catch {
        throw ProcessTreeError.launchFailed("Wine could not start: \(error.localizedDescription)")
    }
    return process
}

public func cleanupWineSession(_ plan: CleanupPlan, timeout: TimeInterval = 8) {
    for pid in plan.trackedPIDs where pid > 1 {
        _ = kill(pid, SIGTERM)
    }

    let killer = Process()
    killer.executableURL = plan.wineserverURL
    killer.arguments = ["-k"]
    killer.environment = plan.environment
    try? killer.run()
    let deadline = Date().addingTimeInterval(timeout)
    while killer.isRunning && Date() < deadline {
        Thread.sleep(forTimeInterval: 0.1)
    }
    if killer.isRunning {
        killer.terminate()
    }
}

public func terminateWindowsGame(_ mode: LaunchMode) {
    let marker: String
    switch mode {
    case .steam:
        return
    case .deadlock:
        marker = #"steamapps\common\Deadlock\game\bin\win64\deadlock.exe"#
    case .megabonk:
        marker = #"steamapps\common\Megabonk\Megabonk.exe"#
    }
    let listing = Process()
    let output = Pipe()
    listing.executableURL = URL(fileURLWithPath: "/bin/ps")
    listing.arguments = ["-axo", "pid=,command="]
    listing.standardOutput = output
    listing.standardError = FileHandle.nullDevice
    try? listing.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    listing.waitUntilExit()
    guard let text = String(data: data, encoding: .utf8) else { return }

    for line in text.split(separator: "\n") where line.contains(marker) {
        let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
        guard let first = fields.first, let pid = Int32(first), pid > 1 else { continue }
        _ = kill(pid, SIGTERM)
    }
}
public func runCleanupWatchdog(layout: RuntimeLayout, ownerPID: Int32, lockURL: URL) {
    while kill(ownerPID, 0) == 0 || errno == EPERM {
        Thread.sleep(forTimeInterval: 0.5)
    }
    cleanupWineSession(buildCleanupPlan(layout: layout, trackedPIDs: []))
    try? FileManager.default.removeItem(at: lockURL)
}
