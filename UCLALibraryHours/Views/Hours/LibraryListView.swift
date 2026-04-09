import SwiftUI

struct LibraryListView: View {
    @EnvironmentObject var vm: LibraryHoursViewModel
    let onUnlockAttempt: () -> Void

    @State private var tapCount = 0
    @State private var tapResetTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if vm.libraries.isEmpty && vm.isLoading {
                    loadingView
                } else if vm.libraries.isEmpty && vm.errorMessage != nil {
                    errorView
                } else {
                    libraryList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    titleButton
                }
                ToolbarItem(placement: .topBarTrailing) {
                    filterButton
                }
            }
            .searchable(text: $vm.searchText, prompt: "Search libraries")
            .refreshable { await vm.refresh() }
        }
        .task { await vm.loadHours() }
    }

    // MARK: - Subviews

    private var titleButton: some View {
        VStack(spacing: 2) {
            Text("UCLA Library Hours")
                .font(.headline)
                .foregroundStyle(.primary)
            Text(formattedDate)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onTapGesture {
            handleTitleTap()
        }
    }

    private var filterButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                vm.showOpenOnly.toggle()
            }
        } label: {
            Label(
                vm.showOpenOnly ? "All" : "Open",
                systemImage: vm.showOpenOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
            )
            .labelStyle(.iconOnly)
            .foregroundStyle(vm.showOpenOnly ? .uclaBlue : .secondary)
        }
    }

    private var libraryList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Status summary banner
                if !vm.isLoading {
                    statusBanner
                        .padding(.horizontal)
                        .padding(.top, 4)
                }

                // Library cards
                ForEach(vm.filteredLibraries) { library in
                    NavigationLink(value: library) {
                        LibraryCard(library: library)
                            .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                }

                if let updated = vm.lastUpdated {
                    Text("Updated \(updated, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 24)
                        .padding(.top, 4)
                }
            }
            .padding(.top, 8)
        }
        .navigationDestination(for: Library.self) { library in
            LibraryDetailView(library: library)
        }
        .overlay {
            if vm.isLoading && !vm.libraries.isEmpty {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Refreshing…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var statusBanner: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(vm.openCount > 0 ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
            Text("\(vm.openCount) of \(vm.totalCount) libraries open now")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.3)
            Text("Loading library hours…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Couldn't Load Hours")
                .font(.title3.bold())
            if let error = vm.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Button("Try Again") {
                Task { await vm.refresh() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.uclaBlue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Secret Unlock (tap title 5 times within 3s)

    private func handleTitleTap() {
        tapResetTask?.cancel()
        tapCount += 1

        if tapCount >= 5 {
            tapCount = 0
            onUnlockAttempt()
            return
        }

        tapResetTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { tapCount = 0 }
        }
    }

    private var formattedDate: String {
        Date().formatted(.dateTime.weekday(.wide).month().day())
    }
}

// MARK: - Library Card

struct LibraryCard: View {
    let library: Library
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(library.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(library.statusText)
                        .font(.subheadline)
                        .foregroundStyle(library.openStatus.isAccessible ? Color.primary : Color.secondary)
                }

                Spacer()

                StatusBadge(status: library.openStatus)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            // Sub-locations (if any, up to 3)
            if !library.subLocations.isEmpty {
                Divider()
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(library.subLocations.prefix(3)) { sub in
                        HStack {
                            Text(sub.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(sub.statusText)
                                .font(.caption)
                                .foregroundStyle(sub.openStatus.isAccessible ? .primary : .tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)

                        if sub.id != library.subLocations.prefix(3).last?.id {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    library.openStatus.isAccessible ? Color.uclaBlue.opacity(0.15) : Color.clear,
                    lineWidth: 1
                )
        }
    }
}
