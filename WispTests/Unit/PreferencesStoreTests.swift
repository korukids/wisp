import XCTest
@testable import Wisp

@MainActor
final class PreferencesStoreTests: XCTestCase {

    private var store: PreferencesStore!
    private var testDefaults: UserDefaults!
    private var testSuiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        testSuiteName = "com.wisp.tests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuiteName)!
        store = PreferencesStore(defaults: testDefaults)
    }

    override func tearDown() async throws {
        testDefaults.removePersistentDomain(forName: testSuiteName)
        store = nil
        testDefaults = nil
        testSuiteName = nil
        try await super.tearDown()
    }

    // MARK: - Cleanup Prompt

    func testDefaultCleanupPromptIsNotEmpty() {
        XCTAssertFalse(PreferencesStore.defaultCleanupPrompt.isEmpty)
    }

    func testInitialCleanupPromptIsDefault() {
        XCTAssertEqual(store.cleanupPrompt, PreferencesStore.defaultCleanupPrompt)
    }

    func testSetCleanupPromptPersists() throws {
        let custom = "Always respond in bullet points."
        try store.setCleanupPrompt(custom)
        XCTAssertEqual(store.cleanupPrompt, custom)

        // New store reading same defaults should see the persisted value
        let store2 = PreferencesStore(defaults: testDefaults)
        XCTAssertEqual(store2.cleanupPrompt, custom)
    }

    func testSetCleanupPromptThrowsOnEmpty() {
        XCTAssertThrowsError(try store.setCleanupPrompt("")) { error in
            XCTAssertEqual(error as? PreferencesError, .emptyPrompt)
        }
    }

    func testSetCleanupPromptThrowsOnWhitespaceOnly() {
        XCTAssertThrowsError(try store.setCleanupPrompt("   \n  ")) { error in
            XCTAssertEqual(error as? PreferencesError, .emptyPrompt)
        }
    }

    func testResetCleanupPromptRestoresDefault() throws {
        try store.setCleanupPrompt("Custom prompt.")
        store.resetCleanupPrompt()
        XCTAssertEqual(store.cleanupPrompt, PreferencesStore.defaultCleanupPrompt)
    }

    func testCorruptedDefaultsFallsBackToDefault() {
        // Simulate a corrupted/empty stored prompt
        testDefaults.set("", forKey: "com.wisp.cleanupPrompt")
        let corruptedStore = PreferencesStore(defaults: testDefaults)
        XCTAssertEqual(corruptedStore.cleanupPrompt, PreferencesStore.defaultCleanupPrompt)
    }

    // MARK: - Microphone UID

    func testInitialSelectedMicrophoneUIDIsNil() {
        XCTAssertNil(store.selectedMicrophoneUID)
    }

    func testSetMicrophoneUIDPersists() {
        let uid = "AppleUSBAudioEngine:Apple Inc.:Test:001"
        store.setMicrophoneUID(uid)
        XCTAssertEqual(store.selectedMicrophoneUID, uid)

        let store2 = PreferencesStore(defaults: testDefaults)
        XCTAssertEqual(store2.selectedMicrophoneUID, uid)
    }

    func testSetMicrophoneUIDNilClearsSelection() {
        store.setMicrophoneUID("SomeDevice")
        store.setMicrophoneUID(nil)
        XCTAssertNil(store.selectedMicrophoneUID)

        let store2 = PreferencesStore(defaults: testDefaults)
        XCTAssertNil(store2.selectedMicrophoneUID)
    }

    func testResetMicrophoneClearsSelection() {
        store.setMicrophoneUID("SomeDevice")
        store.resetMicrophone()
        XCTAssertNil(store.selectedMicrophoneUID)
    }
}
