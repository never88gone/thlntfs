import Foundation
import Security
import Darwin
import CryptoKit

// Shared between the privileged helper (`thlntfs-helper`) and the GUI client
// (`gui/Helper/HelperClient.swift`). PLAN.md §3: the XPC interface is the trust boundary —
// everything in this file is untrusted input until `validateDevice` / `isValidUnmountTarget`
// says otherwise, and the helper re-validates independently of whatever the GUI already checked.

/// PLAN.md L6 — device names are validated against this pattern before touching any shell
/// invocation, in both the CLI (`cli/lib/validate-device.sh`) and here, independently.
public let deviceNamePattern = "^disk[0-9]+s[0-9]+$"

public func validateDevice(_ device: String) -> Bool {
    device.range(of: deviceNamePattern, options: .regularExpression) != nil
}

/// Shared `/Volumes/`-rooted path shape check: non-traversal, and — security review finding
/// (2026-07-13, CRITICAL, originally scoped to `mount`'s `mountPoint` only) — no shell
/// metacharacters, since the vendored `anylinuxfs::cmd_mount::mount()` splices this unescaped
/// into a `sh -c` string (`mount -t nfs ... "<mount_point>"` / the mirror unmount path) and a
/// value containing `"` can break out of that quoted argument. Security review finding
/// (2026-07-13, HIGH): `unmount`'s target got only the traversal check, not this blocklist,
/// despite feeding the same vendored mount/unmount code — nothing proved the unmount path
/// doesn't have the same unescaped-splice shape as mount's. Shared here so the two validators
/// can't drift apart again.
private func isValidVolumesPath(_ path: String) -> Bool {
    guard path.hasPrefix("/Volumes/"), !path.contains("..") else { return false }
    let forbidden = CharacterSet(charactersIn: "\"'`$\\;\n\r&|<>(){}*?~")
    return path.rangeOfCharacter(from: forbidden) == nil
}

/// `anylinuxfs unmount` (and our `cli/commands/unmount.sh` wrapper) accepts either a bare
/// `diskNsM` device or an already-resolved mount point — mirrors `unmount.sh`'s own comment.
/// A bare device still runs the full L6 regex; a path goes through `isValidVolumesPath`.
public func isValidUnmountTarget(_ target: String) -> Bool {
    if validateDevice(target) { return true }
    return isValidVolumesPath(target)
}

/// `mount`'s optional `mountPoint` — see `isValidVolumesPath`.
public func isValidMountPoint(_ path: String) -> Bool {
    isValidVolumesPath(path)
}

/// `stageCLI`'s input check — same discipline as `validateDevice`/`isValidUnmountTarget`
/// (never trust the caller). `build/package-app.sh` only ever produces one relative layout;
/// this string match is what pins the helper to running *that* script and nothing an
/// unprivileged caller could point elsewhere. `..` is rejected outright — a literal absolute
/// path suffix match already can't be satisfied by a traversal, but reject defense-in-depth
/// rather than rely solely on the suffix check.
public func isValidStageCLIPath(_ path: String) -> Bool {
    path.hasPrefix("/") && !path.contains("..") && path.hasSuffix("/Contents/Resources/cli-src/install.sh")
}

