# CLAUDE.md — meet-scribe

> 线下会议自动录音→本地 WhisperX 转写+说话人分离→claude -p 生成纪要，自动落 Obsidian vault；触发=录音文件落盘(launchd WatchPaths)，全链路免费离线

本项目采用 harness 方法论 + 4 层防御体系（Anthropic "Effective Harnesses for Long-Running Agents" + 得物 Harness 工程实践）。

## 入会顺序（每次新 session）
1. **先读 `STATUS.md`** —— 一句话状态 + 下次入口 + 踩坑清单
2. 再读 `PRD.md` / `SPEC.md` / `architecture.md` / `features.json`（三件套覆盖需求/方案/切片）
3. 开工前跑 `bash M1/init.sh` 确认环境全绿

> 🤖 **增量流水合并（每次启动先做）**：若 `M1/PROGRESS.md` 有「🤖 增量流水（待整理）」块（Stop hook 每轮自动追加的原始请求），**先合并进正式 Session Log、清空该块，再开工**。

> 🧹 **本文件当代码对待（Anthropic best-practices）**：Claude 做错一次的事就写进来；定期 prune——每行自问「删掉会让 Claude 犯错吗」，不会就删（规则被噪声淹没=没有规则）；每条约束都是对模型当前能力的临时假设，模型升级后主动做减法。

## 仓库结构
```
meet-scribe/
  CLAUDE.md              本文件（L1 持久化 + L4 隔离纪律）
  STATUS.md              新 session 入口（L1）
  PRD.md / SPEC.md / architecture.md   文档先行三件套（L2 输入源）
  features.json          原子 feature 单一事实源（L2）
  CONTEXT.md             上下文构成审计（CE 产物，LLM 项目才有 → context-engineering-kit）
  M1/         里程碑三件套（init.sh / AGENTS.md / PROGRESS.md）
  fixtures/              fixture（先于代码，含 README 索引）
  .claude/agents/        项目专属子 agent（L4 脏活隔离）
```

---

## 4 层防御体系（本项目的工程底座）

### L1 持久化层
业务语义 / 规则 / 进度从不可靠的 LLM 记忆迁到确定性文件：`CLAUDE.md`（规则）+ `STATUS.md`（进度，每次 session 收尾必更新）+ Auto Memory（跨会话）。

### L2 方法论层（开发纪律）
- `features.json` 是**单一事实源**：status ∈ {pending, in_progress, failing, passing}，**verify 真跑通才能改 passing**
- 📐 **技术方案先于开发（人工评估闸）**：开发任一 feature/功能前先写技术方案（问题定位 / 机制 / 选型权衡 / 实现路径 / 守约 / verify 口径 + 待定决策点），落 `docs/proposals/`（待评估），**交用户评估通过才进开发**。区别于下条 verifier 硬闸门（机器可验证）——这是**人工设计评审闸**，挡"方案没想清就开撸"；通过后转 ADR → 进切片
- 🚦 **verifier 硬闸门**：feature 的 `verify` 字段为空 = **不准开工**（不能离开 pending）。每个目标必须带可衡量的成功信号——"没有验证机制的目标只是许愿"
- 🧭 **三段式关联**：每个 feature 必须填 `related`/`affected`/`out_of_scope`，让 subagent 秒判"读哪些、不读哪些"，对治 context 膨胀（OpenSpec Related Context 实践）。`out_of_scope` 同时防 AI 联调复刻隐性功能
- **线性切片**推进：每切片有 exit_criteria + git_tag，完成才进下一个
- **fixture 先于代码**：verify 引用的 fixture 不存在就先造，不许 mock、不许"等真数据"
- 三件套放 `M1/` 子目录，不放根目录

### L3 自动化钩子层
确定性自动化放项目级 `.claude/settings.local.json`（local 不入 git）。**已内置一对 Stop hook**：
- `stop-progress-append.sh`（异步）——每轮把用户请求增量追加到 `M1/PROGRESS.md` 的「增量流水」区，扛关电脑、不调 LLM。
- `stop-verify-claims.py`（同步）——**防造假收口闸**：末轮出现「已写/已落盘/File created + 文件名」或交付表 `path`（N 行）时逐一 `test -f`，有声称却磁盘不存在的文件就 exit 2 拒绝收口、把缺失清单喂回强制真核验。把 CLAUDE.md 的软规则「完成声明前先回读」在 Stop 边界机器化（缺 python3 自动降级 no-op，fail-open）。

