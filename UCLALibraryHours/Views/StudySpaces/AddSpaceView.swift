import SwiftUI
import PhotosUI

struct AddSpaceView: View {
    @EnvironmentObject var vm: StudySpaceViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var building = ""
    @State private var floor = ""
    @State private var description = ""
    @State private var selectedTags: Set<SpaceTag> = []

    // Photos
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []

    private let maxPhotos = 3
    private let minDescriptionLength = 20
    private let columns = [GridItem(.adaptive(minimum: 130), spacing: 10)]

    private var canSubmit: Bool {
        !name.isEmpty && !building.isEmpty && description.count >= minDescriptionLength
    }

    var body: some View {
        NavigationStack {
            Form {
                // Rate limit banner
                if !vm.canSubmitSpace {
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

                Section {
                    if !selectedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(selectedImages.enumerated()), id: \.offset) { idx, img in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))

                                        Button {
                                            selectedImages.remove(at: idx)
                                            if idx < photoPickerItems.count {
                                                photoPickerItems.remove(at: idx)
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.white, .black.opacity(0.6))
                                                .font(.title3)
                                        }
                                        .offset(x: 6, y: -6)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if selectedImages.count < maxPhotos {
                        PhotosPicker(
                            selection: $photoPickerItems,
                            maxSelectionCount: maxPhotos - selectedImages.count,
                            matching: .images
                        ) {
                            Label("Add Photos (\(selectedImages.count)/\(maxPhotos))", systemImage: "photo.badge.plus")
                        }
                        .onChange(of: photoPickerItems) { _, items in
                            Task { await loadNewPhotos(from: items) }
                        }
                    }
                } header: {
                    Text("Photos (optional)")
                } footer: {
                    Text("Up to \(maxPhotos) photos. Help others find and evaluate the space.")
                        .font(.caption)
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
                    Button("Submit") { addSpace() }
                        .bold()
                        .disabled(!canSubmit || !vm.canSubmitSpace)
                }
            }
        }
    }

    // MARK: - Actions

    private func addSpace() {
        // Save photos to disk
        let service = StudySpaceService.shared
        var fileNames: [String] = []
        for img in selectedImages {
            if let data = img.jpegData(compressionQuality: 1.0),
               let name = service.savePhoto(imageData: data) {
                fileNames.append(name)
            }
        }

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
            createdByUserID: vm.userID,
            isVerified: false,
            photoFileNames: fileNames,
            submissionStatus: .approved
        )
        vm.addSpace(space)
        dismiss()
    }

    @MainActor
    private func loadNewPhotos(from items: [PhotosPickerItem]) async {
        var loaded: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                loaded.append(image)
            }
        }
        // Merge new picks without duplicating existing ones
        let combined = selectedImages + loaded
        selectedImages = Array(combined.prefix(maxPhotos))
    }
}
