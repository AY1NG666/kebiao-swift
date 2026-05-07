import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var store: DataStore
    @State private var weekOffset = 0
    @State private var showAdd = false
    @State private var editCourse: Course? = nil
    @State private var quickRecordCourse: Course? = nil
    @State private var quickRecordDate: Date? = nil

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
                                    let recorded = store.hasAttendanceFor(courseId: course.id, date: day)
                                    Button {
                                        if !recorded {
                                            quickRecordCourse = course
                                            quickRecordDate = day
                                        }
                                    } label: {
                                        HStack {
                                            RoundedRectangle(cornerRadius: 2).fill(courseColor(course)).frame(width: 4, height: 40)
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack(spacing: 4) {
                                                    Text(course.name).font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                                                    if recorded {
                                                        Image(systemName: "checkmark.circle.fill").font(.caption).foregroundColor(.green)
                                                    }
                                                }
                                                Text("\(course.startTime)-\(course.endTime)  |  \(course.location)").font(.caption).foregroundColor(.secondary)
                                            }
                                            Spacer()
                                        }
                                        .padding(8)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(10)
                                        .padding(.horizontal, 8).padding(.vertical, 2)
                                        .opacity(recorded ? 0.55 : 1.0)
                                    }
                                    .contextMenu {
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
                ToolbarItem(placement: .principal) { Text(monthLabel()).font(.subheadline).fontWeight(.medium).foregroundColor(.indigo) }
                ToolbarItem(placement: .topBarTrailing) { Button { weekOffset += 1 } label: { Image(systemName: "chevron.right") } }
            }
            .overlay(alignment: .bottomTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus").font(.title2).foregroundColor(.white).frame(width: 56, height: 56).background(Color.indigo).clipShape(Circle()).padding() }
            }
        }
        .sheet(isPresented: $showAdd) { CourseFormView(onSave: { course in store.addCourse(course); showAdd = false }) }
        .sheet(item: $editCourse) { course in CourseFormView(course: course, onSave: { store.updateCourse($0); editCourse = nil }) }
        .sheet(item: $quickRecordCourse) { course in
            QuickRecordView(course: course, date: quickRecordDate ?? Date(), onSave: { a in
                store.addAttendance(a)
                quickRecordCourse = nil
            })
        }
    }

    private func monthLabel() -> String {
        let firstDay = weekDays[0]
        let lastDay = weekDays[6]
        let cal = Calendar.current
        let c1 = cal.dateComponents([.year, .month], from: firstDay)
        let c2 = cal.dateComponents([.year, .month], from: lastDay)
        if c1.year == c2.year && c1.month == c2.month {
            return "\(c1.year ?? 0)年\(c1.month ?? 0)月"
        } else if c1.year == c2.year {
            return "\(c1.year ?? 0)年\(c1.month ?? 0)月 - \(c2.month ?? 0)月"
        } else {
            return "\(c1.year ?? 0)年\(c1.month ?? 0)月 - \(c2.year ?? 0)年\(c2.month ?? 0)月"
        }
    }

    private func courseColor(_ c: Course) -> Color {
        if !c.colorHex.isEmpty, let rgb = Int(c.colorHex.dropFirst(), radix: 16) {
            return Color(red: Double((rgb>>16)&0xFF)/255, green: Double((rgb>>8)&0xFF)/255, blue: Double(rgb&0xFF)/255)
        }
        return c.isKindergarten ? .green : .orange
    }
}

// MARK: - Quick Record Sheet
struct QuickRecordView: View {
    @EnvironmentObject var store: DataStore
    var course: Course
    var date: Date
    var onSave: (Attendance) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var studentCount = ""
    @State private var assistantCount = "0"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(course.name).font(.headline)
                    Text(date, style: .date).font(.caption)
                    Text("\(course.startTime)-\(course.endTime)  \(course.location)").font(.caption).foregroundColor(.secondary)
                }
                if course.isKindergarten {
                    Section { Text("幼儿园 ¥55/节").foregroundColor(.green) }
                } else {
                    Section("人数") {
                        TextField("学生人数", text: $studentCount).keyboardType(.numberPad)
                        TextField("助教人数", text: $assistantCount).keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle("快速出勤")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认") {
                        let sc = course.isKindergarten ? 0 : (Int(studentCount) ?? 0)
                        let ac = course.isKindergarten ? 0 : (Int(assistantCount) ?? 0)
                        onSave(Attendance(courseId: course.id, date: Calendar.current.startOfDay(for: date), studentCount: sc, assistantCount: ac))
                    }
                    .disabled(!course.isKindergarten && studentCount.isEmpty)
                }
            }
        }
    }
}
