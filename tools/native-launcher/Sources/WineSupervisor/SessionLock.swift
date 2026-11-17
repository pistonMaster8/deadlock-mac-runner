import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public struct SessionRecord: Codable, Equatable, Sendable {
    public let pid: Int32
    public let mode: LaunchMode
    public let startedAt: Date

    public init(pid: Int32, mode: LaunchMode, startedAt: Date = Date()) {
        self.pid = pid
        self.mode = mode
        self.startedAt = startedAt
    }
}

public enum SessionLockError: Error, Equatable {
    case alreadyRunning(SessionRecord)
    case cannotCreate(String)
}

public final class SessionLock: @unchecked Sendable {
    private let url: URL
    private let record: SessionRecord
    private var descriptor: Int32 = -1

    public init(url: URL, pid: Int32 = Int32(getpid()), mode: LaunchMode) {
        self.url = url
        self.record = SessionRecord(pid: pid, mode: mode)
    }

    public var isOwner: Bool { descriptor >= 0 }

    public func acquire() throws {
        if let existing = try readExistingRecord(), isProcessAlive(existing.pid) {
            throw SessionLockError.alreadyRunning(existing)
        }
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }

        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let fd = open(url.path, O_CREAT | O_EXCL | O_WRONLY, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw SessionLockError.cannotCreate("\(url.path) errno=\(errno)") }
        descriptor = fd
        let data = try JSONEncoder().encode(record)
        data.withUnsafeBytes { bytes in
            _ = write(fd, bytes.baseAddress, data.count)
        }
    }

    public func release() {
        guard descriptor >= 0 else { return }
        close(descriptor)
        descriptor = -1
        try? FileManager.default.removeItem(at: url)
    }

    deinit { release() }

    private func readExistingRecord() throws -> SessionRecord? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SessionRecord.self, from: data)
    }

    private func isProcessAlive(_ pid: Int32) -> Bool {
        guard pid > 1 else { return false }
        if kill(pid, 0) == 0 { return true }
        return errno == EPERM
    }
}
