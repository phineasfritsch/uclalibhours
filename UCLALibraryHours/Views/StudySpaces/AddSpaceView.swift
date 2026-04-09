import SwiftUI

struct AddSpaceView: View {
    @EnvironmentObject var vm: StudySpaceViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var building = ""
    @State private var floor = ""
    @State private var description = ""
    @State private var selectedTags: Set<SpaceTag> = []

    private let columns = [GridItem(.adaptive(minimum: 130), spacing: 10)]

    var body: some View {
        NavigationStack {
            Form {
                Section("Space Details") {
                    TextField("Name (e.g. Quiet Corner, 3rd Floor Lounge)", text: $name)
                    TextField("Building", text: $building)
                    TextField("Floor (optional)", text: $floor)
                }

                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if description.isEmpty {
                                Text("What makes this spot special? Tips, hours, restrictions…")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
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
            }
            .navigationTitle("Add Study Space")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { addSpace() }
                        .bold()
                        .disabled(name.isEmpty || building.isEmpty)
                }
            }
        }
    }

    private func addSpace() {
        let space = StudySpace(
            id: UUID().uuidString,
            name: name,
            building: building,
            floor: floor,
            description: description,
            tags: Array(selectedTags),
            reports: [],
            reviews: [],
            createdAt: Date(),
            createdByUserID: vm.userID
        )
        vm.addSpace(space)
        dismiss()
    }
}
