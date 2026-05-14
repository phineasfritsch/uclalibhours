import SwiftUI

struct AddSpaceView: View {
    @EnvironmentObject var vm: StudySpaceViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var building = ""
    @State private var floor = ""
    @State private var description = ""
    @State private var selectedTags: Set<SpaceTag> = []

    // Moderation feedback
    @State private var moderationError: String?
    @State private var showModerationAlert = false

    private let minDescriptionLength = 20
    private let columns = [GridItem(.adaptive(minimum: 130), spacing: 10)]

    private var canSubmit: Bool {
        !name.isEmpty && !building.isEmpty && description.count >= minDescriptionLength
    }

    var body: some View {
        NavigationStack {
            Form {
                // Rate limit banner
                if !vm.canSubmit {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .foregroundStyle(.orange)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Daily Limit Reached")
                                    .font(.subheadline.bold())
                                Text("You've submitted \(3) spaces today. Come back tomorrow to add more.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else if vm.remainingSubmissions < 3 {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.uclaBlue)
                            Text("\(vm.remainingSubmissions) submission\(vm.remainingSubmissions == 1 ? "" : "s") remaining today.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Space Details") {
                    TextField("Name (e.g. Quiet Corner, 3rd Floor Lounge)", text: $name)
                    TextField("Building", text: $building)
                    TextField("Floor (optional)", text: $floor)
                }

                Section {
                    TextEditor(text: $description)
                        .frame(minHeight: 90)
                        .overlay(alignment: .topLeading) {
                            if description.isEmpty {
                                Text("What makes this spot special? Tips, hours, restrictions, noise level… (min \(minDescriptionLength) chars)")
                                    .foregroundStyle(.tertiary)
                                    .font(.body)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                } header: {
                    HStack {
                        Text("Description")
                        Spacer()
                        Text("\(description.count) / \(minDescriptionLength) min")
                            .font(.caption)
                            .foregroundStyle(description.count >= minDescriptionLength ? .green : .secondary)
                    }
                }

                Section("Tags") {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(SpaceTag.allCases) { tag in
                            let isSelected = selectedTags.contains(tag)
                            Button {
                                if isSelected { selectedTags.remove(tag) }
                                else { selectedTags.insert(tag) }
                            } label: {
                                Label(tag.displayName, systemImage: tag.systemImage)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        isSelected ? Color.uclaBlue : Color(.systemGray6),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                    .foregroundStyle(isSelected ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    Text("All submissions are screened and may be removed if they violate the Community Guidelines.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Study Space")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") { addSpace() }
                        .bold()
                        .disabled(!canSubmit || !vm.canSubmit)
                }
            }
            .alert("Can't submit", isPresented: $showModerationAlert, presenting: moderationError) { _ in
                Button("OK", role: .cancel) {}
            } message: { msg in
                Text(msg)
            }
        }
    }

    // MARK: - Actions

    private func addSpace() {
        let checks: [(String, ModerationConfig, String)] = [
            (name, .spaceName, "Name"),
            (building, .building, "Building"),
            (floor, .floor, "Floor"),
            (description, .description, "Description")
        ]

        var sanitized: [String: String] = [:]
        for (raw, config, label) in checks {
            let result = ContentModerator.moderate(raw, config: config)
            if !result.allowed {
                moderationError = "\(label): \(result.userFacingMessage)"
                showModerationAlert = true
                return
            }
            sanitized[label] = result.sanitizedText
        }

        let space = StudySpace(
            id: UUID().uuidString,
            name: sanitized["Name"] ?? name,
            building: sanitized["Building"] ?? building,
            floor: sanitized["Floor"] ?? floor,
            description: sanitized["Description"] ?? description,
            tags: Array(selectedTags),
            createdAt: Date(),
            createdByUserID: vm.userID,
            isVerified: false,
            photoURLs: [],
            submissionStatus: .approved
        )
        vm.addSpace(space)
        dismiss()
    }
}
