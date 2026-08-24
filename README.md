# FinalPilot（学呀学）

[![CI](https://github.com/Jeffhan789/FinalPilot/actions/workflows/ci.yml/badge.svg)](https://github.com/Jeffhan789/FinalPilot/actions/workflows/ci.yml)
![Version](https://img.shields.io/badge/version-v2.0.0-orange)
![Swift](https://img.shields.io/badge/Swift-6.0-f05138?logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-18%2B-007AFF?logo=apple)
![License](https://img.shields.io/badge/license-MIT-green)

FinalPilot is a local-first iOS study planner for turning exam dates, knowledge gaps, and quiz results into an executable daily plan. The app combines task prioritisation, spaced review, progress analytics, reminders, and home-screen widgets in one SwiftUI codebase.

中文说明见[下文](#中文说明)。

## Highlights

- Four focused workflows: Today, Plan, Courses, and Practice.
- Must / Should / Skip prioritisation with a separate flex track for unexpected work.
- Core Data persistence with idempotent seed migration.
- Ebbinghaus-inspired review suggestions and local notifications.
- App Group data sharing across the host app and WidgetKit extension.
- Study heatmaps, mastery trends, accuracy trends, and knowledge-state distribution.
- Swift 6 actor isolation and automated Xcode build-and-test coverage.

## Architecture

```text
SwiftUI views
    ↓
FinalPilotStore (@MainActor)
    ├── planning and quiz domain logic
    ├── StudyStatistics
    ├── NotificationManager
    └── WidgetDataProvider
            ↓
DataController (@MainActor)
            ↓
Core Data + App Group UserDefaults
```

The repository contains three Xcode targets:

| Target | Responsibility |
| --- | --- |
| `FinalPilotApp` | iOS application, persistence, planning, practice, and analytics |
| `FinalPilotWidgets` | Today tasks, countdown, and progress widgets |
| `FinalPilotAppTests` | Algorithm, store, and Core Data migration tests |

## Requirements

- macOS with Xcode 16 or later
- iOS 18 simulator or device
- SwiftLint only if you want to run the same lint job as CI

## Run locally

1. Clone the repository.
2. Open `FinalPilotApp.xcodeproj` in Xcode.
3. Select the shared `FinalPilotApp` scheme and an iOS 18 simulator.
4. Build and run.

Command-line verification:

```bash
xcodebuild \
  -project FinalPilotApp.xcodeproj \
  -scheme FinalPilotApp \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  test

swiftlint lint --reporter github-actions-logging
```

If that simulator name is unavailable, choose any installed iPhone simulator or let the CI workflow select one dynamically.

## Data and privacy

- The repository ships demo course, task, and quiz seed data so the main flows are visible on first launch.
- Runtime study records stay on the device in Core Data.
- The app does not require an account or connect to an external analytics service.
- Local source-sync configuration is intentionally excluded. Use `tools/sync_sources.example.json` as the public template.

## Documentation

- [Requirements](docs/01_需求规格说明书.md)
- [Interaction design](docs/03_版面与交互设计.md)
- [Architecture and course mapping](docs/04_技术架构与课程映射.md)
- [Data model and question bank](docs/05_数据模型与题库规划.md)
- [Source-sync design](docs/12_固定路径实时同步方案.md)
- [TestFlight release flow](docs/16_TestFlight发布流程.md)

## Roadmap

- Replace fixed seed dates with a first-run course editor.
- Add accessibility identifiers and UI tests for critical flows.
- Version the Core Data model before the next schema change.
- Add opt-in iCloud sync without weakening the local-first default.

## 中文说明

FinalPilot（学呀学）是一款本地优先的 iOS 学习计划工具。它把考试日期、知识薄弱点和练习结果整理成每天可执行的任务，并通过间隔复习、提醒、统计图表和桌面小组件形成完整学习闭环。

### 核心能力

- 今日、计划、课程、练习四条主流程。
- Must / Should / Skip 优先级，以及处理突发事务的机动轨道。
- Core Data 本地持久化与幂等种子迁移。
- 基于遗忘间隔的复习建议和本地通知。
- App Groups 支持主应用与 WidgetKit 扩展共享数据。
- 学习热力图、掌握度趋势、正确率趋势和知识状态分布。
- Swift 6 主线程隔离和 GitHub Actions 自动构建测试。

### 当前工程边界

当前版本面向单机个人学习场景，不包含账号系统、远程分析或云端协作。仓库内数据均为演示种子；真实学习记录保存在设备本地。下一阶段优先完善首次启动配置、UI 自动化测试、数据模型版本化与可选 iCloud 同步。

## Contributing

Issues and pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and keep changes covered by the shared Xcode scheme.

## License

[MIT](LICENSE)
