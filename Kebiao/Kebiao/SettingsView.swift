import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: DataStore
    @State private var editCourse: Course? = nil
    @State private var showAdd = false
    @State private var showExport = false
    @State private var exportText = ""
    @State private var showImporter = false
    @State private var importResult: (succeed: Int, errors: [String])? = nil
    @State private var showImportResult = false
    @State private var showAddRule = false
    @State private var editRule: SalaryRule? = nil

    var body: some View {
        NavigationStack {
            List {
                Section("课程管理（\(store.courses.count)门）") {
                    ForEach(store.courses) { course in
                        HStack {
                            Circle().fill(courseColor(course)).frame(width: 12, height: 12)
                            VStack(alignment: .leading) {
                                Text(course.name).font(.subheadline).fontWeight(.medium)
                                Text("\(course.location)  周\(["","一","二","三","四","五","六","日"][course.dayOfWeek]) \(course.startTime)-\(course.endTime)").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                        }.contentShape(Rectangle()).onTapGesture { editCourse = course }
                        .swipeActions { Button("删除", role: .destructive) { store.deleteCourse(course.id) } }
                    }
                    Button("手动添加课程") { showAdd = true }
                }

                Section("数据备份") {
                    Button("导入数据 (CSV)") { showImporter = true }
                    Button("导出全部数据") { exportAll() }
                }

                Section {
                    ForEach(store.salaryRules.sorted(by: { $0.minStudents < $1.minStudents })) { rule in
                        HStack {
                            let range = rule.maxStudents.map { "\(rule.minStudents)-\($0)人" } ?? "\(rule.minStudents)人以上"
                            Text(range).font(.subheadline)
                            Spacer()
                            Text("¥\(rule.ratePerClass, specifier: "%.0f")/节").foregroundColor(.indigo).fontWeight(.medium)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editRule = rule }
                        .swipeActions { Button("删除", role: .destructive) { store.deleteSalaryRule(rule.id) } }
                    }
                    Button("添加规则") { showAddRule = true }
                    Button("重置为默认") { store.resetSalaryRules() }.foregroundColor(.orange)
                } header: {
                    Text("薪资规则 (阶梯)")
                } footer: {
                    Text("薪资规则仅在导入/导出时作为参考，当前工资计算使用：幼儿园¥55/节，超能星球学生×7+助教×3")
                }
            }
            .navigationTitle("设置")
        }
        .sheet(isPresented: $showAdd) { CourseFormView(onSave: { course in store.addCourse(course); showAdd = false }) }
        .sheet(item: $editCourse) { course in CourseFormView(course: course, onSave: { store.updateCourse($0); editCourse = nil }) }
        .sheet(isPresented: $showExport) {
            NavigationStack {
                ScrollView { Text(exportText).font(.system(size: 10, design: .monospaced)).padding() }
                    .navigationTitle("导出数据")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { shareButton() }
                        ToolbarItem(placement: .cancellationAction) { Button("关闭") { showExport = false } }
                    }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [UTType.commaSeparatedText, UTType(filenameExtension: "csv") ?? .plainText], allowsMultipleSelection: false) { result in
            handleImport(result)
        }
        .alert("导入结果", isPresented: $showImportResult) {
            Button("确定", role: .cancel) {}
        } message: {
            if let r = importResult {
                Text("成功导入 \(r.succeed) 条记录\(r.errors.isEmpty ? "" : "\n警告: \(r.errors.joined(separator: "; "))")")
            }
        }
        .sheet(isPresented: $showAddRule) { SalaryRuleFormView(onSave: { store.addSalaryRule($0); showAddRule = false }) }
        .sheet(item: $editRule) { rule in SalaryRuleFormView(rule: rule, onSave: { store.updateSalaryRule($0); editRule = nil }) }
    }

    // MARK: - Export
    private func exportAll() {
        var csv = "--- 课程表 ---\n课程名称,上课地点,星期,开始时间,结束时间,时长(小时),幼儿园,颜色\n"
        for c in store.courses {
            csv += "\(c.name),\(c.location),\(c.dayOfWeek),\(c.startTime),\(c.endTime),\(c.durationHours),\(c.isKindergarten ? "是" : "否"),\(c.colorHex)\n"
        }
        csv += "\n--- 出勤记录 ---\n日期,课程名称,上课地点,学生,助教,课时费,类型\n"
        var total = 0.0
        for a in store.attendances.sorted(by: { $0.date < $1.date }) {
            let c = store.courses.first { $0.id == a.courseId }
            let rate = c?.isKindergarten == true ? 55.0 : Double(a.studentCount)*7 + Double(a.assistantCount)*3
            total += rate
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
            csv += "\(df.string(from: a.date)),\(c?.name ?? "?"),\(c?.location ?? "?"),\(a.studentCount),\(a.assistantCount),\(rate),\(c?.isKindergarten == true ? "幼儿园" : "超能星球")\n"
        }
        csv += "\n--- 汇总 ---\n总课程数,\(store.courses.count)\n总出勤记录,\(store.attendances.count)\n总课时费,\(total)"
        exportText = csv
        showExport = true
    }

    private func shareButton() -> some View {
        let tempDir = FileManager.default.temporaryDirectory
        let df = DateFormatter(); df.dateFormat = "yyyyMMdd"
        let fileURL = tempDir.appendingPathComponent("课表备份_\(df.string(from: Date())).csv")
        if let _ = try? exportText.write(to: fileURL, atomically: true, encoding: .utf8) {
            return AnyView(ShareLink(item: fileURL))
        }
        return AnyView(EmptyView())
    }

    // MARK: - Import
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first, url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                importResult = (0, ["无法读取文件"])
                showImportResult = true
                return
            }
            let r = parseImportCSV(content)
            importResult = r
            showImportResult = true
        case .failure(let error):
            importResult = (0, [error.localizedDescription])
            showImportResult = true
        }
    }

    private func parseImportCSV(_ content: String) -> (succeed: Int, errors: [String]) {
        var importCourses: [Course] = []
        var importAttendances: [Attendance] = []
        var errors: [String] = []
        var section: String = ""

        let lines = content.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }

        for line in lines {
            if line.isEmpty { continue }
            if line.hasPrefix("---") && line.hasSuffix("---") {
                section = line; continue
            }
            let cols = line.components(separatedBy: ",")
            if section.contains("课程表") {
                guard cols.count >= 6 else { errors.append("课程行格式不对: \(line)"); continue }
                let name = cols[0]; let location = cols[1]
                let dayStr = cols[2]; let start = cols[3]; let end = cols[4]
                let isKinder = (cols.count > 5 && (cols[5].hasPrefix("是") || cols[5].hasPrefix("y") || cols[5].hasPrefix("Y")))
                let color = cols.count > 7 ? cols[7] : ""
                if let day = Int(dayStr), (1...7).contains(day) {
                    importCourses.append(Course(name: name, location: location, dayOfWeek: day, startTime: start, endTime: end, isKindergarten: isKinder, colorHex: color))
                } else {
                    errors.append("无效星期: \(dayStr)")
                }
            } else if section.contains("出勤记录") {
                guard cols.count >= 4 else { errors.append("出勤行格式不对: \(line)"); continue }
                let dateStr = cols[0]; let courseName = cols[1]
                let studentCount = Int(cols.count > 3 ? cols[3] : "0") ?? 0
                let assistantCount = Int(cols.count > 4 ? cols[4] : "0") ?? 0

                guard let date = parseFlexibleDate(dateStr) else { errors.append("无效日期: \(dateStr)"); continue }
                // Match by course name (look in just-imported courses first, then existing)
                let matchedCourse = importCourses.first { $0.name == courseName } ?? store.courses.first { $0.name == courseName }
                guard let course = matchedCourse else { errors.append("找不到课程: \(courseName)"); continue }
                let startOfDay = Calendar.current.startOfDay(for: date)
                importAttendances.append(Attendance(courseId: course.id, date: startOfDay, studentCount: studentCount, assistantCount: assistantCount))
            }
        }

        // Apply import
        if !importCourses.isEmpty {
            // Replace all courses with imported ones
            store.courses = importCourses
            store.save()
        }
        var added = 0
        if !importAttendances.isEmpty {
            for a in importAttendances {
                // Skip if already exists
                if !store.hasAttendanceFor(courseId: a.courseId, date: a.date) {
                    store.attendances.append(a)
                    added += 1
                }
            }
            store.save()
        }
        let courseCount = importCourses.isEmpty ? 0 : importCourses.count
        return (courseCount + added, errors)
    }

    private func courseColor(_ c: Course) -> Color {
        if !c.colorHex.isEmpty, let rgb = Int(c.colorHex.dropFirst(), radix: 16) {
            return Color(red: Double((rgb>>16)&0xFF)/255, green: Double((rgb>>8)&0xFF)/255, blue: Double(rgb&0xFF)/255)
        }
        return c.isKindergarten ? .green : .orange
    }
}

