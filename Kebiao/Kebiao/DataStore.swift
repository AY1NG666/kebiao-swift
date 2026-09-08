import Foundation
import SwiftUI

class DataStore: ObservableObject {
    @Published var courses: [Course] = []
    @Published var attendances: [Attendance] = []

    private let coursesKey = "kebiao_courses"
    private let attendancesKey = "kebiao_attendances"

    private var dataDir: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func fileURL(_ name: String) -> URL { dataDir.appendingPathComponent("\(name).json") }

    init() { load() }

    private func loadFromFile<T: Decodable>(_ name: String) -> T? {
        let url = fileURL(name)
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONDecoder().decode(T.self, from: data) else { return nil }
        return obj
    }

    private func saveToFile<T: Encodable>(_ obj: T, name: String) {
        let url = fileURL(name)
        if let data = try? JSONEncoder().encode(obj) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func load() {
        // Try file-based storage first, fall back to UserDefaults (migration)
        if let c: [Course] = loadFromFile("courses") { courses = c }
        else if let d = UserDefaults.standard.data(forKey: coursesKey),
                let c = try? JSONDecoder().decode([Course].self, from: d) { courses = c }

        if let a: [Attendance] = loadFromFile("attendances") {
            attendances = deduplicatedAttendances(a.filter { $0.date.timeIntervalSince1970 > 0 })
        }
        else if let d = UserDefaults.standard.data(forKey: attendancesKey),
                let a = try? JSONDecoder().decode([Attendance].self, from: d) {
            attendances = deduplicatedAttendances(a.filter { $0.date.timeIntervalSince1970 > 0 })
        }

        // Migrate from UserDefaults to files on first load
        if !courses.isEmpty || !attendances.isEmpty { save() }
    }

    func save() {
        saveToFile(courses, name: "courses")
        saveToFile(attendances, name: "attendances")
    }

    func addCourse(_ c: Course) { courses.append(c); save() }
    func updateCourse(_ c: Course) { if let i = courses.firstIndex(where: { $0.id == c.id }) { courses[i] = c; save() } }
    func deleteCourse(_ id: UUID) { courses.removeAll { $0.id == id }; attendances.removeAll { $0.courseId == id }; save() }
    func addAttendance(_ a: Attendance) {
        upsertAttendance(a)
        save()
    }

    func addAttendances(_ list: [Attendance]) {
        for attendance in list {
            upsertAttendance(attendance)
        }
        save()
    }

    private func upsertAttendance(_ attendance: Attendance) {
        let normalized = normalizedAttendance(attendance)
        if let index = attendances.firstIndex(where: {
            $0.courseId == normalized.courseId &&
            Calendar.current.isDate($0.date, inSameDayAs: normalized.date)
        }) {
            attendances[index] = Attendance(
                id: attendances[index].id,
                courseId: normalized.courseId,
                date: normalized.date,
                studentCount: normalized.studentCount,
                assistantCount: normalized.assistantCount,
                note: normalized.note
            )
        } else {
            attendances.append(normalized)
        }
    }

    private func deduplicatedAttendances(_ list: [Attendance]) -> [Attendance] {
        var result: [Attendance] = []
        for attendance in list {
            let normalized = normalizedAttendance(attendance)
            if let index = result.firstIndex(where: {
                $0.courseId == normalized.courseId &&
                Calendar.current.isDate($0.date, inSameDayAs: normalized.date)
            }) {
                result[index] = Attendance(
                    id: result[index].id,
                    courseId: normalized.courseId,
                    date: normalized.date,
                    studentCount: normalized.studentCount,
                    assistantCount: normalized.assistantCount,
                    note: normalized.note
                )
            } else {
                result.append(normalized)
            }
        }
        return result
    }
    func updateAttendance(_ a: Attendance) {
        if let i = attendances.firstIndex(where: { $0.id == a.id }) {
            attendances[i] = normalizedAttendance(a)
            save()
        }
    }
    func deleteAttendance(_ id: UUID) { attendances.removeAll { $0.id == id }; save() }

    private func normalizedAttendance(_ attendance: Attendance) -> Attendance {
        Attendance(
            id: attendance.id,
            courseId: attendance.courseId,
            date: Calendar.current.startOfDay(for: attendance.date),
            studentCount: max(0, attendance.studentCount),
            assistantCount: max(0, attendance.assistantCount),
            note: attendance.note
        )
    }

    func coursesForDayOfWeek(_ day: Int) -> [Course] {
        courses.filter { $0.dayOfWeek == day }.sorted { $0.startTime < $1.startTime }
    }

    func hasAttendanceFor(courseId: UUID, date: Date) -> Bool {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return attendances.contains { $0.courseId == courseId && Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }
    }

    func attendancesForMonth(year: Int, month: Int) -> [Attendance] {
        let cal = Calendar.current
        return attendances.filter {
            let c = cal.dateComponents([.year, .month], from: $0.date)
            return c.year == year && c.month == month
        }
    }

    func salaryForMonth(year: Int, month: Int) -> [SalaryDetail] {
        return attendancesForMonth(year: year, month: month).map { a in
            let course = courses.first { $0.id == a.courseId }
            let isKinder = course?.isKindergarten ?? false
            let rate = isKinder ? (course?.effectiveKindergartenRate ?? Course.defaultKindergartenRate) : Double(a.studentCount) * 7.0 + Double(a.assistantCount) * 3.0
            return SalaryDetail(attendanceId: a.id, date: a.date, courseName: course?.name ?? "?", location: course?.location ?? "?", studentCount: a.studentCount, assistantCount: a.assistantCount, isKindergarten: isKinder, rate: rate)
        }.sorted { $0.date < $1.date }
    }

    func courseName(_ id: UUID) -> String { courses.first(where: { $0.id == id })?.name ?? "?" }
    func isKinderCourse(_ id: UUID) -> Bool { courses.first(where: { $0.id == id })?.isKindergarten ?? false }
}
