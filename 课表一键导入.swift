import SwiftUI
import Foundation

// MARK: - Models

// MARK: - Models.swift

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
}

struct SalaryDetail: Identifiable {
    var id = UUID()
    var attendanceId: UUID
    var date: Date
    var courseName: String
    var studentCount: Int
    var assistantCount: Int
    var isKindergarten: Bool
    var rate: Double
}

// MARK: - DataStore.swift

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

// MARK: - ContentView.swift

// MARK: - Main Tab View
struct ContentView: View {
    var body: some View {
        TabView {
            ScheduleView().tabItem { Label("课表", systemImage: "calendar") }
            AttendanceView().tabItem { Label("出勤", systemImage: "list.clipboard") }
            SalaryView().tabItem { Label("工资", systemImage: "yensign.circle") }
            SettingsView().tabItem { Label("设置", systemImage: "gear") }
        }
    }
}

// MARK: - Helpers
struct DayLabel: View {
    let day: Int; let date: Date
    var body: some View {
        let labels = ["","周一","周二","周三","周四","周五","周六","周日"]
        let fmt = DateFormatter(); fmt.dateFormat = "MM/dd"
        Text("\(labels[day])  \(fmt.string(from: date))").font(.subheadline).foregroundColor(.indigo)
    }
}

let locationOptions = ["欧阳修","木马森林","万达"]
let colorOptions: [(String, Color)] = [
    ("", .gray.opacity(0.3)), ("#4F46E5", .indigo), ("#059669", .green), ("#D97706", .orange),
    ("#DC2626", .red), ("#7C3AED", .purple), ("#0891B2", .cyan), ("#DB2777", .pink), ("#52525B", .gray)
]

// MARK: - ScheduleView.swift

struct ScheduleView: View {
    @EnvironmentObject var store: DataStore
    @State private var weekOffset = 0
    @State private var showAdd = false
    @State private var editCourse: Course? = nil

    private var monday: Date {
        let cal = Calendar.current
        let today = Date()
        let wd = cal.component(.weekday, from: today) // 1=Sun
        let mondayOffset = (wd == 1 ? -6 : 2 - wd) + weekOffset * 7
        return cal.date(byAdding: .day, value: mondayOffset, to: cal.startOfDay(for: today))!
    }

    private var weekDays: [Date] { (0..<7).map { Calendar.current.date(byAdding: .day, value: $0, to: monday)! } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Day headers
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { i in
                            let day = weekDays[i]
                            let isToday = Calendar.current.isDateInToday(day)
                            VStack(spacing: 2) {
                                Text(["一","二","三","四","五","六","日"][i]).font(.caption2).foregroundColor(.secondary)
                                Text("\(Calendar.current.component(.day, from: day))")
                                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                                    .foregroundColor(isToday ? .white : .primary)
                                    .frame(width: 28, height: 28)
                                    .background(isToday ? Color.indigo : Color.clear)
                                    .clipShape(Circle())
                            }.frame(maxWidth: .infinity)
                        }
                    }.padding(.vertical, 6).background(Color(.systemBackground))

                    Divider()

                    // Day sections
                    ForEach(0..<7, id: \.self) { i in
                        let day = weekDays[i]
                        let dayCourses = store.courses.filter { $0.dayOfWeek == i+1 }
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                DayLabel(day: i+1, date: day).padding(.horizontal).padding(.top, 8)
                                Spacer()
                                if !dayCourses.isEmpty { Text("\(dayCourses.count)节").font(.caption).foregroundColor(.secondary).padding(.trailing) }
                            }
                            if dayCourses.isEmpty {
                                Text("休息").font(.caption).foregroundColor(.secondary).padding(.leading).padding(.vertical, 4)
                            } else {
                                ForEach(dayCourses) { course in
                                    Button { quickRecord(course, day) } label: {
                                        HStack {
                                            RoundedRectangle(cornerRadius: 2).fill(courseColor(course)).frame(width: 4, height: 40)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(course.name).font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                                                Text("\(course.startTime)-\(course.endTime)  |  \(course.location)").font(.caption).foregroundColor(.secondary)
                                            }
                                            Spacer()
                                        }.padding(8).background(Color(.systemBackground)).cornerRadius(10).padding(.horizontal, 8).padding(.vertical, 2)
                                    }.contextMenu {
                                        Button { editCourse = course } label: { Label("编辑", systemImage: "pencil") }
                                        Button(role: .destructive) { store.deleteCourse(course.id) } label: { Label("删除", systemImage: "trash") }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("课表")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { weekOffset -= 1 } label: { Image(systemName: "chevron.left") } }
                ToolbarItem(placement: .topBarTrailing) { Button { weekOffset += 1 } label: { Image(systemName: "chevron.right") } }
            }
            .overlay(alignment: .bottomTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus").font(.title2).foregroundColor(.white).frame(width: 56, height: 56).background(Color.indigo).clipShape(Circle()).padding() }
            }
        }
        .sheet(isPresented: $showAdd) { CourseFormView(onSave: { course in store.addCourse(course); showAdd = false }) }
        .sheet(item: $editCourse) { course in CourseFormView(course: course, onSave: { store.updateCourse($0); editCourse = nil }) }
    }

    private func quickRecord(_ course: Course, _ date: Date) {
        if course.isKindergarten {
            store.addAttendance(Attendance(courseId: course.id, date: date))
        } else {
            // Show alert with text field for student count - can't do this properly without UIAlertController wrapper
            store.addAttendance(Attendance(courseId: course.id, date: date))
        }
    }

    private func courseColor(_ c: Course) -> Color {
        if !c.colorHex.isEmpty, let rgb = Int(c.colorHex.dropFirst(), radix: 16) {
            return Color(red: Double((rgb>>16)&0xFF)/255, green: Double((rgb>>8)&0xFF)/255, blue: Double(rgb&0xFF)/255)
        }
        return c.isKindergarten ? .green : .orange
    }
}

