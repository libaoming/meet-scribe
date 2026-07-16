# fixtures 索引

verify 引用的 fixture 都在此。**fixture 先于代码**：feature 的 verify 指向的 fixture 不存在 → 先造，不许 mock、不许"等真数据"。优先设计"一段 fixture 养活多条 feature"的复用结构。

| fixture | 状态 | 用途 / 喂哪些 feature |
|---|---|---|
| `meeting-2spk.wav` | ✅ 已造（gen_fixture.sh 可重生成） | 双说话人中文合成会议（say Tingting/Meijia，42.6s，含「下周三」关键词+明确待办）；喂 F01/F03/F04/F05/F06/F07 全链路 |
| 真实会议录音 | 待补 | 用户第一次真实使用后，挑一段脱敏录音固化为第二个 fixture（合成音跑通 ≠ 真实收音跑通） |
