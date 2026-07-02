# Example: is-prime

一个能跑通的最小 goal-driven 任务,用来演示并冒烟测试整套机械管线(判据 + 审核 + 循环),不消耗任何 LLM 调用。

目标:在 `src/is_prime.py` 里实现 `is_prime(n)`,让 `tests/` 全绿。起始状态是未实现的桩(判据 FAIL)。

判据审核用的对抗基线(`.goal-driven/baselines/`):
- `empty/` —— 恒返回 False 的空解,判据必须判 **FAIL**(判别力下界)。
- `cheat_hardcode/` —— 只写死测试里可见的小质数,判据必须判 **FAIL**(防作弊:范围+随机对照挫败查表)。
- `reference/` —— 正确的试除法解,判据必须判 **PASS**(判别力上界)。

## 试一试(插件已启用时)

```bash
cd examples/is-prime
gdcc check          # 现在应为 FAIL(桩未实现)
gdcc audit          # 机械审核:empty/cheat FAIL、reference PASS、无 flaky、够快 → exit 0
gdcc seal           # 盖章
gdcc run            # 启动 worker 闭环,把 is_prime 真正实现到全绿
```

> 未启用插件时,可用绝对路径:`../../bin/gdcc check` 等。
