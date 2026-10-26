import Foundation
import Security
import Darwin
import CryptoKit

/// Implements the minimal privileged XPC surface (§3, `3-xpc-helper`'s Do clause). Every method
/// re-validates its own input before `runner` ever sees it — the helper
/// treats every caller as hostile regardless of what the GUI/CLI already checked.
public final class HelperService: NSObject, HelperXPCProtocol {
    /// One lock across every connection-owned HelperService instance. Mutating calls must not
    /// interleave a mount with teardown/staging/removal: that could erase a freshly created
    /// session anchor or delete the CLI while a privileged operation is starting.
    private static let mutationLock = NSLock()
    private let runner: PrivilegedCommandRunning
    private let resolvePrefix: @Sendable () -> String
    private let expectedCLITreeHash: String
    private let exitSink: @Sendable () -> Void

    public init(
        runner: PrivilegedCommandRunning,
        thlntfsPrefix: String? = nil,
        expectedCLITreeHash: String = GeneratedCLIManifest.expectedTreeHashHex,
        exitSink: @Sendable @escaping () -> Void = { exit(0) }
    ) {
        self.runner = runner
        if let thlntfsPrefix {
            self.resolvePrefix = { thlntfsPrefix }
        } else {
            self.resolvePrefix = { resolveTHLNTFSPrefix() }
        }
        self.expectedCLITreeHash = expectedCLITreeHash
        self.exitSink = exitSink
    }

    private func encode(_ result: CommandResult, reply: (Data?, String?) -> Void) {
        guard let data = try? JSONEncoder().encode(result) else {
            reply(nil, "helper: failed to encode result")
            return
        }
        reply(data, nil)
    }

    public func mount(device: String, driver: String, mountPoint: String?, readOnly: Bool, reply: @escaping (Data?, String?) -> Void) {
        Self.mutationLock.lock()
        defer { Self.mutationLock.unlock() }
        guard validateDevice(device) else {
            reply(nil, "rejected: device \"\(device)\" does not match \(deviceNamePattern)")
            return
        }
        guard let fsDriver = FsDriver(rawValue: driver) else {
            reply(nil, "rejected: unknown driver \"\(driver)\"")
            return
        }
        if let mountPoint, !isValidMountPoint(mountPoint) {
            reply(nil, "rejected: mountPoint \"\(mountPoint)\" is not a valid /Volumes/ path")
            return
        }
        var args = [device]
        if let mountPoint { args.append(mountPoint) }
        if fsDriver == .ext {
            args.append("--ignore-permissions")
        } else {
            args.append(contentsOf: ["--fs-driver", fsDriver.rawValue])
        }
        if readOnly { args.append("--read-only") }
        let result = runner.run("\(resolvePrefix())/bin/thlntfs", ["mount"] + args)
        encode(result, reply: reply)
    }

    public func unmount(target: String, reply: @escaping (Data?, String?) -> Void) {
        Self.mutationLock.lock()
        defer { Self.mutationLock.unlock() }
        guard isValidUnmountTarget(target) else {
            reply(nil, "rejected: unmount target \"\(target)\" is neither a valid device nor a /Volumes/ path")
            return
        }
        let result = runner.run("\(resolvePrefix())/bin/thlntfs", ["unmount", target])
        encode(result, reply: reply)
    }

    public func teardown(sessionID: String?, reply: @escaping (Data?, String?) -> Void) {
        Self.mutationLock.lock()
        defer { Self.mutationLock.unlock() }
        if let sessionID, !validateDevice(sessionID) {
            reply(nil, "rejected: sessionID \"\(sessionID)\" does not match \(deviceNamePattern)")
            return
        }
        var args: [String] = []
        if let sessionID { args.append(sessionID) }
        let result = runner.run("\(resolvePrefix())/libexec/thlntfs/lib/pf-teardown.sh", args)
        encode(result, reply: reply)
    }

