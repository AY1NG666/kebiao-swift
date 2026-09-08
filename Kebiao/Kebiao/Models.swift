import Foundation

func parseTimeMinutes(_ text: String) -> Int? {
    let parts = text.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count == 2,
          let hour = Int(parts[0]),
          let minute = Int(parts[1]),
          (0...23).contains(hour),
          (0...59).contains(minute) else {
        return nil
    }
    return hour * 60 + minute
}

func isValidTimeRange(start: String, end: String) -> Bool {
    guard let startMinutes = parseTimeMinutes(start),
          let endMinutes = parseTimeMinutes(end) else {
        return false
    }
    return endMinutes > startMinutes
}

struct Course: Codable, Identifiable, Equatable {
    static let defaultKindergartenRate = 55.0

    var id = UUID()
    var name: String
    var location: String
    var dayOfWeek: Int  // 1=Mon...7=Sun
    var startTime: String
    var endTime: String
    var isKindergarten: Bool = false
    var kindergartenRate: Double = Course.defaultKindergartenRate
    var colorHex: String = ""

    init(
        id: UUID = UUID(),
        name: String,
        location: String,
        dayOfWeek: Int,
        startTime: String,
        endTime: String,
        isKindergarten: Bool = false,
        kindergartenRate: Double = Course.defaultKindergartenRate,
        colorHex: String = ""
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.dayOfWeek = dayOfWeek
        self.startTime = startTime
        self.endTime = endTime
        self.isKindergarten = isKindergarten
        self.kindergartenRate = kindergartenRate
        self.colorHex = colorHex
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, location, dayOfWeek, startTime, endTime
        case isKindergarten, kindergartenRate, colorHex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        location = try container.decode(String.self, forKey: .location)
        dayOfWeek = try container.decode(Int.self, forKey: .dayOfWeek)
        startTime = try container.decode(String.self, forKey: .startTime)
        endTime = try container.decode(String.self, forKey: .endTime)
        isKindergarten = try container.decodeIfPresent(Bool.self, forKey: .isKindergarten) ?? false
        let decodedRate = try container.decodeIfPresent(Double.self, forKey: .kindergartenRate) ?? Course.defaultKindergartenRate
        kindergartenRate = decodedRate.isFinite && decodedRate > 0 ? decodedRate : Course.defaultKindergartenRate
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? ""
    }

    var effectiveKindergartenRate: Double {
        kindergartenRate.isFinite && kindergartenRate > 0 ? kindergartenRate : Course.defaultKindergartenRate
    }

    var durationHours: Double {
        guard let startMinutes = parseTimeMinutes(startTime),
              let endMinutes = parseTimeMinutes(endTime),
              endMinutes > startMinutes else {
            return 0.0
        }
        return Double(endMinutes - startMinutes) / 60.0
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
