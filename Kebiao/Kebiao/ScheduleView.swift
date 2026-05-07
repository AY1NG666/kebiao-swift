import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var store: DataStore
    @State private var weekOffset = 0
    @State private var showAdd = false

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
            VStack(spacing: 0) {
                // Month label
                Text(monthLabel())
                    .font(.subheadline).fontWeight(.medium).foregroundColor(.indigo)
                    .padding(.vertical, 8)

                // Day headers
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        let day = weekDays[i]
                        let isToday = Calendar.current.isDateInToday(day)
                        VStack(spacing: 4) {
                            Text(["一","二","三","四","五","六","日"][i]).font(.caption).foregroundColor(.secondary)
                            Text("\(Calendar.current.component(.day, from: day))")
                                .font(.system(size: 16, weight: isToday ? .bold : .regular))
                                .foregroundColor(isToday ? .white : .primary)
                                .frame(width: 32, height: 32)
                                .background(isToday ? Color.indigo : Color.clear)
                                .clipShape(Circle())
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .background(Color(.systemBackground))

                Divider()

                // Day sections
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { i in
                            let day = weekDays[i]
                            let dayCourses = store.courses.filter { $0.dayOfWeek == i+1 }
                            let recordedCount = dayCourses.filter { store.hasAttendanceFor(courseId: $0.id, date: day) }.count

                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    DayLabel(day: i+1, date: day).padding(.horizontal).padding(.top, 8)
                                    Spacer()
                                    if !dayCourses.isEmpty {
                                        Text(recordedCount == dayCourses.count ? "\(dayCourses.count)节 ✓" : "\(dayCourses.count)节")
                                            .font(.caption).foregroundColor(recordedCount == dayCourses.count ? .green : .secondary)
                                            .padding(.trailing)
                                    }
                                }

                                if dayCourses.isEmpty {
                                    Text("休息").font(.caption).foregroundColor(.secondary).padding(.leading).padding(.vertical, 4)
                                } else {
                                    ForEach(dayCourses) { course in
                                        let recorded = store.hasAttendanceFor(courseId: course.id, date: day)
                                        HStack {
                                            RoundedRectangle(cornerRadius: 2).fill(courseColor(course)).frame(width: 4, height: 40)
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack(spacing: 4) {
                                                    Text(course.name).font(.subheadline).fontWeight(.semibold)
                                                    if recorded {
                                                        Image(systemName: "checkmark.circle.fill").font(.caption).foregroundColor(.green)
                                                    }
                                                }
                                                Text("\(course.startTime)-\(course.endTime)  |  \(course.location)")
                                                    .font(.caption).foregroundColor(.secondary)
                                            }
                                            Spacer()
                                        }
                                        .padding(8).background(Color(.systemBackground)).cornerRadius(10)
                                        .padding(.horizontal, 8).padding(.vertical, 2)
                                        .opacity(recorded ? 0.55 : 1.0)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("课表")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottomTrailing) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus").font(.title2).foregroundColor(.white)
                        .frame(width: 56, height: 56).background(Color.indigo).clipShape(Circle()).padding()
                }
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onEnded { value in
                        let h = value.translation.width
                        let v = value.translation.height
                        guard abs(h) > abs(v) && abs(h) > 20 else { return }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            weekOffset += h < 0 ? 1 : -1
                        }
                    }
            )
        }
        .sheet(isPresented: $showAdd) { CourseFormView(onSave: { course in store.addCourse(course); showAdd = false }) }
    }

    private func monthLabel() -> String {
        let firstDay = weekDays[0]; let lastDay = weekDays[6]
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
