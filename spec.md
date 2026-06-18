# Reminder · macOS 任务清单应用 · Spec 文档

> 版本: v1.0  
> 日期: 2026-06-18  
> 状态: ✅ 已确认，待进入第二阶段开发

---

## 0. 已确认决策

| 项 | 决策 |
|---|---|
| 存储方案 | **JSON 文件 + Codable** |
| 最低系统 | **macOS 15.0+ (Sequoia)** |
| 标题栏 | **保留系统标题栏**（窗口标题为 "Reminder"） |
| 关闭行为 | **关闭仅隐藏窗口，应用驻留后台**，避免频繁冷启动 |

---

## 1. 产品目标

打造一款**极简、快、轻**的 macOS 原生任务清单应用，专注"快速记录 / 快速删除"两个动作，不做任何任务管理增强功能。目标用户：希望用最低心智负担在桌面端速记零散事项的人。

**衡量指标**

- 冷启动 ≤ 0.5s；从 Dock 重新唤起 ≤ 50ms（已在后台）
- 安装包 ≤ 5 MB（不含签名/公证开销）
- 1000 条任务下输入、删除、滚动无掉帧
- 代码总量控制在 ~600 行以内（不含资源）

---

## 2. 功能范围

| 模块 | 包含 | 不包含 |
|------|------|------|
| 分类 | 工作 / 生活 切换 | 自定义分类、新增/删除分类 |
| 新增任务 | 输入、保存、Enter 快捷键、空输入校验、保存后清空 | 编辑、富文本、附件、@提及 |
| 任务列表 | 倒序展示、新任务置顶、稳定滚动 | 完成态、优先级、标签、搜索、排序、拖拽 |
| 删除任务 | 单击删除、即刻生效 | 二次确认、撤销、回收站 |
| 数据存储 | 本地持久化、重启保留、按分类隔离 | 同步、账号、导入/导出、备份 |
| 窗口生命周期 | 关闭→隐藏到后台、Dock/快捷键唤起、单窗口 | 多窗口、菜单栏 driver、托盘、Dock 角标 |

---

## 3. 页面结构

应用只有**一个主窗口**，无菜单页、无设置页、无详情页。

```
┌────────────────────────────────────────────────────┐
│  🔴 🟡 🟢            Reminder                      │  ← 系统标题栏 (高 28~32, 系统渲染)
├────────────────────────────────────────────────────┤
│                                                    │
│                  [ 工作 ][ 生活 ]                   │  ← 分类 Tab (居中, 152×26)
│                                                    │
│  ┌──────────────────────────────────────────────┐  │
│  │ 任务内容                              删除   │  │  ← 任务卡 (高 44)
│  └──────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────┐  │
│  │ 任务内容                              删除   │  │     列表区
│  └──────────────────────────────────────────────┘  │   (LazyVStack)
│                       ⋮                            │
│                                                    │
│  ┌──────────────────────────────────────┐ ┌─────┐ │
│  │ 请输入...                            │ │ 保存│ │  ← 输入栏 + 保存按钮
│  └──────────────────────────────────────┘ └─────┘ │     (输入框 44h, 按钮 105×44)
└────────────────────────────────────────────────────┘
```

**默认窗口尺寸**：813 × 686（与设计稿一致）；最小尺寸 480 × 480。

---

## 4. 交互流程

### 4.1 启动流程

1. 应用首次启动（冷启动）→ 加载本地 JSON 数据 → 默认进入"工作"分类 → 输入框获得焦点。
2. 应用从后台唤起（热启动）→ 直接显示已存在的窗口实例（`makeKeyAndOrderFront`），数据已在内存中。
3. 若读取失败/文件不存在 → 使用空数据集，不弹错误。

### 4.2 切换分类

- 点击 Tab → 切换 `currentCategory` → 列表立即刷新为该分类数据 → 输入框焦点保持/重新获取 → 输入框现有内容**不清空**（用户半路切换不丢失正在打字的内容）。

### 4.3 新增任务

1. 输入框输入内容。
2. 触发保存的两种方式：
    - 按 `Enter`（无修饰键）。
    - 点击"保存"按钮。
3. 校验：`trimmingCharacters(.whitespacesAndNewlines).isEmpty` → true 则**忽略**操作（不弹提示，不报错），保持输入框聚焦。
4. 通过校验后：构造 Task → 插入到当前分类数组**头部** → 写入持久化 → 清空输入框 → 输入框保持焦点 → 列表自动滚动到顶部（因新项在顶部，自然可见）。

