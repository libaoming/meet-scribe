# Architecture — meet-scribe

## 设计原则
1. **触发靠文件落盘，不靠会议检测**——线下会议唯一确定的信号是「录音文件出现」。
2. **目录即状态机**——inbox/processing/archive/error 四目录承载全部流转状态，无数据库无常驻进程。
3. **单接缝**——launchd、CLI、手动全都收敛到 `pipeline.sh`，验证与回归只打这一条命令。
4. **$0 边际成本**——本地模型 + 订阅内 claude -p。

## 系统总览

```
入口 A（Mac 在场）              入口 B（iPhone 主力）
┌──────────────────┐          ┌───────────────────────┐
│ meet start 标题    │          │ 语音备忘录录音            │
│  └ ffmpeg 录内置麦 │          │  └「存储到文件」→ iCloud   │
│ meet stop         │          │     Drive/MeetInbox     │
└─────────┬────────┘          └───────────┬───────────┘
          │ mv                            │ iCloud 自动同步
          ▼                               ▼
   ┌────────────────────────────────────────────┐
   │ ~/Meetings/inbox/  ◀── launchd WatchPaths  │
   └───────────────────────┬────────────────────┘
                           ▼ （size 稳定检查 → mv processing/ 原子防重）
   ┌────────────────────────────────────────────┐
   │ pipeline.sh                                 │
   │ ① ffmpeg → 16kHz mono wav                  │
   │ ② whisperx（venv 绝对路径，HF 走 hf-mirror）  │
   │    转写 zh + pyannote 说话人分离 → JSON       │
   │ ③ 拼 prompt → claude -p → 纪要 md           │
   │ ④ 落 ~/ObsidianVault/meetings/ + 音频归档    │
   └───────┬───────────────────────┬────────────┘
           ▼ 成功                   ▼ 失败
   osascript 通知+open 纪要   error/ + 日志 + 失败通知
```

## 模块职责
- `bin/meet`：录音生命周期（start/stop），只负责把合格音频送进 inbox。
- `bin/pipeline.sh`：编排四步，唯一接缝；`--engine` 预留（v1 只有 whisperx）。
- `prompts/minutes.md`：纪要生成 prompt（结构、只依据逐字稿、猜角色规则）。
- `launchd plist`：WatchPaths=inbox → 调 pipeline 扫描模式。
- `venv/`：whisperx 专用 Python 环境，项目内自包含。

## 数据流
音频(m4a/任意) → wav(16k mono) → whisperx JSON(segments+speaker) → prompt 拼装(逐字稿文本化) → claude -p 输出 md 正文 → 加 frontmatter 落 vault → 音频+JSON 进 archive。

## 关键技术决策
见 PRD 决策登记表 D1–D6。补充实现层决策：
- **whisperx 而非 whisper.cpp + 独立 pyannote**：一个工具内置「转写+对齐+分离」整合，segments 直接带 speaker，少一层自己写的对齐胶水。
- **mv 原子性防重** 而非锁文件：同盘 mv 原子，最简。
- **纪要复跑不重转写**：转写 JSON 归档，`pipeline.sh --minutes-only <json>` 可只重跑 ③④（prompt 迭代时省 10+ 分钟）。
