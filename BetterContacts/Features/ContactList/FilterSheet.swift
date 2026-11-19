import Domain
import SwiftUI

struct FilterSheet: View {
    @Binding var filter: ContactFilter
    @Environment(\.dismiss) private var dismiss

    @State private var locationText: String = ""
    @State private var tagText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Show") {
                    Toggle("Close circle only", isOn: closeCircleBinding)
                    Toggle("Has a birthday", isOn: birthdayBinding)
                    Toggle("Has a phone number", isOn: phoneBinding)
                }
                Section("Tag") {
                    TextField("Any tag, e.g. work", text: $tagText)
                        .onSubmit(applyTag)
                    Button("Apply tag filter", action: applyTag)
                    if !filter.tags.isEmpty {
                        Text("Filtering by: " + filter.tags.sorted().joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Location") {
                    TextField("Contains, e.g. berlin", text: $locationText)
                        .onSubmit(applyLocation)
                    Button("Apply location filter", action: applyLocation)
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        filter = ContactFilter()
                        tagText = ""
                        locationText = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                locationText = filter.location ?? ""
            }
        }
    }

    private var closeCircleBinding: Binding<Bool> {
        Binding(
            get: { filter.onlyCloseCircle },
            set: { filter.onlyCloseCircle = $0 }
        )
    }

    private var birthdayBinding: Binding<Bool> {
        Binding(
            get: { filter.onlyWithBirthdays },
            set: { filter.onlyWithBirthdays = $0 }
        )
    }

    private var phoneBinding: Binding<Bool> {
        Binding(
            get: { filter.onlyWithPhoneNumbers },
            set: { filter.onlyWithPhoneNumbers = $0 }
        )
    }

    private func applyTag() {
        let trimmed = tagText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return }
        filter.tags.insert(trimmed)
        tagText = ""
    }

    private func applyLocation() {
        let trimmed = locationText.trimmingCharacters(in: .whitespaces)
        filter.location = trimmed.isEmpty ? nil : trimmed
    }
}
