# 课表 iOS

少儿运动馆教练课表管理 App — 记录出勤、计算课时费工资。

## 功能

- 周课表管理（左右滑动切周）
- 出勤录入（日期驱动，自动列出当天课程）
- 课时费工资计算（按地点/分组统计）
- CSV 导入导出
- 应用内更新日志

## 薪资规则

| 地点 | 规则 |
|------|------|
| 欧阳修 / 木马森林 | ￥55/节 |
| 超能星球（万达） | 学生 x7 + 助教 x3 |

## 构建 IPA

通过 GitHub Actions（无需本地 Xcode）：

1. 进入 Actions → Build IPA → Run workflow
2. 等待构建完成，下载 artifact 即 IPA

本地构建（需 macOS + Xcode）：

```bash
git clone https://github.com/AY1NG666/kebiao-swift.git
cd kebiao-swift/Kebiao/Kebiao
swiftc -o ~/Kebiao \
  -sdk $(xcrun --show-sdk-path --sdk iphoneos) \
  -target arm64-apple-ios16.0 \
  -framework SwiftUI -framework Foundation -framework UniformTypeIdentifiers \
  *.swift
```

## 技术栈

SwiftUI · Foundation · UniformTypeIdentifiers

## 许可

MIT