/// Deterministic content hash over every regular file under `directory` — sorted relative
/// paths, each file's SHA-256 digest folded in that order into one combined digest. Security
/// review finding (2026-07-12, CRITICAL): `isValidStageCLIPath`'s shape check alone doesn't
/// prove the caller-supplied `install.sh` is the genuine, untampered one this app shipped —
/// ad-hoc signing (L4) means `codesign -v` on the individual copied binaries only proves
/// internal self-consistency, not authenticity, and `verifyClientIdentity`'s pid-based check can
/// be spoofed by any locally ad-hoc-signed process claiming the same identifier string. This
/// hash is what actually closes that gap: the *expected* value is compiled into this helper
/// binary at build time (`GeneratedCLIManifest.expectedTreeHashHex`, written by
/// `build/package-app.sh` before the shipped build, verified reproducible via a throwaway first
/// build pass using this exact function) — something only the trusted build pipeline can set,
/// not a caller of the XPC API, not even one that fully spoofs `verifyClientIdentity`.
/// `stageCLI` recomputes this over the caller-supplied path's containing directory and refuses
/// to execute anything that doesn't match bit-for-bit.
public func computeTreeHash(at directory: URL) -> String? {
    guard let enumerator = FileManager.default.enumerator(
        at: directory.standardizedFileURL,
        includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
        options: [.skipsHiddenFiles]
    ) else { return nil }

    let prefix = directory.standardizedFileURL.path
    var relativePaths: [String] = []
    for case let fileURL as URL in enumerator {
        guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else {
            return nil
        }
        // Security review finding (2026-07-13, CRITICAL): the previous `isRegularFile`-only
        // filter silently excluded symlinks from the hash — their presence/target contributed
        // nothing to `actualHash`, so a symlink planted anywhere under `directory` (dereferenced
        // by `install.sh` or anything it sources) bypassed the tamper check entirely. Fail
        // closed instead: a build-generated `cli-src/` tree should never legitimately contain a
        // symlink, so any symlink here — file or directory — rejects the whole hash rather than
        // being silently skipped.
        if values.isSymbolicLink == true { return nil }
        guard values.isRegularFile == true else { continue }
        let path = fileURL.standardizedFileURL.path
        guard path.hasPrefix(prefix + "/") else { continue }
        relativePaths.append(String(path.dropFirst(prefix.count + 1)))
    }
    guard !relativePaths.isEmpty else { return nil }
    relativePaths.sort()

    var combined = SHA256()
    for relativePath in relativePaths {
        guard let data = FileManager.default.contents(atPath: directory.appendingPathComponent(relativePath).path) else { return nil }
        combined.update(data: Data(relativePath.utf8))
        combined.update(data: Data(SHA256.hash(data: data)))
    }
    return combined.finalize().map { String(format: "%02x", $0) }.joined()
}

/// Fixed resolution path for vendored binaries the helper shells out to. `install.sh`'s CLI
/// path writes here directly; the GUI's first-run installer (`3-first-run-install`) stages its
/// own bundled copies to the same prefix so the privileged helper — which runs standalone under
/// launchd after SMJobBless, no `Bundle.main` back to the .app — always resolves one fixed path
/// regardless of which install path produced it.
public let installPrefix = "/usr/local/thlntfs"

/// Second candidate: Homebrew's own version-independent `opt/<formula>` symlink (always
/// present once `brew install thlntfs` links it, Apple Silicon default prefix — this project
/// is arm64-only per CLAUDE.md, so no Intel `/usr/local` brew prefix to also check). The
/// Formula deliberately keeps normal `bin.install`/`libexec.install` (Homebrew forbids `sudo`
/// during `brew install`, so it can never write the fixed `installPrefix` above) — this second
/// candidate is what lets the privileged helper find a brew-tap-only install without either
/// side needing to know about the other's install mechanism.
public let homebrewOptPrefix = "/opt/homebrew/opt/thlntfs"

public let thlntfsCandidatePrefixes = [installPrefix, homebrewOptPrefix]

/// Picks whichever candidate actually has a real `bin/thlntfs` on disk, first-listed wins.
/// Falls back to `installPrefix` (the documented default) when neither is present — same
/// behavior every caller already hardcoded before this existed, so injecting this as a
/// default parameter value never changes what a from-clean unit test observes.
public func resolveTHLNTFSPrefix(fileManager: FileManager = .default) -> String {
    for candidate in thlntfsCandidatePrefixes where fileManager.isExecutableFile(atPath: "\(candidate)/bin/thlntfs") {
        return candidate
    }
    return installPrefix
}

public let helperMachServiceName = AppIdentifiers.helperMachServiceName

public enum FsDriver: String, Codable, Sendable {
    // Raw value matches `cli/commands/mount.sh`'s literal `--fs-driver` values (L1: ntfs-3g is
    // the implicit default, ntfs3 is opt-in only via this flag, never an `-o` token).
    case ntfs3g = "ntfs-3g"
    case ntfs3 = "ntfs3"
    // ext2/3/4: the kernel auto-detects, so this is NOT a --fs-driver value. It's the GUI's
    // signal to the helper to skip --fs-driver (ntfs-3g can't mount ext4) and pass
    // --ignore-permissions instead, so the NFS export gets all_squash,anonuid=0,anongid=0
    // (vendor vmproxy/main.rs:1327) and the macOS user can write past ext's Unix ownership.
    // Reuses the existing `driver` XPC channel — no protocol signature change. NTFS keeps
    // .ntfs3g/.ntfs3 and never gets all_squash ("do not change the NTFS part").
    case ext = "ext"
}

