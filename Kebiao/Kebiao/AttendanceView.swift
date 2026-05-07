import SwiftUI

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
