import SwiftUI

// MARK: - EULA / first-launch acceptance

struct EULAView: View {
    let onAccept: () -> Void

    @State private var hasScrolledToEnd = false
    @State private var agreed = false
    @State private var showFullEULA = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Community Guidelines")
                                .font(.title3.bold())
                            Text(CommunityGuidelines.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            VStack(spacing: 14) {
                                ForEach(Array(CommunityGuidelines.rules.enumerated()), id: \.offset) { _, rule in
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: rule.icon)
                                            .font(.title3)
                                            .foregroundStyle(.uclaBlue)
                                            .frame(width: 32)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(rule.title)
                                                .font(.subheadline.bold())
                                            Text(rule.body)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enforcement")
                                .font(.headline)
                            Text(CommunityGuidelines.enforcementText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Button {
                            showFullEULA = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.text")
                                Text("Read full End User License Agreement")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.uclaBlue)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.uclaBlue.opacity(0.1)))
                        }

                        // Sentinel to detect that the user scrolled all the way down.
                        Color.clear
                            .frame(height: 1)
                            .onAppear { hasScrolledToEnd = true }
                    }
                    .padding(20)
                }

                acceptanceBar
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showFullEULA) {
                EULADetailSheet()
            }
        }
        .interactiveDismissDisabled(true)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(.uclaBlue)
            Text("Welcome")
                .font(.largeTitle.bold())
            Text("Before you start, please review our Community Guidelines and Terms.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    private var acceptanceBar: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $agreed) {
                Text("I have read and agree to the Community Guidelines and EULA.")
                    .font(.footnote)
            }
            .toggleStyle(.switch)
            .tint(.uclaBlue)

            Button {
                onAccept()
            } label: {
                Text("Accept & Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canAccept ? Color.uclaBlue : Color.gray.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canAccept)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: -2)
                .ignoresSafeArea()
        )
    }

    private var canAccept: Bool { agreed && hasScrolledToEnd }
}

// MARK: - EULA full text sheet

struct EULADetailSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(EULAContent.title)
                        .font(.title2.bold())
                    Text("Version \(EULAContent.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(LocalizedStringKey(EULAContent.bodyMarkdown))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .navigationTitle("EULA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .bold()
                }
            }
        }
    }
}
