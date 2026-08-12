# 提案：录音时长硬上限 + 超时自动收尾

- 日期：2026-08-09
- 状态：**待评估**（按 CLAUDE.md「技术方案先于开发」闸门，评估通过才进开发）
- 触发事件：一次真实失控 —— `2026-08-06-1002-会议` 录了 **3 天 8 小时**，产出 431MB 文件，全程占用麦克风

---

## 1. 问题定位

### 现象（实测证据）

```
ffmpeg -v error -f avfoundation -i :default -ac 1 -ar 16000 -c:a aac -b:a 48k \
  /Users/baomingli/.local/state/meet-scribe/2026-08-06-1002-会议.m4a
PPID=1   ELAPSED=03-08:12:40   文件 431278906 字节
```

用户 8月6日 10:02 开完会没跑 `meet stop`，录音一直持续到 8月9日 18:16 被手动 kill。副作用：

1. 磁盘持续增长（约 5.4MB/小时，无上限，理论上会写满磁盘）
2. **麦克风被独占 80 小时** —— 菜单栏常亮橙色指示器，用户误以为是终端语音输入
3. 无声无息 —— 没有任何提醒机制

### 根因（`bin/meet:23`）

```bash
nohup ffmpeg -v error -f avfoundation -i ":default" -ac 1 -ar 16000 -c:a aac -b:a 48k "$out" \
  > "$STATE_DIR/ffmpeg.log" 2>&1 &
```

**没有 `-t` 时长上限**。ffmpeg 会一直录到进程被杀或磁盘写满。整条链路上不存在任何自动终止条件 —— 唯一的出口是人记得跑 `meet stop`。

### 次生缺陷（连带发现）

| # | 位置 | 问题 |
|---|---|---|
| a | `bin/meet:35` | `stop` 只判断 `PID_FILE` 存在，不判断进程是否活着。ffmpeg 若已自行退出，`kill -INT` 静默失败（被 `\|\| true` 吞掉）后仍继续走 mv，逻辑侥幸能通但语义错乱 |
| b | 全局 | ffmpeg 若因任何原因自行退出（超时/设备拔出/磁盘满），录音文件滞留 `STATE_DIR`，**不会进 INBOX，管线永不触发** —— 用户以为录了，实际没纪要 |
| c | `bin/meet:16` | 陈旧的 `rec.pid`/`rec.meta` 会让 `start` 判断失误（本次事故清理后即遇到，需手动 rm） |

---

## 2. 机制设计

### 核心：把「唯一出口是人」改成「保底出口是时间」

给 ffmpeg 加 `-t $MEET_MAX_SEC`（默认 4 小时）。到点 ffmpeg 自行优雅收尾，写出完整可播放的 m4a。

### 关键设计选择：统一收尾路径

超时自停引入一个新问题 —— 到点后**谁负责把文件搬进 INBOX 触发管线**（缺陷 b）。

现状是 `meet stop` 负责 mv。若只加 `-t` 不管搬运，超时录音就变成"录了但没纪要"的哑文件，比现在更糟（用户以为万无一失，实际静默丢失）。

**方案：用 wrapper 子 shell 收口，让"搬运"只有一条路径。**

```
meet start
  └─ nohup bash -c '
       ffmpeg -t $MAX ... "$out" &      # ffmpeg 真实 pid 写进 PID_FILE，
       echo $! > $PID_FILE              # 保证 meet stop 的 kill -INT 仍直达 ffmpeg
       wait                             # 等它结束（无论是超时自停还是被 stop 中断）
       [[ -s "$out" ]] && mv "$out" "$INBOX/"   # 统一在此搬运 → 触发 launchd 管线
     ' &
```

两条终止路径在 `wait` 处合流，之后共用同一段收尾逻辑：

| 终止方式 | ffmpeg 如何结束 | 谁搬运 |
|---|---|---|
| 用户 `meet stop` | `kill -INT` → 优雅退出 | wrapper |
| 超时 4 小时 | `-t` 到点自退 | wrapper |

**无竞争**：`meet stop` 不再自己 mv，只负责发信号 + 等待文件出现在 INBOX。搬运动作全局唯一。

---

## 3. 选型权衡

