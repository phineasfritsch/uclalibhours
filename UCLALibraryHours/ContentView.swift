import SwiftUI

struct ContentView: View {
    @EnvironmentObject var hoursViewModel: LibraryHoursViewModel
    @EnvironmentObject var studySpaceViewModel: StudySpaceViewModel
    @AppStorage("studySpacesUnlocked") private var studySpacesUnlocked = false
    @State private var selectedTab = 0
    @State private var showUnlockAnimation = false

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                LibraryListView(onUnlockAttempt: handleUnlockAttempt)
                    .tabItem {
                        Label("Hours", systemImage: "clock.fill")
                    }
                    .tag(0)

                if studySpacesUnlocked {
                    StudySpacesView()
                        .tabItem {
                            Label("Spaces", systemImage: "location.fill")
                        }
                        .tag(1)
                }
            }
            .tint(.uclaBlue)

            if showUnlockAnimation {
                UnlockAnimationView {
                    showUnlockAnimation = false
                    selectedTab = 1
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut, value: studySpacesUnlocked)
    }

    private func handleUnlockAttempt() {
        guard !studySpacesUnlocked else {
            selectedTab = 1
            return
        }
        studySpacesUnlocked = true
        withAnimation { showUnlockAnimation = true }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
