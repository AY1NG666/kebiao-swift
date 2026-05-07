import SwiftUI

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
