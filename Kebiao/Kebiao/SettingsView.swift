import SwiftUI

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
