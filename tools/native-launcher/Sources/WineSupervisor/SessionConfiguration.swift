import Foundation

public enum LaunchMode: String, Codable, CaseIterable, Sendable {
    case steam
    case deadlock
    case megabonk
}

public enum RuntimeLayoutError: Error, CustomStringConvertible {
    case missingRuntime(URL)

    public var description: String {
        switch self {
        case .missingRuntime(let url):
            return "Wine runtime is missing at \(url.path)"
        }
    }
}

public struct RuntimeLayout: Sendable {
    public let runtimeURL: URL
    public let prefixURL: URL
    public let wineURL: URL
    public let wineserverURL: URL
    public let frameworksURL: URL

    public init(runtimeURL: URL) throws {
        self.runtimeURL = runtimeURL
        self.prefixURL = runtimeURL.appendingPathComponent("Contents/SharedSupport/prefix")
        self.wineURL = runtimeURL.appendingPathComponent("Contents/SharedSupport/wine/bin/wine")
        self.wineserverURL = runtimeURL.appendingPathComponent("Contents/SharedSupport/wine/bin/wineserver")
        self.frameworksURL = runtimeURL.appendingPathComponent("Contents/Frameworks")
    }

    public init(bundleURL: URL) throws {
        let roots = [
            bundleURL,
            bundleURL.deletingLastPathComponent(),
            bundleURL.deletingLastPathComponent().deletingLastPathComponent(),
            bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        ]
        let candidates = roots.flatMap { root in
            [
                root.appendingPathComponent("Wine Runtime.app"),
                root.appendingPathComponent("Megabonk Runner.app"),
                root.appendingPathComponent(".runtime/Megabonk Runner.app")
            ]
        } + [bundleURL]
        if let runtime = candidates.first(where: { runtime in
            FileManager.default.fileExists(atPath: runtime.appendingPathComponent("Contents/SharedSupport/prefix").path) &&
            FileManager.default.fileExists(atPath: runtime.appendingPathComponent("Contents/SharedSupport/wine/bin/wine").path)
        }) {
            try self.init(runtimeURL: runtime)
            return
        }
        let diagnostics = candidates.map { candidate in
            "\(candidate.path): prefix=\(FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Contents/SharedSupport/prefix").path)) wine=\(FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Contents/SharedSupport/wine/bin/wine").path))"
        }.joined(separator: "\n")
        try? diagnostics.write(to: URL(fileURLWithPath: "/tmp/WineSupervisor-runtime.log"), atomically: true, encoding: .utf8)
        throw RuntimeLayoutError.missingRuntime(bundleURL)
    }

    public var steamWindowsPath: String {
        #"C:\Program Files (x86)\Steam\steam.exe"#
    }

    public func appID(for mode: LaunchMode) -> String? {
        switch mode {
        case .steam: return nil
        case .deadlock: return "1422450"
        case .megabonk: return "3405340"
        }
    }
    public var wineEnvironment: [String: String] {
        let wineRoot = runtimeURL.appendingPathComponent("Contents/SharedSupport/wine")
        let gstreamer = frameworksURL.appendingPathComponent("GStreamer.framework/Libraries")
        let fallback = [
            wineRoot.appendingPathComponent("lib").path,
            wineRoot.appendingPathComponent("lib64").path,
            frameworksURL.path,
            gstreamer.path,
            "/opt/wine/lib",
            "/usr/lib",
            "/usr/libexec",
            "/usr/lib/system"
        ].joined(separator: ":")
        var environment = ProcessInfo.processInfo.environment
        environment.merge([
            "WINEPREFIX": prefixURL.path,
            "WINEARCH": "win64",
            "WINEDEBUG": "-all",
            "WINEESYNC": "1",
            "WINEMSYNC": "1",
            "DYLD_FALLBACK_LIBRARY_PATH": fallback
        ]) { _, newValue in newValue }
        return environment
    }
}
