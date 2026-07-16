# meet-scribe

线下会议自动纪要管线：录音 → WhisperX 本地转写 + pyannote 说话人分离 → `claude -p` 生成纪要 → 落 Obsidian vault。全链路本地/免费，launchd 无人值守。

## 用法

- **Mac 在场**：`bin/meet start 会议名` 开录，`bin/meet stop` 停止，之后全自动。
- **iPhone**：语音备忘录录音 →「存储到文件」→ iCloud Drive/MeetInbox（配置见 `docs/iphone-setup.md`）。

文件落盘 `~/Meetings/inbox/` 即触发管线，纪要落 `~/ObsidianVault/meetings/`，完成后系统通知。

## 架构

见 `docs/architecture.md`（完整调用链路图）。核心原则：触发靠文件落盘、目录即状态机（inbox/processing/archive/error）、单接缝 `bin/pipeline.sh`。

## 换机恢复（models/ 与 venv/ 不入库）

1. **venv**：`uv venv venv --python 3.11 && uv pip install --python venv/bin/python whisperx`
2. **模型**（全部从 **ModelScope** 下载，hf-mirror 已失效、HF 直连不通，别走 HF 路线）：
   - `models/faster-whisper-large-v3-turbo/` ← ModelScope `pengzhendong/faster-whisper-large-v3-turbo`（1.5G）
   - `models/community-1/` ← pyannote community-1 整仓（含 `plda/plda.npz`，无需 HF token）
   - `models/wav2vec2-zh/` ← 中文词级对齐模型（1.2G）
   - `models/segmentation-3.0/`、`models/wespeaker-voxceleb-resnet34-LM/` ← pyannote 依赖权重
   - `models/*.yaml`（diarization 本地路径配置）已入库，无需重建
3. **自检**：`M1/init.sh` 走一遍，FAIL=0 即可开工。
4. **launchd**：`launchd/com.baoming.meet-scribe.plist` 装载到 `~/Library/LaunchAgents/`。

## 项目状态

harness 项目，进度见 `STATUS.md` / `features.json`；规格见 `docs/PRD.md`、`docs/SPEC.md`。
