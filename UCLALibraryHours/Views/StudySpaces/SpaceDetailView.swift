import SwiftUI

struct SpaceDetailView: View {
    @EnvironmentObject var vm: StudySpaceViewModel
    let space: StudySpace

    @State private var showReport = false
    @State private var showAddReview = false
    @State private var localSpace: StudySpace

    init(space: StudySpace) {
        self.space = space
        _localSpace = State(initialValue: space)
    }

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Location & description
                headerSection

                // Latest crowd report
                if let report = localSpace.latestReport {
                    crowdReportCard(report)
                }

                // Tags
                if !localSpace.tags.isEmpty {
                    tagsSection
                }

                // Report button
                reportButton

                // Divider
                Divider()
                    .padding(.horizontal)

                // Reviews
                reviewsSection

                Spacer(minLength: 32)
            }
            .padding(.top, 16)
        }
        .navigationTitle(localSpace.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        vm.deleteSpace(id: localSpace.id)
                    } label: {
                        Label("Remove Space", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showReport) {
            ReportSpaceView(spaceID: localSpace.id)
                .onDisappear { syncLocalSpace() }
        }
        .sheet(isPresented: $showAddReview) {
            AddReviewView(spaceID: localSpace.id)
                .onDisappear { syncLocalSpace() }
        }
        .onAppear { syncLocalSpace() }
    }

    private func syncLocalSpace() {
        if let updated = vm.spaces.first(where: { $0.id == space.id }) {
            localSpace = updated
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "building.2")
                    .foregroundStyle(.secondary)
                Text("\(localSpace.building)\(localSpace.floor.isEmpty ? "" : " · \(localSpace.floor)")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if let rating = localSpace.averageRating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", rating))
                            .bold()
                        Text("(\(localSpace.reviewCount))")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
            .padding(.horizontal)

            if !localSpace.description.isEmpty {
                Text(localSpace.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }

    private func crowdReportCard(_ report: SpaceReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Latest Report")
                    .font(.headline)
                Spacer()
                Text(report.timeAgo)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 16) {
                ReportStatItem(
                    icon: report.crowdLevel.systemImage,
                    label: "Crowd",
                    value: report.crowdLevel.displayName,
                    color: crowdColor(report.crowdLevel)
                )
                ReportStatItem(
                    icon: report.noiseLevel.systemImage,
                    label: "Noise",
                    value: report.noiseLevel.displayName,
                    color: .primary
                )
                ReportStatItem(
                    icon: "bolt.fill",
                    label: "Outlets",
                    value: report.outletAvailability.displayName,
                    color: .primary
                )
                ReportStatItem(
                    icon: "chair.lounge.fill",
                    label: "Seats",
                    value: report.seatingAvailability.displayName,
                    color: .primary
                )
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
        .padding(.horizontal)
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Features")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(localSpace.tags) { tag in
                        Label(tag.displayName, systemImage: tag.systemImage)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.uclaBlue.opacity(0.1), in: Capsule())
                            .foregroundStyle(.uclaBlue)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var reportButton: some View {
        Button {
            showReport = true
        } label: {
            HStack {
                Image(systemName: "chart.bar.fill")
                Text("Report Current Status")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .font(.subheadline.bold())
            .foregroundStyle(.uclaBlue)
            .padding(16)
            .background(Color.uclaBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reviews")
                    .font(.headline)
                Spacer()
                Button("Write a Review") {
                    showAddReview = true
                }
                .font(.subheadline)
                .foregroundStyle(.uclaBlue)
            }
            .padding(.horizontal)

            if localSpace.reviews.isEmpty {
                Text("No reviews yet — be the first!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(localSpace.reviews.sorted { $0.timestamp > $1.timestamp }) { review in
                        ReviewRow(review: review)
                        if review.id != localSpace.reviews.sorted { $0.timestamp > $1.timestamp }.last?.id {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                }
                .padding(.horizontal)
            }
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

// MARK: - Report Stat Item

struct ReportStatItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Review Row

struct ReviewRow: View {
    let review: SpaceReview

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                StarsView(rating: review.rating)
                Spacer()
                Text(review.timeAgo)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if !review.body.isEmpty {
                Text(review.body)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Add Review View

struct AddReviewView: View {
    @EnvironmentObject var vm: StudySpaceViewModel
    let spaceID: String

    @State private var rating = 3
    @State private var body = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Rating") {
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundStyle(.yellow)
                                .onTapGesture { rating = star }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Comments (optional)") {
                    TextEditor(text: $body)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Write a Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        let review = SpaceReview(
                            id: UUID().uuidString,
                            userID: vm.userID,
                            rating: rating,
                            body: body,
                            timestamp: Date()
                        )
                        vm.submitReview(review, to: spaceID)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
