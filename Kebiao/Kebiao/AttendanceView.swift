import SwiftUI

// MARK: - Flexible date parsing
func parseFlexibleDate(_ text: String) -> Date? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }

    let cal = Calendar.current
    let thisYear = cal.component(.year, from: Date())

    let df = DateFormatter()
    df.locale = Locale(identifier: "zh_CN")

    let formats: [String] = [
        "yyyy-MM-dd", "yyyy/MM/dd", "yyyy.MM.dd",
        "yyyy年M月d日", "yyyy年MM月dd日",
        "M月d日", "MM月dd日",
        "M月d号", "M.d", "M-d", "M/d"
    ]
    for fmt in formats {
        df.dateFormat = fmt
        if let date = df.date(from: trimmed) {
            let comps = cal.dateComponents([.year], from: date)
            // If format didn't include year, use current year
            let isShort = fmt.contains("M月d") || fmt.contains("M.") || fmt.contains("M-") || fmt.contains("M/")
            if isShort && !fmt.contains("yyyy") {
                return cal.date(byAdding: .year, value: thisYear - (comps.year ?? thisYear), to: date)
            }
            return date
        }
    }

    // Try numeric: "M-d" or "M/d" or "M.d" with 1-2 digit parts
    let seps: [Character] = ["-", "/", "."]
    for sep in seps {
        let parts = trimmed.components(separatedBy: String(sep))
        if parts.count == 2, let m = Int(parts[0]), let d = Int(parts[1]),
           (1...12).contains(m), (1...31).contains(d) {
            var comps = DateComponents(); comps.year = thisYear; comps.month = m; comps.day = d
            if let date = cal.date(from: comps) { return date }
        }
        if parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
           (1...12).contains(m), (1...31).contains(d) {
            var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
            if let date = cal.date(from: comps) { return date }
        }
    }
    return nil
}

// MARK: - AttendanceView
struct AttendanceView: View {
    @EnvironmentObject var store: DataStore
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var month = Calendar.current.component(.month, from: Date())
    @State private var showAdd = false
    @State private var editItem: Attendance? = nil

    private var items: [Attendance] { store.attendancesForMonth(year: year, month: month) }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("\(String(year))年\(month)月  已上\(items.count)节")) {
                    if items.isEmpty { Text("暂无出勤记录").foregroundColor(.secondary) }
                    ForEach(items) { a in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(store.courseName(a.courseId)).font(.headline)
                                Text(a.date, style: .date).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if !store.isKinderCourse(a.courseId) && a.studentCount > 0 {
                                Text("\(a.studentCount)人").font(.title3).fontWeight(.bold).foregroundColor(.indigo)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editItem = a }
                        .swipeActions { Button("删除", role: .destructive) { store.deleteAttendance(a.id) } }
                    }
                }
            }
            .navigationTitle("出勤记录")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { prevMonth() } label: { Image(systemName: "chevron.left") } }
                ToolbarItem(placement: .principal) { Text("\(String(year))年\(month)月").font(.subheadline).fontWeight(.medium).foregroundColor(.indigo) }
                ToolbarItem(placement: .topBarTrailing) { Button { nextMonth() } label: { Image(systemName: "chevron.right") } }
            }
            .overlay(alignment: .bottomTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus").font(.title2).foregroundColor(.white).frame(width: 56, height: 56).background(Color.indigo).clipShape(Circle()).padding() }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddAttendanceView(onSave: { list in store.addAttendances(list); showAdd = false })
        }
        .sheet(item: $editItem) { item in
            EditAttendanceView(attendance: item, onSave: { store.updateAttendance($0); editItem = nil })
        }
    }

    private func prevMonth() { if month == 1 { year -= 1; month = 12 } else { month -= 1 } }
    private func nextMonth() { if month == 12 { year += 1; month = 1 } else { month += 1 } }
}

