import XCTest
@testable import Wisp

@MainActor
final class LogEntryEditTests: XCTestCase {

    private var logStore: TranscriptionLogStore!
    private var wordDictionary: WordDictionaryStore!
    private var testURL: URL!
    private var testDefaults: UserDefaults!
    private var testSuiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        testURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wisp-test-log-\(UUID().uuidString).json")
        testSuiteName = "com.wisp.tests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuiteName)!
        logStore = TranscriptionLogStore(url: testURL)
        wordDictionary = WordDictionaryStore(defaults: testDefaults)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: testURL)
        testDefaults.removePersistentDomain(forName: testSuiteName)
        logStore = nil
        wordDictionary = nil
        testURL = nil
        testDefaults = nil
        testSuiteName = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Simulates the commit-edit action performed by LogEntryRow.
    private func simulateEditCommit(entryID: UUID, oldText: String, newText: String) {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newWords = WordDictionaryStore.extractNewWords(from: oldText, to: trimmed)
        for word in newWords {
            wordDictionary.add(word)
        }
        logStore.update(id: entryID, text: trimmed)
    }

    // MARK: - Dictionary population from edits

    func testEditCommit_newWordAddedToDictionary() {
        logStore.append(text: "hello wisk")
        let entry = logStore.entries[0]
        simulateEditCommit(entryID: entry.id, oldText: entry.text, newText: "hello whisk")
        XCTAssertTrue(wordDictionary.contains("whisk"))
    }

    func testEditCommit_unchangedWordsNotAddedToDictionary() {
        logStore.append(text: "hello world")
        let entry = logStore.entries[0]
        simulateEditCommit(entryID: entry.id, oldText: entry.text, newText: "hello world")
        XCTAssertTrue(wordDictionary.words.isEmpty)
    }

    func testEditCommit_multipleNewWordsAllAdded() {
        logStore.append(text: "a b")
        let entry = logStore.entries[0]
        simulateEditCommit(entryID: entry.id, oldText: entry.text, newText: "a b SwiftUI Rosoll")
        XCTAssertTrue(wordDictionary.contains("SwiftUI"))
        XCTAssertTrue(wordDictionary.contains("Rosoll"))
    }

    // MARK: - Blank edit handling

    func testEditCommit_blankInputDoesNotAddToDictionary() {
        logStore.append(text: "hello world")
        let entry = logStore.entries[0]
        simulateEditCommit(entryID: entry.id, oldText: entry.text, newText: "   ")
        XCTAssertTrue(wordDictionary.words.isEmpty)
    }

    func testEditCommit_blankInputDoesNotUpdateLog() {
        logStore.append(text: "hello world")
        let entry = logStore.entries[0]
        simulateEditCommit(entryID: entry.id, oldText: entry.text, newText: "   ")
        XCTAssertEqual(logStore.entries[0].text, "hello world")
    }

    // MARK: - Log store update

    func testEditCommit_updatesLogEntryText() {
        logStore.append(text: "hello wisk")
        let entry = logStore.entries[0]
        simulateEditCommit(entryID: entry.id, oldText: entry.text, newText: "hello whisk")
        XCTAssertEqual(logStore.entries[0].text, "hello whisk")
    }

    func testEditCommit_persistsLogUpdate() {
        logStore.append(text: "hello wisk")
        let entry = logStore.entries[0]
        simulateEditCommit(entryID: entry.id, oldText: entry.text, newText: "hello whisk")
        let reloaded = TranscriptionLogStore(url: testURL)
        XCTAssertEqual(reloaded.entries[0].text, "hello whisk")
    }

    // MARK: - No duplicate dictionary entries

    func testEditCommit_duplicateWordNotAddedTwice() {
        logStore.append(text: "hello")
        let entry1 = logStore.entries[0]
        simulateEditCommit(entryID: entry1.id, oldText: entry1.text, newText: "hello SwiftUI")
        logStore.append(text: "world")
        let entry2 = logStore.entries[0]
        simulateEditCommit(entryID: entry2.id, oldText: entry2.text, newText: "world SwiftUI")
        XCTAssertEqual(wordDictionary.words.filter {
            $0.caseInsensitiveCompare("SwiftUI") == .orderedSame
        }.count, 1)
    }
}