    public func removeDependencies(reply: @escaping (Data?, String?) -> Void) {
        Self.mutationLock.lock()
        defer { Self.mutationLock.unlock() }
        guard noActiveNfsMount() else {
            reply(nil, "rejected: an NFS mount is currently active — unmount it first")
            return
        }

        let prefix = resolvePrefix()
        let cleanup = runner.run("\(prefix)/libexec/thlntfs/lib/pf-teardown.sh", [])
        guard cleanup.exitCode == 0,
              !cleanup.output.contains("=unknown"),
              !cleanup.output.contains("=notEnforced")
        else {
            reply(nil, "rejected: session security cleanup could not be proven")
            return
        }

        guard noActiveNfsMount() else {
            reply(nil, "rejected: an NFS mount became active — aborting before removing files")
            return
        }

        var removedPaths = [prefix]
        _ = runner.run("/bin/rm", ["-rf", prefix])

        let pathSymlink = "/usr/local/bin/thlntfs"
        let linkTarget = runner.run("/bin/readlink", [pathSymlink])
        if linkTarget.exitCode == 0,
           linkTarget.output.trimmingCharacters(in: .whitespacesAndNewlines) == "\(installPrefix)/bin/thlntfs" {
            removedPaths.append(pathSymlink)
            _ = runner.run("/bin/rm", ["-f", pathSymlink])
        }

        if let home = Self.invokingUserHomeDirectory() {
            let cachePath = home.appendingPathComponent(".anylinuxfs").path
            removedPaths.append(cachePath)
            _ = runner.run("/bin/rm", ["-rf", cachePath])

            let logsDir = home.appendingPathComponent("Library/Logs")
            let logFiles = (try? FileManager.default.contentsOfDirectory(atPath: logsDir.path)) ?? []
            let matchingLogs = logFiles
                .filter { $0.hasPrefix("anylinuxfs") && $0.hasSuffix(".log") }
                .map { logsDir.appendingPathComponent($0).path }
            if !matchingLogs.isEmpty {
                removedPaths.append(contentsOf: matchingLogs)
                _ = runner.run("/bin/rm", ["-f"] + matchingLogs)
            }
        }

        encode(CommandResult(output: removedPaths.joined(separator: "\n"), exitCode: 0), reply: reply)
    }

    private func noActiveNfsMount() -> Bool {
        runner.run("/sbin/mount", ["-t", "nfs"]).output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func stageCLI(installScriptPath: String, reply: @escaping (Data?, String?) -> Void) {
        Self.mutationLock.lock()
        defer { Self.mutationLock.unlock() }
        guard isValidStageCLIPath(installScriptPath) else {
            reply(nil, "rejected: installScriptPath \"\(installScriptPath)\" is not a bundled install.sh")
            return
        }
        let resolvedScriptPath = URL(fileURLWithPath: installScriptPath).resolvingSymlinksInPath()
        guard FileManager.default.isExecutableFile(atPath: resolvedScriptPath.path) else {
            reply(nil, "rejected: \(installScriptPath) does not exist or isn't executable")
            return
        }
        let cliSrcDir = resolvedScriptPath.deletingLastPathComponent()
        guard let actualHash = computeTreeHash(at: cliSrcDir), actualHash == expectedCLITreeHash else {
            reply(nil, "rejected: cli-src content does not match the hash pinned into this helper at build time — refusing (possible tampering)")
            return
        }
        let markerPath = "\(installPrefix)/libexec/thlntfs/cli-tree.sha256"
        if let marker = try? String(contentsOfFile: markerPath, encoding: .utf8),
           marker.trimmingCharacters(in: .whitespacesAndNewlines) == expectedCLITreeHash {
            encode(CommandResult(output: "cli already current", exitCode: 0), reply: reply)
            return
        }
        let result = runner.run(resolvedScriptPath.path, ["--no-path-link"])
        if result.exitCode == 0 {
            try? expectedCLITreeHash.write(toFile: markerPath, atomically: true, encoding: .utf8)
        }
        encode(result, reply: reply)
    }

    public func version(reply: @escaping (String?) -> Void) {
        reply(expectedCLITreeHash)
    }

    public func uninstallHelper(reply: @escaping (Data?, String?) -> Void) {
        Self.mutationLock.lock()
        defer { Self.mutationLock.unlock() }
        let label = helperMachServiceName
        _ = runner.run("/bin/rm", ["-f", "/Library/LaunchDaemons/\(label).plist"])
        let removeBinary = runner.run("/bin/rm", ["-f", "/Library/PrivilegedHelperTools/\(label)"])
        _ = runner.run("/usr/bin/tccutil", ["reset", "SystemPolicyAllFiles", label])
        _ = runner.run("/usr/bin/tccutil", ["reset", "All", label])
        encode(removeBinary, reply: reply)
        _ = runner.run("/bin/launchctl", ["bootout", "system/\(label)"])
    }

    public func exitHelper(reply: @escaping (Data?, String?) -> Void) {
        reply(Data(), nil)
        exitSink()
    }

    private static func invokingUserHomeDirectory() -> URL? {
        guard let uid = NSXPCConnection.current()?.effectiveUserIdentifier,
              let pw = getpwuid(uid), let dir = pw.pointee.pw_dir
        else { return nil }
        return URL(fileURLWithPath: String(cString: dir))
    }
}