| 方案 | 做法 | 取舍 | 结论 |
|---|---|---|---|
| A. 仅加 `-t` | ffmpeg 加时长上限，其余不动 | 改动最小；但超时录音滞留 STATE_DIR 不进管线，静默丢失（缺陷 b 恶化） | ❌ |
| **B. `-t` + wrapper 统一收尾** | 如上 | 多一层 bash 进程；收尾路径唯一、无竞争、超时也进管线 | ✅ **推荐** |
| C. launchd 定时巡检 | 独立 agent 定期扫描超时录音 | 需要新增 plist、新增状态机；与现有 WatchPaths 管线职责重叠 | ❌ 过度设计 |
| D. 到点提醒不自停 | 4 小时发通知，人来决定 | 人不在电脑前就等于没有保护 —— 本次事故正是此场景（会开完人走了） | ❌ 不解决问题 |

选 B。理由：**保护机制不能依赖人在场**，而 A 的"静默丢失"违反最小惊讶原则 —— 宁可自动交付一份 4 小时的纪要，也不要留一个用户不知道存在的哑文件。

### 时长取值

默认 **4 小时 = 14400 秒**，可用环境变量 `MEET_MAX_SEC` 覆盖。

依据：实测 `work/*.json` 里全部历史会议的转写时长 ——

| 会议 | 时长 |
|---|---|
| 2026-07-30-1857 | 61 分钟（最长） |
| 2026-07-15-1016 | 38 分钟 |
| 2026-07-17-1656 | 25 分钟 |

最长 61 分钟。4 小时 = 最长实际值的 **4× 余量**，正常会议不可能触顶；同时把失控上限从"无限"压到单次 ~22MB，且**麦克风占用绝不过夜**。

---

## 4. 实现路径

改动集中在 `bin/meet` 单文件，三处：

1. **`start`**：加 `MAX_SEC=${MEET_MAX_SEC:-14400}`；ffmpeg 加 `-t "$MAX_SEC"`；套 wrapper 子 shell 承担搬运；启动回显补出自停时刻
2. **`stop`**：改为「发 INT → 等 wrapper 把文件搬进 INBOX → 报告」；补进程已死的分支（缺陷 a）；补陈旧状态文件自愈（缺陷 c）
3. **`status`**：显示已录时长 + 距自停剩余时间；发现 PID 已死时自动清理陈旧状态文件

不碰：`bin/pipeline.sh`、launchd 配置、models/、转写与纪要逻辑。

---

## 5. 守约（不变量）

- `meet start` → `meet stop` 的正常路径行为**完全不变**（文件名、落点、管线触发时机一致）
- 4 小时内的会议**感知不到任何差异**
- `PID_FILE` 中始终是 **ffmpeg 的真实 pid**（不是 wrapper 的），保证既有的 `kill -0` 存活检测和 `kill -INT` 优雅停止语义不破
- 录音文件搬进 INBOX 的动作全局**有且仅有一处**

---

## 6. verify 口径（feature F08）

新增 `F08_recording_timeout`，verify 用**缩短上限**的方式做真实端到端，不等 4 小时：

```bash
# 1. 超时自停 + 自动进管线（核心断言）
MEET_MAX_SEC=5 meet start verify-timeout
sleep 9
test ! -e ~/.local/state/meet-scribe/rec.pid           # 状态已清理
ls ~/Meetings/inbox/*verify-timeout*.m4a               # 文件已自动进 INBOX ← 关键
meet status | grep -q '○ 未在录音'

# 2. 正常 stop 路径无回归
MEET_MAX_SEC=3600 meet start verify-normal
sleep 3 && meet stop
ls ~/Meetings/inbox/*verify-normal*.m4a

# 3. 陈旧状态文件自愈
echo 99999 > ~/.local/state/meet-scribe/rec.pid
meet status | grep -q '○ 未在录音'
```

EXIT=0 为过。三条全绿才可标 `passing`（按 `DEFINITION_OF_DONE.md`，需运行时验证过真实行为，非仅单测）。

⚠️ verify 会真实占用麦克风数秒并产生纪要管线任务，跑之前确认没有正在进行的真实录音。

---

## 7. 待定决策点（需你拍板）

| # | 决策 | 我的推荐 | 备选 |
|---|---|---|---|
| D1 | 默认上限时长 | **4 小时** | 2 小时（更紧）/ 8 小时（容纳全天工作坊） |
| D2 | 超时后是否自动送管线转写 | **是**（否则静默丢失） | 否：只停录，文件留 STATE_DIR 等人工处理 |
| D3 | 超时是否发 macOS 通知 | **是**，`osascript` 一行，零依赖 | 否：保持静默 |

---

## 8. 范围外（本提案不做）

- `F07_icloud_inbox`（仍 pending，与本提案无关）
- 磁盘配额检查 / 老录音自动归档 —— 是独立问题，值得单开 feature，不塞进本次
- 那份 431MB 事故录音的处置 —— 用户已决定保留原地，不自动处理
