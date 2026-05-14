import SwiftUI

struct ReportContentSheet: View {
    let contentType: ReportedContentType
    let contentID: String
    let parentSpaceID: String?
    let reportedUserID: String?

    @Environment(\.dismiss) var dismiss
    @State private var selectedReason: ReportReason = .spam
    @State private var note: String = ""
    @State private var isSubmitting = false
    @State private var alertMessage: String?
    @State private var showAlert = false
    @State private var didSucceed = false

    private var contentTypeName: String {
        switch contentType {
        case .space: return "space"
        case .review: return "review"
        case .user: return "user"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Reports are reviewed by our moderation team. We act on objectionable content within 24 hours. Abuse of the reporting system may result in restrictions on your account.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Reason") {
                    ForEach(ReportReason.allCases) { reason in
                        Button {
                            selectedReason = reason
                        } label: {
                            HStack {
                                Text(reason.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedReason == reason {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.uclaBlue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    TextEditor(text: $note)
                        .frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if note.isEmpty {
                                Text("Optional: add details to help us review (no personal info please).")
                                    .foregroundStyle(.tertiary)
                                    .font(.body)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                } header: {
                    Text("Additional Notes (Optional)")
                }
            }
            .navigationTitle("Report \(contentTypeName.capitalized)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") { submit() }
                        .bold()
                        .disabled(isSubmitting)
                }
            }
            .alert(didSucceed ? "Report Sent" : "Couldn't Send Report",
                   isPresented: $showAlert,
                   presenting: alertMessage) { _ in
                Button("OK") {
                    if didSucceed { dismiss() }
                }
            } message: { msg in
                Text(msg)
            }
        }
    }

    private func submit() {
        isSubmitting = true
        Task {
            do {
                try await ContentReportService.shared.submitReport(
                    contentType: contentType,
                    contentID: contentID,
                    parentSpaceID: parentSpaceID,
                    reportedUserID: reportedUserID,
                    reason: selectedReason,
                    note: note
                )
                didSucceed = true
                alertMessage = "Thanks. Our team will review this within 24 hours."
            } catch {
                didSucceed = false
                alertMessage = error.localizedDescription
            }
            isSubmitting = false
            showAlert = true
        }
    }
}
