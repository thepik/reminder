# Reminder

[English](README.md) | [中文](README.zh-CN.md)

Reminder 是一个小巧的原生 macOS 应用，用于快速记录、快速删除，以及快速复制命令。

## 环境要求

- macOS 15.0 或更新版本
- Xcode Command Line Tools
- macOS SDK 中的 AppKit 和 Foundation

## 运行

所有构建、运行、测试、打包都收敛到同一个入口脚本：

```bash
./script/make.sh <子命令>
```

可用子命令：

| 子命令   | 用途                                |
| -------- | ----------------------------------- |
| `build`  | 构建发布版 `.app` 到 `dist/`        |
| `run`    | 构建并启动（不传子命令时的默认值）  |
| `debug`  | 构建后用 `lldb` 启动                |
| `logs`   | 启动并流式查看 `os_log`             |
| `verify` | 启动并验证进程存活（CI 友好）       |
| `test`   | 编译并运行存储 / 布局测试           |
| `dmg`    | 构建并生成 `dist/Reminder.dmg`      |
| `clean`  | 清理 `build/` 与 `dist/`            |

发布版应用会输出到：

```text
dist/Reminder.app
```

如需指定 codesign 身份，通过环境变量 `SIGN_IDENTITY` 覆盖（默认 `-`，即 ad-hoc 签名）。

注意：在某些受沙盒限制的 shell 环境中，即使是系统应用，`open` 也可能失败。运行脚本会报告这种情况，并在可行时使用备用方式；通过 Finder 或 Dock 启动应用时，应在不受该限制的环境中验证。

## 项目结构

- `ReminderObjC/Sources/main.m`：应用入口
- `ReminderObjC/Sources/AppDelegate.*`：生命周期、关闭窗口时隐藏、Dock 重新打开、退出前最终写盘
- `ReminderObjC/Sources/Models/`：分类和事项模型
- `ReminderObjC/Sources/Store/`：JSON 持久化和数据结构迁移
- `ReminderObjC/Sources/Views/`：窗口、标签、列表行和输入视图
- `ReminderObjC/Sources/Theme/`：共享颜色、字体和按钮标题辅助方法
- `ReminderObjC/Tests/`：基于 Foundation 的存储测试
- `script/`：测试、构建、运行和 DMG 打包脚本

## 验收清单

- 启动后打开一个标题为 `Reminder` 的窗口
- 默认分类是 `工作`
- 标签显示 `工作` / `生活` / `快捷命令`
- 空输入或仅包含空白字符的输入会被忽略
- 回车和 `保存` 都可以创建事项
- 新事项会显示在当前分类顶部
- 列表行正文支持用鼠标选中部分文字，并可通过 `Command+C` 复制选中内容
- `工作` 和 `生活` 列表行只显示 `删除`
- `快捷命令` 列表行显示 `复制` 和 `删除`
- `复制` 会把完整命令写入系统剪贴板
- 快捷命令复制成功后会显示轻量 `已复制` 提示
- 快捷命令的 `复制` 按钮会有文字按压反馈
- 关闭窗口会隐藏窗口，但不会退出应用
- 点击 Dock 图标会恢复同一个窗口
- 重启应用后会从 `~/Library/Application Support/Reminder/tasks.json` 重新加载数据
