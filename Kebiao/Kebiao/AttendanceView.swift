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
            let isShort = fmt.contains("M月d") || fmt.contains("M.") || fmt.contains("M-") || fmt.contains("M/")
            if isShort && !fmt.contains("yyyy") {
                return cal.date(byAdding: .year, value: thisYear - (comps.year ?? thisYear), to: date)
            }
            return date
        }
    }

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

private let dayNames = ["","一","二","三","四","五","六","日"]

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
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("\(String(year))年\(month)月  已上\(items.count)节").font(.subheadline).foregroundColor(.secondary); Spacer() }
                        .padding(.horizontal)

                    if items.isEmpty {
                        Text("暂无出勤记录").foregroundColor(.secondary).frame(maxWidth: .infinity).padding(.top, 32)
                    }

                    ForEach(items) { a in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.courseName(a.courseId)).font(.subheadline).fontWeight(.semibold)
                                Text(a.date, style: .date).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if !store.isKinderCourse(a.courseId) && a.studentCount > 0 {
                                Text("\(a.studentCount)人").font(.title3).fontWeight(.bold).foregroundColor(.indigo)
                            } else if store.isKinderCourse(a.courseId) {
                                Image(systemName: "checkmark").foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                        .padding(.horizontal)
                        .contentShape(Rectangle())
                        .onTapGesture { editItem = a }
                        .contextMenu {
                            Button(role: .destructive) { store.deleteAttendance(a.id) } label: { Label("删除", systemImage: "trash") }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
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

// MARK: - AddAttendanceView (auto-detect today's date)
struct AddAttendanceView: View {
    @EnvironmentObject var store: DataStore
    var onSave: ([Attendance]) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var selectedDate: Date
    @State private var dayCourses: [Course] = []
    @State private var entries: [UUID: (studentCount: String, assistantCount: String, enabled: Bool)] = [:]

    init(onSave: @escaping ([Attendance]) -> Void) {
        self.onSave = onSave
        let today = Calendar.current.startOfDay(for: Date())
        _selectedDate = State(initialValue: today)
    }

    private var hasTodayCourses: Bool { !dayCourses.isEmpty }
    private var pendingCourses: [Course] { dayCourses.filter { !store.hasAttendanceFor(courseId: $0.id, date: selectedDate) } }
    private var recordedCourses: [Course] { dayCourses.filter { store.hasAttendanceFor(courseId: $0.id, date: selectedDate) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Date header
                    VStack(spacing: 4) {
                        Text(selectedDate, style: .date)
                            .font(.title2).fontWeight(.bold).foregroundColor(.indigo)
                        Text("周\(dayNames[Calendar.current.component(.weekday, from: selectedDate) == 1 ? 7 : Calendar.current.component(.weekday, from: selectedDate) - 1])")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.indigo.opacity(0.08)).cornerRadius(12).padding(.horizontal)

                    // Date picker for changing date
                    DatePicker("修改日期", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .padding(.horizontal)
                        .onChange(of: selectedDate) { _ in loadCourses() }

                    if dayCourses.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.exclamationmark").font(.system(size: 40)).foregroundColor(.secondary)
                            Text("当天无课程安排").foregroundColor(.secondary)
                        }.frame(maxWidth: .infinity).padding(.top, 32)
                    } else {
                        // Already recorded
                        if !recordedCourses.isEmpty {
                            Text("已录入").font(.subheadline).foregroundColor(.secondary).padding(.horizontal)
                            ForEach(recordedCourses) { course in
                                HStack {
                                    RoundedRectangle(cornerRadius: 2).fill(course.isKindergarten ? Color.green : Color.orange).frame(width: 4, height: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(course.name).font(.subheadline).fontWeight(.medium)
                                        Text("\(course.startTime)-\(course.endTime)").font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                }
                                .padding().background(Color(.systemBackground)).cornerRadius(10)
                                .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
                                .padding(.horizontal)
                            }
                        }

                        // Pending courses
                        if !pendingCourses.isEmpty {
                            Text(recordedCourses.isEmpty ? "当天课程（\(dayCourses.count)门）" : "待录入（\(pendingCourses.count)门）")
                                .font(.subheadline).foregroundColor(.secondary).padding(.horizontal)

                            ForEach(pendingCourses) { course in
                                pendingCourseCard(course: course)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("录入出勤")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveAll() }
                        .disabled(!hasTodayCourses || !hasAnyEntry())
                }
            }
        }
        .onAppear { loadCourses() }
    }

    @ViewBuilder
    private func pendingCourseCard(course: Course) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RoundedRectangle(cornerRadius: 2).fill(course.isKindergarten ? Color.green : Color.orange).frame(width: 4, height: 20)
                Text(course.name).font(.subheadline).fontWeight(.semibold)
                Spacer()
                if course.isKindergarten {
                    Text("¥55").font(.caption).foregroundColor(.green).fontWeight(.medium)
                }
            }

            if course.isKindergarten {
                Toggle("到课", isOn: Binding(
                    get: { entries[course.id]?.enabled ?? false },
                    set: { entries[course.id] = ("0", "0", $0) }
                )).tint(.green)
            } else {
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Text("学生")
                        TextField("0", text: Binding(
                            get: { entries[course.id]?.studentCount ?? "" },
                            set: { v in
                                var e = entries[course.id] ?? ("", "0", true)
                                e.studentCount = v; entries[course.id] = e
                            }
                        )).keyboardType(.numberPad).frame(width: 48).multilineTextAlignment(.center)
                            .textFieldStyle(.roundedBorder)
                            .font(.subheadline)
                    }
                    HStack(spacing: 6) {
                        Text("助教")
                        TextField("0", text: Binding(
                            get: { entries[course.id]?.assistantCount ?? "0" },
                            set: { v in
                                var e = entries[course.id] ?? ("", "0", true)
                                e.assistantCount = v; entries[course.id] = e
                            }
                        )).keyboardType(.numberPad).frame(width: 48).multilineTextAlignment(.center)
                            .textFieldStyle(.roundedBorder)
                            .font(.subheadline)
                    }
                    Spacer()
                    Text("×7+助教×3").font(.caption2).foregroundColor(.orange.opacity(0.6))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
        .padding(.horizontal)
    }

    private func loadCourses() {
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        let cal = Calendar.current
        let iosWd = cal.component(.weekday, from: startOfDay)
        let dayOfWeek = iosWd == 1 ? 7 : iosWd - 1
        dayCourses = store.coursesForDayOfWeek(dayOfWeek)
        entries = [:]
    }

    private func hasAnyEntry() -> Bool {
        for course in pendingCourses {
            if course.isKindergarten {
                if entries[course.id]?.enabled == true { return true }
            } else {
                if let e = entries[course.id], !e.studentCount.isEmpty || (Int(e.assistantCount) ?? 0) > 0 { return true }
            }
        }
        return false
    }

    private func saveAll() {
        var newAttendances: [Attendance] = []
        for course in pendingCourses {
            if course.isKindergarten {
                if entries[course.id]?.enabled == true {
                    newAttendances.append(Attendance(courseId: course.id, date: selectedDate, studentCount: 0, assistantCount: 0))
                }
            } else {
                let e = entries[course.id]
                let sc = Int(e?.studentCount ?? "") ?? 0
                let ac = Int(e?.assistantCount ?? "0") ?? 0
                if sc > 0 || ac > 0 {
                    newAttendances.append(Attendance(courseId: course.id, date: selectedDate, studentCount: sc, assistantCount: ac))
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
