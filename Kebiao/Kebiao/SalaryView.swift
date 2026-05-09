import SwiftUI

struct SalaryView: View {
    @EnvironmentObject var store: DataStore
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var month = Calendar.current.component(.month, from: Date())
    @State private var displayTotal: Double = -1  // -1 = loading sentinel (Android pattern)
    @State private var hasInitialLoad = false

    private var details: [SalaryDetail] { store.salaryForMonth(year: year, month: month) }
    private var total: Double { details.reduce(0) { $0 + $1.rate } }
    private var yanMeng: [SalaryDetail] { details.filter { $0.location == "炎梦" } }
    private var kinder: [SalaryDetail] { details.filter { $0.isKindergarten && $0.location != "炎梦" } }
    private var normal: [SalaryDetail] { details.filter { !$0.isKindergarten && $0.location != "炎梦" } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Total card (matching Android: indigo bg, white text)
                    VStack(spacing: 6) {
                        Text("课时费合计").font(.subheadline).foregroundColor(.white.opacity(0.85))
                        if displayTotal < 0 {
                            Text("...").font(.system(size: 44, weight: .bold, design: .rounded)).foregroundColor(.white)
                        } else {
                            Text("¥ \(displayTotal, specifier: "%.2f")")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .contentTransition(.numericText())
                        }
                        Text("\(String(year))年\(month)月 · \(details.count)节课")
                            .font(.caption).foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 36)
                    .background(Color.indigo)
                    .animation(.easeInOut(duration: 0.8), value: displayTotal)

                    // Detail sections
                    VStack(spacing: 12) {
                        if !kinder.isEmpty {
                            categorySection(title: "幼儿园", subtotal: kinder.reduce(0){$0+$1.rate}, items: kinder, accentColor: .green)
                        }
                        if !normal.isEmpty {
                            categorySection(title: "超能星球", subtotal: normal.reduce(0){$0+$1.rate}, items: normal, accentColor: .orange)
                        }
                        if !yanMeng.isEmpty {
                            categorySection(title: "炎梦", subtotal: yanMeng.reduce(0){$0+$1.rate}, items: yanMeng, accentColor: .blue)
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("课时费工资")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { prevMonth() } label: { Image(systemName: "chevron.left") } }
                ToolbarItem(placement: .principal) { Text("\(String(year))年\(month)月").font(.subheadline).fontWeight(.medium).foregroundColor(.indigo) }
                ToolbarItem(placement: .topBarTrailing) { Button { nextMonth() } label: { Image(systemName: "chevron.right") } }
            }
        }
        .onAppear {
            if !hasInitialLoad {
                displayTotal = total  // show immediately, no animation on first load
                hasInitialLoad = true
            } else {
                animateTotal()
            }
        }
        .onChange(of: month) { _ in animateTotal() }
        .onChange(of: year) { _ in animateTotal() }
        .onChange(of: total) { _ in animateTotal() }
    }

    private func animateTotal() {
        withAnimation(.easeInOut(duration: 0.8)) {
            displayTotal = total
        }
    }

    @ViewBuilder
    private func categorySection(title: String, subtotal: Double, items: [SalaryDetail], accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(accentColor).frame(width: 8, height: 8)
                Text(title).font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("小计 ¥\(subtotal, specifier: "%.2f")")
                    .font(.caption).foregroundColor(accentColor).fontWeight(.medium)
            }
            .padding(.horizontal, 4)

            ForEach(items) { d in
                HStack {
                    Text(d.courseName).font(.subheadline)
                    Spacer()
                    Text(d.date, style: .date).font(.caption).foregroundColor(.secondary)
                    Text("¥\(d.rate, specifier: "%.0f")")
                        .font(.subheadline).fontWeight(.semibold).foregroundColor(accentColor)
                        .frame(minWidth: 48, alignment: .trailing)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color(.systemBackground)).cornerRadius(8)
            }
        }
    }

    private func prevMonth() { if month == 1 { year -= 1; month = 12 } else { month -= 1 } }
    private func nextMonth() { if month == 12 { year += 1; month = 1 } else { month += 1 } }
}
