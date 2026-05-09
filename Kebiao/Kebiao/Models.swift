import Foundation

struct Course: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var location: String
    var dayOfWeek: Int  // 1=Mon...7=Sun
    var startTime: String
    var endTime: String
    var isKindergarten: Bool = false
    var colorHex: String = ""

    var durationHours: Double {
        let s = startTime.split(separator: ":").compactMap { Int($0) }
        let e = endTime.split(separator: ":").compactMap { Int($0) }
        guard s.count == 2, e.count == 2 else { return 1.0 }
        let sm = s[0]*60 + s[1]
        let em = e[0]*60 + e[1]
        let diff = em > sm ? em - sm : em + 1440 - sm
        return Double(diff) / 60.0
    }
}

struct Attendance: Codable, Identifiable {
    var id = UUID()
    var courseId: UUID
    var date: Date
    var studentCount: Int = 0
    var assistantCount: Int = 0
    var note: String? = nil  // custom time or memo (e.g. "14:00-15:00")
}

struct SalaryRule: Codable, Identifiable {
    var id = UUID()
    var minStudents: Int
    var maxStudents: Int? = nil  // nil = no upper limit
    var ratePerClass: Double
}

struct SalaryDetail: Identifiable {
    var id = UUID()
    var attendanceId: UUID
    var date: Date
    var courseName: String
    var location: String
    var studentCount: Int
    var assistantCount: Int
    var isKindergarten: Bool
    var rate: Double
}
