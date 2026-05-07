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
                TextField("课程名称", text: $name)
                Picker("上课地点", selection: $location) { ForEach(locationOptions, id: \.self) { Text($0) } }
                Picker("星期", selection: $day) {
                    ForEach(1..<8) { i in Text(["","周一","周二","周三","周四","周五","周六","周日"][i]).tag(i) }
                }
                Section("时间") {
                    HStack {
                        TextField("时", text: $startH).keyboardType(.numberPad).frame(width: 50)
                        Text(":"); TextField("分", text: $startM).keyboardType(.numberPad).frame(width: 50)
                        Text("→").foregroundColor(.secondary)
                        TextField("时", text: $endH).keyboardType(.numberPad).frame(width: 50)
                        Text(":"); TextField("分", text: $endM).keyboardType(.numberPad).frame(width: 50)
                    }
                }
                Toggle("幼儿园课程（固定55元/节）", isOn: $isKinder)
                Section("卡片颜色") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                        ForEach(colorOptions, id: \.0) { hex, color in
                            Circle().fill(color).frame(width: 36, height: 36)
                                .overlay(hex == colorHex ? Image(systemName: "checkmark").foregroundColor(.white).font(.caption2) : nil)
                                .overlay(hex == colorHex ? Circle().stroke(Color.indigo, lineWidth: 3) : Circle().stroke(Color.clear))
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
                        let start = "\(startH.padding(toLength: 2, withPad: "0", startingAt: 0)):\(startM.padding(toLength: 2, withPad: "0", startingAt: 0))"
                        let end = "\(endH.padding(toLength: 2, withPad: "0", startingAt: 0)):\(endM.padding(toLength: 2, withPad: "0", startingAt: 0))"
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
