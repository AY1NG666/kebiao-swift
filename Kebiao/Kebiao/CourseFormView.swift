import SwiftUI

struct CourseFormView: View {
    var course: Course? = nil
    var onSave: (Course) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var location = "欧阳修"
    @State private var day = 1
    @State private var startH = ""
    @State private var startM = ""
    @State private var endH = ""
    @State private var endM = ""
    @State private var isKinder = false
    @State private var colorHex = ""

    private let dayAbbrs = ["一","二","三","四","五","六","日"]

    private var durationText: String {
        let sH = Int(startH) ?? 0; let sM = Int(startM) ?? 0
        let eH = Int(endH) ?? 0; let eM = Int(endM) ?? 0
        let sm = sH * 60 + sM
        let em = eH * 60 + eM
        let diff = em > sm ? em - sm : em + 1440 - sm
        let hours = Double(diff) / 60.0
        if hours == 0 { return "—" }
        if hours == floor(hours) { return "\(Int(hours))小时" }
        return String(format: "%.1f小时", hours)
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
            _colorHex = State(initialValue: c.colorHex)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("课程名称", text: $name)
                }

                // Location chips
                Section("上课地点") {
                    HStack(spacing: 8) {
                        ForEach(locationOptions, id: \.self) { loc in
                            Button {
                                location = loc
                            } label: {
                                Text(loc)
                                    .font(.subheadline)
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(location == loc ? Color.indigo : Color(.systemGray5))
                                    .foregroundColor(location == loc ? .white : .primary)
                                    .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                        }
                    }
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

                Toggle("幼儿园课程（固定55元/节）", isOn: $isKinder)

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
                        let sh = min(Int(startH) ?? 0, 23); let sm = min(Int(startM) ?? 0, 59)
                        let eh = min(Int(endH) ?? 0, 23); let em = min(Int(endM) ?? 0, 59)
                        let start = String(format: "%02d:%02d", sh, sm)
                        let end = String(format: "%02d:%02d", eh, em)
                        var c = course ?? Course(name: "", location: "", dayOfWeek: 1, startTime: "09:00", endTime: "10:30")
                        c.name = name; c.location = location; c.dayOfWeek = day
                        c.startTime = start; c.endTime = end; c.isKindergarten = isKinder; c.colorHex = colorHex
                        onSave(c)
                    }.disabled(name.isEmpty || startH.isEmpty || startM.isEmpty || endH.isEmpty || endM.isEmpty)
                }
            }
        }
    }
}
