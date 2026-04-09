import SwiftUI
import BackgroundTasks

@main
struct UCLALibraryHoursApp: App {
    @StateObject private var hoursViewModel = LibraryHoursViewModel()
    @StateObject private var studySpaceViewModel = StudySpaceViewModel()

    init() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.uclalib.hours.refresh",
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleBackgroundRefresh(task: refreshTask)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(hoursViewModel)
                .environmentObject(studySpaceViewModel)
        }
    }
}

private func handleBackgroundRefresh(task: BGAppRefreshTask) {
    scheduleBackgroundRefresh()
    let work = Task {
        do {
            _ = try await LibraryHoursService.shared.fetchAndCacheHours()
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }
    task.expirationHandler = { work.cancel() }
}

func scheduleBackgroundRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.uclalib.hours.refresh")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 3600)
    try? BGTaskScheduler.shared.submit(request)
}
