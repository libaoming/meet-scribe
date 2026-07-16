# SPEC — meet-scribe

> v1（2026-07-13）。记决策不记路径；唯一验证接缝 = pipeline 命令。

## 数据模型 / Schema

**目录契约**（管线的状态机就是目录）：

| 目录 | 角色 | 进入条件 | 离开条件 |
|---|---|---|---|
| `~/Meetings/inbox/` | 待处理队列（唯一触发点） | 录音结束落盘 / iCloud 同步 / 手动 cp | 管线拾取后移入 processing |
| `~/Meetings/processing/` | 处理中（防重复拾取） | 管线开始 | 成功→archive，失败→error |
| `~/Meetings/archive/` | 已完成音频归档 | 纪要生成成功 | 永久保留 |
| `~/Meetings/error/` | 失败隔离区（附 .log） | 任一步失败 | 人工处理 |

**纪要文件命名**：`YYYY-MM-DD-<会议名>.md`，会议名取音频文件名主干（`meet` CLI 用用户给的标题命名）。

**纪要 md 结构**（frontmatter + 五段 + 折叠逐字稿）：

```yaml
---
type: meeting-minutes
date: YYYY-MM-DD
source_audio: <归档路径>
duration: <mm:ss>
speakers: [说话人1, 说话人2]   # 人工改真名处
---
## 会议主题 / ## 关键结论 / ## 待办（谁·何时） / ## 分歧与遗留 / ## 下一步
<details><summary>逐字稿</summary> [mm:ss] [说话人N] 文本… </details>
```

**中间产物**：转写 JSON（whisperx 原生输出，segments 含 start/end/text/speaker），随音频进 archive（复跑纪要不必重转写）。

## 接口 / 协议

| 接口 | 签名 | 行为 |
|---|---|---|
| 录音 | `meet start [标题]` | ffmpeg 后台录内置麦（16kHz mono m4a），PID 与元数据写临时文件；重复 start 报错 |
| 录音 | `meet stop` | 停止 ffmpeg，产物移入 inbox（触发管线）|
| 管线 | `pipeline.sh <音频>` | 转码→转写(+分离)→纪要→落 vault→通知→归档；幂等：同名纪要已存在则加序号 |
| 纪要 | `claude -p < 拼装的prompt` | 输入=minutes prompt + 带说话人逐字稿；输出=纯 md 正文 |
| 自动化 | launchd WatchPaths=inbox | 事件触发跑 pipeline 的「扫 inbox」模式，串行处理所有待办文件 |

**环境契约**：whisper CT2 模型**固化在项目 `models/` 目录**（源=ModelScope pengzhendong/faster-whisper-large-v3-turbo；2026-07-13 实测 hf-mirror 已失效、HF 直连不通，见 PROGRESS Deviations D-01），whisperx 走本地路径，运行时零下载依赖；`HF_TOKEN` 从 `~/.config/meet-scribe/env` 读（S3 说话人分离用）；whisperx 装在项目自有 venv，管线用绝对路径调用，不依赖用户 shell PATH（launchd 环境干净）。

## 关键约束

1. **免费硬约束**：管线内禁止出现任何按量计费调用（云 ASR/云 LLM API）。纪要只走 `claude -p`（订阅）。
2. **launchd 环境**：hook/plist 里一切命令用绝对路径；不 source 用户 profile。
3. **防重复处理**：处理前先 `mv` 到 processing（mv 同盘原子），WatchPaths 重复触发无害。
4. **iCloud 同步半成品**：拾取前检查文件 5 秒内 size 稳定才处理（防抓到传输中的文件）。
5. **失败必留痕**：任一步失败→音频+日志进 error/ + 系统通知失败原因，不静默吞。
6. **转写语言**固定 `zh`，模型固定 large-v3-turbo（改动=决策，回填本文件）。

## 反模式

- ❌ 在 launchd 里常驻 daemon 轮询（用事件 WatchPaths，跑完即退）。
- ❌ 纪要 prompt 里让模型编造发言（prompt 必须声明「只依据逐字稿」）。
- ❌ 用 `length/4` 估中文 token（踩过：偏低 4 倍）——逐字稿超长时按字符数×1.8 估，超限分段摘要再汇总。
- ❌ 把 whisperx 装进全局 Python / 依赖 shell PATH。
- ❌ verify 靠人读输出判断——一律 grep/test/exit code 自证。

## 切片关联 — Related Context

| 切片 | Related | Affected | Out of scope |
|---|---|---|---|
| S1 录音入口 | SPEC·接口/录音 | meet CLI、inbox 产生文件 | 转写及以后；系统音频 |
| S2 转写 | SPEC·环境契约 | venv、whisperx 调用、转写 JSON | 说话人分离（S3）、纪要 |
| S3 说话人分离 | SPEC·数据模型/中间产物 | 转写 JSON 增加 speaker 字段 | 声纹认人 |
| S4 纪要 | SPEC·纪要 md 结构 + prompts | vault 落盘、md 结构 | 通知/归档（S5） |
| S5 自动化 | SPEC·目录契约/关键约束 2-5 | launchd plist、通知、归档、error | iPhone 侧配置 |
| S6 iPhone 入口 | SPEC·目录契约 | iCloud 目录→inbox 接线 | 手机端自动化（快捷指令进阶） |

## 端到端验证步骤（收尾）

```bash
cp fixtures/meeting-2spk.wav ~/Meetings/inbox/ \
 && sleep <管线时长> \
 && test -f ~/ObsidianVault/meetings/$(date +%F)-meeting-2spk.md \
 && grep -q "待办" ~/ObsidianVault/meetings/$(date +%F)-meeting-2spk.md \
 && grep -q "说话人" ~/ObsidianVault/meetings/$(date +%F)-meeting-2spk.md \
 && test -f ~/Meetings/archive/meeting-2spk.wav \
 && echo E2E_PASS
```