/// Generic passthrough result for wrapper scripts that only ever print human-readable text —
/// none of `mount.sh`/`unmount.sh`/`pf-anchor.sh`/`pf-teardown.sh` emit structured JSON, so this
/// carries the real (stdout+stderr, exit code) shape rather than inventing fields none of them
/// produce.
public struct CommandResult: Codable, Sendable {
    public var output: String
    public var exitCode: Int32

    public init(output: String, exitCode: Int32) {
        self.output = output
        self.exitCode = exitCode
    }
}

/// Mutating XPC surface. Mount/unmount call the CLI's per-session security transaction inside the
/// already-root helper; there is deliberately no raw "load these PF rules" method anymore. That
/// older split API could load an unevaluated anchor with no lifecycle ownership or measured state.
/// `listDrives`/`status`/`diagnose` are deliberately absent:
/// each is read-only and explicitly Don't-listed as privileged in their own units
/// (`3-drive-detect`, `3-status-speed`, `3-diagnose-ui` all call the CLI directly, unprivileged).
@objc public protocol HelperXPCProtocol {
    /// `device` is re-validated against `deviceNamePattern` inside the helper before any shell
    /// call — never trusts the caller (§3). `driver`'s raw value must match `FsDriver`.
    /// `readOnly`: appends `ro` to the NFS client mount options (`cli/lib/nfs-mount.sh`'s
    /// `--read-only` flag) — the only real lever for a requested read-only mount, since
    /// anylinuxfs/ntfs-3g have no mode-request flag of their own (confirmed: no `force`/mode
    /// field on `MountCmd` in the vendored `cli.rs`; ntfs-3g's own dirty-journal check is the
    /// only thing that can *also* force read-only, independent of this flag).
    func mount(device: String, driver: String, mountPoint: String?, readOnly: Bool, reply: @escaping (Data?, String?) -> Void)

    /// `target` is re-validated against `isValidUnmountTarget` inside the helper.
    func unmount(target: String, reply: @escaping (Data?, String?) -> Void)

    /// Removes one recorded session, or reconciles stale sessions when nil. Never flushes a
    /// global/shared anchor, so one mount cannot invalidate another mount's protection.
    func teardown(sessionID: String?, reply: @escaping (Data?, String?) -> Void)

    /// Removes `installPrefix` (CLI + vendored dependencies, same tree `cli/commands/
    /// uninstall.sh` targets) plus the real invoking user's `~/.anylinuxfs` (rootfs cache +
    /// config.toml) and `~/Library/Logs/anylinuxfs*.log` — never the helper itself (see
    /// `uninstallHelper`). Rejects while any NFS mount is active, same safety check
    /// `uninstall.sh` makes.
    func removeDependencies(reply: @escaping (Data?, String?) -> Void)

    /// Un-blesses this helper: deletes its own `/Library/LaunchDaemons` plist and
    /// `/Library/PrivilegedHelperTools` binary, replies to the client, then `launchctl bootout`s
    /// its own launchd job last. The last XPC call any client should make — the mach service is
    /// gone once this returns. Combined with `removeDependencies`, this is what lets "drag the
    /// app to Trash" leave zero leftovers.
    func uninstallHelper(reply: @escaping (Data?, String?) -> Void)

    /// Runs the bundled `install.sh` (staged read-only inside the calling app's own
    /// `Contents/Resources/cli-src/`, `build/package-app.sh`) as this already-root helper
    /// process, with `--no-path-link` so a GUI-only install never puts `thlntfs` on the user's
    /// Terminal PATH. `installScriptPath` is re-validated inside the helper (§3: never trust
    /// the caller) before any shell call — must resolve to a real file whose path literally
    /// ends `/Contents/Resources/cli-src/install.sh`, the one fixed layout this script ever
    /// produces; nothing else is accepted regardless of what the GUI sends.
    func stageCLI(installScriptPath: String, reply: @escaping (Data?, String?) -> Void)

