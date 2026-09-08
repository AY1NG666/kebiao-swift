import SwiftUI

private func formatKindergartenRate(_ value: Double) -> String {
    String(format: "%.2f", value)
}

private func sanitizedRateInput(_ value: String) -> String {
    let allowed = value.filter { $0.isNumber || $0 == "." }
    let parts = allowed.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count > 1 else { return allowed }
    return String(parts[0]) + "." + String(parts[1].prefix(2))
}

struct CourseFormView: View {
    var course: Course? = nil
    var onSave: (Course) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var location = ""
    @State private var day = 1
    @State private var startH = ""
    @State private var startM = ""
    @State private var endH = ""
    @State private var endM = ""
    @State private var isKinder = false
    @State private var kindergartenRateText = formatKindergartenRate(Course.defaultKindergartenRate)
    @State private var colorHex = ""

    private let dayAbbrs = ["一","二","三","四","五","六","日"]

    private var durationText: String {
        guard let sH = Int(startH), let sM = Int(startM),
              let eH = Int(endH), let eM = Int(endM),
              (0...23).contains(sH), (0...59).contains(sM),
              (0...23).contains(eH), (0...59).contains(eM),
              eH * 60 + eM > sH * 60 + sM else {
            return "--"
        }
        let hours = Double(eH * 60 + eM - sH * 60 - sM) / 60.0
        if hours == floor(hours) { return "\(Int(hours))小时" }
        return String(format: "%.1f小时", hours)
    }

    private var validTimeInput: Bool {
        guard !startH.isEmpty, !startM.isEmpty, !endH.isEmpty, !endM.isEmpty,
              let sH = Int(startH), let sM = Int(startM),
              let eH = Int(endH), let eM = Int(endM) else {
            return false
        }
        return isValidTimeRange(
            start: String(format: "%02d:%02d", sH, sM),
            end: String(format: "%02d:%02d", eH, eM)
        )
    }

    init(course: Course? = nil, onSave: @escaping (Course) -> Void) {
        self.course = course
        self.onSave = onSave
        if let c = course {
            _name = State(initialValue: c.name)
            _location = State(initialValue: c.location)
            _day = State(initialValue: c.dayOfWeek)
            let s = c.startTime.split(separator: ":")
            _startH = State(initialValue: s.count>0 ? String(s[0]) : "")
            _startM = State(initialValue: s.count>1 ? String(s[1]) : "")
            let e = c.endTime.split(separator: ":")
            _endH = State(initialValue: e.count>0 ? String(e[0]) : "")
            _endM = State(initialValue: e.count>1 ? String(e[1]) : "")
            _isKinder = State(initialValue: c.isKindergarten)
            _kindergartenRateText = State(initialValue: formatKindergartenRate(c.effectiveKindergartenRate))
            _colorHex = State(initialValue: c.colorHex)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("课程名称", text: $name)
                }

                Section("上课地点") {
                    TextField("例如：欧阳修、木马森林或自定义地点", text: $location)
                }

                // Day of week chips
                Section("星期") {
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { i in
                            let d = i + 1
                            Button {
                                day = d
                            } label: {
                                Text(dayAbbrs[i])
                                    .font(.system(size: 14, weight: day == d ? .bold : .regular))
                                    .frame(width: 36, height: 36)
                                    .background(day == d ? Color.indigo : Color(.systemGray5))
                                    .foregroundColor(day == d ? .white : .primary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Time section
                Section {
                    HStack {
                        TextField("时", text: $startH).keyboardType(.numberPad).frame(width: 44)
                            .onChange(of: startH) { startH = String($0.filter { $0.isNumber }.prefix(2)) }
                        Text(":").foregroundColor(.secondary)
                        TextField("分", text: $startM).keyboardType(.numberPad).frame(width: 44)
                            .onChange(of: startM) { startM = String($0.filter { $0.isNumber }.prefix(2)) }
                        Spacer()
                        Text("→").foregroundColor(.secondary)
                        Spacer()
                        TextField("时", text: $endH).keyboardType(.numberPad).frame(width: 44)
                            .onChange(of: endH) { endH = String($0.filter { $0.isNumber }.prefix(2)) }
                        Text(":").foregroundColor(.secondary)
                        TextField("分", text: $endM).keyboardType(.numberPad).frame(width: 44)
                            .onChange(of: endM) { endM = String($0.filter { $0.isNumber }.prefix(2)) }
                    }
                    // Auto-calculated duration
                    HStack {
                        Text("课时长")
                        Spacer()
                        Text(durationText).foregroundColor(.indigo).fontWeight(.medium)
                    }
                }

                Toggle("幼儿园课程", isOn: $isKinder)

                if isKinder {
                    Section("幼儿园课时费") {
                        TextField("每节金额（元）", text: $kindergartenRateText)
                            .keyboardType(.decimalPad)
                            .onChange(of: kindergartenRateText) {
                                let sanitized = sanitizedRateInput($0)
                                if sanitized != kindergartenRateText { kindergartenRateText = sanitized }
                            }
                        if kindergartenRateValue == nil {
                            Text("请输入大于 0 的有效金额")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                // Color picker grid
                Section("卡片颜色") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                        ForEach(colorOptions, id: \.0) { hex, color in
                            Circle().fill(color).frame(width: 36, height: 36)
                                .overlay(hex == colorHex ? Image(systemName: "checkmark").foregroundColor(.white).font(.caption2) : nil)
                                .overlay(hex == colorHex ? Circle().stroke(Color.indigo, lineWidth: 3) : Circle().stroke(Color(.systemGray4), lineWidth: 0.5))
                                .onTapGesture { colorHex = hex }
                        }
                    }
                }
            }
            .navigationTitle(course == nil ? "添加课程" : "编辑课程")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard let sh = Int(startH), let sm = Int(startM),
                              let eh = Int(endH), let em = Int(endM),
                              validTimeInput,
                              let rate = kindergartenRateValue else { return }
                        let start = String(format: "%02d:%02d", sh, sm)
                        let end = String(format: "%02d:%02d", eh, em)
                        var c = course ?? Course(name: "", location: "", dayOfWeek: 1, startTime: "09:00", endTime: "10:30")
                        c.name = name; c.location = location; c.dayOfWeek = day
                        c.startTime = start; c.endTime = end; c.isKindergarten = isKinder
                        c.kindergartenRate = rate; c.colorHex = colorHex
                        onSave(c)
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !validTimeInput || kindergartenRateValue == nil)
                }
            }
        }
    }

    private var kindergartenRateValue: Double? {
        guard let value = Double(kindergartenRateText), value.isFinite, value > 0 else {
            return isKinder ? nil : Course.defaultKindergartenRate
        }
        return value
    }
}
