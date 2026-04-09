import SwiftUI

struct ReportSpaceView: View {
    @EnvironmentObject var vm: StudySpaceViewModel
    let spaceID: String

    @State private var crowdLevel: CrowdLevel = .moderate
    @State private var noiseLevel: NoiseLevel = .quiet
    @State private var outletAvailability: OutletAvailability = .some
    @State private var seatingAvailability: SeatingAvailability = .some

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    header
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section("How crowded is it?") {
                    CrowdPicker(selection: $crowdLevel)
                }

                Section("Noise level") {
                    NoisePicker(selection: $noiseLevel)
                }

                Section("Power outlets") {
                    AvailabilityPicker(
                        options: OutletAvailability.allCases,
                        selection: $outletAvailability,
                        labelProvider: { $0.displayName }
                    )
                }

                Section("Seating") {
                    AvailabilityPicker(
                        options: SeatingAvailability.allCases,
                        selection: $seatingAvailability,
                        labelProvider: { $0.displayName }
                    )
                }
            }
            .navigationTitle("Report Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") { submitReport() }
                        .bold()
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.bar.fill")
                .font(.title)
                .foregroundStyle(.uclaBlue)
            Text("Share the current vibe so others know what to expect.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func submitReport() {
        let report = SpaceReport(
            id: UUID().uuidString,
            userID: vm.userID,
            crowdLevel: crowdLevel,
            noiseLevel: noiseLevel,
            outletAvailability: outletAvailability,
            seatingAvailability: seatingAvailability,
            timestamp: Date()
        )
        vm.submitReport(report, to: spaceID)
        dismiss()
    }
}

// MARK: - Crowd Picker

struct CrowdPicker: View {
    @Binding var selection: CrowdLevel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CrowdLevel.allCases) { level in
                Button {
                    withAnimation(.spring(response: 0.2)) { selection = level }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: level.systemImage)
                            .font(.title3)
                        Text(level.displayName)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selection == level ? Color.uclaBlue : Color.clear)
                    .foregroundStyle(selection == level ? .white : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Noise Picker

struct NoisePicker: View {
    @Binding var selection: NoiseLevel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(NoiseLevel.allCases) { level in
                Button {
                    withAnimation(.spring(response: 0.2)) { selection = level }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: level.systemImage)
                            .font(.title3)
                        Text(level.displayName)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selection == level ? noiseColor(level) : Color.clear)
                    .foregroundStyle(selection == level ? .white : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func noiseColor(_ level: NoiseLevel) -> Color {
        switch level {
        case .silent, .quiet: return .green
        case .moderate: return .yellow
        case .loud: return .red
        }
    }
}

// MARK: - Generic Availability Picker

struct AvailabilityPicker<T: Hashable & Identifiable>: View {
    let options: [T]
    @Binding var selection: T
    let labelProvider: (T) -> String

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options) { option in
                Text(labelProvider(option)).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .padding(.vertical, 4)
    }
}
