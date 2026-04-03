import Testing
import Darwin
import ArgumentParser
@testable import NSAssetsCLI

@Suite(
    .serialized,
    .disabled("Temporarily disabled while investigating CI exit code 1 after terminal-related tests.")
)
struct TerminalRawModeTests {
    @Test
    func initThrowsCleanExitWhenTerminalAttributesCannotBeRead() {
        let terminal = TerminalOperations(
            getAttributes: { _, _ in -1 },
            setAttributes: { _, _, _ in 0 },
            installRestoreSignalHandlers: {}
        )

        do {
            _ = try TerminalRawMode(terminal: terminal)
            Issue.record("Expected TerminalRawMode init to throw when tcgetattr fails.")
        } catch let error as CleanExit {
            #expect(String(describing: error) == "Unable to read terminal attributes.")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func enableConfiguresRawModeAndDisableRestoresOriginalAttributes() throws {
        let original = makeTermios(
            localFlags: tcflag_t(ECHO | ICANON | ISIG),
            inputFlags: tcflag_t(ICRNL | IXON | IXOFF)
        )
        var configuredRaw: termios?
        var restoredAttributes: termios?
        var installCount = 0
        let terminal = TerminalOperations(
            getAttributes: { _, attributes in
                attributes.pointee = original
                return 0
            },
            setAttributes: { _, _, attributes in
                let snapshot = attributes.pointee
                if configuredRaw == nil {
                    configuredRaw = snapshot
                } else {
                    restoredAttributes = snapshot
                }
                return 0
            },
            installRestoreSignalHandlers: {
                installCount += 1
            }
        )

        let rawMode = try TerminalRawMode(terminal: terminal)
        try rawMode.enable()

        let raw = try #require(configuredRaw)
        #expect(installCount == 1)
        #expect(raw.c_lflag & tcflag_t(ECHO) == 0)
        #expect(raw.c_lflag & tcflag_t(ICANON) == 0)
        #expect(raw.c_lflag & tcflag_t(ISIG) == tcflag_t(ISIG))
        #expect(raw.c_iflag & tcflag_t(ICRNL) == 0)
        #expect(raw.c_iflag & tcflag_t(IXON) == 0)
        #expect(raw.c_iflag & tcflag_t(IXOFF) == tcflag_t(IXOFF))

        rawMode.disable()

        let restored = try #require(restoredAttributes)
        #expect(restored.c_lflag == original.c_lflag)
        #expect(restored.c_iflag == original.c_iflag)
    }

    @Test
    func enableThrowsCleanExitWhenRawModeConfigurationFails() throws {
        let original = makeTermios(localFlags: tcflag_t(ECHO | ICANON), inputFlags: tcflag_t(ICRNL | IXON))
        var installCount = 0
        let terminal = TerminalOperations(
            getAttributes: { _, attributes in
                attributes.pointee = original
                return 0
            },
            setAttributes: { _, _, _ in -1 },
            installRestoreSignalHandlers: {
                installCount += 1
            }
        )

        let rawMode = try TerminalRawMode(terminal: terminal)

        do {
            try rawMode.enable()
            Issue.record("Expected enable() to throw when tcsetattr fails.")
        } catch let error as CleanExit {
            #expect(String(describing: error) == "Unable to configure terminal for interactive selection.")
        }

        #expect(installCount == 0)
    }

    @Test
    func disableDoesNothingWhenRawModeIsInactive() {
        var restoreCount = 0

        let rawMode = try? TerminalRawMode(terminal: TerminalOperations(
            getAttributes: { _, _ in 0 },
            setAttributes: { _, _, _ in
                restoreCount += 1
                return 0
            },
            installRestoreSignalHandlers: {}
        ))
        rawMode?.disable()

        #expect(restoreCount == 0)
    }
}

private func makeTermios(localFlags: tcflag_t, inputFlags: tcflag_t) -> termios {
    var attributes = termios()
    attributes.c_lflag = localFlags
    attributes.c_iflag = inputFlags
    return attributes
}
