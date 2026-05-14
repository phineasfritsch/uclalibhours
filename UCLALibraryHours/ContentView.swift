import SwiftUI

struct ContentView: View {
    @EnvironmentObject var hoursViewModel: LibraryHoursViewModel
    @EnvironmentObject var studySpaceViewModel: StudySpaceViewModel
    @EnvironmentObject var fitnessViewModel: FitnessViewModel

    @AppStorage("eulaAcceptedVersion") private var eulaAcceptedVersion: String = ""
    @State private var selectedTab = 0

    private var hasAcceptedEULA: Bool {
        eulaAcceptedVersion == EULAContent.version
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                LibraryListView()
                    .tabItem {
                        Label("Hours", systemImage: "clock.fill")
                    }
                    .tag(0)

                StudySpacesView()
                    .tabItem {
                        Label("Spaces", systemImage: "location.fill")
                    }
                    .tag(1)

                FitnessView()
                    .tabItem {
                        Label("Fitness", systemImage: "dumbbell.fill")
                    }
                    .tag(2)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(3)
            }
            .tint(.uclaBlue)
            .disabled(!hasAcceptedEULA)

            if !hasAcceptedEULA {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
            }
        }
        .fullScreenCover(isPresented: .constant(!hasAcceptedEULA)) {
            EULAView {
                eulaAcceptedVersion = EULAContent.version
            }
        }
    }
}
