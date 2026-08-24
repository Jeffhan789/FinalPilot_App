# TestFlight 发布流程

## 1. 当前目标

目标不是直接把未签名 IPA 发给别人安装，而是通过 TestFlight 分发 `学呀学`。

TestFlight 的流程是：

1. 用 Apple Developer Program 账号签名。
2. 在 App Store Connect 创建 App。
3. 从 Xcode Archive 上传构建。
4. 在 TestFlight 中邀请测试者或生成公开链接。

## 2. 前置条件

必须准备：

- Apple Developer Program 会员账号。
- Xcode 已登录同一个 Apple ID。
- App Store Connect 可访问权限。
- 一个唯一的 Bundle ID。

当前工程值：

- App 名称：`学呀学`
- Xcode Scheme：`FinalPilotApp`
- 当前 Bundle ID：`com.jeffhan.FinalPilot`
- 当前版本号：`0.1`
- 当前构建号：`1`

如果 `com.jeffhan.FinalPilot` 不能注册，可以改成：

```text
com.jeffhan.XueYaXue
```

## 3. App Store Connect 建议填写

新建 App 时建议：

- Platform：iOS
- Name：学呀学
- Primary Language：Simplified Chinese
- Bundle ID：选择上面注册好的 Bundle ID
- SKU：XUEYAXUE-2026
- User Access：Full Access

TestFlight 测试信息：

```text
Beta App Description:
学呀学是一款面向期末冲刺和机动事务并行场景的 iOS 复习助手。App 根据 C310 多智能体、E320 神经网络、C315 云计算三门课程的真实考试时间，提供今日任务、两周计划、课程路线、练习题和收纳在计划页的里程碑准备清单。

What to Test:
请重点测试四个底部页面：今日、计划、课程、练习。重点检查 2026-05-13 C310、2026-05-14 E320、2026-05-26 C315 的考试日期是否正确；今日页知识手卡是否覆盖 C310/E320 前两天笔记并显示重要程度；计划页是否能清楚展示 A4 两周冲刺安排，且里程碑只作为计划页二级分支出现；固定路径同步面板在未开启本地服务时是否显示内置快照。

Beta App Review Information:
无需账号登录。打开 App 即可体验全部功能。固定路径同步服务是本机开发辅助能力，如果审核环境没有开启该服务，App 会自动显示内置快照，不影响主流程。
```

## 4. Xcode 上传步骤

1. 打开 `FinalPilotApp.xcodeproj`。
2. 点击项目 Target `FinalPilotApp`。
3. 进入 `Signing & Capabilities`。
4. 勾选 `Automatically manage signing`。
5. Team 选择 Apple Developer Program 对应团队。
6. 确认 Bundle Identifier 和 App Store Connect 里创建的 Bundle ID 一致。
7. 顶部设备选择 `Any iOS Device`。
8. 菜单选择 `Product > Archive`。
9. Archive 完成后进入 Organizer。
10. 点击 `Distribute App`。
11. 选择 `TestFlight & App Store`。
12. 使用自动签名上传到 App Store Connect。

## 5. 邀请测试者

上传处理完成后：

1. 打开 App Store Connect。
2. 进入 `My Apps > 学呀学 > TestFlight`。
3. 先添加内部测试组。
4. 内部测试通过后，再添加外部测试组。
5. 外部测试需要填写测试信息并等待 Beta App Review。
6. 审核通过后，可以用邮箱邀请，或者创建公开链接发给别人。

## 6. 术语解释

- TestFlight：Apple 的官方 Beta 测试分发渠道。
- Archive：Xcode 生成的可上传发布构建。
- App Store Connect：管理 App、TestFlight、版本和审核的后台。
- Internal Testing：内部测试，面向 App Store Connect 团队成员。
- External Testing：外部测试，面向普通测试者，需要 Beta App Review。
