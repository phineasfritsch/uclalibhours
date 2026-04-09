import SwiftUI

struct StudySpacesView: View {
    @EnvironmentObject var vm: StudySpaceViewModel
    @State private var showAddSpace = false
    @State private var tagSheetVisible = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            Group {
                if vm.filteredSpaces.isEmpty && vm.spaces.isEmpty {
                    emptyState
                } else {
                    spaceList
                }
            }
            .navigationTitle("Study Spaces")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    filterButton
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSpace = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .searchable(text: $vm.searchText, prompt: "Search spaces")
            .sheet(isPresented: $showAddSpace) {
                AddSpaceView()
            }
        }
        .onAppear { vm.loadSpaces() }
    }

    // MARK: - Subviews

    private var spaceList: some View {
        ScrollView {
            // Active tag filters
            if !vm.selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(vm.selectedTags)) { tag in
                            TagChip(tag: tag, isSelected: true) {
                                vm.selectedTags.remove(tag)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)
            }

            LazyVStack(spacing: 12) {
                ForEach(vm.filteredSpaces) { space in
                    NavigationLink(value: space) {
                        SpaceCard(space: space)
                            .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .navigationDestination(for: StudySpace.self) { space in
            SpaceDetailView(space: space)
        }
    }

    private var filterButton: some View {
        Button {
            tagSheetVisible = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: vm.selectedTags.isEmpty
                      ? "line.3.horizontal.decrease.circle"
                      : "line.3.horizontal.decrease.circle.fill")
                if !vm.selectedTags.isEmpty {
                    Text("\(vm.selectedTags.count)")
                        .font(.caption.bold())
                }
            }
            .foregroundStyle(vm.selectedTags.isEmpty ? .secondary : .uclaBlue)
        }
        .sheet(isPresented: $tagSheetVisible) {
            TagFilterSheet(selectedTags: $vm.selectedTags)
                .presentationDetents([.medium])
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.magnifyingglass")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("No Study Spaces Yet")
                .font(.title3.bold())
            Text("Be the first to add a hidden study spot on campus.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Add a Space") { showAddSpace = true }
                .buttonStyle(.borderedProminent)
                .tint(.uclaBlue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Space Card

struct SpaceCard: View {
    let space: StudySpace
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(space.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Label("\(space.building)\(space.floor.isEmpty ? "" : ", \(space.floor)")", systemImage: "building.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Tags (up to 3)
                    if !space.tags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(space.tags.prefix(3)) { tag in
                                Label(tag.displayName, systemImage: tag.systemImage)
                                    .font(.caption2)
                                    .foregroundStyle(.uclaBlue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.uclaBlue.opacity(0.1), in: Capsule())
                            }
                            if space.tags.count > 3 {
                                Text("+\(space.tags.count - 3)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    // Rating
                    if let rating = space.averageRating {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.subheadline.bold())
                            Text("(\(space.reviewCount))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Latest crowd report
                    if let report = space.latestReport, report.isRecent {
                        HStack(spacing: 4) {
                            Image(systemName: report.crowdLevel.systemImage)
                                .font(.caption)
                            Text(report.crowdLevel.displayName)
                                .font(.caption.bold())
                        }
                        .foregroundStyle(crowdColor(report.crowdLevel))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(crowdColor(report.crowdLevel).opacity(0.1), in: Capsule())

                        Text(report.timeAgo)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(16)
        }
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
    }

    private func crowdColor(_ level: CrowdLevel) -> Color {
        switch level {
        case .empty, .light: return .green
        case .moderate: return .yellow
        case .busy: return .orange
        case .full: return .red
        }
    }
}

// MARK: - Tag Filter Sheet

struct TagFilterSheet: View {
    @Binding var selectedTags: Set<SpaceTag>
    @Environment(\.dismiss) var dismiss

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(SpaceTag.allCases) { tag in
                        let selected = selectedTags.contains(tag)
                        Button {
                            if selected { selectedTags.remove(tag) }
                            else { selectedTags.insert(tag) }
                        } label: {
                            Label(tag.displayName, systemImage: tag.systemImage)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(selected ? Color.uclaBlue : Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(selected ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Filter by Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") { selectedTags.removeAll() }
                        .disabled(selectedTags.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .bold()
                }
            }
        }
    }
}
