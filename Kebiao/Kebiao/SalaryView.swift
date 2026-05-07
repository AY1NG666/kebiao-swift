import SwiftUI

struct SalaryView: View {
    @EnvironmentObject var store: DataStore
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var month = Calendar.current.component(.month, from: Date())

    private var details: [SalaryDetail] { store.salaryForMonth(year: year, month: month) }
    private var total: Double { details.reduce(0) { $0 + $1.rate } }
    private var kinder: [SalaryDetail] { details.filter { $0.isKindergarten } }
    private var normal: [SalaryDetail] { details.filter { !$0.isKindergarten } }

    var body: some View {
        NavigationStack {
            List {
                Section {} header: {
                    VStack(spacing: 8) {
                        Text("当月工资总额").font(.subheadline).foregroundColor(.white.opacity(0.8))
                        Text("¥ \(total, specifier: "%.2f")").font(.system(size: 40, weight: .bold)).foregroundColor(.white)
                        Text("共 \(details.count) 节课").font(.caption).foregroundColor(.white.opacity(0.7))
                    }.frame(maxWidth: .infinity).padding(.vertical, 24)
                }.listRowBackground(Color.indigo)

                if !kinder.isEmpty {
                    Section("幼儿园  小计 ¥\(kinder.reduce(0){$0+$1.rate}, specifier: "%.2f")") {
                        ForEach(kinder) { d in
                            HStack {
                                VStack(alignment: .leading) { Text(d.courseName).font(.headline); Text(d.date, style: .date).font(.caption) }
                                Spacer(); Text("¥\(d.rate, specifier: "%.2f")").font(.title3).fontWeight(.semibold).foregroundColor(.green)
                            }
                        }
                    }
                }
                if !normal.isEmpty {
                    Section("超能星球  小计 ¥\(normal.reduce(0){$0+$1.rate}, specifier: "%.2f")") {
                        ForEach(normal) { d in
                            HStack {
                                VStack(alignment: .leading) { Text(d.courseName).font(.headline); Text(d.date, style: .date).font(.caption) }
                                Spacer(); Text("¥\(d.rate, specifier: "%.2f")").font(.title3).fontWeight(.semibold).foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("课时费工资")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { prevMonth() } label: { Image(systemName: "chevron.left") } }
                ToolbarItem(placement: .topBarTrailing) { Button { nextMonth() } label: { Image(systemName: "chevron.right") } }
            }
        }
    }

    private func prevMonth() { if month == 1 { year -= 1; month = 12 } else { month -= 1 } }
    private func nextMonth() { if month == 12 { year += 1; month = 1 } else { month += 1 } }
}
