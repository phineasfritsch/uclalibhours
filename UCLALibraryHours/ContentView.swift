import SwiftUI

struct ContentView: View {
    @EnvironmentObject var hoursViewModel: LibraryHoursViewModel
    @EnvironmentObject var studySpaceViewModel: StudySpaceViewModel
    @EnvironmentObject var fitnessViewModel: FitnessViewModel
    @State private var selectedTab = 0

    var body: some View {
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
        }
        .tint(.uclaBlue)
    }
}
