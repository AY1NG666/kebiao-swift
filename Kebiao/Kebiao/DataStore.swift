import Foundation
import SwiftUI

class DataStore: ObservableObject {
    @Published var courses: [Course] = []
    @Published var attendances: [Attendance] = []

    private let coursesKey = "kebiao_courses"
    private let attendancesKey = "kebiao_attendances"

    init() { load() }

    func load() {
        if let d = UserDefaults.standard.data(forKey: coursesKey),
           let c = try? JSONDecoder().decode([Course].self, from: d) { courses = c }
        if let d = UserDefaults.standard.data(forKey: attendancesKey),
           let a = try? JSONDecoder().decode([Attendance].self, from: d) { attendances = a.filter { $0.date.timeIntervalSince1970 > 0 } }
    }

    func save() {
        if let d = try? JSONEncoder().encode(courses) { UserDefaults.standard.set(d, forKey: coursesKey) }
        if let d = try? JSONEncoder().encode(attendances) { UserDefaults.standard.set(d, forKey: attendancesKey) }
    }

    func addCourse(_ c: Course) { courses.append(c); save() }
    func updateCourse(_ c: Course) { if let i = courses.firstIndex(where: { $0.id == c.id }) { courses[i] = c; save() } }
    func deleteCourse(_ id: UUID) { courses.removeAll { $0.id == id }; attendances.removeAll { $0.courseId == id }; save() }
    func addAttendance(_ a: Attendance) { attendances.append(a); save() }
    func updateAttendance(_ a: Attendance) { if let i = attendances.firstIndex(where: { $0.id == a.id }) { attendances[i] = a; save() } }
    func deleteAttendance(_ id: UUID) { attendances.removeAll { $0.id == id }; save() }

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
            return SalaryDetail(attendanceId: a.id, date: a.date, courseName: course?.name ?? "?", studentCount: a.studentCount, assistantCount: a.assistantCount, isKindergarten: isKinder, rate: rate)
        }.sorted { $0.date < $1.date }
    }

    func courseName(_ id: UUID) -> String { courses.first(where: { $0.id == id })?.name ?? "?" }
    func isKinderCourse(_ id: UUID) -> Bool { courses.first(where: { $0.id == id })?.isKindergarten ?? false }
}
