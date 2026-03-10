import Testing
@testable import ApertureCLI

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
}
