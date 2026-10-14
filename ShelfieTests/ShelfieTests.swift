import XCTest
@testable import Shelfie

final class ShelfieTests: XCTestCase {
    func testTabsAreShelfAddNext() {
        XCTAssertEqual(ShelfieTab.allCases.map(\.rawValue), ["Shelf", "Add", "Next"])
    }

    func testPaletteHexValues() {
        // Guards the design tokens against accidental edits; hex parsing round-trips.
        let ui = UIColor(Theme.Colors.brick)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(Int((r * 255).rounded()), 0x8E)
        XCTAssertEqual(Int((g * 255).rounded()), 0x3F)
        XCTAssertEqual(Int((b * 255).rounded()), 0x2B)
    }
}