### 4.4 删除任务

- 点击任务卡右侧"删除" → 立即从数组中移除 → 写入持久化 → 列表带轻微动画收起（`.easeInOut(0.18s)`）。

### 4.5 关闭与重新唤起（核心调整）

- **点击红色关闭按钮（或 ⌘W）** → 仅**隐藏窗口**，应用进程不退出（`window.orderOut`）。
- **点击 Dock 图标 / 通过 ⌘Tab / Spotlight 重新打开** → 通过 `applicationShouldHandleReopen(_:hasVisibleWindows:)` 重新显示窗口（`makeKeyAndOrderFront`）。
- **真正退出**：仅通过菜单 `Reminder → Quit Reminder`（⌘Q）或系统强制退出。
- 由于进程驻留，唤起几乎瞬时，且数据无需重新读盘。

---

## 5. 状态说明

### 5.1 全局状态（`TaskStore: ObservableObject`）

| 状态 | 类型 | 说明 |
|------|------|------|
| `workTasks` | `[Task]` | 工作分类任务列表（已按 createdAt 倒序） |
| `lifeTasks` | `[Task]` | 生活分类任务列表（已按 createdAt 倒序） |
| `currentCategory` | `Category` | 当前 Tab，`.work` / `.life`，默认 `.work` |

### 5.2 视图局部状态

| 状态 | 类型 | 说明 |
|------|------|------|
| `inputText` | `String` | 输入框内容，`@State` |
| `inputFocused` | `Bool` | 输入框焦点，`@FocusState` |

### 5.3 派生状态

- `currentTasks: [Task]` —— 由 `currentCategory` 决定返回 `workTasks` 或 `lifeTasks`。
- `canSave: Bool` —— `inputText.trimmed.isEmpty == false`，控制按钮禁用透明度（视觉反馈）。

---

## 6. 数据结构设计

```swift
enum Category: String, Codable, CaseIterable {
    case work = "work"
    case life = "life"

    var displayName: String {
        switch self {
        case .work: return "工作"
        case .life: return "生活"
        }
    }
}

struct Task: Identifiable, Codable, Equatable {
    let id: UUID            // 唯一标识
    let category: Category  // 所属分类
    var content: String     // 任务内容
    let createdAt: Date     // 创建时间，用于倒序排序
}

// 落盘格式（一个文件存全部）
struct Snapshot: Codable {
    var work: [Task]
    var life: [Task]
    var schemaVersion: Int  // 预留版本号，方便后续兼容
}
```

> **不引入完成状态字段**：需求明确不做完成态，避免数据膨胀。

---

## 7. 本地存储方案

### 7.1 选型：**JSON 文件 + Codable**（已确认）

### 7.2 落盘细节

- **文件路径**：`~/Library/Application Support/Reminder/tasks.json`
    - 通过 `FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)` 获取并自动创建目录。
- **写入策略**：每次 `add` / `delete` 后**异步**写盘（`Task.detached`，避免阻塞 UI）。
- **写入方式**：原子写入（`Data.write(to:options: [.atomic])`），防止崩溃时文件损坏。
- **读取时机**：`TaskStore.init()` 同步读取（启动一次，文件小，不阻塞）。
- **失败兜底**：读取/解析失败 → 打印日志 → 使用空数据 → 下次写入会覆盖坏文件。
- **节流（可选优化）**：连续删除时使用 0.3s 防抖合并写盘，避免高频 IO。MVP 暂不实现，留作扩展点。
- **由于进程驻留后台**，应用退出时（接收到 `applicationWillTerminate`）做一次最终同步写盘作为安全网。

---

## 8. 技术选型说明

