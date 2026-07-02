# Goal-Driven for Claude Code

> 你只给**一句话目标**。插件的 subagent 自动把它提炼成规格、合成**可执行判据 + 对抗测试**、**对抗式自审**判据是否可信;审核盖章后,主 CC 在**对话里**当 master,反复派 worker 干活,直到判据**真正**全绿——全程不进终端、无需人工按小时干预。

控制论**负反馈**在 coding agent 上最直接的实践:

- **判据(`CRITERIA.sh`)= 传感器**,客观测量"目标达成没有"。
- **master = 对话里的主 CC**(+ Stop-hook 兜底),判据不过就派 worker、绝不提前收手。
- **worker(子代理,独立上下文)= 执行机构**,读失败项做最小真实改动。

命门在于:**传感器测错了,反馈越强越自信地收敛到错的地方**。所以本项目把最大精力放在**自动构建 + 自动审核判据**上,并把"自动审核"做成**客观的变异测试**,而不是"再让一个 LLM 觉得行"。

---

## 两层嵌套闭环

```
一句话目标
   ▼
┌ 环 A:判据构建(全 subagent 自动) ────────────────────────────┐
│ goal-analyst      一句话(+2~3 反问)→ 结构化 GOAL.md          │
│ criteria-designer GOAL → CRITERIA.sh(记分板)+ 测试 + 对抗基线 │
│ criteria-auditor  gdcc audit(机械)+ 覆盖复核 → 不达标打回      │
│                   达标 → gdcc seal(验"未实现必挂"+ 锁校验和)    │
└──────────────── 判据可信、已盖章 ────────────────────────────────┘
   │  (硬门:未盖章不许进环 B)
   ▼
┌ 环 B:解构建(master = 对话里的主 CC,全程不进终端) ───────────┐
│ while (判据不过) { 派 goal-worker 子代理修失败项 → 重跑判据 }    │
│ 判据连续 k 次过 → 起 goal-verifier 复核作弊/软条件 → 真达成才停   │
│ Stop-hook 兜底:主 CC 想提前停就拦下,重跑判据逼着继续           │
└──────────────────────────────────────────────────────────────────┘
```

---

## 安装(标准插件,一键)

本仓库既是**插件**又是**市场**:

```
/plugin marketplace add <owner>/goal-driven-cc
/plugin install goal-driven@goal-driven-cc
```

启用后得到:命令 `/goal-driven:new|run|status`;子代理 `goal-analyst / criteria-designer / criteria-auditor / goal-worker / goal-verifier`;裸命令 `gdcc`、`gd-audit`;两个 hook(Stop 门 + PreToolUse 守卫,**仅任务 arm 后生效,平时零干扰**)。

---

## 快速开始

**全自动建立一个目标(对话里):**
```
/goal-driven:new 实现一个线程安全的 LRU 缓存,容量满时淘汰最久未用项
```
Claude 会:反问 2~3 问 → 写 GOAL → 造判据+对抗基线 → 自审到盖章 → 让你确认。满意后 `/goal-driven:run` 就在**同一个对话里**跑到判据全绿。

**先体会机械管线(内置示例,零 LLM 消耗):**
```bash
cd examples/is-prime
gdcc check     # 记分板,当前 FAIL
gdcc audit     # empty/cheat 必挂、reference 必过、无 flaky、够快 → PASS
gdcc seal      # 审核过 + 确认"未实现必挂" + 锁校验和
gdcc run       # 无人值守外部循环(或直接在对话里 /goal-driven:run)
```

---

## 判据 = 逐条记分板(master 看得到"为什么失败")

`CRITERIA.sh` 每条验收要求一行,用两个助手:

```bash
check C1 "单元测试通过"   -- python3 -m unittest discover -s tests -q   # 确定性:能测的
check C2 "p95 < 200ms"    -- python3 bench/p95.py --max-ms 200
soft  C3 "报告清晰"       judge/c3.md "报告是否含 p95 数字及测法?"       # 软条件:调独立严格判据
```

跑出来是逐条记分板,master(和 Stop-hook)据此把 `[FAIL]` 条目连原因派给 worker:

```
[PASS] C1    单元测试通过
[FAIL] C2    p95 < 200ms
         | p95=240ms exceeds 200ms
RESULT: 1 criterion(s) FAILED   → exit 1
```

**软条件(`soft` / `gdcc judge`)**:无法机械判定的要求(文案/设计),交给一个**全新、只读、严格、独立于 worker** 的 `gdcc judge` 实例裁决,折成 0/1 进记分板。于是同一个退出码契约同时覆盖"硬"和"软",Stop-hook 一并强制。纯不可机械验证的目标,`CRITERIA.sh` 可以只有 `soft` 行。

---

## 判据审核:把"自动审核"变成客观事实

`gdcc audit` 用对抗-变异实测校准传感器。盖章前判据必须通过:

| # | 元判据 | 机械验证 | 防的是 |
|---|---|---|---|
| 2 | 判别力下界 | `baselines/empty/` 空解必判 **FAIL** | 判据太松 |
| 3 | 判别力上界 | `baselines/reference/` 参考解必判 **PASS**(可选) | 判据太严 |
| 4 | 不可作弊 | `baselines/cheat_*/` 作弊解必判 **FAIL** | reward-hacking |
| 5 | 无 flaky | 连跑 N 次结论一致 | 传感器抖动 |
| 6 | 够快 | 单次判据 < 预算 | 循环不起来 |

缺 `empty/` 或 `cheat_*/` 直接失败(fail-closed)。语义覆盖(元判据 7)由 `criteria-auditor` 做覆盖矩阵复核。

