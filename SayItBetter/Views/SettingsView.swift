import SwiftUI

struct SettingsView: View {
    @Environment(WordStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var confirmingReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Known words", value: "\(store.known.count) of \(store.words.count)")
                    Button("Reset progress", role: .destructive) { confirmingReset = true }
                } header: {
                    Text("Progress")
                } footer: {
                    Text("Known words are saved on this device.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Mark every word as still learning?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Reset progress", role: .destructive) { store.resetProgress() }
            }
        }
    }
}
