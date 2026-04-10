import XCTest
@testable import Wisp

@MainActor
final class WordDictionaryStoreTests: XCTestCase {

    private var store: WordDictionaryStore!
    private var testDefaults: UserDefaults!
    private var testSuiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        testSuiteName = "com.wisp.tests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuiteName)!
        store = WordDictionaryStore(defaults: testDefaults)
    }

    override func tearDown() async throws {
        testDefaults.removePersistentDomain(forName: testSuiteName)
        store = nil
        testDefaults = nil
        testSuiteName = nil
        try await super.tearDown()
    }

    // MARK: - add

    func testAdd_appendsWord() {
        store.add("SwiftUI")
        XCTAssertEqual(store.words, ["SwiftUI"])
    }

    func testAdd_trimsWhitespace() {
        store.add("  WhisperKit  ")
        XCTAssertEqual(store.words, ["WhisperKit"])
    }

    func testAdd_ignoresBlankInput() {
        store.add("   ")
        XCTAssertTrue(store.words.isEmpty)
    }

    func testAdd_ignoresEmptyString() {
        store.add("")
        XCTAssertTrue(store.words.isEmpty)
    }

    func testAdd_ignoresDuplicateCaseSensitive() {
        store.add("Wisp")
        store.add("Wisp")
        XCTAssertEqual(store.words.count, 1)
    }

    func testAdd_ignoresDuplicateCaseInsensitive() {
        store.add("Wisp")
        store.add("wisp")
        XCTAssertEqual(store.words.count, 1)
    }

    func testAdd_storesWordAsEntered() {
        store.add("SwiftUI")
        XCTAssertEqual(store.words.first, "SwiftUI")
    }

    // MARK: - remove(word:)

    func testRemove_byWord_removesEntry() {
        store.add("Wisp")
        store.add("Swift")
        store.remove("Wisp")
        XCTAssertEqual(store.words, ["Swift"])
    }

    func testRemove_byWord_isCaseInsensitive() {
        store.add("Wisp")
        store.remove("wisp")
        XCTAssertTrue(store.words.isEmpty)
    }

    func testRemove_byWord_noOpIfAbsent() {
        store.add("Wisp")
        store.remove("Other")
        XCTAssertEqual(store.words.count, 1)
    }

    // MARK: - remove(at:)

    func testRemove_atOffsets_removesEntry() {
        store.add("A")
        store.add("B")
        store.remove(at: IndexSet(integer: 0))
        XCTAssertEqual(store.words, ["B"])
    }

    // MARK: - update

    func testUpdate_replacesWordAtIndex() {
        store.add("Wisk")
        store.update(at: 0, word: "Whisk")
        XCTAssertEqual(store.words, ["Whisk"])
    }

    func testUpdate_ignoresBlankReplacement() {
        store.add("Wisp")
        store.update(at: 0, word: "  ")
        XCTAssertEqual(store.words, ["Wisp"])
    }

    func testUpdate_ignoresOutOfBoundsIndex() {
        store.add("Wisp")
        store.update(at: 5, word: "Other")
        XCTAssertEqual(store.words, ["Wisp"])
    }

    // MARK: - contains

    func testContains_returnsTrueForExistingWord() {
        store.add("Wisp")
        XCTAssertTrue(store.contains("Wisp"))
    }

    func testContains_isCaseInsensitive() {
        store.add("Wisp")
        XCTAssertTrue(store.contains("wisp"))
        XCTAssertTrue(store.contains("WISP"))
    }

    func testContains_returnsFalseForAbsentWord() {
        XCTAssertFalse(store.contains("Wisp"))
    }

    // MARK: - Persistence (UserDefaults round-trip)

    func testPersistence_roundTrip() {
        store.add("SwiftUI")
        store.add("Rosoll")
        let store2 = WordDictionaryStore(defaults: testDefaults)
        XCTAssertEqual(store2.words, ["SwiftUI", "Rosoll"])
    }

    func testPersistence_deletedWordDoesNotReappear() {
        store.add("Wisp")
        store.remove("Wisp")
        let store2 = WordDictionaryStore(defaults: testDefaults)
        XCTAssertTrue(store2.words.isEmpty)
    }

    func testPersistence_emptyOnFirstInit() {
        let freshStore = WordDictionaryStore(defaults: testDefaults)
        XCTAssertTrue(freshStore.words.isEmpty)
    }
}