// MARK: - AttendanceView.swift

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
                ToolbarItem(placement: .topBarTrailing) { Button { nextMonth() } label: { Image(systemName: "chevron.right") } }
            }
            .overlay(alignment: .bottomTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus").font(.title2).foregroundColor(.white).frame(width: 56, height: 56).background(Color.indigo).clipShape(Circle()).padding() }
            }
        }
        .sheet(isPresented: $showAdd) { AddAttendanceView(onSave: { a in store.addAttendance(a); showAdd = false }) }
        .sheet(item: $editItem) { item in
            EditAttendanceView(attendance: item, onSave: { store.updateAttendance($0); editItem = nil })
        }
    }

    private func prevMonth() { if month == 1 { year -= 1; month = 12 } else { month -= 1 } }
    private func nextMonth() { if month == 12 { year += 1; month = 1 } else { month += 1 } }
}

struct AddAttendanceView: View {
    @EnvironmentObject var store: DataStore
    var onSave: (Attendance) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedCourseId: UUID?
    @State private var date = Date()
    @State private var studentCount = ""
    @State private var assistantCount = "0"

    private var selCourse: Course? { store.courses.first { $0.id == selectedCourseId } }
    private var isKinder: Bool { selCourse?.isKindergarten ?? false }

    var body: some View {
        NavigationStack {
            Form {
                if store.courses.isEmpty { Text("请先在设置中添加课程").foregroundColor(.red) }
                Picker("课程", selection: $selectedCourseId) {
                    Text("选择课程").tag(nil as UUID?)
                    ForEach(store.courses) { Text($0.name).tag($0.id as UUID?) }
                }
                DatePicker("日期", selection: $date, displayedComponents: .date)
                if isKinder { Text("幼儿园 ¥55/节").foregroundColor(.green) } else {
                    TextField("学生人数", text: $studentCount).keyboardType(.numberPad)
                    TextField("助教人数", text: $assistantCount).keyboardType(.numberPad)
                }
            }
            .navigationTitle("录入出勤")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认") {
                        guard let cid = selectedCourseId else { return }
                        let d = Calendar.current.startOfDay(for: date)
                        let sc = isKinder ? 0 : (Int(studentCount) ?? 0)
                        let ac = isKinder ? 0 : (Int(assistantCount) ?? 0)
                        onSave(Attendance(courseId: cid, date: d, studentCount: sc, assistantCount: ac))
                    }.disabled(selectedCourseId == nil || (!isKinder && studentCount.isEmpty))
                }
            }
        }
    }
}

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
                Text(store.courseName(attendance.courseId)).font(.headline)
                Text(attendance.date, style: .date).font(.caption)
                if !isKinder {
                    TextField("学生人数", text: $studentCount).keyboardType(.numberPad)
                    TextField("助教人数", text: $assistantCount).keyboardType(.numberPad)
                } else { Text("幼儿园 ¥55/节").foregroundColor(.green) }
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

// MARK: - SalaryView.swift

struct SalaryView: View {
    @EnvironmentObject var store: DataStore
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var month = Calendar.current.component(.month, from: Date())