// MARK: - AddAttendanceView (date-driven batch recording)
struct AddAttendanceView: View {
    @EnvironmentObject var store: DataStore
    var onSave: ([Attendance]) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var dateText = ""
    @State private var parsedDate: Date? = nil
    @State private var parseError: String? = nil
    @State private var dayCourses: [Course] = []
    @State private var entries: [UUID: (studentCount: String, assistantCount: String, enabled: Bool)] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section("选择日期") {
                    HStack {
                        TextField("输入日期 (如 5月8日)", text: $dateText)
                            .onSubmit { parseAndLoad() }
                        Button("确定") { parseAndLoad() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                    if let error = parseError {
                        Text(error).foregroundColor(.red).font(.caption)
                    }
                    if let date = parsedDate {
                        HStack {
                            Text("已选择:")
                            Text(date, style: .date).foregroundColor(.indigo).fontWeight(.medium)
                        }.font(.caption)
                    }
                }

                if let date = parsedDate {
                    if dayCourses.isEmpty {
                        Section { Text("当天无课程安排").foregroundColor(.secondary) }
                    } else {
                        Section("当天课程（共\(dayCourses.count)门）") {
                            ForEach(dayCourses) { course in
                                courseEntryRow(course: course, date: date)
                            }
                        }
                    }
                }
            }
            .navigationTitle("录入出勤")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("批量保存") { saveAll() }
                        .disabled(parsedDate == nil || dayCourses.isEmpty || !hasAnyEntry())
                }
            }
        }
    }

    // MARK: Course entry row
    @ViewBuilder
    private func courseEntryRow(course: Course, date: Date) -> some View {
        let alreadyRecorded = store.hasAttendanceFor(courseId: course.id, date: date)

        if alreadyRecorded {
            HStack {
                VStack(alignment: .leading) {
                    Text(course.name).font(.headline)
                    Text("\(course.startTime)-\(course.endTime)").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Text("已录入")
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color(.systemGray5)).cornerRadius(6)
            }
        } else if course.isKindergarten {
            HStack {
                VStack(alignment: .leading) {
                    Text(course.name).font(.headline)
                    Text("幼儿园 ¥55/节").font(.caption).foregroundColor(.green)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { entries[course.id]?.enabled ?? false },
                    set: { entries[course.id] = ("0", "0", $0) }
                )).labelsHidden()
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(course.name).font(.headline)
                    Spacer()
                    Text("学生×7 + 助教×3").font(.caption2).foregroundColor(.orange)
                }
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        TextField("0", text: Binding(
                            get: { entries[course.id]?.studentCount ?? "" },
                            set: { v in
                                var e = entries[course.id] ?? ("", "0", true)
                                e.studentCount = v; entries[course.id] = e
                            }
                        )).keyboardType(.numberPad).frame(width: 48).multilineTextAlignment(.center)
                            .textFieldStyle(.roundedBorder)
                        Text("学生").font(.caption).foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        TextField("0", text: Binding(
                            get: { entries[course.id]?.assistantCount ?? "0" },
                            set: { v in
                                var e = entries[course.id] ?? ("", "0", true)
                                e.assistantCount = v; entries[course.id] = e
                            }
                        )).keyboardType(.numberPad).frame(width: 48).multilineTextAlignment(.center)
                            .textFieldStyle(.roundedBorder)
                        Text("助教").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func hasAnyEntry() -> Bool {
        guard let date = parsedDate else { return false }
        for course in dayCourses {
            if store.hasAttendanceFor(courseId: course.id, date: date) { continue }
            if course.isKindergarten {
                if entries[course.id]?.enabled == true { return true }
            } else {
                if let e = entries[course.id], !e.studentCount.isEmpty || (Int(e.assistantCount) ?? 0) > 0 || e.enabled { return true }
            }
        }
        return false
    }

    private func parseAndLoad() {
        parseError = nil
        parsedDate = nil
        dayCourses = []
        entries = [:]

        guard let date = parseFlexibleDate(dateText) else {
            parseError = "无法识别日期格式，请使用如 5月8日 或 2026-05-08"
            return
        }
        let startOfDay = Calendar.current.startOfDay(for: date)
        parsedDate = startOfDay
        let cal = Calendar.current
        let iosWd = cal.component(.weekday, from: startOfDay) // 1=Sun..7=Sat
        let dayOfWeek = iosWd == 1 ? 7 : iosWd - 1 // 1=Mon..7=Sun
        dayCourses = store.coursesForDayOfWeek(dayOfWeek)
    }

    private func saveAll() {
        guard let date = parsedDate else { return }
        var newAttendances: [Attendance] = []
        for course in dayCourses {
            guard !store.hasAttendanceFor(courseId: course.id, date: date) else { continue }
            if course.isKindergarten {
                if entries[course.id]?.enabled == true {
                    newAttendances.append(Attendance(courseId: course.id, date: date, studentCount: 0, assistantCount: 0))
                }
            } else {
                let e = entries[course.id]
                let sc = Int(e?.studentCount ?? "") ?? 0
                let ac = Int(e?.assistantCount ?? "0") ?? 0
                if sc > 0 || ac > 0 {
                    newAttendances.append(Attendance(courseId: course.id, date: date, studentCount: sc, assistantCount: ac))
                }
            }
        }
        if !newAttendances.isEmpty { onSave(newAttendances) }
    }
}

// MARK: - EditAttendanceView
struct EditAttendanceView: View {
    @EnvironmentObject var store: DataStore
    var attendance: Attendance
    var onSave: (Attendance) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var studentCount = ""
    @State private var assistantCount = ""
    private var isKinder: Bool { store.isKinderCourse(attendance.courseId) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(store.courseName(attendance.courseId)).font(.headline)
                    Text(attendance.date, style: .date).font(.caption)
                }
                if !isKinder {
                    Section("人数") {
                        TextField("学生人数", text: $studentCount).keyboardType(.numberPad)
                        TextField("助教人数", text: $assistantCount).keyboardType(.numberPad)
                    }
                } else {
                    Section { Text("幼儿园 ¥55/节").foregroundColor(.green) }
                }
            }
            .onAppear { studentCount = String(attendance.studentCount); assistantCount = String(attendance.assistantCount) }
            .navigationTitle("编辑出勤")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var a = attendance
                        a.studentCount = Int(studentCount) ?? 0
                        a.assistantCount = Int(assistantCount) ?? 0
                        onSave(a)
                    }
                }
            }
        }
    }
}
