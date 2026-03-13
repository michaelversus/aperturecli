import Testing
@testable import NSAssetsCLI

struct CursorMultiSelectTests {
    @Test(arguments: [
        (0, 0, 5, 0),
        (2, 3, 5, 2),
        (4, 0, 5, 0),
        (5, 0, 5, 1),
        (8, 4, 3, 6)
    ])
    func updatedTopIndexKeepsCursorVisible(
        cursor: Int,
        topIndex: Int,
        viewportSize: Int,
        expected: Int
    ) {
        let selector = CursorMultiSelect(options: ["A", "B", "C", "D", "E", "F", "G", "H", "I"])

        let result = selector.updatedTopIndex(cursor: cursor, topIndex: topIndex, viewportSize: viewportSize)

        #expect(result == expected)
    }

    @Test
    func makeFrameShowsVisibleOptionsSelectionMarkersAndFooter() {
        let selector = CursorMultiSelect(options: ["Snapshots", "FeatureSnapshots", "UITests"])

        let frame = selector.makeFrame(
            cursor: 1,
            topIndex: 0,
            viewportSize: 5,
            selected: [0, 2],
            previousLines: 0
        )

        #expect(frame == [
            "Select snapshot schemes (2 selected):",
            "  (x) Snapshots",
            "> ( ) FeatureSnapshots",
            "  (x) UITests",
            "",
            "",
            "Showing 1-3 of 3",
            "Up/Down: move, Space: toggle, Enter: confirm",
            ""
        ].joined(separator: "\n"))
    }

    @Test
    func makeFramePrependsClearSequencesForPreviouslyRenderedLines() {
        let selector = CursorMultiSelect(options: ["A", "B", "C", "D"])

        let frame = selector.makeFrame(
            cursor: 2,
            topIndex: 1,
            viewportSize: 2,
            selected: [],
            previousLines: 2
        )

        #expect(frame.hasPrefix("\u{1B}[1A\r\u{1B}[2K\u{1B}[1A\r\u{1B}[2K"))
        #expect(frame.contains("  ( ) B\n> ( ) C\n"))
        #expect(frame.contains("Showing 2-3 of 4\n"))
    }

    @Test
    func runReturnsHighlightedOptionWhenNothingIsSelected() throws {
        let selector = CursorMultiSelect(options: ["Snapshots", "FeatureSnapshots", "UITests"])
        var writtenOutput = [String]()
        var enableCount = 0
        var disableCount = 0
        var keys: [CursorMultiSelect.Key] = [.arrowDown, .enter]
        let environment = CursorMultiSelect.Environment(
            makeRawMode: {
                MockTerminalMode(
                    enable: { enableCount += 1 },
                    disable: { disableCount += 1 }
                )
            },
            readKey: { keys.removeFirst() },
            writeToStdout: { writtenOutput.append($0) },
            terminalRows: { 12 }
        )

        let selected = try selector.run(environment: environment)

        #expect(selected == ["FeatureSnapshots"])
        #expect(enableCount == 1)
        #expect(disableCount == 1)
        #expect(writtenOutput.first == "\u{1B}[?25l")
        #expect(writtenOutput.suffix(2).elementsEqual(["\u{1B}[?25h", "\n"]))
    }

    @Test
    func runReturnsSortedToggledSelectionsWhenConfirmed() throws {
        let selector = CursorMultiSelect(options: ["Snapshots", "FeatureSnapshots", "UITests"])
        var writtenOutput = [String]()
        var keys: [CursorMultiSelect.Key] = [.space, .arrowDown, .arrowDown, .space, .enter]
        let environment = CursorMultiSelect.Environment(
            makeRawMode: {
                MockTerminalMode(enable: {}, disable: {})
            },
            readKey: { keys.removeFirst() },
            writeToStdout: { writtenOutput.append($0) },
            terminalRows: { 14 }
        )

        let selected = try selector.run(environment: environment)

        #expect(selected == ["Snapshots", "UITests"])
        #expect(writtenOutput.count == 8)
    }

    @Test(arguments: [
        ([CursorMultiSelect.Key.arrowUp, .enter], "UITests"),
        ([CursorMultiSelect.Key.arrowDown, .arrowDown, .arrowDown, .enter], "Snapshots")
    ])
    func runWrapsCursorMovementAroundTheOptions(
        keys: [CursorMultiSelect.Key],
        expectedSelection: String
    ) throws {
        let selector = CursorMultiSelect(options: ["Snapshots", "FeatureSnapshots", "UITests"])
        var remainingKeys = keys
        let environment = CursorMultiSelect.Environment(
            makeRawMode: {
                MockTerminalMode(enable: {}, disable: {})
            },
            readKey: { remainingKeys.removeFirst() },
            writeToStdout: { _ in },
            terminalRows: { 12 }
        )

        let selected = try selector.run(environment: environment)

        #expect(selected == [expectedSelection])
    }

    @Test
    func runIgnoresUnknownKeysAndAllowsDeselection() throws {
        let selector = CursorMultiSelect(options: ["Snapshots", "FeatureSnapshots", "UITests"])
        var keys: [CursorMultiSelect.Key] = [.unknown, .space, .space, .enter]
        let environment = CursorMultiSelect.Environment(
            makeRawMode: {
                MockTerminalMode(enable: {}, disable: {})
            },
            readKey: { keys.removeFirst() },
            writeToStdout: { _ in },
            terminalRows: { 12 }
        )

        let selected = try selector.run(environment: environment)

        #expect(selected == ["Snapshots"])
    }
}

private final class MockTerminalMode: TerminalMode {
    private let onEnable: () throws -> Void
    private let onDisable: () -> Void

    init(
        enable: @escaping () throws -> Void,
        disable: @escaping () -> Void
    ) {
        self.onEnable = enable
        self.onDisable = disable
    }

    func enable() throws {
        try onEnable()
    }

    func disable() {
        onDisable()
    }
}
