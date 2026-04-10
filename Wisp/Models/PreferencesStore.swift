import Foundation
import Observation
import Security
import ServiceManagement

enum PreferencesError: Error, Equatable {
    case emptyPrompt
}

@MainActor
@Observable
final class PreferencesStore {

    static let defaultCleanupPrompt: String = """
        You are a dictation cleanup assistant. Clean up the following \
        transcribed speech. Rules:
        - Remove filler words (um, uh, like when used as filler, you know, etc.)
        - Fix punctuation and capitalization
        - Preserve the original meaning exactly — do NOT rephrase or rewrite
        - Do NOT add any commentary, just return the cleaned text
        - If the input is already clean, return it unchanged
        """

    private(set) var apiKey: String?
    private(set) var cleanupPrompt: String
    private(set) var selectedMicrophoneUID: String?
    private(set) var launchOnStartup: Bool

    private let defaults: UserDefaults

    private enum Keys {
        static let cleanupPrompt = "com.wisp.cleanupPrompt"
        static let selectedMicrophoneUID = "com.wisp.selectedMicrophoneUID"
        static let launchOnStartup = "com.wisp.launchOnStartup"
        static let apiKeyService = "com.wisp.api-key"
        static let apiKeyAccount = "elevenlabs"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.apiKey = Self.loadApiKeyFromKeychain()
        let stored = defaults.string(forKey: Keys.cleanupPrompt) ?? ""
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        self.cleanupPrompt = trimmed.isEmpty ? Self.defaultCleanupPrompt : trimmed
        self.selectedMicrophoneUID = defaults.string(forKey: Keys.selectedMicrophoneUID)
        self.launchOnStartup = defaults.bool(forKey: Keys.launchOnStartup)
    }

    // MARK: - API Key (Keychain)

    func setApiKey(_ key: String?) {
        if let key, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            apiKey = trimmed
            Self.saveApiKeyToKeychain(trimmed)
        } else {
            apiKey = nil
            Self.deleteApiKeyFromKeychain()
        }
    }

    private static func saveApiKeyToKeychain(_ value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keys.apiKeyService,
            kSecAttrAccount as String: Keys.apiKeyAccount,
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = data
        SecItemAdd(attrs as CFDictionary, nil)
    }

    private static func loadApiKeyFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keys.apiKeyService,
            kSecAttrAccount as String: Keys.apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteApiKeyFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keys.apiKeyService,
            kSecAttrAccount as String: Keys.apiKeyAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Cleanup Prompt

    func setCleanupPrompt(_ prompt: String) throws {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PreferencesError.emptyPrompt }
        cleanupPrompt = trimmed
        defaults.set(trimmed, forKey: Keys.cleanupPrompt)
    }

    func resetCleanupPrompt() {
        cleanupPrompt = Self.defaultCleanupPrompt
        defaults.removeObject(forKey: Keys.cleanupPrompt)
    }

    // MARK: - Microphone

    func setMicrophoneUID(_ uid: String?) {
        selectedMicrophoneUID = uid
        if let uid {
            defaults.set(uid, forKey: Keys.selectedMicrophoneUID)
        } else {
            defaults.removeObject(forKey: Keys.selectedMicrophoneUID)
        }
    }

    func resetMicrophone() {
        setMicrophoneUID(nil)
    }

    // MARK: - Launch on Startup

    /// Registers or unregisters the app as a login item and persists the preference.
    /// Throws if the system call fails (e.g. permission denied, MDM restriction).
    func setLaunchOnStartup(_ enabled: Bool) throws {
        let currentStatus = SMAppService.mainApp.status
        if enabled {
            if currentStatus != .enabled {
                try SMAppService.mainApp.register()
            }
        } else {
            if currentStatus == .enabled || currentStatus == .requiresApproval {
                try SMAppService.mainApp.unregister()
            }
        }
        launchOnStartup = enabled
        defaults.set(enabled, forKey: Keys.launchOnStartup)
    }

    /// Updates the stored preference to match the actual system state without calling SMAppService.
    /// Called at app launch to reconcile with changes made outside the app (e.g. System Settings).
    func syncLaunchOnStartup(_ enabled: Bool) {
        launchOnStartup = enabled
        defaults.set(enabled, forKey: Keys.launchOnStartup)
    }
}
