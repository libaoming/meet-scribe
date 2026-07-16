# STATUS — meet-scribe

> 每次 session 第一个读的文件。收尾必更新本文件。

## 一句话状态
2026-07-13 M1 基本收官：F01–F06 全部 passing（E2E_PASS，launchd 无人工干预全链路），F07（iCloud 入口实测）后台验证中。系统已可用。

## 下次入口
1. 读本文件 → 读 `M1/PROGRESS.md`
2. 跑 `bash M1/init.sh` 确认环境
3. 待办：① F07 结果回填；② 用户第一次真实会议录音后，固化一段脱敏真录音做第二个 fixture（合成音跑通 ≠ 真实收音跑通）；③ vault 顶层新增 meetings/ 目录未登记进 vault CLAUDE.md schema（PRD·D5 可复议）；④ 评估用 Apple SpeechAnalyzer(yap) 替换 whisperx+wav2vec2 两层——spike 已验证（46s 中文 fixture 0.54s、词级时间戳、仅 1 同音字错），方案与风险见 `docs/spike-speechanalyzer.md`，走「技术方案先于开发」闸后再动 features.json

## 关键技术事实
- 全链路免费离线：whisperx(CPU int8) + pyannote community-1 + claude -p(sonnet)
- **模型全部固化在 `models/`（来源 ModelScope，非 HF）**：whisper large-v3-turbo CT2 1.6G + community-1(分离,33M) + wav2vec2-zh(中文词级对齐,1.2G)。hf-mirror 已死（308 回源），HF 直连不通——别改回 HF 路线
- 说话人分离无需 HF token（community-1 整仓本地化，含 PLDA）
- 逐字稿按**词级 speaker 聚合成 turn**渲染（whisper 粗段会跨说话人）
- launchd: `com.baoming.meet-scribe`，WatchPaths=~/Meetings/inbox + iCloud/MeetInbox
- 46s fixture 全链路（含纪要）约 3 分钟；1h 会议预估 15–25 分钟（待实测）

## 文档地图
- 需求：`docs/PRD.md`（决策 D1-D6）　方案：`docs/SPEC.md`　架构：`docs/architecture.md`　切片：`features.json`
- 用户手册：`docs/iphone-setup.md`（iPhone 入口操作）
- 里程碑三件套：`M1/`　fixture：`fixtures/`（gen_fixture.sh 可重生成）

## 踩坑清单
- macOS bash 3.2 + `set -u` 空数组展开报 unbound → `${arr[@]+"${arr[@]}"}`
- pyannote 4.x 默认 plda 参数必去 HF 拉 community-1，null 会 TypeError → 本地整仓 + config.yaml `$model` 相对路径
- pyannote embedding 加载按路径**子串**路由，wespeaker 权重路径不能含 "pyannote"
- 同性双 TTS 音色分离会聚成一人 → fixture 说话人B 变调 -4 半音
- `say` 合成音是分离困难样本；真实会议靠「手机放桌子中央」保收音
