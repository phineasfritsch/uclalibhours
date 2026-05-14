import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var blockService: BlockService
    @State private var showEULA = false
    @State private var showGuidelines = false

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Community") {
                    Button {
                        showGuidelines = true
                    } label: {
                        Label("Community Guidelines", systemImage: "checkmark.shield")
                    }
                    Button {
                        showEULA = true
                    } label: {
                        Label("End User License Agreement", systemImage: "doc.text")
                    }
                }

                Section {
                    NavigationLink {
                        BlockedUsersView()
                    } label: {
                        HStack {
                            Label("Blocked Users", systemImage: "hand.raised")
                            Spacer()
                            Text("\(blockService.blockedUserIDs.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Moderation")
                } footer: {
                    Text("Content from blocked users is hidden across the app.")
                }

                Section("Contact & Support") {
                    Link(destination: URL(string: "mailto:\(CommunityGuidelines.contactEmail)?subject=UCLA%20Library%20Hours%20Support")!) {
                        HStack {
                            Label("Email Support", systemImage: "envelope")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    Link(destination: URL(string: "mailto:\(CommunityGuidelines.contactEmail)?subject=Content%20Moderation%20Appeal")!) {
                        HStack {
                            Label("Appeal a Moderation Decision", systemImage: "hand.raised.app")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Guidelines Version", value: CommunityGuidelines.version)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showEULA) {
                EULADetailSheet()
            }
            .sheet(isPresented: $showGuidelines) {
                GuidelinesSheet()
            }
        }
    }
}

// MARK: - Blocked users list with unblock

struct BlockedUsersView: View {
    @EnvironmentObject var blockService: BlockService

    var body: some View {
        Group {
            if blockService.blockedUserIDs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "hand.raised")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("No Blocked Users")
                        .font(.headline)
                    Text("Users you block will appear here. You can unblock them at any time.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(blockService.blockedUserIDs).sorted(), id: \.self) { uid in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Anonymous User")
                                    .font(.subheadline.bold())
                                Text(uid.prefix(12) + "…")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Unblock") {
                                blockService.unblock(userID: uid)
                            }
                            .buttonStyle(.bordered)
                            .tint(.uclaBlue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Guidelines sheet (read-only summary)

struct GuidelinesSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
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
                                VStack(alignment: .leading, spacing: 4) {
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

                    Divider()

                    Text("Enforcement")
                        .font(.headline)
                    Text(CommunityGuidelines.enforcementText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .navigationTitle("Guidelines")
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
