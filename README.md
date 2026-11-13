# StandUp - 避免久坐

一款简洁、原生的 macOS 菜单栏休息提醒工具，帮你有效避免久坐。原本想直接找款免费的用，无奈翻遍 App Store 和 GitHub 都没找到合适的，自己动手写了。

StandUp 通过周期性工作计时和全屏休息遮罩，提醒你暂时离开屏幕、起身活动、放松眼睛。除了工作与休息循环，还提供可编辑的一次性闹钟，适合会议、喝水、服药或其他定时提醒场景。

![macOS](https://img.shields.io/badge/macOS-14.0%2B-black?logo=apple)
![Version](https://img.shields.io/badge/version-1.30-blue)
![xcode](https://img.shields.io/badge/Xcode-26%2B-1575F9?logo=xcode&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5%20language%20mode-orange?logo=swift)
![License](https://img.shields.io/badge/License-MIT-blue)

当前项目版本配置为 `1.30`；此版本之后的源码还包含计时器续跑、闹钟编辑和退出文案等维护更新。

## 📖 如在macOS下无法运行，请执行以下步骤：
> 系统设置 → 隐私与安全性 → 安全性 → 已阻止“StandUp.app”以保护Mac → 仍要打开

<p align="center">
  <img src="assets/iShot_15.20.29.png" alt="StandUp 菜单栏界面" width="420">
</p>
<p align="center">
  <img src="assets/IMG_6967@1920×1080.png" alt="StandUp 遮罩效果" width="1920">
</p>

## 功能介绍

### 工作与休息计时

- 自定义工作间隔，支持 `1～240` 分钟。
- 自定义休息时长，支持 `1～60` 分钟。
- 提供常用时长快捷选项，也可以手动输入时间。
- 菜单栏弹窗实时显示当前状态和工作倒计时；休息倒计时显示在全屏遮罩内。
- 应用启动约 2 秒后自动开始工作计时；也可以手动停止或重新开始。
- 完成休息或提前结束休息后，自动开始下一轮工作计时。
- 计时运行期间，工作/休息时长和提醒内容暂不可修改。

### 全屏休息提醒

- 工作计时结束后显示沉浸式全屏提醒，减少忽略提醒的可能。
- 覆盖主显示器及所有外接显示器，支持横屏和竖屏布局。
- 主屏显示提醒、操作按钮和休息倒计时；副屏显示匹配屏幕方向的背景遮罩。
- 可以点击“开始休息”，也可以按空格键或回车键快速开始。
- 休息过程中可以提前结束并继续工作。

### 个性化提醒

- 工作提醒和闹钟均支持设置最长 20 个字符的自定义提醒文字。
- 内置多条健康提示语，每轮随机展示。
- 可选在全屏遮罩出现前 10 秒播放提示音。
- 可选在休息提醒出现和结束时发送系统播放／暂停按键。

### 闹钟模式

- 支持选择具体日期和 24 小时时间。
- 最多可以同时添加 5 个一次性闹钟。
- 支持查看、编辑和删除已添加的闹钟。
- 设置为当前或过去时间时，按所选时分顺延到下一次出现的时间。
- 闹钟触发时显示当前时间、提醒内容和全屏提示；点击“我知道了”后移除该闹钟。
- 闹钟与休息提醒不会互相覆盖；若两者同时到期，会先处理闹钟，再显示休息提醒。
- 已保存的未到期闹钟会在应用重新启动后恢复。

### 原生 macOS 体验

- 常驻菜单栏，不在 Dock 显示图标，也不会创建普通启动窗口。
- 使用 SwiftUI 与 AppKit 构建，无第三方依赖。
- 设置和闹钟数据保存在本机 `UserDefaults` 中。
- 支持毛玻璃菜单、SF Symbols 和 macOS 原生交互。
- 已优化计时器与闹钟切换、多显示器遮罩、时间选择器交互和退出流程。

## 系统要求

- macOS 14.0 或更高版本
- Apple Silicon 或 Intel Mac
- 从源码构建需要 Xcode 26 或更高版本的工具链，项目使用 Swift 5 语言模式；本次验证使用 Xcode 27.2。

## 从源码运行

1. 克隆本仓库并进入项目目录。
2. 使用 Xcode 打开 `StandUp.xcodeproj`。
3. 选择共享的 `StandUp` Scheme。
4. 点击 Run，或使用以下命令构建：

```bash
xcodebuild -project StandUp.xcodeproj -scheme StandUp \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Release 构建：

```bash
xcodebuild -project StandUp.xcodeproj -scheme StandUp \
  -configuration Release CODE_SIGNING_ALLOWED=NO build
```

## 使用说明

1. 启动 StandUp，点击菜单栏中的计时器图标打开设置面板。
2. 在“计时器”模式中设置工作间隔、休息时长和提醒文字。
3. 根据需要开启提前提醒或自动暂停媒体。
4. 点击“开始”进入工作计时；计时结束后，按照全屏提示开始休息。
5. 如需指定时间提醒，切换到“闹钟”模式并添加闹钟。

> StandUp 启动后约 2 秒会自动开始工作计时。若需要完全退出，请在菜单面板底部点击“退出”。

## 辅助功能权限

“**休息提醒出现和结束时切换媒体播放**”需要 macOS 辅助功能权限。若尚未授权，开启此功能时会提示打开系统设置；已开启该功能的用户也会在启动时收到提示：

`系统设置 → 隐私与安全性 → 辅助功能`，找到并允许 `StandUp.app`。授权后，休息提醒出现时会发送一次播放/暂停切换，休息结束或计时器停止时再发送一次切换。该功能发送的是系统媒体按键事件，不会检测媒体当前是否正在播放。

如果不使用自动暂停媒体功能，可以选择“稍后”或不授予权限；其他计时和提醒功能仍可正常使用。系统按键会作用于当时响应它的媒体应用，也可能开始播放原本已暂停的媒体。

## 运行测试

共享 Scheme 包含独立的 `StandUpTests`，覆盖工作与休息续跑、提醒排队、闹钟改期和持久化等行为。

```bash
xcodebuild -project StandUp.xcodeproj -scheme StandUp \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

## 项目结构

```text
StandUp/
├── App/                 # 应用入口
├── Models/              # 闹钟及显示模式等数据模型
├── Controllers/         # 计时、菜单栏、生命周期和遮罩窗口管理
├── Views/
│   ├── Menu/            # 菜单栏设置界面
│   ├── Components/      # 通用 SwiftUI 组件和 AppKit 桥接
│   └── Overlay/         # 全屏休息与闹钟界面
└── Resources/           # 应用图标、横竖屏背景图片和提示音
```

项目遵循清晰的 MVC 职责划分：视图负责呈现状态和发送操作，控制器负责计时、持久化及窗口协调，模型保持为独立的数据类型。

## 参与贡献

欢迎提交 Issue。

- 本项目基于 [@heidebaiyang](https://github.com/heidebaiyang/Stop-Working) 二次开发。

## 许可证

本项目基于 [MIT License](LICENSE) 开源。
