import Foundation
import XCTest
@testable import WineSupervisor

final class SessionConfigurationTests: XCTestCase {
    func testAppIDsAndSteamPathAreStable() throws {
        let layout = try RuntimeLayout(runtimeURL: URL(fileURLWithPath: "/tmp/runtime"))
        XCTAssertEqual(layout.appID(for: .deadlock), "1422450")
        XCTAssertEqual(layout.appID(for: .megabonk), "3405340")
        XCTAssertNil(layout.appID(for: .steam))
        XCTAssertEqual(layout.steamWindowsPath, #"C:\Program Files (x86)\Steam\steam.exe"#)
    }

    func testEnvironmentUsesSharedPrefixAndFrameworks() throws {
        let layout = try RuntimeLayout(runtimeURL: URL(fileURLWithPath: "/tmp/runtime"))
        let environment = layout.wineEnvironment
        XCTAssertEqual(environment["WINEPREFIX"], layout.prefixURL.path)
        XCTAssertEqual(environment["WINEARCH"], "win64")
        XCTAssertTrue(environment["DYLD_FALLBACK_LIBRARY_PATH"]?.contains(layout.frameworksURL.path) == true)
    }
}
