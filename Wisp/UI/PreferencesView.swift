import SwiftUI
import KeyboardShortcuts

struct PreferencesView: View {

    let preferences: PreferencesStore
    let microphoneList: MicrophoneList
    @Bindable var wordDictionary: WordDictionaryStore

    @State private var apiKeyDraft: String = ""
    @State private var apiKeySaved: Bool = false
    @State private var promptDraft: String = ""
    @State private var promptError: String? = nil

    var body: some View {
        Form {
            apiKeySection
            shortcutSection
            microphoneSection
            startupSection
            promptSection
            dictionarySection
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 360)
        .onAppear {
            promptDraft = preferences.cleanupPrompt
        }
    }

    // MARK: - Sections

    private var apiKeySection: some View {
        Section("ElevenLabs API Key") {
            if preferences.apiKey != nil, apiKeyDraft.isEmpty {
                HStack {
                    Label("API key is configured", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Button("Remove") {
                        preferences.setApiKey(nil)
                        apiKeyDraft = ""
                        apiKeySaved = false
                    }
                    .foregroundStyle(.red)
                }
            } else {
                SecureField("Paste your API key", text: $apiKeyDraft)
                    .onSubmit { saveApiKey() }
                HStack {
                    if apiKeySaved {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                    Spacer()
                    Button("Save") { saveApiKey() }
                        .disabled(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var shortcutSection: some View {
        Section("Recording Shortcut") {
            LabeledContent("Toggle Dictation") {
                KeyboardShortcuts.Recorder(for: .toggleDictation)
            }
        }
    }

    private var microphoneSection: some View {
        Section("Input Microphone") {
            if microphoneList.devices.isEmpty {
                Text("No microphones detected")
                    .foregroundStyle(.secondary)
            } else {
                Picker(
                    "Microphone",
                    selection: Binding(
                        get: { preferences.selectedMicrophoneUID },
                        set: { preferences.setMicrophoneUID($0) }
                    )
                ) {
                    Text("System Default").tag(String?.none)
                    ForEach(microphoneList.devices) { device in
                        Text(device.displayName).tag(String?.some(device.uid))
                    }
                }
            }
        }
    }

    private var startupSection: some View {
        Section("System") {
            Toggle(
                "Launch Wisp on Startup",
                isOn: Binding(
                    get: { preferences.launchOnStartup },
                    set: { try? preferences.setLaunchOnStartup($0) }
                )
            )
        }
    }

    private var promptSection: some View {
        Section("Transcription Cleanup Prompt") {
            TextEditor(text: $promptDraft)
                .frame(minHeight: 120)
                .font(.body)
                .onChange(of: promptDraft) { _, newValue in
                    if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        promptError = nil
                    }
                }
                .onSubmit { commitPrompt() }

            if let error = promptError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Spacer()
                Button("Reset to Default") {
                    preferences.resetCleanupPrompt()
                    promptDraft = preferences.cleanupPrompt
                    promptError = nil
                }
                .buttonStyle(.link)
            }

            Button("Save Prompt") {
                commitPrompt()
            }
            .disabled(promptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var dictionarySection: some View {
        Section("Transcription Dictionary") {
            WordDictionaryView(wordDictionary: wordDictionary)
        }
    }

    // MARK: - Actions

    private func saveApiKey() {
        let trimmed = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        preferences.setApiKey(trimmed)
        apiKeyDraft = ""
        apiKeySaved = true
    }

    private func commitPrompt() {
        do {
            try preferences.setCleanupPrompt(promptDraft)
            promptError = nil
        } catch PreferencesError.emptyPrompt {
            promptError = "Prompt cannot be empty. Enter text or reset to default."
            promptDraft = preferences.cleanupPrompt
        } catch {}
    }
}