    /// Reports the CLI tree hash this specific running helper binary was built with
    /// (`expectedCLITreeHash`, same value `stageCLI` gates on). Has nothing to do with staging —
    /// it exists so `HelperInstaller` can tell "a helper is registered" (`SMJobCopyDictionary`,
    /// which only proves *some* job exists under the label — see its own doc comment) apart from
    /// "the registered helper is *this build's* helper." A daemon left running from a previous
    /// build reports its own old hash (or, for a helper old enough to predate this method
    /// entirely, doesn't answer at all) — both read as stale to the caller.
    func version(reply: @escaping (String?) -> Void)

    /// Self-termination path for GUI Quit. The GUI's Quit flow first calls `unmount`/`teardown`
    /// for cleanup, then this so the privileged launchd on-demand helper doesn't linger as root
    /// after the app closes (Activity Monitor can't kill it without sudo — it must exit itself
    /// via XPC). Replies before `exit(0)`, same reason `uninstallHelper` does: a reply queued
    /// after self-termination never reaches the client, and the GUI's `await` would hang.
    /// Distinct from `uninstallHelper` (which un-blesses + bootouts the launchd job for removal);
    /// this leaves registration intact so the next app launch re-uses the same blessed helper.
    func exitHelper(reply: @escaping (Data?, String?) -> Void)
}

/// Seam for `HelperService` so unit tests can assert on the exact argv built for a request
/// without ever spawning a real (privileged) process. `RealCommandRunner` is the only
/// production implementation.
public protocol PrivilegedCommandRunning {
    func run(_ executablePath: String, _ arguments: [String]) -> CommandResult
    func runPipingStdin(_ input: String, to executablePath: String, _ arguments: [String]) -> CommandResult
}

/// Lock-protected single-value holder — lets `captureOutput`'s two background readers each
/// write their own result without Swift 6 strict concurrency flagging a shared captured `var`
/// as a data race (the two boxes below are never touched by more than one thread at a time in
/// practice, but the type system can't see that through a plain closure capture).
private final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Data()

    func set(_ data: Data) {
        lock.lock()
        value = data
        lock.unlock()
    }

    func get() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

public struct RealCommandRunner: PrivilegedCommandRunning {
    public static let timeoutExitCode: Int32 = 124

    public init() {}

