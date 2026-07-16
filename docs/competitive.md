# 竞品参考 — meet-scribe

> 收录与 meet-scribe 同问题域（本地会议转写/纪要）的竞品对照。每条目记录：形态差异、可借鉴工程点、差异化定位。来源标注调研日期，数据以当日为准。

---

## meetily（Zackriya-Solutions/meetily）

- 调研日期：2026-07-13（GitHub Trending 周榜 +7,440★，总 23.8k★，v0.4.0）
- https://github.com/Zackriya-Solutions/meetily
- 定位：privacy-first 本地 AI 会议助手，Tauri 桌面 App（Rust 后端 + Next.js 前端），会中实时转写 + Ollama 摘要，macOS/Windows。
- 商业模式：开源社区版引流 → PRO 付费（更准模型、自定义模板、自动入会、**speaker diarization 也在 PRO 的 Coming Soon 列表**）。

### 与 meet-scribe 的形态对照

| 维度 | meetily | meet-scribe |
|------|---------|-------------|
| 产品形态 | GUI App，会中实时转写 | 无 GUI 批处理管线，文件落盘触发 |
| 音频入口 | 麦克风 + 系统音频混音（ducking 防削波，可抓 Zoom/Teams） | 内置麦（bin/meet）+ iPhone 语音备忘录 → iCloud |
| 转写引擎 | Whisper.cpp（CoreML/Metal）或 Parakeet ONNX | WhisperX（faster-whisper large-v3-turbo） |
| 说话人分离 | **开源版没有**；PRO 版 Coming Soon | pyannote（ModelScope 本地权重），S3 |
| 纪要生成 | Ollama 本地小模型为主 | claude -p（订阅内 $0 边际成本） |
| 落地 | App 内数据库 + 导出 | 直接落 Obsidian vault |

> [!NOTE] 关键事实：trending 简介里的 "speaker diarization" 是营销话术——README 明写 diarization 是 PRO 付费版的 Coming Soon，开源版没有。meet-scribe 的 S3 正在免费长出别人拿去收费的能力，方向被市场验证。

### 可借鉴的工程点

1. **Apple Silicon 加速路线（backlog 唯一新增项）**：faster-whisper 底层 CTranslate2 在 Mac 基本吃 CPU；meetily 走 Whisper.cpp + CoreML/Metal，同硬件转写快得多。若真实长录音（1h 会议）转写太慢，`pipeline.sh --engine` 预留接缝可挂 whisper.cpp 后端——architecture.md 留的口子现在有了明确候选实现。
2. **系统音频捕捉（v2 候选，当前 out_of_scope）**：F02 明确 out_of_scope「系统音频捕捉、线上会议」。日后做线上会议时，meetily 的 Rust 混音层（自认借了 Screenpipe 代码）是最直接的参考实现，不必从零研究 CoreAudio。
3. **Import & Enhance ≈ 我们的 `--minutes-only`**：转写产物归档、纪要可廉价重跑，同一思想，互相印证，设计不用改。

### 明确不跟的

- **Parakeet ONNX（"4x faster" 卖点）**：其模型 istupakov/parakeet-tdt-0.6b-v3-onnx 只覆盖 25 种欧洲语言，**不含中文**。中文会议场景 whisperx large-v3-turbo 是正确选择。
- **实时转写 GUI**：与 iPhone-first 无人值守批处理的定位根本不同，不跟。

### 差异化定位（meetily 够不着的三处）

1. **纪要质量**：claude -p vs Ollama 本地小模型写中文纪要，不是一个量级。
2. **知识库闭环**：它的纪要是 App 内孤岛；meet-scribe 落 Obsidian vault 进 wiki 体系。
3. **iPhone-first 无人值守**：它必须开着 App 开会；meet-scribe 录完扔 iCloud 即走。

若日后开源：「本地转写 + 分离 + Claude 订阅内纪要 + Obsidian 落盘」的 Unix 管线形态在 trending 上暂无对位选手，与 meetily 的 App 形态错位竞争。

### 对 S2/S3 的结论

**路线不用动**——中文场景 whisperx + pyannote 就是对的。唯一记 backlog：转写慢时挂 whisper.cpp CoreML 后端（走 `--engine` 接缝）。
