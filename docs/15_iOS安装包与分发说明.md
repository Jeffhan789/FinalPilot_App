# iOS 安装包与分发说明

## 1. 当前桌面产物

已在桌面生成三个文件：

- `学呀学_App图标.png`
- `学呀学_unsigned_for_resigning.ipa`
- `学呀学_FinalPilot_source_<commit>.zip`

其中 `学呀学_unsigned_for_resigning.ipa` 是未签名 IPA，用于后续转签或 Ad Hoc 导出流程，不建议直接发给普通用户安装。iPhone 安装 App 必须通过 Apple 签名验证。

该 IPA 使用 Release 配置构建，并已剥离调试符号，避免把本机源码绝对路径带入分享包。

`学呀学_FinalPilot_source_<commit>.zip` 是源码分享包，不包含 `.git` 历史，适合发给同学、导师或机动事务对象查看工程结构。

## 2. 为什么不能直接把 IPA 发给别人装

iOS 的安装包和 Android APK 不同。普通 iPhone 不能随便安装未签名 App。

可行分发方式主要有三种：

- TestFlight：最适合发给读者、同学或测试用户，用户通过 TestFlight 链接安装。
- Ad Hoc：需要收集对方 iPhone 的 UDID，把设备加入 Apple Developer 后导出可安装 IPA。
- Xcode 真机安装：只适合安装到自己的 iPhone，或对方有 Mac、Xcode 和源码时自行运行。

## 3. 推荐方案

如果只是里程碑项目展示，推荐优先使用：

1. 自己手机安装 `学呀学`，现场演示。
2. 同时准备源码压缩包和 GitHub 仓库链接。
3. 如果需要远程给别人试用，再走 TestFlight。

这个路径成本最低，也最符合项目展示场景。

## 4. 后续要做成真正可安装分发包

需要准备：

- Apple Developer Program 账号。
- Xcode 中配置 `Signing & Capabilities` 的 Team。
- 唯一的 Bundle Identifier，例如 `com.jeffhan.XueYaXue`。

然后在 Xcode 中执行：

1. 选择真实设备或 `Any iOS Device`。
2. `Product > Archive`。
3. 打开 Organizer。
4. 选择 `Distribute App`。
5. 如果面向多人测试，选择 TestFlight / App Store Connect。
6. 如果只给特定设备安装，选择 Ad Hoc，并提前注册设备 UDID。

## 5. 术语解释

- IPA：iOS App 的安装包格式，本质是一个包含 `.app` 的压缩包。
- 签名：Apple 用开发者证书确认这个 App 来源可信。
- Provisioning Profile：授权某个 App 可以安装到哪些设备、使用哪些能力的配置文件。
- UDID：每台 iPhone 的唯一设备编号，Ad Hoc 分发需要登记它。
