import Foundation
import XCTest
@testable import WineSupervisor

final class SessionLockTests: XCTestCase {
    func testLockRejectsSecondOwnerAndReclaimsDeadOwner() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let lockURL = directory.appendingPathComponent("session.lock")
        let first = SessionLock(url: lockURL, pid: Int32(getpid()), mode: .steam)
        try first.acquire()
        XCTAssertThrowsError(try SessionLock(url: lockURL, pid: Int32(getpid()), mode: .deadlock).acquire())
        first.release()

        let staleRecord = SessionRecord(pid: 999_999, mode: .steam, startedAt: Date())
        try JSONEncoder().encode(staleRecord).write(to: lockURL)
        let reclaimed = SessionLock(url: lockURL, pid: Int32(getpid()), mode: .megabonk)
        try reclaimed.acquire()
        XCTAssertTrue(reclaimed.isOwner)
        reclaimed.release()
    }
}
