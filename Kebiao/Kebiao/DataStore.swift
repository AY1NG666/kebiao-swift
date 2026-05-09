import Foundation
import SwiftUI

class DataStore: ObservableObject {
    @Published var courses: [Course] = []
    @Published var attendances: [Attendance] = []
    @Published var salaryRules: [SalaryRule] = []

    private let coursesKey = "kebiao_courses"
    private let attendancesKey = "kebiao_attendances"
    private let rulesKey = "kebiao_rules"

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

        if let a: [Attendance] = loadFromFile("attendances") { attendances = a.filter { $0.date.timeIntervalSince1970 > 0 } }
        else if let d = UserDefaults.standard.data(forKey: attendancesKey),
                let a = try? JSONDecoder().decode([Attendance].self, from: d) { attendances = a.filter { $0.date.timeIntervalSince1970 > 0 } }

        if let r: [SalaryRule] = loadFromFile("rules") { salaryRules = r }
        else if let d = UserDefaults.standard.data(forKey: rulesKey),
                let r = try? JSONDecoder().decode([SalaryRule].self, from: d) { salaryRules = r }

        if salaryRules.isEmpty {
            salaryRules = [
                SalaryRule(minStudents: 0, maxStudents: 5, ratePerClass: 35),
                SalaryRule(minStudents: 6, maxStudents: 10, ratePerClass: 50),
                SalaryRule(minStudents: 11, maxStudents: nil, ratePerClass: 70)
            ]
        }

        // Migrate from UserDefaults to files on first load
        if !courses.isEmpty || !attendances.isEmpty { save() }
    }

    func save() {
        saveToFile(courses, name: "courses")
        saveToFile(attendances, name: "attendances")
        saveToFile(salaryRules, name: "rules")
    }

    func addSalaryRule(_ r: SalaryRule) { salaryRules.append(r); save() }
    func updateSalaryRule(_ r: SalaryRule) { if let i = salaryRules.firstIndex(where: { $0.id == r.id }) { salaryRules[i] = r; save() } }
    func deleteSalaryRule(_ id: UUID) { salaryRules.removeAll { $0.id == id }; save() }
    func resetSalaryRules() {
        salaryRules = [
            SalaryRule(minStudents: 0, maxStudents: 5, ratePerClass: 35),
            SalaryRule(minStudents: 6, maxStudents: 10, ratePerClass: 50),
            SalaryRule(minStudents: 11, maxStudents: nil, ratePerClass: 70)
        ]
        save()
    }

    func addCourse(_ c: Course) { courses.append(c); save() }
    func updateCourse(_ c: Course) { if let i = courses.firstIndex(where: { $0.id == c.id }) { courses[i] = c; save() } }
    func deleteCourse(_ id: UUID) { courses.removeAll { $0.id == id }; attendances.removeAll { $0.courseId == id }; save() }
    func addAttendance(_ a: Attendance) { attendances.append(a); save() }
    func addAttendances(_ list: [Attendance]) { attendances.append(contentsOf: list); save() }
    func updateAttendance(_ a: Attendance) { if let i = attendances.firstIndex(where: { $0.id == a.id }) { attendances[i] = a; save() } }
    func deleteAttendance(_ id: UUID) { attendances.removeAll { $0.id == id }; save() }

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
            let rate = isKinder ? 55.0 : Double(a.studentCount) * 7.0 + Double(a.assistantCount) * 3.0
            return SalaryDetail(attendanceId: a.id, date: a.date, courseName: course?.name ?? "?", location: course?.location ?? "?", studentCount: a.studentCount, assistantCount: a.assistantCount, isKindergarten: isKinder, rate: rate)
        }.sorted { $0.date < $1.date }
    }

    func courseName(_ id: UUID) -> String { courses.first(where: { $0.id == id })?.name ?? "?" }
    func isKinderCourse(_ id: UUID) -> Bool { courses.first(where: { $0.id == id })?.isKindergarten ?? false }
}