其它按需加（session 启动注入 / 产物同步 / 提交前校验）。

### L4 上下文隔离层 ⭐
把"吃大量 context 的脏活"派给子 agent（**Agent 工具, `subagent_type=general-purpose`** 或下方项目专属子 agent）在独立 context 跑完，**只回结论**；主 context 保持干净，专注改代码决策 + 跟用户对话。

**必须隔离的脏活（派子 agent，prompt 自包含）**
- 大文档检索：PRD/SPEC/大 features.json/长日志 → 子 agent 读完只回「相关切片 / 答案」，主 context 绝不整文件 Read
- 远程/生产状态核查：ssh 日志、systemctl、容器日志（动辄上千行）→ 子 agent 只回结论
- 大数据/transcript 分析 → 子 agent 只回诊断结论

**留主线（不外包）**：改代码、架构决策、跟用户对话、verify 判定

**🚨 子 agent 铁律**
1. prompt **完全自包含**：写死路径、命令、远程 alias（子 agent 冷启动看不到对话）
2. **远程/生产只读**：对线上只允许 `systemctl is-active` / `journalctl` / `docker logs` / `grep` / `cat` 这类只读命令
3. **改动只在本地**：不擅自 `git push` / `pull` / 重启线上 / 改生产配置；部署是用户显式触发的独立动作

---

## 上下文工程纪律（LLM 项目）

若本项目调用 LLM（agent / chat / 工作流），`CONTEXT.md` 是 harness 四件套的第四件（`features.json` + 三件套 + **CONTEXT.md**）：
- **开工前**：写第一行 LLM 调用代码前先画 `CONTEXT.md`（7 层上下文构成 + 暗物质审计）
- **改动前**：改任何 system prompt / 上下文拼装代码前先读 CONTEXT.md
- **改动后**：回填 CONTEXT.md，防文档腐烂
- 模板与方法 → [context-engineering-kit](https://github.com/libaoming/context-engineering-kit)

## verify 纪律
- **开工闸门**：`verify` 字段为空的 feature 不准动（停在 pending），先定义可衡量的成功信号再开工
- `features.json` status：单测通过只到 `in_progress`；**真实端到端 verify 通过才能改 `passing`**
- verify 通过的细节写进 feature 的 `verify_notes`
- 🚫 **反安慰性重跑**：同一条 verify 命令，在**代码没改**的情况下不重复跑——未改代码重跑不产生新信息，只制造「又绿了」的完成错觉。要么改了代码再跑，要么就依上一次输出下结论。
- 📋 **恒定完成门**：per-feature 的 `verify` 之外，每个改动还要过 `DEFINITION_OF_DONE.md`（全项目不变的底线：运行时验证过行为 / 测试先红后绿 / 新模块真被链接住 / 无回归）。二者正交，缺一不算 done。

## 收尾交付格式（Change Summaries 三段）

非琐碎改动收尾时，向用户输出三段——把「克制、没越界翻修」变成必须书写的交付物（吸收自 addyosmani/agent-skills 的 git-workflow Change Summaries，是本仓「外科手术式改动 + Deviations 协议」的可执行化）：

```
CHANGES MADE            —— 改了什么（逐条，可追溯到本次需求）
THINGS I DIDN'T TOUCH   —— 我刻意没碰什么、为什么（证明守了 scope discipline；
                           看到但没动的问题在这里列，问用户要不要单开 task）
POTENTIAL CONCERNS      —— 遗留顾虑 / 偏差 / 不确定项（接 Deviations 逐条核对）
```

> 「THINGS I DIDN'T TOUCH」段是重点：多数计划外翻修就死在「顺手改了但没说」，写出来 = 强制自己交代边界。

## 命名约定
（按需补：git branch / docker tag / 代码注释 vs 用户可见文案）