// MARK: - Salary Rule Form
struct SalaryRuleFormView: View {
    var rule: SalaryRule? = nil
    var onSave: (SalaryRule) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var minStudents = ""
    @State private var maxStudents = ""
    @State private var ratePerClass = ""

    init(rule: SalaryRule? = nil, onSave: @escaping (SalaryRule) -> Void) {
        self.rule = rule
        self.onSave = onSave
        if let r = rule {
            _minStudents = State(initialValue: String(r.minStudents))
            _maxStudents = State(initialValue: r.maxStudents.map { String($0) } ?? "")
            _ratePerClass = State(initialValue: String(Int(r.ratePerClass)))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("学生人数区间") {
                    HStack {
                        TextField("最低", text: $minStudents).keyboardType(.numberPad)
                        Text("—")
                        TextField("最高(留空=不限)", text: $maxStudents).keyboardType(.numberPad)
                    }
                }
                Section {
                    HStack {
                        Text("¥")
                        TextField("每节课课时费", text: $ratePerClass).keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle(rule == nil ? "添加规则" : "编辑规则")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let mn = Int(minStudents) ?? 0
                        let mx = maxStudents.isEmpty ? nil : Int(maxStudents)
                        let rate = Double(ratePerClass) ?? 0
                        var r = rule ?? SalaryRule(minStudents: mn, maxStudents: mx, ratePerClass: rate)
                        r.minStudents = mn; r.maxStudents = mx; r.ratePerClass = rate
                        onSave(r)
                    }
                    .disabled(minStudents.isEmpty || ratePerClass.isEmpty)
                }
            }
        }
    }
}
