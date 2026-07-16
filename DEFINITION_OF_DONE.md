# Definition of Done — meet-scribe

> **恒定完成门**。区别于 `features.json` 里每个 feature 各不相同的 `verify`（"这件事做对了吗"），本清单是**全项目每次改动都一样的底线**（"够不够格算完成"）。一个改动 done = 该 feature 的 `verify` 通过 **AND** 本清单全绿。二者正交、互补，不互相替代。
>
> 来源：吸收自 addyosmani/agent-skills 的 `references/definition-of-done.md`，对齐本仓「完成声明前先回读 / verify 闭环」纪律。

## Correctness（正确性）
- [ ] 代码**在运行时跑过、行为符合预期**——不是「编译过 / 类型过」就算数
- [ ] 新行为有测试覆盖，且该测试**没有这次改动会红、有了会绿**（先红后绿，立即通过的测试证明不了任何事）
- [ ] 原始需求 / bug 场景**端到端复现过一次**（跑用户入口，不是只 grep 自己写的函数）

## Quality（质量）
- [ ] 遵循项目既有约定（读过 CLAUDE.md，风格对齐，非按个人偏好）
- [ ] 改动范围只覆盖这次需求（外科手术式，无顺手翻修 / 无计划外重构）
- [ ] refactor 与 feature/bugfix **分开提交**，未混在一个 diff 里

## Integration（集成）
- [ ] 新写的模块**真被调用链接住**（有人 import / 有人调），不是孤岛死代码
- [ ] build / lint / typecheck 全过
- [ ] 无回归：相关既有测试仍全绿

## Documentation（文档）
- [ ] 重大 / 难逆的决策留了痕（ADR / STATUS / feature 的 verify_notes）
- [ ] 影响他人的接口变更、gotcha 就地记录

## Ship-readiness（可交付）
- [ ] `features.json` 里本 feature 的 status 依真实 verify 输出更新（单测过只到 `in_progress`，端到端 verify 过才 `passing`）
- [ ] 收尾交付附「Change Summaries 三段」（改了什么 / 没碰什么 / 遗留顾虑）——见 CLAUDE.md

---

### Red Flags（出现即视为「未完成」）
- 🚩 **「做完了，我只是还没跑」——没验证过的工作不算完成。**
- 🚩 「测试过了」被当成「完成」的同义词，而运行时行为验证 / 文档 / 回归被跳过。
- 🚩 同一条命令在**代码没改**的情况下重复跑，用「又绿了」制造完成的错觉——未改代码重跑不产生新信息。