    /// Drains both pipes concurrently on background queues, started *before* `waitUntilExit()`
    /// — reading them sequentially afterward (the previous shape of this code) deadlocks the
    /// instant combined stdout+stderr exceeds the ~64KB pipe buffer: the child blocks writing to
    /// a full pipe nobody is draining yet, while this thread blocks in `waitUntilExit()` waiting
    /// for a child that itself is blocked. Apple's own `Process`/`Pipe` docs call this out
    /// explicitly. Every command run through here so far produced small enough output to never
    /// hit it — `HelperService.stageCLI`'s `install.sh` (several file copies + `codesign`/`xattr`
    /// calls per binary) was the first real trigger.
    private func captureOutput(_ process: Process, _ outPipe: Pipe, _ errPipe: Pipe) -> String {
        let outBox = DataBox()
        let errBox = DataBox()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            outBox.set(outPipe.fileHandleForReading.readDataToEndOfFile())
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            errBox.set(errPipe.fileHandleForReading.readDataToEndOfFile())
            group.leave()
        }
        process.waitUntilExit()
        group.wait()
        return (String(data: outBox.get(), encoding: .utf8) ?? "") + (String(data: errBox.get(), encoding: .utf8) ?? "")
    }

    private func configureEnvironment(for process: Process) {
        var env = ProcessInfo.processInfo.environment
        if let connection = NSXPCConnection.current() {
            let uid = connection.effectiveUserIdentifier
            let gid = connection.effectiveGroupIdentifier
            env["SUDO_UID"] = String(uid)
            env["SUDO_GID"] = String(gid)
            if let pw = getpwuid(uid), let dir = pw.pointee.pw_dir {
                env["HOME"] = String(cString: dir)
            }
        }
        process.environment = env
    }

    public func run(_ executablePath: String, _ arguments: [String]) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        configureEnvironment(for: process)

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return CommandResult(output: "helper: failed to launch \(executablePath): \(error)", exitCode: -1)
        }
        let combined = captureOutput(process, outPipe, errPipe)
        return CommandResult(output: combined, exitCode: process.terminationStatus)
    }

    /// Runs an unprivileged or otherwise bounded command. The protocol requirement above stays
    /// unbounded because helper mount/install operations have their own lifecycle contracts; the
    /// GUI drive scanner opts into this overload so a wedged raw-device probe cannot live forever.
    /// A temporary file avoids pipe-buffer and inherited-pipe EOF traps if the child spawns its
    /// own short-lived probe subprocess before the timeout fires.
    public func run(
        _ executablePath: String,
        _ arguments: [String],
        timeout: TimeInterval
    ) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        configureEnvironment(for: process)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("thlntfs-command-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil),
              let outputHandle = try? FileHandle(forWritingTo: outputURL)
        else {
            return CommandResult(output: "helper: failed to create command output file", exitCode: -1)
        }
        defer {
            try? outputHandle.close()
            try? FileManager.default.removeItem(at: outputURL)
        }
        process.standardOutput = outputHandle
        process.standardError = outputHandle

        do {
            try process.run()
        } catch {
            return CommandResult(output: "helper: failed to launch \(executablePath): \(error)", exitCode: -1)
        }

        let processGroup = DispatchGroup()
        processGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            processGroup.leave()
        }

        var timedOut = false
        let timeoutMilliseconds = max(1, Int(timeout * 1_000))
        if processGroup.wait(timeout: .now() + .milliseconds(timeoutMilliseconds)) == .timedOut {
            timedOut = true
            process.terminate()
            // A process stuck in a kernel-backed device operation may ignore SIGTERM. Keep the
            // caller bounded and escalate only that exact child after a short grace period.
            if processGroup.wait(timeout: .now() + .milliseconds(250)) == .timedOut {
                if process.isRunning {
                    _ = Darwin.kill(process.processIdentifier, SIGKILL)
                }
                processGroup.wait()
            }
        }

        try? outputHandle.synchronize()
        let output = (try? String(contentsOf: outputURL, encoding: .utf8)) ?? ""
        if timedOut {
            let suffix = output.isEmpty ? "" : "\n\(output)"
            return CommandResult(output: "command timed out\(suffix)", exitCode: Self.timeoutExitCode)
        }
        return CommandResult(output: output, exitCode: process.terminationStatus)
    }

    public func runPipingStdin(_ input: String, to executablePath: String, _ arguments: [String]) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        configureEnvironment(for: process)

        let inPipe = Pipe()
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardInput = inPipe
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return CommandResult(output: "helper: failed to launch \(executablePath): \(error)", exitCode: -1)
        }
        inPipe.fileHandleForWriting.write(input.data(using: .utf8) ?? Data())
        inPipe.fileHandleForWriting.closeFile()
        let combined = captureOutput(process, outPipe, errPipe)
        return CommandResult(output: combined, exitCode: process.terminationStatus)
    }
}

/// Best-effort caller-identity check. Ad-hoc signing (L4 — no paid Developer account, no
/// notarization) means there is no trusted certificate chain to pin against: this only confirms
/// the connecting process's own code-signed identifier, which any locally ad-hoc-signed binary
/// can also claim. The load-bearing security control is per-call input validation above
/// (`validateDevice`/`isValidUnmountTarget`), not this check — documented here so it isn't
/// mistaken for a strong boundary later.
public func verifyClientIdentity(pid: pid_t, expectedIdentifier: String) -> Bool {
    var code: SecCode?
    let attributes = [kSecGuestAttributePid: pid] as CFDictionary
    guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess, let code else {
        return false
    }
    var requirement: SecRequirement?
    let requirementString = "identifier \"\(expectedIdentifier)\"" as CFString
    guard SecRequirementCreateWithString(requirementString, [], &requirement) == errSecSuccess,
          let requirement else {
        return false
    }
    return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
}
