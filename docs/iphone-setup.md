# iPhone 录音入口（入口 B，线下会议主力）

> 原理：iPhone 录音 → 存到 iCloud Drive 的 `MeetInbox` 文件夹 → 自动同步到 Mac → launchd 检测到新文件 → 管线自动转写出纪要。

## 一次性设置（1 分钟）

1. iPhone 打开「文件」App → 浏览 → iCloud 云盘 → 右上角 ⋯ → 新建文件夹，命名 **MeetInbox**（必须一字不差）。
2. Mac 端确认目录已同步出现：`~/Library/Mobile Documents/com~apple~CloudDocs/MeetInbox/`（launchd 已在盯这个路径，无需再配）。

## 每次开会（两个动作）

1. **开会前**：打开「语音备忘录」开始录音，手机放桌子中央（收音质量 = 说话人分离质量的上限）。
2. **散会后**：结束录音 → 点录音条目 ⋯ → 「存储到文件」→ 选 iCloud 云盘/MeetInbox → 存储。

之后不用管：文件同步到 Mac 后管线自动跑，完成后 Mac 弹通知并打开纪要。

## 注意

- 手机与 Mac 需同一 iCloud 账号；大文件（1h 录音 ≈ 30MB）在 Wi-Fi 下几分钟同步完。
- Mac 若在睡眠，同步和处理会等到唤醒后进行（launchd WatchPaths 唤醒后触发）。
- 处理成功后文件会从 MeetInbox 消失（= 已归档到 `~/Meetings/archive/`），这是正常信号。
- 进阶（可选）：iPhone「快捷指令」可以把「停止录音→存储到 MeetInbox」做成一键，v1 不强求。
