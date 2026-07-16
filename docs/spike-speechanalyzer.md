# Spike：Apple SpeechAnalyzer（yap CLI）做 ASR 后端备选 · 2026-07-14

## 结论
**强烈值得接入。** macOS 26 原生 SpeechAnalyzer（经 `yap` CLI，brew 已装 v1.2.0）在本项目 46s 中文 fixture 上：

| 指标 | SpeechAnalyzer (yap) | 现有 whisperx 链路 |
|---|---|---|
| 46s fixture 转写耗时 | **0.54s（~85x 实时）** | 全链路 ~3min（含分离+纪要） |
| 10min 拼接音频 | **3.7s（~163x 实时）** | 未单测 |
| 转写质量（对照 gen_fixture.sh 原文） | 仅 1 个同音字错（「引导页」→「引导业」），标点偏少、偶有空格残留 | 基线 |
| 词级时间戳 | ✅ `--json --word-timestamps` | 需 wav2vec2-zh（1.2G）对齐 |
| 模型下载 | 系统自带，0 下载 | models/ 共 ~2.8G |
| 说话人分离 | ❌ 无 | pyannote community-1（保留） |

复现命令：
```bash
yap transcribe fixtures/meeting-2spk.wav --locale zh-CN --srt
yap transcribe <f> --locale zh-CN --json --word-timestamps   # 词级时间戳
```

## 接入方案（建议，未实施）
- 替换 `whisperx ASR + wav2vec2 对齐` 两层：yap 出词级时间戳 → 与 pyannote turn 区间做 overlap 归属（现有 turn 聚合逻辑不变）。
- pyannote 分离、claude -p 纪要两层不动。
- 预期收益：1h 会议 ASR 从分钟级 → 秒级，全链路瓶颈只剩 pyannote；models/ 可瘦身 ~2.8G。

## 风险 / 待验证
- fixture 是 `say` 合成音（干净样本）；**真实会议收音下的 SpeechAnalyzer 质量未验证**——与 STATUS 待办②（真录音 fixture）合并验证。
- 标点/分句比 whisper 弱，对纪要生成影响待观察（claude -p 对无标点文本容忍度高，预计影响小）。
- yap 是第三方封装（finnvoor/tools），如需去依赖可自写 ~100 行 Swift 直调 SpeechAnalyzer。

## 旁支：小鹅通项目（xet-courses）
`batch_local.py` 现用 whisper.cpp large-v3；将 `whisper-cli` 调用换成 `yap transcribe --locale zh-CN --txt` 即可，875 节课预计数小时内本地转完、¥0，**火山充值放量的前置条件可以取消**。
