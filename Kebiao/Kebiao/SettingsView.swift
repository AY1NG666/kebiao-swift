import SwiftUI
import UniformTypeIdentifiers

// MARK: - Document picker wrapper (replaces .fileImporter to fix delegate callback bug)
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.isPresented = false
            parent.onPick(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var store: DataStore
    @State private var editCourse: Course? = nil
    @State private var showAdd = false
    @State private var showExport = false
    @State private var exportFileURL: URL? = nil
    @State private var showImporter = false
    @State private var importResult: (succeed: Int, errors: [String])? = nil
    @State private var showImportResult = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Course management
                    Text("课程管理").font(.subheadline).foregroundColor(.secondary).padding(.horizontal)

                    ForEach(store.courses) { course in
                        HStack {
                            Circle().fill(courseColor(course)).frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(course.name).font(.subheadline).fontWeight(.medium)
                                Text("\(course.location)  周\(["","一","二","三","四","五","六","日"][course.dayOfWeek]) \(course.startTime)-\(course.endTime)")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
                        .padding(.horizontal)
                        .contentShape(Rectangle())
                        .onTapGesture { editCourse = course }
                    }

                    Button {
                        showAdd = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill").foregroundColor(.indigo)
                            Text("手动添加课程").foregroundColor(.indigo)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
                        .padding(.horizontal)
                    }

                    // Data backup
                    Text("数据备份").font(.subheadline).foregroundColor(.secondary).padding(.horizontal).padding(.top, 16)

                    VStack(spacing: 0) {
                        Button {
                            showImporter = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down").frame(width: 24)
                                Text("导入数据 (CSV)")
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                            }
                            .padding()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 48)

                        Button {
                            exportAll()
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up").frame(width: 24)
                                Text("导出全部数据")
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                            }
                            .padding()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("设置")
        }
        .sheet(isPresented: $showAdd) { CourseFormView(onSave: { course in store.addCourse(course); showAdd = false }) }
        .sheet(item: $editCourse) { course in CourseFormView(course: course, onSave: { store.updateCourse($0); editCourse = nil }) }
        .sheet(isPresented: $showExport) {
            if let url = exportFileURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showImporter) {
            DocumentPicker(isPresented: $showImporter) { urls in
                handleImport(urls)
            }
        }
        .alert("导入结果", isPresented: $showImportResult) {
            Button("确定", role: .cancel) {}
        } message: {
            if let r = importResult {
                Text("成功导入 \(r.succeed) 条记录\(r.errors.isEmpty ? "" : "\n警告: \(r.errors.joined(separator: "; "))")")
            }
        }
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

        let df = DateFormatter(); df.dateFormat = "yyyyMMdd"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("课表备份_\(df.string(from: Date())).csv")
        try? csv.write(to: fileURL, atomically: true, encoding: .utf8)
        exportFileURL = fileURL
        showExport = true
    }

    // MARK: - Import
    private func handleImport(_ urls: [URL]) {
        guard let url = urls.first else { return }
        // asCopy=true already provides a local copy — no security scope needed
        let needsSecurityScope = !url.path.hasPrefix(NSTemporaryDirectory())
        if needsSecurityScope {
            guard url.startAccessingSecurityScopedResource() else {
                importResult = (0, ["无法访问文件（安全限制）"])
                showImportResult = true
                return
            }
        }
        defer { if needsSecurityScope { url.stopAccessingSecurityScopedResource() } }

        var content: String? = nil
        for enc in [String.Encoding.utf8, .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))] {
            if let c = try? String(contentsOf: url, encoding: enc), !c.isEmpty { content = c; break }
        }
        guard let csvStr = content else {
            importResult = (0, ["无法读取文件内容（编码错误）"])
            showImportResult = true
            return
        }

        let r = parseImportCSV(csvStr)
        importResult = r
        showImportResult = true
    }

    private func parseImportCSV(_ content: String) -> (succeed: Int, errors: [String]) {
        var importCourses: [Course] = []
        var importAttendances: [Attendance] = []
        var errors: [String] = []
        var section: String = ""
        var skipNext = false
        var lineNum = 0

        var courseMap: [String: UUID] = [:]
        for c in store.courses { courseMap[c.name] = c.id }

        let lines = content.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }

        for line in lines {
            lineNum += 1
            if line.isEmpty { continue }
            if line.hasPrefix("---") {
                section = line.replacingOccurrences(of: "-", with: "").trimmingCharacters(in: .whitespaces)
                skipNext = true
                continue
            }
            if skipNext { skipNext = false; continue }

            let cols = parseCSVLine(line)

            if section.contains("课程表") {
                guard cols.count >= 6 else { errors.append("第\(lineNum)行: 列数不够"); continue }
                let dayStr = cols[2].trimmingCharacters(in: .whitespaces)
                guard let day = Int(dayStr), (1...7).contains(day) else { errors.append("第\(lineNum)行: 无效星期 '\(dayStr)'"); continue }
                let name = cols[0]; let location = cols[1]
                let start = cols[3]; let end = cols[4]
                let isKinder = cols.count > 5 && (cols[5].hasPrefix("是") || cols[5].hasPrefix("1") || cols[5].lowercased().hasPrefix("y"))
                let color = cols.count > 7 ? cols[7] : ""
                let c = Course(name: name, location: location, dayOfWeek: day, startTime: start, endTime: end, isKindergarten: isKinder, colorHex: color)
                importCourses.append(c)
                courseMap[name] = c.id
            } else if section.contains("出勤记录") {
                guard cols.count >= 2 else { errors.append("第\(lineNum)行: 列数不够"); continue }
                let dateStr = cols[0]; let courseName = cols[1]
                let studentCount = Int(cols.count > 3 ? cols[3] : "0") ?? 0
                let assistantCount = Int(cols.count > 4 ? cols[4] : "0") ?? 0

                guard let date = parseFlexibleDate(dateStr) else { errors.append("第\(lineNum)行: 无效日期 '\(dateStr)'"); continue }
                guard let courseId = courseMap[courseName] else { errors.append("第\(lineNum)行: 找不到课程 '\(courseName)'"); continue }
                let startOfDay = Calendar.current.startOfDay(for: date)
                importAttendances.append(Attendance(courseId: courseId, date: startOfDay, studentCount: studentCount, assistantCount: assistantCount))
            }
        }

        if importCourses.isEmpty && importAttendances.isEmpty {
            return (0, ["未识别到任何课程或出勤数据，请确认CSV格式正确"])
        }

        if !importCourses.isEmpty {
            let importNames = Set(importCourses.map { $0.name })
            let keptCourses = store.courses.filter { !importNames.contains($0.name) }
            store.courses = keptCourses + importCourses
            store.save()
        }
        var added = 0
        if !importAttendances.isEmpty {
            for a in importAttendances {
                if !store.hasAttendanceFor(courseId: a.courseId, date: a.date) {
                    store.attendances.append(a)
                    added += 1
                } else {
                    errors.append("跳过重复: \(courseMap.first(where:{$0.value==a.courseId})?.key ?? "?") \(a.date)")
                }
            }
            store.save()
        }
        let courseCount = importCourses.isEmpty ? 0 : importCourses.count
        return (courseCount + added, errors)
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" { inQuotes.toggle(); continue }
            if ch == "," && !inQuotes { result.append(current.trimmingCharacters(in: .whitespaces)); current = ""; continue }
            current.append(ch)
        }
        result.append(current.trimmingCharacters(in: .whitespaces))
        return result
    }

    private func courseColor(_ c: Course) -> Color {
        if !c.colorHex.isEmpty, let rgb = Int(c.colorHex.dropFirst(), radix: 16) {
            return Color(red: Double((rgb>>16)&0xFF)/255, green: Double((rgb>>8)&0xFF)/255, blue: Double(rgb&0xFF)/255)
        }
        return c.isKindergarten ? .green : .orange
    }
}

// MARK: - Share sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
