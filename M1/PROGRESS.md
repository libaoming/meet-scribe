# M1 PROGRESS

| 字段 | 值 |
|---|---|
| active_feature | F07_icloud_inbox（后台验证中） |
| slice | S6 |
| 更新 | 2026-07-13 |

## Next Candidates
- F07 结果回填 → M1 收官打 tag
- 第二个 fixture：真实会议脱敏录音（首次真实使用后固化）

## Blockers
- （无。原 F04 的 HF token 阻塞已解除：pyannote community-1 从 ModelScope 整仓本地化，无需 token）

## Deviations
- **D-01**（2026-07-13）：SPEC 原定 `HF_ENDPOINT=hf-mirror.com` 下载 whisper 模型 → 实测 hf-mirror 已失效（308 重定向回被墙源站）。改为从 ModelScope（pengzhendong/faster-whisper-large-v3-turbo）下载 CT2 模型到 `models/`，whisperx 走本地路径。SPEC 已同步改。保守选项：模型固化在项目内，反而消除运行时下载依赖。
- **D-02**（2026-07-13）：venv 里 torchcodec 缺 ffmpeg dylib（警告级）。转写路径不受影响（whisperx 自带音频加载）；是否影响 S3 pyannote 待 S3 verify 时判定，先记录不修。

## Session Log（倒序）
### 2026-07-13（续）
- S5 E2E_PASS：20:55 投 inbox → launchd 触发 → 转写+分离+纪要+归档+通知全自动，turn 级说话人归属 6/6 正确。F06 passing。
- S4 完成：claude -p(sonnet) 五段纪要落 vault，角色推测正确，F05 passing。修 duration 取值 bug（改取 max(end)）。
- S3 完成：pyannote community-1 从 ModelScope 整仓本地化（含 PLDA），**无需 HF token**；首跑同性 TTS 聚成一人 → fixture 说话人B 变调-4半音后 F04 passing；再下 wav2vec2-zh 对齐模型，逐字稿改词级聚 turn。
- S6 接线：pipeline --scan 兼扫 iCloud MeetInbox（含 .icloud 占位触发下载），launchd 双 WatchPaths；F07 实测后台进行中。
- S1 完成：F01 fixture（say 双音色 42.57s）PASS、F02 meet CLI（真麦克风 3s 录音）PASS。
- S2 进行中：venv+whisperx 装好（torch 2.8.0）；撞 hf-mirror 失效 → 转 ModelScope 下模型（见 D-01）。
- 踩坑：macOS bash 3.2 + set -u 空数组展开报 unbound → 用 `${arr[@]+"${arr[@]}"}` 习语。
- 项目脚手架完成（4 层骨架）+ PRD/SPEC/architecture/features.json 填实（决策 D1-D6 见 PRD）。

## 如果…就…
- 如果不知道做什么 → 按 AGENTS.md「选 feature 算法」
- 如果 fixture 缺 → 先造 fixture，不许 mock
- 如果要核查线上/读大文件 → 派 `.claude/agents/meet-scribe-ops.md` 子 agent，别在主 context 拉原始输出

## 🤖 增量流水（待整理）
（空）
