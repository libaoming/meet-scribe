# Spike：sherpa-onnx 做说话人分离（Rust 侧可行性）· 2026-08-11

> 服务于「会议记忆体」新项目的 D3 决策（说话人分离选型）。meet-scribe 本身不改动——
> 它在这里的身份是**已验证的技术来源**：提供 fixture、pyannote 基线与模型。

## 结论

**D3 拍板 sherpa-onnx，头号未知解除。** 在同一 fixture 上质量与 pyannote 并列、速度快 3.7 倍、
体积小一个数量级，且 Rust 绑定官方支持 —— Tauri 打包不再需要 Python sidecar，D4（Tauri）技术栈站得住。

| 指标 | sherpa-onnx | pyannote community-1（现有基线） |
|---|---|---|
| DER（collar=0.25，学界惯例） | **0.00%** | **0.00%** |
| DER（collar=0，严格） | 1.53% / **1.07%**（int8） | 1.27% |
| 说话人数 / 段数 | 2 / 6 ✅ 全对 | 2 / 6 ✅ 全对 |
| 说话人混淆 | 0.00% | 0.00% |
| 分离耗时（46.29s 音频） | **5.47s（8.5x 实时）** | 20.11s（2.3x 实时） |
| 模型加载 | **0.09s** | 3.02s |
| 运行时体积 | onnxruntime 28M + c-api 4.1M ≈ **32M** | torch **373M** + pyannote 3.6M + 依赖 |
| 模型体积 | seg int8 1.5M + emb 38M ≈ **39.5M** | 31M |
| **打包总增量** | **≈ 72M** | **≈ 410M+** |
| Rust 绑定 | ✅ 官方 `rust-api-examples/run-offline-speaker-diarization.sh`；第三方 `sherpa-rs` 0.6.8（77k 下载）有 `examples/diarize.rs` | ❌ 只能 Python sidecar |

**int8 量化版反而更准**（严格 DER 1.07% vs fp32 1.53%），且 segmentation 模型从 5.7M 降到 1.5M —— 直接用 int8。

## 用的模型

两个都来自 GitHub Releases，**国内直连可下**（实测 200，无需 HF / ModelScope 绕行）：

```
segmentation: sherpa-onnx-pyannote-segmentation-3-0.tar.bz2   （解压后 model.int8.onnx 1.5M）
embedding:    3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k.onnx   （38M，中文）
```

注意 sherpa 的 segmentation 模型**就是 pyannote segmentation-3.0 转的 onnx**，
所以「质量与 pyannote 并列」是预期内的结果，不是巧合；差异只在 embedding 与聚类实现。

## 复现

```bash
cd docs/spike-sherpa
bash make_gt.sh                              # 重建 ground truth（复刻 gen_fixture.sh 的合成流程）
python diarize_sherpa.py <wav> out.rttm --int8
python der.py gt.rttm out.rttm --collar 0.25
```

**ground truth 的可信度**：`make_gt.sh` 完整复刻 `fixtures/gen_fixture.sh` 的合成流程并逐段量真实时长，
重建总时长 46.289s vs fixture 实际 46.289688s，**误差 0.7 毫秒** —— GT 不是估的。

`der.py` 是自写的帧级 DER。注意 collar 的实现：标准做法是把参考段边界 ±collar 的帧
**从评分中双向排除**（ref 和 hyp 都不计）。第一版只内缩了 ref，导致 collar 区被误记成虚警、
虚报 9.78% 的 DER —— 已修正，用这份数字前请确认 `collar_mask()` 还在。

## 风险 / 待验证

- 🚨 **fixture 的难度是被人为降低过的**。`gen_fixture.sh` 里把说话人 B 变调 -4 半音，
  原因写在注释里：「两个 say 音色都偏女声，embedding 距离不够会被聚成一人」。
  也就是说 **0.00% DER 是在一个刻意放宽的样本上取得的**，两条路线都吃了这个便宜。
  正确的结论表述是「同等难度下 sherpa 不劣于 pyannote」，**不是**「sherpa 在真实会议够用」。
- 只测了 2 人。3 人以上、抢话重叠、混响串音全部未测 —— 与 U1（真实录音 fixture）合并验证。
- 只测了 macOS arm64。
- **未做 Rust 侧真实编译链接**，只确认了官方 example 与 crate 存在。首次接线时仍可能踩
  构建/交叉编译的坑，建议在新项目 S0 收尾前跑通一个最小 Rust demo 再关闭这个未知。

## 兜底方案（若真实场景翻车）

v1 退到**双轨分离**：麦克风一轨（我）、CoreAudio tap 一轨（远端），天然两个说话人，不需要任何模型。
覆盖线上会议的绝大多数场景，把多人分离推到 v1.1。这个降级很干净，不影响记忆层的任何设计。

## 相关

- 转写侧选型见 `spike-speechanalyzer.md`（Apple SpeechAnalyzer，46s → 0.54s）
- 两个 spike 合起来看：新项目的「采集 → 转写 → 分离」三层全部不需要 Python，可以整体进 Rust/Tauri
