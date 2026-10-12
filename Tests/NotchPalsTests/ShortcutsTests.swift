import XCTest
@testable import NotchPals

final class ShortcutsTests: XCTestCase {
    func testParserTrimsDropsEmptyAndDuplicates() {
        let out = "Uno\n  Dos  \r\n\nUno\nTres con espacios\n"
        XCTAssertEqual(ShortcutsListParser.parse(out), ["Uno", "Dos", "Tres con espacios"])
        XCTAssertEqual(ShortcutsListParser.parse(""), [])
    }

    func testDefaultFavorites() {
        let ids = FavoriteAppList().items.map(\.bundleID)
        XCTAssertEqual(ids.count, 5)
        XCTAssertTrue(ids.contains("com.apple.Safari"))
    }

    func testAddRemoveAndFilter() {
        var list = FavoriteAppList(items: [])
        XCTAssertTrue(list.add(FavoriteApp(bundleID: "a", name: "A")))
        XCTAssertFalse(list.add(FavoriteApp(bundleID: "a", name: "Otra")))
        list.add(FavoriteApp(bundleID: "b", name: "B"))
        XCTAssertEqual(list.filtered { $0 == "b" }.map(\.bundleID), ["b"])
        list.remove(bundleID: "a")
        XCTAssertEqual(list.items.map(\.bundleID), ["b"])
    }

    func testStoreRoundTripAndDefaults() {
        let suite = "notchpals.tests.shortcuts"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = FavoriteAppsStore(defaults: defaults)
        XCTAssertEqual(store.load(), FavoriteAppList())
        var list = FavoriteAppList(items: [])
        list.add(FavoriteApp(bundleID: "x.y", name: "XY"))
        store.save(list)
        XCTAssertEqual(store.load().items, [FavoriteApp(bundleID: "x.y", name: "XY")])
    }
}
