import SwiftUI

struct SpaceDetailView: View {
    @EnvironmentObject var vm: StudySpaceViewModel
    let space: StudySpace

    @State private var showReport = false
    @State private var showAddReview = false

    @Environment(\.colorScheme) var colorScheme

    /// Always reads the latest version of this space from the ViewModel.
    /// Because vm.spaces is @Published, any mutation (review, report, delete)
    /// automatically re-renders this view without any manual sync needed.
    private var currentSpace: StudySpace {
        vm.spaces.first(where: { $0.id == space.id }) ?? space
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Photo carousel (if photos exist)
                if !currentSpace.photoURLs.isEmpty {
                    photoCarousel
                }

                // Location & description
                headerSection

                // Latest crowd report
                if let report = currentSpace.latestReport {
                    crowdReportCard(report)
                }

                // Tags
                if !currentSpace.tags.isEmpty {
                    tagsSection
                }

                // Report button
                reportButton

                Divider()
                    .padding(.horizontal)

                // Reviews
                reviewsSection

                Spacer(minLength: 32)
            }
            .padding(.top, currentSpace.photoURLs.isEmpty ? 16 : 0)
        }
        .navigationTitle(currentSpace.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !currentSpace.isVerified {
                    Menu {
                        Button(role: .destructive) {
                            vm.deleteSpace(id: currentSpace.id)
                        } label: {
                            Label("Remove Space", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showReport) {
            ReportSpaceView(spaceID: currentSpace.id)
        }
        .sheet(isPresented: $showAddReview) {
            AddReviewView(spaceID: currentSpace.id)
        }
    }

    // MARK: - Photo Carousel

    private var photoCarousel: some View {
        TabView {
            ForEach(currentSpace.photoURLs, id: \.self) { urlString in
                AsyncImage(url: URL(string: urlString)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Color(.systemGray5)
                            .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
                    default:
                        Color(.systemGray5)
                            .overlay { ProgressView() }
                    }
                }
                .clipped()
            }
        }
        .tabViewStyle(.page(indexDisplayMode: currentSpace.photoURLs.count > 1 ? .always : .never))
        .frame(height: 260)
        .ignoresSafeArea(edges: .horizontal)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "building.2")
                    .foregroundStyle(.secondary)
                Text("\(currentSpace.building)\(currentSpace.floor.isEmpty ? "" : " · \(currentSpace.floor)")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if currentSpace.isVerified {
                    Label("Verified", systemImage: "checkmark.seal.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.uclaBlue, in: Capsule())
                }

                Spacer()

                if let rating = currentSpace.averageRating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", rating))
                            .bold()
                        Text("(\(currentSpace.reviewCount))")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
            .padding(.horizontal)

            if !currentSpace.description.isEmpty {
                Text(currentSpace.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Crowd Report Card

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
                // Noise with traffic-light color
                ReportStatItem(
                    icon: report.noiseLevel.systemImage,
                    label: "Noise",
                    value: report.noiseLevel.displayName,
                    color: noiseColor(report.noiseLevel)
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

            // Noise level traffic light indicator
            noiseLevelBar(report.noiseLevel)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
        .padding(.horizontal)
    }

    private func noiseLevelBar(_ level: NoiseLevel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Noise Level")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                ForEach(NoiseLevel.allCases) { lvl in
                    let isActive = lvl == level || NoiseLevel.allCases.firstIndex(of: lvl)! <= NoiseLevel.allCases.firstIndex(of: level)!
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isActive ? noiseColor(level) : Color(.systemGray5))
                        .frame(height: 8)
                }

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Circle()
                        .fill(noiseColor(level))
                        .frame(width: 8, height: 8)
                    Text(level.displayName)
                        .font(.caption.bold())
                        .foregroundStyle(noiseColor(level))
                }
            }
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Features")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(currentSpace.tags) { tag in
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

    // MARK: - Report Button

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

    // MARK: - Reviews

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

            if currentSpace.reviews.isEmpty {
                Text("No reviews yet — be the first!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            } else {
                let sorted = currentSpace.reviews.sorted { $0.timestamp > $1.timestamp }
                VStack(spacing: 0) {
                    ForEach(sorted) { review in
                        ReviewRow(review: review)
                        if review.id != sorted.last?.id {
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

    // MARK: - Color Helpers

    private func crowdColor(_ level: CrowdLevel) -> Color {
        switch level {
        case .empty, .light: return .green
        case .moderate: return .yellow
        case .busy: return .orange
        case .full: return .red
        }
    }

    private func noiseColor(_ level: NoiseLevel) -> Color {
        switch level {
        case .silent, .quiet: return .green
        case .moderate: return .yellow
        case .loud: return .red
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
    @State private var reviewText = ""
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
                    TextEditor(text: $reviewText)
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
                            body: reviewText,
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
