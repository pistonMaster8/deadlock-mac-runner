import Foundation
import XCTest
@testable import WineSupervisor

final class ProcessTreeTests: XCTestCase {
    func testCleanupPlanUsesOnlyBundledWineserver() throws {
        let layout = try RuntimeLayout(runtimeURL: URL(fileURLWithPath: "/tmp/runtime"))
        let plan = buildCleanupPlan(layout: layout, trackedPIDs: [123, 456])
        XCTAssertEqual(plan.trackedPIDs, [123, 456])
        XCTAssertEqual(plan.wineserverURL.path, layout.wineserverURL.path)
        XCTAssertEqual(plan.environment["WINEPREFIX"], layout.prefixURL.path)
    }
}