| 项 | 选择 | 理由 |
|---|------|------|
| 语言 | **Swift 5.9+** | 原生、性能最佳、与 SwiftUI 一等公民 |
| UI 框架 | **SwiftUI** | 声明式、代码量少、原生外观、热预览 |
| 最低系统 | **macOS 15.0 (Sequoia)** | 已确认；可放心使用最新 SwiftUI API |
| 列表组件 | **`ScrollView` + `LazyVStack`** | 比 `List` 更易精确控制视觉（圆角卡片），且懒加载性能好 |
| 持久化 | **JSON + Codable** | 轻量、零依赖、调试友好（见 §7） |
| 状态管理 | **`@StateObject` + `ObservableObject`** | 标准方案，无需引入 TCA / Redux |
| 字体 | **SF Pro**（系统默认） | 与设计稿一致，零额外资源 |
| 图标 | **SF Symbols** | 系统内置，零包体积 |
| 窗口生命周期 | **`NSApplicationDelegateAdaptor` + `applicationShouldTerminateAfterLastWindowClosed = false`** | 关闭隐藏不退出，重新唤起即时 |
| 构建 | **Xcode 16+** | macOS 15 SDK 要求 |
| 第三方依赖 | **零** | 不使用 CocoaPods / SPM 第三方库 |
| 拒绝项 | Electron / RN / Flutter / Catalyst | 体积大、启动慢、非原生体验 |

**预期产物**：单架构 ~3 MB，Universal (Intel + Apple Silicon) ~5 MB。

---

## 9. 项目目录规划

```
Reminder/
├── Reminder.xcodeproj
├── Reminder/
│   ├── ReminderApp.swift           # @main 入口、窗口配置、AppDelegate
│   ├── AppDelegate.swift           # 关闭隐藏不退出、Dock 重新唤起逻辑
│   ├── Models/
│   │   ├── Task.swift              # Task / Category / Snapshot
│   │   └── TaskStore.swift         # ObservableObject + 持久化
│   ├── Views/
│   │   ├── ContentView.swift       # 主容器（Tab、列表、输入栏组合）
│   │   ├── CategoryTabView.swift   # 工作/生活 Tab
│   │   ├── TaskRowView.swift       # 单条任务卡 + 删除按钮
│   │   └── InputBarView.swift      # 输入框 + 保存按钮
│   ├── Theme/
│   │   └── Theme.swift             # 颜色、间距、字号常量
│   └── Assets.xcassets/
│       ├── AppIcon.appiconset/
│       └── AccentColor.colorset/
└── README.md                       # 运行/构建说明
```

文件总数 ~9 个 Swift 文件，结构扁平，单职责清晰。

---

## 10. 关键实现点

### 10.1 设计 → 代码映射表

| 设计元素 | 实现 |
|---|---|
| 窗口背景 #24252f | `Color(hex: 0x24252F)` 作为根 `.background` |
| 系统标题栏 | 默认保留，`window.title = "Reminder"` |
| 分类 Tab (152×26) | `HStack(spacing: 0)` 两个等宽矩形，选中态 #4482f9，未选中 #292a35，文字 13pt Medium |
| 任务卡 (44h, 圆角 4) | `RoundedRectangle` + `HStack`：内容左对齐 padding 20，"删除" 红色 #b00000 右对齐 padding 20 |
| 输入框 (44h, 圆角 8, 蓝边) | 自定义 `TextField` + `.overlay(RoundedRectangle.stroke(#4482F9))` |
| 保存按钮 (105×44, 圆角 39 胶囊) | `Button` + `.background(Capsule().fill(#4482F9))` |

### 10.2 列表性能

- `ScrollView { LazyVStack(spacing: 8) { ForEach(currentTasks) { ... } } }`
- 行高固定 44，避免动态测量。
- `Equatable` + `id: UUID` 让 SwiftUI 高效 diff。
- 删除使用 `withAnimation(.easeInOut(duration: 0.18))`，单行动画不会拖累千条列表。

### 10.3 Enter 快捷保存

- 使用 SwiftUI `.onSubmit { save() }` 配合 `TextField`，原生支持 Enter 提交，无须手写 `NSEvent` 监听。

### 10.4 焦点管理

- `@FocusState private var inputFocused: Bool`
- `.onAppear { inputFocused = true }`
- 保存后：`inputText = ""`；保持 `inputFocused = true`，无需手动重新设置。
- 窗口从后台唤起时，重新让输入框获得焦点。

### 10.5 颜色集中管理

```swift
enum Theme {
    static let bg            = Color(hex: 0x24252F)
    static let titleBar      = Color(hex: 0x323334)
    static let card          = Color(hex: 0x272D31)
    static let accent        = Color(hex: 0x4482F9)
    static let inactiveTab   = Color(hex: 0x292A35)
    static let placeholder   = Color(hex: 0x848484)
    static let danger        = Color(hex: 0xB00000)
    static let secondaryText = Color(hex: 0xA3A3A5)
}
```

