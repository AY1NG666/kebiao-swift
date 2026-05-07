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
    private var dateStr: String {
        let fmt = DateFormatter(); fmt.dateFormat = "MM/dd"; return fmt.string(from: date)
    }
    var body: some View {
        let labels = ["","周一","周二","周三","周四","周五","周六","周日"]
        Text("\(labels[day])  \(dateStr)").font(.subheadline).foregroundColor(.indigo)
    }
}

let locationOptions = ["欧阳修","木马森林","万达","炎梦"]

let colorOptions: [(String, Color)] = [
    ("", .gray.opacity(0.3)),
    // Indigo / Blue
    ("#312E81", Color(red: 0.19, green: 0.18, blue: 0.51)), ("#4F46E5", .indigo), ("#6366F1", Color(red: 0.39, green: 0.40, blue: 0.95)), ("#A5B4FC", Color(red: 0.65, green: 0.71, blue: 0.99)),
    // Blue
    ("#1E3A5F", Color(red: 0.12, green: 0.23, blue: 0.37)), ("#2563EB", .blue), ("#60A5FA", Color(red: 0.38, green: 0.65, blue: 0.98)), ("#93C5FD", Color(red: 0.58, green: 0.77, blue: 0.99)),
    // Cyan / Teal
    ("#155E75", Color(red: 0.08, green: 0.37, blue: 0.46)), ("#0891B2", .cyan), ("#22D3EE", Color(red: 0.13, green: 0.83, blue: 0.93)), ("#67E8F9", Color(red: 0.40, green: 0.91, blue: 0.98)),
    ("#0F766E", .teal), ("#14B8A6", Color(red: 0.08, green: 0.72, blue: 0.65)), ("#5EEAD4", Color(red: 0.37, green: 0.92, blue: 0.83)),
    // Green
    ("#14532D", Color(red: 0.08, green: 0.33, blue: 0.18)), ("#059669", .green), ("#22C55E", .mint), ("#86EFAC", Color(red: 0.53, green: 0.94, blue: 0.67)),
    // Lime / Yellow
    ("#3F6212", Color(red: 0.25, green: 0.38, blue: 0.07)), ("#65A30D", Color(red: 0.40, green: 0.64, blue: 0.05)), ("#A3E635", Color(red: 0.64, green: 0.90, blue: 0.21)),
    ("#854D0E", Color(red: 0.52, green: 0.30, blue: 0.05)), ("#CA8A04", .yellow), ("#FACC15", Color(red: 0.98, green: 0.80, blue: 0.08)), ("#FDE047", Color(red: 0.99, green: 0.88, blue: 0.28)),
    // Amber / Orange
    ("#92400E", Color(red: 0.57, green: 0.25, blue: 0.05)), ("#D97706", .orange), ("#F59E0B", Color(red: 0.96, green: 0.62, blue: 0.04)), ("#FBBF24", Color(red: 0.98, green: 0.75, blue: 0.14)),
    ("#C2410C", Color(red: 0.76, green: 0.25, blue: 0.05)), ("#EA580C", Color(red: 0.92, green: 0.35, blue: 0.05)), ("#FB923C", Color(red: 0.98, green: 0.57, blue: 0.24)),
    // Red / Rose
    ("#7F1D1D", Color(red: 0.50, green: 0.11, blue: 0.11)), ("#DC2626", .red), ("#EF4444", Color(red: 0.94, green: 0.27, blue: 0.27)), ("#FCA5A5", Color(red: 0.99, green: 0.65, blue: 0.65)),
    ("#881337", Color(red: 0.53, green: 0.07, blue: 0.22)), ("#E11D48", Color(red: 0.88, green: 0.11, blue: 0.28)), ("#FB7185", Color(red: 0.98, green: 0.44, blue: 0.52)),
    // Pink / Fuchsia
    ("#831843", Color(red: 0.51, green: 0.09, blue: 0.26)), ("#DB2777", .pink), ("#F472B6", Color(red: 0.96, green: 0.45, blue: 0.71)), ("#F9A8D4", Color(red: 0.98, green: 0.66, blue: 0.83)),
    ("#701A75", Color(red: 0.44, green: 0.10, blue: 0.46)), ("#C026D3", .purple), ("#D946EF", Color(red: 0.85, green: 0.27, blue: 0.94)),
    // Purple / Violet
    ("#4C1D95", Color(red: 0.30, green: 0.11, blue: 0.58)), ("#7C3AED", Color(red: 0.49, green: 0.23, blue: 0.93)), ("#A855F7", Color(red: 0.66, green: 0.33, blue: 0.97)), ("#C4B5FD", Color(red: 0.77, green: 0.71, blue: 0.99)),
    // Gray
    ("#1C1917", Color(red: 0.11, green: 0.10, blue: 0.09)), ("#52525B", Color(red: 0.32, green: 0.32, blue: 0.36)), ("#9CA3AF", Color(red: 0.61, green: 0.64, blue: 0.69)), ("#E5E5E5", Color(red: 0.90, green: 0.90, blue: 0.90)),
]