`gdcc seal` 盖章时还会:**验证判据对未实现的代码判 FAIL**(否则判据是空的)+ **锁定判据校验和**——之后 worker 若偷改 `CRITERIA.sh`,Stop-hook 和 `gdcc run` 会检测到校验和不符并停机报警。

---

## 完成判定:pass^k(不靠侥幸)

判据要**连续 `GDCC_CONSECUTIVE_PASSES` 次通过**才算达成(默认 2)。这防"某轮侥幸"或"软判据抖动"。全绿后主 CC 还会起一个独立 `goal-verifier` 做最终防作弊 + 软条件复核,verdict 为 `ACHIEVED` 才真正停。

---

## 命令参考

**Skills**

| 命令 | 作用 |
|---|---|
| `/goal-driven:new <一句话>` | 环 A:澄清→设计判据→自审→盖章(不启动 worker) |
| `/goal-driven:run` | 环 B:主 CC 当 master,在**对话里**循环到判据真过 |
| `/goal-driven:status` | 看记分板、盖章/校验和、进度、下一步建议 |

**`gdcc` 子命令**

| 子命令 | 作用 |
|---|---|
| `gdcc init` | 脚手架 `.goal-driven/` |
| `gdcc check` | 跑判据一次,打印记分板 |
| `gdcc judge --rubric <f> "<问题>"` | 起独立严格 verifier 判一个软条件,返回 0/1 |
| `gdcc audit` | 机械变异审核 |
| `gdcc seal` / `unseal` | 盖章(审核+基线+校验和)/ 撤销 |
| `gdcc run [--max N] [--force] [--dry-run]` | 外部无人值守闭环(未盖章拦截) |
| `gdcc status` / `arm` / `disarm` / `stop` / `resume` | 状态 / 开关会话门 / 停止恢复 |

---

## 模型分层(默认关,可按需开)

默认**所有 agent 都继承你的会话模型**(不分层)。想省钱/提速再开:

- worker 换便宜模型:编辑 `agents/goal-worker.md` 的 `model: inherit` → `sonnet`;或外部循环设 `GDCC_MODEL=sonnet`。
- 设计/审核/verify 想更强:把对应 agent 的 `model:` 设为 `opus`。
- 软判据模型单独设:`GDCC_JUDGE_MODEL`。

推荐分层(可选):worker→sonnet,designer/auditor/verifier→opus。

---

## 配置(`.goal-driven/config.env`)

```bash
GDCC_MODEL=""                 # 外部循环 worker 模型;"" = 继承(不分层)
GDCC_MAX_ITERS=100            # 迭代上限(也是 Stop-hook 上限)
GDCC_MAX_DURATION=0           # gdcc run 墙钟上限秒(0=关)
GDCC_CONSECUTIVE_PASSES=2     # pass^k:连续几次过才算达成
GDCC_STALL_LIMIT=5            # 判据输出连续 N 轮不变则停
GDCC_NOPROGRESS_LIMIT=3       # 代码连续 N 轮零改动则停
GDCC_JUDGE_MODEL=""           # 软条件 verifier 模型
GDCC_PERMISSION_MODE="acceptEdits"
GDCC_SAFETY_PROFILE="standard"  # strict 还会挡 force-push/hard-reset
GDCC_CRITERIA_BUDGET=120      # 单次判据最长秒(元判据6)
GDCC_DETERMINISM_RUNS=3       # 无 flaky 复跑次数(元判据5)
```

---

## ⚠️ 安全须知

无人值守 = agent 自动改文件/跑命令、无人逐条确认。请:

- 在**一次性/可丢弃的 git 仓库或容器**里跑;`GDCC_COMMIT=1` 每轮快照可审计可回滚。
- 环境里**不放密钥**;假设 worker 能碰到 shell 能碰到的一切。
- 任务 arm 后,PreToolUse 守卫**硬禁 `git commit --no-verify`**(strict 档还挡 force-push/hard-reset);破坏性命令会记 `logs/governance.log`。
- 完全放开需 `GDCC_PERMISSION_MODE=bypassPermissions`,只在沙箱用。
- 只对**可自动验证**的目标使用;`goal-analyst` 会拒绝无法客观判定的目标。
- worker 禁止篡改判据(校验和锁 + `goal-verifier` 抽查);判据全绿仍建议人工瞄一眼 diff。

---

## 目录结构

```
goal-driven-cc/                     # 仓库根 = 插件根 = 市场根
├── .claude-plugin/{plugin,marketplace}.json
├── skills/{new,run,status}/SKILL.md
├── agents/{goal-analyst,criteria-designer,criteria-auditor,goal-worker,goal-verifier}.md
├── hooks/hooks.json                # Stop→stop-gate.sh, PreToolUse→guard.sh
├── bin/{gdcc,gd-audit}             # 自动进 PATH 的裸命令
├── scripts/{stop-gate,guard}.sh
│   └── lib/{common,check,audit,judge}.sh
├── templates/  examples/is-prime/  README.md  LICENSE  CHANGELOG.md
```

每个任务状态在**你项目**的 `.goal-driven/`(GOAL/CRITERIA/baselines/config/PROGRESS + 运行时 logs/state);仓库 `.gitignore` 忽略运行时产物。

---

## 语言约定

面向 Claude 的 prompt(agents/skills/worker)一律**英文**;面向你的阶段汇报、澄清提问、状态总结、master 输出用**简体中文**。

## 局限

- 只适用于**可自动验证**的目标;不可机械判定的用 `soft`/`gdcc judge`,但那是有噪声的传感器(靠 pass^k + 独立实例 + 你的复核兜底)。
- 长跑成本真实存在:每轮一次完整 agent 调用,`GDCC_MAX_ITERS/MAX_DURATION/CONSECUTIVE_PASSES` 是你的护栏。

MIT License.