### 10.6 窗口与生命周期配置

```swift
@main
struct ReminderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("Reminder") {
            ContentView()
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 813, height: 686)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    // 关闭最后一个窗口时不退出应用
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // 用户点击 Dock 图标时，如果没有可见窗口则恢复主窗口
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag, let window = sender.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
        return true
    }

    // 真正退出前再写一次盘作为安全网
    func applicationWillTerminate(_ notification: Notification) {
        TaskStore.shared.flushSync()
    }
}
```

---

## 11. 边界场景

| 场景 | 处理 |
|---|---|
| 输入为空白 / 全空格 | 静默忽略，不报错 |
| 输入超长（>500 字） | 不限制，但任务卡 `.lineLimit(1) + .truncationMode(.tail)` 截断显示 |
| 同一秒连续多次保存 | id 用 UUID，createdAt 精度 `Date()`，可能秒级相同——按插入顺序倒序时使用数组头部 insert，天然保序 |
| 数据文件损坏 | 解析异常 → 启动后空列表 → 用户保存即重写 |
| 数据文件丢失（首次启动） | 正常空列表，无任何提示 |
| 任务数量 1000+ | LazyVStack 懒加载，仅渲染可视区，无卡顿 |
| 多次快速删除 | 每次单独写盘；如有性能问题可加防抖（MVP 不做） |
| 切换分类时输入框有内容 | 保留内容，不清空（用户体验一致性） |
| 系统深色/浅色模式 | App 强制深色（与设计一致），通过 `.preferredColorScheme(.dark)` |
| Retina / 非 Retina | SwiftUI 自动适配，无需额外处理 |
| 关闭窗口未保存 | 不存在该场景——每次变更已即时写盘；退出前再 `flushSync()` 兜底 |
| 长时间在后台未操作 | 进程保留，无内存压力（数据集小）；macOS 在内存紧张时可能 jetsam，不做特殊处理 |

---

## 12. 不做的功能清单

明确**不**实现以下功能，**任何"顺手加上"的请求都需要在第二阶段单独确认**：

- ❌ 任务完成 / 勾选 / 划线
- ❌ 编辑已有任务
- ❌ 优先级 / 标签 / 颜色
- ❌ 截止时间 / 提醒推送 / 日历集成
- ❌ 搜索 / 筛选 / 排序选项
- ❌ 批量删除 / 全部清空
- ❌ 撤销 / 回收站 / 历史记录 / 归档
- ❌ 拖拽排序
- ❌ 自定义分类 / 多分类
- ❌ iCloud / 设备间同步
- ❌ 账号系统
- ❌ 导入 / 导出（JSON、Markdown）
- ❌ 设置页 / 偏好窗口
- ❌ 菜单栏常驻图标 / Dock 角标 / 全局快捷键
- ❌ 通知中心 widget
- ❌ 多语言（仅简体中文）
- ❌ 浅色模式适配（强制深色）

---

## 附录 A · 设计稿规格快照（来自 Figma）

| 元素 | 颜色 | 尺寸 / 字号 |
|------|------|------|
| 窗口背景 | #24252F | 813 × 686，圆角 6 |
| 标题栏 | #323334 | 高 32（系统渲染） |
| Tab 选中 | #4482F9 | 76 × 26，文字 13pt Medium 白 |
| Tab 未选中 | #292A35 | 76 × 26，文字 13pt Medium 白 |
| 任务卡背景 | #272D31 | 高 44，圆角 4 |
| 任务正文 | #FFFFFF | 16pt Regular SF Pro |
| 删除文字 | #B00000 | 16pt Regular SF Pro |
| 输入框 | #24252F + #4482F9 描边 | 高 44，圆角 8 |
| 输入占位符 | #848484 | 16pt Medium |
| 保存按钮 | #4482F9 | 105 × 44，圆角 39（胶囊） |
| 保存按钮文字 | #FFFFFF | 16pt Medium |

---

## 进入第二阶段的交付物（开发后输出）

1. 完整的 Xcode 项目（位于 `/Users/thepik/Desktop/mypro/newpro/Reminder/`）
2. README.md，包含：
    - 系统要求（macOS 15.0+，Xcode 16+）
    - 运行方式（`open Reminder.xcodeproj` → ⌘R）
    - 构建方式（Archive → Export，或 `xcodebuild` 命令）
    - 项目结构说明
3. 自测清单（验收标准对照表）
