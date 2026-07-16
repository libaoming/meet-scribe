# M1 Session Kickoff（开新会话先读这份）

> 接班说明：不靠任何人讲背景，10 分钟内选到正确的下一件事干。
> 依据：Anthropic "Effective Harnesses for Long-Running Agents"。

## 0. 一句话定位
线下会议自动录音→本地 WhisperX 转写+说话人分离→claude -p 生成纪要，自动落 Obsidian vault；触发=录音文件落盘(launchd WatchPaths)，全链路免费离线

## 1. Session 启动 5 步
1. `cat M1/PROGRESS.md` → 看 active_feature / blockers / next_candidates
2. 读 `../STATUS.md` → 一句话状态 + 踩坑
3. `bash M1/init.sh` → 环境全绿才开工
4. 按"选 feature 算法"挑下一件事
5. 动手 → 收尾更新 PROGRESS.md + STATUS.md

## 2. 选 feature 算法
1. 优先 `status=failing` 且 `blocking=[]` 的最低编号 feature
2. 没有则取 `pending` 且依赖已 passing 的
3. 同一 slice 内做完再进下一 slice（线性切片）

## 3. 6 条硬规矩
1. **fixture 先于代码**：verify 引用的 fixture 不存在就先造，不许 mock
2. **verify 真跑通才改 passing**：单测过只到 in_progress
3. **不跳 slice**：当前 slice 的 exit_criteria 没达成不开下一个
4. **收尾必更新 PROGRESS.md + STATUS.md**
5. **偏差协议（Deviations）**：撞上边缘情况不得不偏离 SPEC/计划时——选保守选项 → 记进 PROGRESS.md 的「Deviations」栏 → 继续；收尾把 Deviations 逐条向用户核对，不静默改道
6. **对抗审查（切片收口前）**：派一个 fresh-context 子 agent 对照 SPEC/feature 条目审查刚完成的实现——「每条需求都实现了吗、边界有测试吗、范围外的东西没动吗」，**只报影响正确性的 gap**（Anthropic best-practices adversarial review；实现者不能自评）

## 4. commit 规范
`{feat|fix|refactor|docs}(feature_id): 描述`

## 5. 反模式
过早宣布胜利 / 一次性大包大揽 / 环境不可复现 / 缺端到端验证 → 对应修法见项目 CLAUDE.md L2。
