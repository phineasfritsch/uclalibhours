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

    // MARK: - Toolbar items

    private var titleButton: some View {
        VStack(spacing: 2) {
            Text("UCLA Library Hours")
                .font(.headline)
                .foregroundStyle(.primary)
            Text(formattedDate)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onTapGesture { handleTitleTap() }
    }

    private var filterButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                vm.showOpenOnly.toggle()
            }
        } label: {
            Label(
                vm.showOpenOnly ? "All" : "Open",
                systemImage: vm.showOpenOnly
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
            .labelStyle(.iconOnly)
            .foregroundStyle(vm.showOpenOnly ? Color.uclaBlue : .secondary)
        }
    }

    // MARK: - Main list

    private var libraryList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {

                if !vm.isLoading {
                    statusBanner
                        .padding(.horizontal)
                        .padding(.top, 4)
                }

                ForEach(vm.groupedLibraries) { library in
                    ExpandableLibraryCard(library: library)
                        .padding(.horizontal)
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
                        ProgressView().scaleEffect(0.8)
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

    // MARK: - Status banner

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

    // MARK: - Loading / Error

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.3)
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
            .tint(Color.uclaBlue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Secret unlock (tap title 5× within 3 s)

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

// MARK: - Expandable Library Card

struct ExpandableLibraryCard: View {
    let library: Library
    @Environment(\.colorScheme) var colorScheme
    @State private var isExpanded = false

    private var hasSubs: Bool { !library.subLocations.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header row ──────────────────────────────────────────────────
            HStack(alignment: .center, spacing: 10) {

                // Name + today's hours  →  navigates to detail
                NavigationLink(value: library) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(library.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Text(library.statusText)
                            .font(.subheadline)
                            .foregroundStyle(
                                library.openStatus.isAccessible ? .primary : .secondary
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                StatusBadge(status: library.openStatus)

                // Chevron toggle (only when there are sub-locations)
                if hasSubs {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .frame(width: 28, height: 28)
                            .background(Color(.systemGray5), in: Circle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // ── Sub-locations (revealed on expand) ─────────────────────────
            if isExpanded && hasSubs {
                Divider()
                    .padding(.horizontal, 16)

                ForEach(Array(library.subLocations.enumerated()), id: \.element.id) { idx, sub in
                    NavigationLink(value: sub) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sub.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Text(sub.statusText)
                                    .font(.caption)
                                    .foregroundStyle(
                                        sub.openStatus.isAccessible ? .primary : .secondary
                                    )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            StatusBadge(status: sub.openStatus, size: .small)

                            Image(systemName: "chevron.right")
                                .font(.caption2.bold())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if idx < library.subLocations.count - 1 {
                        Divider()
                            .padding(.leading, 32)
                    }
                }

                Spacer(minLength: 6)
            }
        }
        // Clip content to the card shape, then apply shadow outside the clip
        .background(colorScheme == .dark ? Color(.systemGray6) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 2)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    library.openStatus.isAccessible
                        ? Color.uclaBlue.opacity(0.18)
                        : Color.clear,
                    lineWidth: 1
                )
        }
    }
}