    private var details: [SalaryDetail] { store.salaryForMonth(year: year, month: month) }
    private var total: Double { details.reduce(0) { $0 + $1.rate } }
    private var kinder: [SalaryDetail] { details.filter { $0.isKindergarten } }
    private var normal: [SalaryDetail] { details.filter { !$0.isKindergarten } }

    var body: some View {
        NavigationStack {
            List {
                Section {} header: {
                    VStack(spacing: 8) {
                        Text("当月工资总额").font(.subheadline).foregroundColor(.white.opacity(0.8))
                        Text("¥ \(total, specifier: "%.2f")").font(.system(size: 40, weight: .bold)).foregroundColor(.white)
                        Text("共 \(details.count) 节课").font(.caption).foregroundColor(.white.opacity(0.7))
                    }.frame(maxWidth: .infinity).padding(.vertical, 24)
                }.listRowBackground(Color.indigo)

                if !kinder.isEmpty {
                    Section("幼儿园  小计 ¥\(kinder.reduce(0){$0+$1.rate}, specifier: "%.2f")") {
                        ForEach(kinder) { d in
                            HStack {
                                VStack(alignment: .leading) { Text(d.courseName).font(.headline); Text(d.date, style: .date).font(.caption) }
                                Spacer(); Text("¥\(d.rate, specifier: "%.2f")").font(.title3).fontWeight(.semibold).foregroundColor(.green)
                            }
                        }
                    }
                }
                if !normal.isEmpty {
                    Section("超能星球  小计 ¥\(normal.reduce(0){$0+$1.rate}, specifier: "%.2f")") {
                        ForEach(normal) { d in
                            HStack {
                                VStack(alignment: .leading) { Text(d.courseName).font(.headline); Text(d.date, style: .date).font(.caption) }
                                Spacer(); Text("¥\(d.rate, specifier: "%.2f")").font(.title3).fontWeight(.semibold).foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("课时费工资")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { prevMonth() } label: { Image(systemName: "chevron.left") } }
                ToolbarItem(placement: .topBarTrailing) { Button { nextMonth() } label: { Image(systemName: "chevron.right") } }
            }
        }
    }

    private func prevMonth() { if month == 1 { year -= 1; month = 12 } else { month -= 1 } }
    private func nextMonth() { if month == 12 { year += 1; month = 1 } else { month += 1 } }
}

// MARK: - SettingsView.swift

struct SettingsView: View {
    @EnvironmentObject var store: DataStore
    @State private var editCourse: Course? = nil
    @State private var showAdd = false
    @State private var showExport = false
    @State private var exportText = ""

    var body: some View {
        NavigationStack {
            List {
                Section("课程管理（\(store.courses.count)门）") {
                    ForEach(store.courses) { course in
                        HStack {
                            Circle().fill(courseColor(course)).frame(width: 12, height: 12)
                            VStack(alignment: .leading) {
                                Text(course.name).font(.subheadline).fontWeight(.medium)
                                Text("\(course.location)  周\(course.dayOfWeek) \(course.startTime)-\(course.endTime)").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                        }.contentShape(Rectangle()).onTapGesture { editCourse = course }
                        .swipeActions { Button("删除", role: .destructive) { store.deleteCourse(course.id) } }
                    }
                    Button("手动添加课程") { showAdd = true }
                }
                Section {
                    Button("导出全部数据") { exportAll() }
                }
                Section("薪资规则") {
                    Text("幼儿园：¥55/节").font(.caption)
                    Text("超能星球：学生×7 + 助教×3").font(.caption)
                }
            }
            .navigationTitle("设置")
        }
        .sheet(isPresented: $showAdd) { CourseFormView(onSave: { course in store.addCourse(course); showAdd = false }) }
        .sheet(item: $editCourse) { course in CourseFormView(course: course, onSave: { store.updateCourse($0); editCourse = nil }) }
        .sheet(isPresented: $showExport) {
            NavigationStack {
                ScrollView { Text(exportText).font(.system(size: 10, design: .monospaced)).padding() }
                    .navigationTitle("导出数据").toolbar { ToolbarItem { Button("关闭") { showExport = false } } }
            }
        }
    }

    private func exportAll() {
        var csv = "课程名称,上课地点,星期,开始时间,结束时间,幼儿园\n"
        for c in store.courses {
            csv += "\(c.name),\(c.location),\(c.dayOfWeek),\(c.startTime),\(c.endTime),\(c.isKindergarten ? "是" : "否")\n"
        }
        csv += "\n日期,课程,学生,助教,课时费,类型\n"
        var total = 0.0
        for a in store.attendances.sorted(by: { $0.date < $1.date }) {
            let c = store.courses.first { $0.id == a.courseId }
            let rate = c?.isKindergarten == true ? 55.0 : Double(a.studentCount)*7 + Double(a.assistantCount)*3
            total += rate
            csv += "\(a.date.formatted(.iso8601)),\(c?.name ?? "?"),\(a.studentCount),\(a.assistantCount),\(rate),\(c?.isKindergarten == true ? "幼儿园" : "超能星球")\n"
        }
        csv += "\n合计,\(total)"
        exportText = csv
        showExport = true
    }

    private func courseColor(_ c: Course) -> Color {
        if !c.colorHex.isEmpty, let rgb = Int(c.colorHex.dropFirst(), radix: 16) {
            return Color(red: Double((rgb>>16)&0xFF)/255, green: Double((rgb>>8)&0xFF)/255, blue: Double(rgb&0xFF)/255)
        }
        return c.isKindergarten ? .green : .orange
    }
}

// MARK: - CourseFormView.swift

struct CourseFormView: View {
    var course: Course? = nil
    var onSave: (Course) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var location = "欧阳修"
    @State private var day = 1
    @State private var startH = ""
    @State private var startM = ""
    @State private var endH = ""
    @State private var endM = ""
    @State private var isKinder = false
    @State private var colorHex = ""

    init(course: Course? = nil, onSave: @escaping (Course) -> Void) {
        self.course = course
        self.onSave = onSave
        if let c = course {
            _name = State(initialValue: c.name)
            _location = State(initialValue: c.location)
            _day = State(initialValue: c.dayOfWeek)
            let s = c.startTime.split(separator: ":")
            _startH = State(initialValue: s.count>0 ? String(s[0]) : "")
            _startM = State(initialValue: s.count>1 ? String(s[1]) : "")
            let e = c.endTime.split(separator: ":")
            _endH = State(initialValue: e.count>0 ? String(e[0]) : "")
            _endM = State(initialValue: e.count>1 ? String(e[1]) : "")
            _isKinder = State(initialValue: c.isKindergarten)
            _colorHex = State(initialValue: c.colorHex)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("课程名称", text: $name)
                Picker("上课地点", selection: $location) { ForEach(locationOptions, id: \.self) { Text($0) } }
                Picker("星期", selection: $day) {
                    ForEach(1..<8) { i in Text(["","周一","周二","周三","周四","周五","周六","周日"][i]).tag(i) }
                }
                Section("时间") {
                    HStack {
                        TextField("时", text: $startH).keyboardType(.numberPad).frame(width: 50)
                        Text(":"); TextField("分", text: $startM).keyboardType(.numberPad).frame(width: 50)
                        Text("→").foregroundColor(.secondary)
                        TextField("时", text: $endH).keyboardType(.numberPad).frame(width: 50)
                        Text(":"); TextField("分", text: $endM).keyboardType(.numberPad).frame(width: 50)
                    }
                }
                Toggle("幼儿园课程（固定55元/节）", isOn: $isKinder)
                Section("卡片颜色") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                        ForEach(colorOptions, id: \.0) { hex, color in
                            Circle().fill(color).frame(width: 36, height: 36)
                                .overlay(hex == colorHex ? Image(systemName: "checkmark").foregroundColor(.white).font(.caption2) : nil)
                                .overlay(hex == colorHex ? Circle().stroke(Color.indigo, lineWidth: 3) : Circle().stroke(Color.clear))
                                .onTapGesture { colorHex = hex }
                        }
                    }
                }
            }
            .navigationTitle(course == nil ? "添加课程" : "编辑课程")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let start = "\(startH.padding(toLength: 2, withPad: "0", startingAt: 0)):\(startM.padding(toLength: 2, withPad: "0", startingAt: 0))"
                        let end = "\(endH.padding(toLength: 2, withPad: "0", startingAt: 0)):\(endM.padding(toLength: 2, withPad: "0", startingAt: 0))"
                        var c = course ?? Course(name: "", location: "", dayOfWeek: 1, startTime: "09:00", endTime: "10:30")
                        c.name = name; c.location = location; c.dayOfWeek = day
                        c.startTime = start; c.endTime = end; c.isKindergarten = isKinder; c.colorHex = colorHex
                        onSave(c)
                    }.disabled(name.isEmpty || startH.isEmpty || startM.isEmpty || endH.isEmpty || endM.isEmpty)
                }
            }
        }
    }
}

// MARK: - KebiaoApp.swift

@main
struct KebiaoApp: App {
    @StateObject private var store = DataStore()

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
        }
    }
}
