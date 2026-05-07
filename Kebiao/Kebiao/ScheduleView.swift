import SwiftUI

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
