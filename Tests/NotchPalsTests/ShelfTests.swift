import XCTest
@testable import NotchPals

final class ShelfTests: XCTestCase {
    private var root: URL!
    private var shelfDir: URL!
    private var storage: ShelfStorage!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShelfTests-\(UUID().uuidString)", isDirectory: true)
        shelfDir = root.appendingPathComponent("shelf", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        storage = ShelfStorage(directory: shelfDir)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeFile(_ name: String, _ content: String = "x") throws -> URL {
        let url = root.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testAddCopiesFileAndSurvivesOriginalRemoval() throws {
        let src = try makeFile("a.txt", "hola")
        let copy = try storage.add(src)
        try FileManager.default.removeItem(at: src)
        XCTAssertEqual(try String(contentsOf: copy), "hola")
        XCTAssertEqual(copy.deletingLastPathComponent().standardizedFileURL, shelfDir.standardizedFileURL)
    }

    func testUniqueNames() throws {
        let src = try makeFile("a.txt")
        let c1 = try storage.add(src)
        let c2 = try storage.add(src)
        let c3 = try storage.add(src)
        XCTAssertEqual(c1.lastPathComponent, "a.txt")
        XCTAssertEqual(c2.lastPathComponent, "a 2.txt")
        XCTAssertEqual(c3.lastPathComponent, "a 3.txt")
    }

    func testUniqueNamesWithoutExtension() throws {
        let src = try makeFile("README")
        _ = try storage.add(src)
        XCTAssertEqual(try storage.add(src).lastPathComponent, "README 2")
    }

    func testRemove() throws {
        let copy = try storage.add(try makeFile("a.txt"))
        storage.remove(copy)
        XCTAssertFalse(FileManager.default.fileExists(atPath: copy.path))
    }

    func testClearDeletesDirectory() throws {
        _ = try storage.add(try makeFile("a.txt"))
        storage.clear()
        XCTAssertFalse(FileManager.default.fileExists(atPath: shelfDir.path))
    }

    @MainActor func testStoreAddRemoveClear() throws {
        let store = ShelfStore(storage: storage)
        let src = try makeFile("a.txt")
        store.add(urls: [src])
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items[0].name, "a.txt")
        store.remove(store.items[0])
        XCTAssertTrue(store.items.isEmpty)
        store.add(urls: [src, src])
        XCTAssertEqual(store.items.count, 2)
        store.clear()
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: shelfDir.path))
    }

    @MainActor func testModuleMetadata() {
        let m = ShelfModule()
        XCTAssertEqual(m.id, "shelf")
        XCTAssertEqual(m.title, "Bandeja")
        XCTAssertEqual(m.systemImage, "tray.and.arrow.down")
    }
}
