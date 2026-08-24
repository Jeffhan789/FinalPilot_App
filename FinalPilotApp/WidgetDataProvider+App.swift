import Foundation

// MARK: - Main app synchronization

extension FinalPilotStore {
    /// Writes the current application state to the shared App Group for widgets.
    func syncToWidget() {
        let provider = WidgetDataProvider.shared

        let examInfos = courses.compactMap { course -> WidgetExamInfo? in
            guard let examDate = course.examDate else { return nil }
            return WidgetExamInfo(
                id: course.id,
                name: course.name,
                examDate: examDate,
                colorKey: course.colorKey,
                symbol: course.symbol,
                location: course.examLocation
            )
        }
        provider.saveExams(examInfos)

        let taskInfos = tasks.map { task in
            WidgetTaskInfo(
                id: task.id,
                title: task.title,
                subtitle: task.subtitle,
                minutes: task.minutes,
                isDone: task.status == .done,
                bucket: task.bucket.rawValue
            )
        }
        provider.saveTasks(taskInfos)

        let activeTasks = tasks.filter { $0.bucket != .skip }
        let doneCount = activeTasks.filter { $0.status == .done }.count
        let progress = WidgetProgressInfo(
            completedTasks: doneCount,
            totalTasks: activeTasks.count,
            studyMinutes: totalStudyMinutes,
            completionRate: completionRate,
            lastUpdated: Date()
        )
        provider.saveProgress(progress)

        provider.saveSnapshot(
            WidgetSnapshot(
                exams: examInfos,
                tasks: taskInfos,
                progress: progress,
                lastUpdated: Date()
            )
        )
    }
}
