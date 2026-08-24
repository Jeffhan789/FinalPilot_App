# 贡献指南

感谢您对 FinalPilot（学呀学）项目的关注！本文档将帮助您快速了解如何参与项目贡献。

## 如何贡献

### 报告 Bug

如果您发现了 Bug，请通过 [GitHub Issues](https://github.com/Jeffhan789/FinalPilot/issues) 提交，并使用我们提供的 **Bug 报告模板** 填写以下信息：

- 问题描述（发生了什么）
- 复现步骤（如何触发）
- 期望行为（应该发生什么）
- 实际行为（实际发生了什么）
- 环境信息（iOS 版本、设备型号、App 版本）

### 提交功能建议

欢迎提交新功能建议！请描述：

- 功能的使用场景
- 期望的交互方式
- 可能的实现思路（可选）

### 提交代码（Pull Request）

1. **Fork 仓库**：点击右上角 Fork 按钮，将项目复制到您的账户下
2. **创建分支**：从 `main` 分支切出功能分支
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **编写代码**：遵循现有代码风格和 Swift 规范
4. **本地验证**：确保项目能在 Xcode 中正常构建
   ```bash
   xcodebuild -project FinalPilotApp.xcodeproj -scheme FinalPilotApp -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
   ```
5. **运行 SwiftLint**：
   ```bash
   swiftlint lint
   ```
6. **提交变更**：使用清晰的 commit 信息
   ```bash
   git commit -m "feat: add dark mode support for PlanView"
   ```
7. **推送并创建 PR**：推送到您的 Fork 并创建 Pull Request

## 代码规范

### Swift 风格

- 遵循 [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- 使用 SwiftLint 检查代码规范（项目已配置 `.swiftlint.yml`）
- 使用 SwiftFormat 自动格式化（项目已配置 `.swiftformat`）

### Commit 信息规范

我们采用 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

| 类型 | 用途 |
|------|------|
| `feat` | 新功能 |
| `fix` | Bug 修复 |
| `docs` | 文档更新 |
| `style` | 代码格式调整（不影响功能） |
| `refactor` | 代码重构 |
| `test` | 测试相关 |
| `chore` | 构建/工具/依赖更新 |

示例：
```
feat: add exam countdown widget
fix: resolve Core Data migration crash on iOS 18
chore: update SwiftLint rules
```

### 分支命名规范

- `feature/<描述>` — 新功能
- `fix/<描述>` — Bug 修复
- `docs/<描述>` — 文档更新
- `chore/<描述>` — 工具/配置更新

## 项目结构说明

```
FinalPilotApp/
├── FinalPilotApp.swift          # App 入口
├── ContentView.swift            # 根视图
├── Models.swift                 # 数据模型
├── DataController.swift         # Core Data 控制器
├── AppStore.swift               # 状态管理
├── Theme.swift                  # 主题/颜色配置
├── Components.swift             # 可复用组件
├── DashboardView.swift          # 首页仪表盘
├── PlanView.swift               # 学习计划
├── CoursesView.swift            # 课程列表
├── PracticeView.swift           # 练习/测验
├── AnalyticsView.swift          # 学习统计
├── CareerView.swift             # 里程碑相关
├── FinalPilot.xcdatamodeld/     # Core Data 模型
└── Assets.xcassets/             # 图片资源
```

## 技术栈

- **Swift 6.0** + **SwiftUI**
- **Core Data** 数据持久化
- **WidgetKit** 桌面小组件
- **UserNotifications** 本地通知
- **Charts** 数据可视化

## 开发环境要求

- macOS 15+
- Xcode 16.1+
- iOS 18+ 模拟器或真机
- SwiftLint（可选，用于代码规范检查）

## 许可证

本项目采用 [MIT 许可证](LICENSE) 开源。

---

如有任何疑问，欢迎通过 [GitHub Discussions](https://github.com/Jeffhan789/FinalPilot/discussions) 交流！
